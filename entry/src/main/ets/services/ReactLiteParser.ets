import { tokenizeReactLite } from './ReactLiteTokenizer';
import { ReactLiteAst, ReactLiteAstAttribute, ReactLiteAstNode, ReactLiteDiagnostic, ReactLiteExpression,
  ReactLiteExpressionProperty, ReactLiteParseResult, ReactLiteToken } from './ReactLiteTypes';
import { reactLiteAllowedEvents, reactLiteAllowedProps, reactLiteComponentNames } from './ReactLiteCatalog';

const COMPONENTS: string[] = reactLiteComponentNames();
const MAX_SOURCE_CHARACTERS: number = 300000;
const MAX_TOKENS: number = 100000;
const MAX_PARSE_STEPS: number = 300000;
const MAX_PARSE_DEPTH: number = 64;
const PRECEDENCE: Record<string, number> = { '??': 1, '||': 2, '&&': 3, '===': 4, '!==': 4, '==': 4, '!=': 4,
  '<': 5, '<=': 5, '>': 5, '>=': 5, '+': 6, '-': 6, '*': 7, '/': 7, '%': 7 };

export function parseReactLite(source: string): ReactLiteParseResult {
  try {
    if (source.length > MAX_SOURCE_CHARACTERS) {
      return { ok: false, ast: undefined, diagnostics: [parserDiagnostic('RL_SOURCE_SIZE_LIMIT', 'React Lite 源码超过长度限制。')] };
    }
    let tokenResult = tokenizeReactLite(source);
    if (tokenResult.tokens.length > MAX_TOKENS) {
      return { ok: false, ast: undefined, diagnostics: tokenResult.diagnostics.concat([parserDiagnostic('RL_TOKEN_LIMIT', 'React Lite Token 数量超过限制。')]) };
    }
    let parser: Parser = new Parser(tokenResult.tokens, tokenResult.diagnostics);
    let ast: ReactLiteAst = parser.parse();
    let diagnostics: ReactLiteDiagnostic[] = parser.diagnostics;
    return { ok: diagnostics.filter((item: ReactLiteDiagnostic) => item.severity === 'error').length === 0 && ast.root !== undefined,
      ast: ast.root === undefined ? undefined : ast, diagnostics: diagnostics };
  } catch (error) {
    return { ok: false, ast: undefined, diagnostics: [parserDiagnostic('RL_PARSER_INTERNAL_ERROR', 'React Lite Parser 发生受控异常。')] };
  }
}

class Parser {
  private tokens: ReactLiteToken[];
  private index: number = 0;
  public diagnostics: ReactLiteDiagnostic[];
  private computed: Record<string, ReactLiteExpression> = {};
  private initialState: ReactLiteExpression = literalObject([]);
  private steps: number = 0;
  private depth: number = 0;

  constructor(tokens: ReactLiteToken[], diagnostics: ReactLiteDiagnostic[]) {
    this.tokens = tokens; this.diagnostics = diagnostics;
  }

  parse(): ReactLiteAst {
    this.expect('identifier', 'export', 'RL1002', '必须使用 export default function App()。');
    this.expect('identifier', 'default', 'RL1002', '必须使用 export default function App()。');
    this.expect('identifier', 'function', 'RL1002', '必须使用 export default function App()。');
    this.expect('identifier', 'App', 'RL1002', '函数名称必须是 App。');
    this.expectValue('(', 'RL1001'); this.expectValue(')', 'RL1001'); this.expectValue('{', 'RL1001');
    while (!this.checkValue('return') && !this.checkKind('eof') && !this.checkValue('}')) {
      if (!this.tick('RL_PARSE_BUDGET_EXCEEDED')) { break; }
      let startIndex: number = this.index;
      this.parseConst();
      if (this.index === startIndex) { this.recoverToBoundary(); }
    }
    this.expect('identifier', 'return', 'RL1002', '函数体必须返回 AppShell。');
    let wrapped: boolean = this.checkValue('(');
    if (wrapped) { this.index++; }
    let root: ReactLiteAstNode | undefined = this.parseJsxNode();
    if (wrapped) { this.expectValue(')', 'RL1001'); }
    this.optional(';');
    this.expectValue('}', 'RL1001');
    return { initialState: this.initialState, computed: this.computed, root: root };
  }

