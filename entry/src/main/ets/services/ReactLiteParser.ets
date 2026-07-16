import { tokenizeReactLite } from './ReactLiteTokenizer';
import { ReactLiteAst, ReactLiteAstAttribute, ReactLiteAstNode, ReactLiteDiagnostic, ReactLiteExpression,
  ReactLiteExpressionProperty, ReactLiteParseResult, ReactLiteToken } from './ReactLiteTypes';

const COMPONENTS: string[] = ['AppShell', 'Page', 'SafeArea', 'Scroll', 'Column', 'Row', 'Stack', 'Grid', 'List',
  'Card', 'Text', 'Image', 'Icon', 'Badge', 'Progress', 'Divider', 'Spacer', 'Button', 'IconButton', 'TextInput',
  'TextArea', 'Toggle', 'Checkbox', 'ChoiceChips', 'SegmentedControl', 'Hero', 'Section', 'InfoCard', 'FormGroup',
  'MetricGrid', 'Timeline', 'ResultList', 'MediaGallery', 'StatusBanner', 'Tabs', 'ActionBar', 'EmptyState', 'Sheet', 'If', 'ForEach'];
const PRECEDENCE: Record<string, number> = { '??': 1, '||': 2, '&&': 3, '===': 4, '!==': 4, '==': 4, '!=': 4,
  '<': 5, '<=': 5, '>': 5, '>=': 5, '+': 6, '-': 6, '*': 7, '/': 7, '%': 7 };

export function parseReactLite(source: string): ReactLiteParseResult {
  let tokenResult = tokenizeReactLite(source);
  let parser: Parser = new Parser(tokenResult.tokens, tokenResult.diagnostics);
  let ast: ReactLiteAst = parser.parse();
  let diagnostics: ReactLiteDiagnostic[] = parser.diagnostics;
  return { ok: diagnostics.filter((item: ReactLiteDiagnostic) => item.severity === 'error').length === 0 && ast.root !== undefined,
    ast: ast.root === undefined ? undefined : ast, diagnostics: diagnostics };
}