  private parseConst(): void {
    this.expect('identifier', 'const', 'RL1002', '只允许 const state/useComputed 声明。');
    let name: string = '';
    if (this.checkValue('[')) {
      this.index++;
      name = this.current().value;
      this.expectKind('identifier', 'RL1002');
      if (this.checkValue(',')) { this.index++; }
      if (this.checkKind('identifier')) { this.index++; }
      this.expectValue(']', 'RL1001');
      if (name !== 'state') {
        this.addError('RL_STATE_TUPLE_UNSUPPORTED', 'React Lite 只允许 [state, setState] 这一种状态解构。', this.current(),
          '改为 const state = useState({...})。');
      }
    } else {
      name = this.current().value; this.expectKind('identifier', 'RL1002');
    }
    this.expectValue('=', 'RL1001');
    let hook: string = this.current().value; this.expectKind('identifier', 'RL1006');
    this.expectValue('(', 'RL1001'); let expression: ReactLiteExpression = this.parseExpression(); this.expectValue(')', 'RL1001');
    this.optional(';');
    if (hook === 'useState') {
      if (name !== 'state' || this.initialState.kind !== 'literal' || this.initialState.value === 'state-set') {
        if (this.initialState.value === 'state-set') { this.addError('RL1006', '只能声明一次 useState。', this.current()); }
      }
      expression.value = 'state-set'; this.initialState = expression;
    } else if (hook === 'useComputed') {
      this.computed[name] = expression;
    } else {
      this.addError('RL1006', '未知 Hook：' + hook, this.current());
    }
  }

  private parseJsxNode(): ReactLiteAstNode | undefined {
    if (!this.tick('RL_PARSE_BUDGET_EXCEEDED')) { return undefined; }
    if (this.depth >= MAX_PARSE_DEPTH) { this.addError('RL_PARSE_DEPTH_EXCEEDED', 'JSX 嵌套深度超过限制。', this.current()); this.recoverToBoundary(); return undefined; }
    this.depth++;
    if (!this.checkValue('<')) { this.addError('RL1001', '期望 JSX 组件。', this.current()); this.depth--; return undefined; }
    if (this.peek(1).value === '>') {
      this.addError('RL_FRAGMENT_UNSUPPORTED', 'JSX Fragment 暂不支持。', this.current(), '使用 Column 或显式容器组件。');
      this.index += 2;
      this.recoverToBoundary();
      this.depth--;
      return undefined;
    }
    let open = this.current(); this.index++;
    let closing: boolean = this.checkValue('/'); if (closing) { this.index++; }
    let component: string = this.current().value; this.expectKind('identifier', 'RL1004');
    if (COMPONENTS.indexOf(component) < 0 || component === 'Else' || component === 'Modal') {
      this.addError('RL1004', '未知或暂不支持的组件：' + component, open, '使用受限组件目录。');
    }
    let attributes: ReactLiteAstAttribute[] = [];
    while (!this.checkValue('>') && !this.checkValue('/') && !this.checkKind('eof')) {
      if (!this.tick('RL_PARSE_BUDGET_EXCEEDED')) { break; }
      let startIndex: number = this.index;
      attributes.push(this.parseAttribute());
      if (this.index === startIndex) { this.addError('RL_PARSE_NO_PROGRESS', '属性解析无法继续。', this.current()); this.recoverToBoundary(); }
    }
    this.validateAttributes(component, attributes);
    if (this.checkValue('/')) { this.index++; this.expectValue('>', 'RL1001'); this.depth--; return nodeFor(component, attributes, [], open); }
    this.expectValue('>', 'RL1001');
    let children: ReactLiteAstNode[] = [];
    while (!this.checkKind('eof') && !(this.checkValue('<') && this.peek(1).value === '/')) {
      if (!this.tick('RL_PARSE_BUDGET_EXCEEDED')) { break; }
      let startIndex: number = this.index;
      if (this.checkValue('<')) { let child = this.parseJsxNode(); if (child !== undefined) { children.push(child); } }
      else if (this.checkKind('jsxText')) {
        let text = this.current(); this.index++; if (text.value.trim().length > 0) { children.push(textNode(text)); }
      } else if (this.checkValue('{')) {
        let expressionToken = this.current(); this.index++;
        let expression: ReactLiteExpression = this.parseExpression();
        this.expectValue('}', 'RL1001');
        children.push(expressionNode(expression, expressionToken));
      } else { this.index++; }
      if (this.index === startIndex) { this.addError('RL_PARSE_NO_PROGRESS', 'JSX 子节点解析无法继续。', this.current()); this.recoverToBoundary(); }
    }
    this.expectValue('<', 'RL1001'); this.expectValue('/', 'RL1001');
    let endName: string = this.current().value; this.expectKind('identifier', 'RL1001');
    if (endName !== component) { this.addError('RL1001', 'JSX 标签未正确闭合。', this.current()); }
    this.expectValue('>', 'RL1001');
    this.depth--;
    return nodeFor(component, attributes, children, open);
  }

  private validateAttributes(component: string, attributes: ReactLiteAstAttribute[]): void {
    let allowedProps: string[] = reactLiteAllowedProps(component); let allowedEvents: string[] = reactLiteAllowedEvents(component);
    for (let i: number = 0; i < attributes.length; i++) {
      let name: string = attributes[i].name;
      if (name.indexOf('on') === 0) {
        if (allowedEvents.indexOf(name) < 0) { this.addError('RL1008', '组件不支持事件：' + component + '.' + name, this.current(), '使用组件目录中的事件。'); }
      } else if (allowedProps.indexOf(name) < 0) {
        this.addError('RL1009', '组件不支持属性：' + component + '.' + name, this.current(), '使用组件目录中的属性。');
      }
    }
  }

  private parseAttribute(): ReactLiteAstAttribute {
    if (this.checkValue('{') && this.peek(1).value === '.' && this.peek(2).value === '.' && this.peek(3).value === '.') {
      this.addError('RL_JSX_SPREAD_UNSUPPORTED', 'JSX Spread 属性不受支持。', this.current(), '展开为显式属性。');
      this.skipBalanced('{', '}');
      return { name: '__spread__', stringValue: '', booleanValue: false, line: this.current().line, column: this.current().column };
    }
    let current = this.current(); let name: string = current.value; this.expectKind('identifier', 'RL1005');
    if (!this.checkValue('=')) { return { name: name, stringValue: '', booleanValue: true, line: current.line, column: current.column }; }
    this.index++; if (this.checkKind('string')) {
      let value = this.current(); this.index++; return { name: name, stringValue: value.value, booleanValue: false, line: current.line, column: current.column };
    }
    this.expectValue('{', 'RL1001'); let expression = this.parseExpression(); this.expectValue('}', 'RL1001');
    if (name === 'style' && expression.kind === 'object') {
      this.addError('RL_INLINE_STYLE_UNSUPPORTED', 'Inline style 对象不受支持。', current, '使用 className 样式 Token。');
    }
    return { name: name, value: expression, stringValue: '', booleanValue: false, line: current.line, column: current.column };
  }

  private parseExpression(minPrecedence: number = 0): ReactLiteExpression {
    if (!this.tick('RL_PARSE_BUDGET_EXCEEDED')) { return literalString(''); }
    let left: ReactLiteExpression = this.parseUnary();
    while (this.current().kind === 'operator' && PRECEDENCE[this.current().value] !== undefined && PRECEDENCE[this.current().value] >= minPrecedence) {
      let operator: string = this.current().value; let precedence: number = PRECEDENCE[operator]; this.index++;
      let right = this.parseExpression(precedence + 1);
      left = { kind: 'binary', value: '', operator: operator, path: [], left: left, right: right, items: [], properties: [], callee: '', args: [], line: left.line, column: left.column };
    }
    if (minPrecedence === 0 && this.checkValue('?')) {
      this.index++; let consequent = this.parseExpression(); this.expectValue(':', 'RL1001'); let alternate = this.parseExpression();
      left = { kind: 'conditional', value: '', operator: '?', path: [], test: left, consequent: consequent, alternate: alternate,
        items: [], properties: [], callee: '', args: [], line: left.line, column: left.column };
    }
    return left;
  }