class Parser {
  private tokens: ReactLiteToken[];
  private index: number = 0;
  public diagnostics: ReactLiteDiagnostic[];
  private computed: Record<string, ReactLiteExpression> = {};
  private initialState: ReactLiteExpression = literalObject([]);

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
      this.parseConst();
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
    let name: string = this.current().value; this.expectKind('identifier', 'RL1002');
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
    if (!this.checkValue('<')) { this.addError('RL1001', '期望 JSX 组件。', this.current()); return undefined; }
    let open = this.current(); this.index++;
    let closing: boolean = this.checkValue('/'); if (closing) { this.index++; }
    let component: string = this.current().value; this.expectKind('identifier', 'RL1004');
    if (COMPONENTS.indexOf(component) < 0 || component === 'Else' || component === 'Modal') {
      this.addError('RL1004', '未知或暂不支持的组件：' + component, open, '使用受限组件目录。');
    }
    let attributes: ReactLiteAstAttribute[] = [];
    while (!this.checkValue('>') && !this.checkValue('/') && !this.checkKind('eof')) { attributes.push(this.parseAttribute()); }
    if (this.checkValue('/')) { this.index++; this.expectValue('>', 'RL1001'); return nodeFor(component, attributes, [], open); }
    this.expectValue('>', 'RL1001');
    let children: ReactLiteAstNode[] = [];
    while (!this.checkKind('eof') && !(this.checkValue('<') && this.peek(1).value === '/')) {
      if (this.checkValue('<')) { let child = this.parseJsxNode(); if (child !== undefined) { children.push(child); } }
      else if (this.checkKind('jsxText')) {
        let text = this.current(); this.index++; if (text.value.trim().length > 0) { children.push(textNode(text)); }
      } else if (this.checkValue('{')) {
        this.index++; this.parseExpression(); this.expectValue('}', 'RL1001');
      } else { this.index++; }
    }
    this.expectValue('<', 'RL1001'); this.expectValue('/', 'RL1001');
    let endName: string = this.current().value; this.expectKind('identifier', 'RL1001');
    if (endName !== component) { this.addError('RL1001', 'JSX 标签未正确闭合。', this.current()); }
    this.expectValue('>', 'RL1001');
    return nodeFor(component, attributes, children, open);
  }

  private parseAttribute(): ReactLiteAstAttribute {
    let current = this.current(); let name: string = current.value; this.expectKind('identifier', 'RL1005');
    if (!this.checkValue('=')) { return { name: name, stringValue: '', booleanValue: true, line: current.line, column: current.column }; }
    this.index++; if (this.checkKind('string')) {
      let value = this.current(); this.index++; return { name: name, stringValue: value.value, booleanValue: false, line: current.line, column: current.column };
    }
    this.expectValue('{', 'RL1001'); let expression = this.parseExpression(); this.expectValue('}', 'RL1001');
    return { name: name, value: expression, stringValue: '', booleanValue: false, line: current.line, column: current.column };
  }

  private parseExpression(minPrecedence: number = 0): ReactLiteExpression {
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
    if (this.checkValue('(')) { this.index++; let value = this.parseExpression(); this.expectValue(')', 'RL1001'); return value; }
    if (current.kind === 'identifier') {
      this.index++; let parts: string[] = [current.value];
      while (this.checkValue('.')) { this.index++; parts.push(this.current().value); this.expectKind('identifier', 'RL1007'); }
      if (this.checkValue('(')) {
        this.index++; let args: ReactLiteExpression[] = [];
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
    while (!this.checkValue(']') && !this.checkKind('eof')) { items.push(this.parseExpression()); if (this.checkValue(',')) { this.index++; } else { break; } }
    this.expectValue(']', 'RL1001'); return { kind: 'array', value: '', operator: '', path: [], items: items, properties: [], callee: '', args: [], line: current.line, column: current.column };
  }

  private parseObject(): ReactLiteExpression {
    let current = this.current(); this.index++; let properties: ReactLiteExpressionProperty[] = [];
    while (!this.checkValue('}') && !this.checkKind('eof')) {
      let key = this.current(); this.index++; let name: string = key.value; this.expectValue(':', 'RL1001');
      properties.push({ key: name, value: this.parseExpression() }); if (this.checkValue(',')) { this.index++; } else { break; }
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
  private current(): ReactLiteToken { return this.tokens[Math.min(this.index, this.tokens.length - 1)]; }
  private peek(offset: number): ReactLiteToken { return this.tokens[Math.min(this.index + offset, this.tokens.length - 1)]; }
  private addError(code: string, message: string, token: ReactLiteToken, suggestion: string = ''): void {
    this.diagnostics.push({ code: code, severity: 'error', message: message, line: token.line, column: token.column,
      length: Math.max(1, token.value.length), suggestion: suggestion });
  }
}

function nodeFor(component: string, attributes: ReactLiteAstAttribute[], children: ReactLiteAstNode[], token: ReactLiteToken): ReactLiteAstNode {
  let kind: 'element' | 'if' | 'forEach' = component === 'If' ? 'if' : component === 'ForEach' ? 'forEach' : 'element';
  return { kind: kind, component: component, attributes: attributes, children: children, line: token.line, column: token.column };
}
function textNode(token: ReactLiteToken): ReactLiteAstNode {
  return { kind: 'text', component: 'Text', attributes: [{ name: 'text', stringValue: token.value.trim(), booleanValue: false, line: token.line, column: token.column }], children: [], line: token.line, column: token.column };
}
function literalString(value: string): ReactLiteExpression { return { kind: 'literal', value: value, operator: '', path: [], items: [], properties: [], callee: '', args: [], line: 0, column: 0 }; }
function literalObject(properties: ReactLiteExpressionProperty[]): ReactLiteExpression { return { kind: 'object', value: 'state', operator: '', path: [], items: [], properties: properties, callee: '', args: [], line: 0, column: 0 }; }