  private parseUnary(): ReactLiteExpression {
    if (this.current().kind === 'operator' && ['!', '-', '+'].indexOf(this.current().value) >= 0) {
      let current = this.current(); let operator: string = current.value; this.index++;
      return { kind: 'unary', value: '', operator: operator, path: [], left: this.parseUnary(), items: [], properties: [], callee: '', args: [], line: current.line, column: current.column };
    }
    let current = this.current();
    if (current.kind === 'string' || current.kind === 'number' || current.value === 'true' || current.value === 'false' || current.value === 'null') {
      this.index++; return { kind: 'literal', value: current.value, operator: '', path: [], items: [], properties: [], callee: '', args: [], line: current.line, column: current.column };
    }
    if (this.checkValue('[')) { return this.parseArray(); }
    if (this.checkValue('{')) { return this.parseObject(); }
    if (this.checkValue('<')) {
      let jsx = this.parseJsxNode();
      return { kind: 'jsx', value: '', operator: '', path: [], items: [], properties: [], callee: '', args: [],
        jsxNode: jsx, line: current.line, column: current.column };
    }
    if (this.checkValue('(') && this.peek(1).value === ')' && this.peek(2).value === '=>') {
      this.index++; this.expectValue(')', 'RL1001'); this.expectValue('=>', 'RL1001');
      if (this.checkValue('{')) { this.addError('RL_ARROW_BLOCK_UNSUPPORTED', '箭头函数语句块暂不支持。', this.current()); this.skipBalanced('{', '}'); return literalString(''); }
      let body = this.parseExpression();
      return { kind: 'lambda', value: '', operator: '=>', path: [], items: [], properties: [], callee: '', args: [],
        parameter: '', body: body, line: current.line, column: current.column };
    }
    if (this.checkValue('(') && this.peek(1).kind === 'identifier' && this.peek(2).value === ')' && this.peek(3).value === '=>') {
      this.index++; let parameter = this.current().value; this.index++; this.expectValue(')', 'RL1001'); this.expectValue('=>', 'RL1001');
      if (this.checkValue('{')) { this.addError('RL_ARROW_BLOCK_UNSUPPORTED', '箭头函数语句块暂不支持。', this.current()); this.skipBalanced('{', '}'); return literalString(''); }
      let body = this.parseExpression();
      return { kind: 'lambda', value: '', operator: '=>', path: [], items: [], properties: [], callee: '', args: [],
        parameter: parameter, body: body, line: current.line, column: current.column };
    }
    if (this.checkValue('(')) { this.index++; let value = this.parseExpression(); this.expectValue(')', 'RL1001'); return value; }
    if (current.kind === 'identifier') {
      if (this.peek(1).value === '=>') {
        this.index++; this.expectValue('=>', 'RL1001');
        if (this.checkValue('{')) { this.addError('RL_ARROW_BLOCK_UNSUPPORTED', '箭头函数语句块暂不支持。', this.current()); this.skipBalanced('{', '}'); return literalString(''); }
        let body = this.parseExpression();
        return { kind: 'lambda', value: '', operator: '=>', path: [], items: [], properties: [], callee: '', args: [],
          parameter: current.value, body: body, line: current.line, column: current.column };
      }
      this.index++; let parts: string[] = [current.value];
      while (this.checkValue('.')) { this.index++; parts.push(this.current().value); this.expectKind('identifier', 'RL1007'); }
      if (this.checkValue('(')) {
        this.index++; let args: ReactLiteExpression[] = [];
        if (parts.length > 1 && parts[parts.length - 1] === 'map' && this.checkKind('identifier') && this.peek(1).value === '=>') {
          let parameter = this.current().value; this.index++; this.expectValue('=>', 'RL1001');
          let body = this.parseExpression();
          this.expectValue(')', 'RL1001');
          return { kind: 'map', value: '', operator: '', path: parts.slice(0, parts.length - 1), items: [], properties: [], callee: parts.join('.'), args: [],
            parameter: parameter, body: body, template: body.kind === 'jsx' ? body.jsxNode : undefined,
            source: pathExpression(parts.slice(0, parts.length - 1), current), line: current.line, column: current.column };
        }
        while (!this.checkValue(')') && !this.checkKind('eof')) { args.push(this.parseExpression()); if (this.checkValue(',')) { this.index++; } else { break; } }
        this.expectValue(')', 'RL1001'); return { kind: 'call', value: '', operator: '', path: parts, items: [], properties: [], callee: parts.join('.'), args: args, line: current.line, column: current.column };
      }
      return { kind: 'path', value: '', operator: '', path: parts, items: [], properties: [], callee: '', args: [], line: current.line, column: current.column };
    }
    this.addError('RL1007', '不支持的表达式。', current, '只使用白名单表达式。'); this.index++;
    return literalString('');
  }

  private parseArray(): ReactLiteExpression {
    let current = this.current(); this.index++; let items: ReactLiteExpression[] = [];
    while (!this.checkValue(']') && !this.checkKind('eof')) {
      let startIndex: number = this.index; items.push(this.parseExpression());
      if (this.checkValue(',')) { this.index++; } else if (this.index === startIndex) { this.recoverToBoundary(); } else { break; }
    }
    this.expectValue(']', 'RL1001'); return { kind: 'array', value: '', operator: '', path: [], items: items, properties: [], callee: '', args: [], line: current.line, column: current.column };
  }

  private parseObject(): ReactLiteExpression {
    let current = this.current(); this.index++; let properties: ReactLiteExpressionProperty[] = [];
    while (!this.checkValue('}') && !this.checkKind('eof')) {
      let startIndex: number = this.index;
      let key = this.current(); this.index++; let name: string = key.value; this.expectValue(':', 'RL1001');
      properties.push({ key: name, value: this.parseExpression() });
      if (this.checkValue(',')) { this.index++; } else if (this.index === startIndex) { this.recoverToBoundary(); } else { break; }
    }
    this.expectValue('}', 'RL1001'); return { kind: 'object', value: '', operator: '', path: [], items: [], properties: properties, callee: '', args: [], line: current.line, column: current.column };
  }

  private expect(kind: string, value: string, code: string, suggestion: string): void {
    if (this.current().kind !== kind || this.current().value !== value) { this.addError(code, '期望 ' + value + '。', this.current(), suggestion); return; }
    this.index++;
  }
  private expectKind(kind: string, code: string): void { if (this.current().kind !== kind) { this.addError(code, '语法类型不匹配。', this.current()); } else { this.index++; } }
  private expectValue(value: string, code: string): void { if (this.current().value !== value) { this.addError(code, '期望 ' + value + '。', this.current()); } else { this.index++; } }
  private optional(value: string): void { if (this.checkValue(value)) { this.index++; } }
  private checkValue(value: string): boolean { return this.current().value === value; }
  private checkKind(value: string): boolean { return this.current().kind === value; }
  private tick(code: string): boolean {
    this.steps++;
    if (this.steps > MAX_PARSE_STEPS) {
      this.addError(code, 'React Lite 解析步骤超过限制。', this.current());
      this.index = this.tokens.length - 1;
      return false;
    }
    return true;
  }
  private recoverToBoundary(): void {
    if (!this.checkKind('eof')) { this.index++; }
    while (!this.checkKind('eof') && ['>', '/', '}', ';'].indexOf(this.current().value) < 0) { this.index++; }
  }
  private skipBalanced(open: string, close: string): void {
    let depth: number = 0;
    while (!this.checkKind('eof') && this.steps <= MAX_PARSE_STEPS) {
      this.steps++;
      if (this.current().value === open) { depth++; }
      if (this.current().value === close) { depth--; }
      this.index++;
      if (depth <= 0) { break; }
    }
  }
  private current(): ReactLiteToken { return this.tokens[Math.min(this.index, this.tokens.length - 1)]; }
  private peek(offset: number): ReactLiteToken { return this.tokens[Math.min(this.index + offset, this.tokens.length - 1)]; }
  private addError(code: string, message: string, token: ReactLiteToken, suggestion: string = ''): void {
    this.diagnostics.push({ code: code, severity: 'error', message: message, line: token.line, column: token.column,
      length: Math.max(1, token.value.length), suggestion: suggestion });
  }
}

function parserDiagnostic(code: string, message: string): ReactLiteDiagnostic {
  return { code: code, severity: 'error', message: message, line: 1, column: 1, length: 1, suggestion: '' };
}

function nodeFor(component: string, attributes: ReactLiteAstAttribute[], children: ReactLiteAstNode[], token: ReactLiteToken): ReactLiteAstNode {
  let kind: 'element' | 'if' | 'forEach' = component === 'If' ? 'if' : component === 'ForEach' ? 'forEach' : 'element';
  return { kind: kind, component: component, attributes: attributes, children: children, line: token.line, column: token.column };
}
function textNode(token: ReactLiteToken): ReactLiteAstNode {
  return { kind: 'text', component: 'Text', attributes: [{ name: 'text', stringValue: token.value.trim(), booleanValue: false, line: token.line, column: token.column }], children: [], line: token.line, column: token.column };
}
function expressionNode(expression: ReactLiteExpression, token: ReactLiteToken): ReactLiteAstNode {
  return { kind: 'expression', component: '', attributes: [], children: [], expression: expression, line: token.line, column: token.column };
}
function literalString(value: string): ReactLiteExpression { return { kind: 'literal', value: value, operator: '', path: [], items: [], properties: [], callee: '', args: [], line: 0, column: 0 }; }
function literalObject(properties: ReactLiteExpressionProperty[]): ReactLiteExpression { return { kind: 'object', value: 'state', operator: '', path: [], items: [], properties: properties, callee: '', args: [], line: 0, column: 0 }; }
function pathExpression(path: string[], token: ReactLiteToken): ReactLiteExpression {
  return { kind: 'path', value: '', operator: '', path: path, items: [], properties: [], callee: '', args: [], line: token.line, column: token.column };
}
