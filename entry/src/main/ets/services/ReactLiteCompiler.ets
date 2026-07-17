import { AppBlueprint, SkillManifest } from './SkillAppTypes';
import { arrayValue, booleanValue, nullValue, numberValue, objectValue, stringValue } from './UiValue';
import { UiAction, UiActionKind, UiComponentType, UiComputedDefinition, UiExpression, UiIrNode, UiIrPage, UiIrSpec, UiIrTheme,
  UiValue } from './UiIrTypes';
import { validateUiIrSpec } from './UiIrValidator';
import { runReactLiteQualityGate } from './ReactLiteQualityGate';
import { parseReactLite } from './ReactLiteParser';
import { ReactLiteAstAttribute, ReactLiteAstNode, ReactLiteExpression, ReactLiteDiagnostic } from './ReactLiteTypes';

export interface ReactLiteCompileContext {
  manifest: SkillManifest;
  blueprint: AppBlueprint;
  localAssetIds: string[];
}

export interface ReactLiteCompileResult {
  ok: boolean;
  value: UiIrSpec | undefined;
  diagnostics: ReactLiteDiagnostic[];
  uiDiagnostics: string[];
}

export function compileReactLite(source: string, context: ReactLiteCompileContext): ReactLiteCompileResult {
  try {
    return compileReactLiteInternal(source, context);
  } catch (error) {
    return { ok: false, value: undefined, diagnostics: [
      { code: 'RL_COMPILER_INTERNAL_ERROR', severity: 'error', message: 'React Lite Compiler 发生受控异常。',
        line: 1, column: 1, length: 1, suggestion: '检查生成源码并重新生成。' }
    ], uiDiagnostics: [] };
  }
}

// Public boundary used by Forge and debug callers. Keep the existing name for
// ui-ir-1 compatibility while making the safe contract explicit.
export function compileReactLiteSafe(source: string, context: ReactLiteCompileContext): ReactLiteCompileResult {
  return compileReactLite(source, context);
}

function compileReactLiteInternal(source: string, context: ReactLiteCompileContext): ReactLiteCompileResult {
  let parsed = parseReactLite(source);
  if (!parsed.ok || parsed.ast === undefined || parsed.ast.root === undefined) {
    return { ok: false, value: undefined, diagnostics: parsed.diagnostics, uiDiagnostics: [] };
  }
  let root: ReactLiteAstNode = parsed.ast.root;
  let appTitle: string = attrString(root, 'title', context.blueprint.title);
  let appSubtitle: string = attrString(root, 'subtitle', context.blueprint.summary);
  let initialPageId: string = attrString(root, 'initialPage', context.blueprint.pages[0].id);
  let pages: UiIrPage[] = [];
  let compileDiagnostics: ReactLiteDiagnostic[] = [];
  let rootChildren: ReactLiteAstNode[] = root.children;
  for (let i: number = 0; i < rootChildren.length; i++) {
    if (rootChildren[i].component !== 'Page') { continue; }
    pages.push(compilePage(rootChildren[i], context, compileDiagnostics));
  }
  if (pages.length === 0) {
    return { ok: false, value: undefined, diagnostics: [diagnostic('RL1014', 'AppShell 必须包含至少一个 Page。', root)], uiDiagnostics: [] };
  }
  let computed: UiComputedDefinition[] = [];
  let computedNames: string[] = Object.keys(parsed.ast.computed);
  for (let i: number = 0; i < computedNames.length; i++) {
    computed.push({ name: computedNames[i], expression: compileExpression(parsed.ast.computed[computedNames[i]]) });
  }
  let initialState: Record<string, UiValue> = compileInitialState(parsed.ast.initialState);
  let theme: UiIrTheme = morandiTheme();
  let spec: UiIrSpec = { schemaVersion: 'ui-ir-1', appId: context.blueprint.appId, title: appTitle,
    subtitle: appSubtitle, initialPageId: initialPageId, theme: theme, initialState: initialState, computed: computed, pages: pages };
  let toolNames: string[] = [];
  for (let i: number = 0; i < context.manifest.toolContracts.length; i++) {
    if (context.manifest.toolContracts[i].implemented) { toolNames.push(context.manifest.toolContracts[i].name); }
  }
  if (compileDiagnostics.length > 0) {
    return { ok: false, value: undefined, diagnostics: parsed.diagnostics.concat(compileDiagnostics), uiDiagnostics: [] };
  }
  let validation = validateUiIrSpec(spec, toolNames, context.localAssetIds);
  let uiDiagnostics: string[] = [];
  for (let i: number = 0; i < validation.diagnostics.length; i++) { uiDiagnostics.push(validation.diagnostics[i].message); }
  if (validation.ok) { uiDiagnostics = uiDiagnostics.concat(runReactLiteQualityGate(spec)); }
  return { ok: validation.ok && uiDiagnostics.length === 0, value: validation.ok && uiDiagnostics.length === 0 ? spec : undefined,
    diagnostics: parsed.diagnostics, uiDiagnostics: uiDiagnostics };
}

function compilePage(page: ReactLiteAstNode, context: ReactLiteCompileContext, diagnostics: ReactLiteDiagnostic[]): UiIrPage {
  let id: string = attrString(page, 'id', 'page-' + page.line.toString());
  let title: string = attrString(page, 'title', id);
  let preset: string = attrString(page, 'layoutPreset', inferPreset(page));
  let children: UiIrNode[] = [];
  let overlays: UiIrNode[] = [];
  for (let i: number = 0; i < page.children.length; i++) {
    let compiled = compileNode(page.children[i], preset, diagnostics);
    let extracted = extractOverlayNodes(compiled);
    if (extracted.content !== undefined) { children.push(extracted.content); }
    overlays = overlays.concat(extracted.overlays);
  }
  let root: UiIrNode = elementNode(id + '-root', 'Column', {}, defaultClass('Page', preset), {}, children);
  return { id: id, title: title, scroll: attrBoolean(page, 'scroll', true), layoutPreset: preset, root: root, overlays: overlays };
}

interface OverlayExtraction {
  content: UiIrNode | undefined;
  overlays: UiIrNode[];
}

function extractOverlayNodes(node: UiIrNode): OverlayExtraction {
  if (node.component === 'Sheet') {
    return { content: undefined, overlays: [node] };
  }
  if (node.kind === 'forEach') {
    // A Sheet inside a repeated item would lose the item alias when lifted to
    // the page host. Keep the list intact until a dedicated portal contract exists.
    return { content: node, overlays: [] };
  }
  if (node.children.length === 0) {
    return { content: node, overlays: [] };
  }
  let contentChildren: UiIrNode[] = [];
  let overlayChildren: UiIrNode[] = [];
  for (let i: number = 0; i < node.children.length; i++) {
    let child = extractOverlayNodes(node.children[i]);
    if (child.content !== undefined) { contentChildren.push(child.content); }
    overlayChildren = overlayChildren.concat(child.overlays);
  }
  if (node.kind === 'if' && overlayChildren.length > 0) {
    let overlayWrapper: UiIrNode = cloneNodeWithChildren(node, node.id + '-overlay', overlayChildren);
    overlayChildren = [overlayWrapper];
  }
  let content: UiIrNode | undefined = contentChildren.length > 0 ? cloneNodeWithChildren(node, node.id, contentChildren) : undefined;
  return { content: content, overlays: overlayChildren };
}

function cloneNodeWithChildren(node: UiIrNode, id: string, children: UiIrNode[]): UiIrNode {
  return { kind: node.kind, id: id, component: node.component, props: node.props, binding: node.binding,
    className: node.className, actions: node.actions, children: children, condition: node.condition,
    source: node.source, itemAlias: node.itemAlias, keyPath: node.keyPath };
}

function compileNode(node: ReactLiteAstNode, preset: string, diagnostics: ReactLiteDiagnostic[] = []): UiIrNode {
  if (node.kind === 'text') {
    return elementNode('text-' + node.line.toString() + '-' + node.column.toString(), 'Text', propsFrom(node), 'text-sm text-ink', {}, []);
  }
  if (node.kind === 'if') {
    return { kind: 'if', id: 'if-' + node.line.toString() + '-' + node.column.toString(), component: 'Column', props: {}, binding: '', className: '', actions: {},
      children: compileChildren(node.children, preset, diagnostics), condition: compileExpression(attrExpression(node, 'when')), itemAlias: '', keyPath: '' };
  }
  if (node.kind === 'forEach') {
    return { kind: 'forEach', id: 'each-' + node.line.toString() + '-' + node.column.toString(), component: 'Column', props: {}, binding: '', className: '', actions: {},
      children: compileChildren(node.children, preset, diagnostics), source: compileExpression(attrExpression(node, 'items')), condition: undefined,
      itemAlias: attrString(node, 'item', 'item'), keyPath: attrString(node, 'keyBy', 'id') };
  }
  if (node.kind === 'expression' && node.expression !== undefined) {
    return compileExpressionNode(node.expression, preset, node, diagnostics);
  }
  if (node.component === 'ResultList') {
    if (node.children.length === 0) {
      diagnostics.push(diagnostic('RL_LIST_TEMPLATE_REQUIRED', 'ResultList 必须包含 item template；自闭合 ResultList 不会生成可渲染列表。', node));
      return elementNode('invalid-result-list-' + node.line.toString(), 'EmptyState', {}, 'w-full p-4 bg-card rounded-xl', {}, []);
    }
    return { kind: 'forEach', id: 'result-list-' + node.line.toString() + '-' + node.column.toString(), component: 'Column', props: {}, binding: '', className: '', actions: {},
      children: compileChildren(node.children, preset, diagnostics), source: compileExpression(attrExpression(node, 'items')), condition: undefined,
      itemAlias: attrString(node, 'item', 'item'), keyPath: attrString(node, 'keyBy', 'id') };
  }
  let component: string = canonicalComponent(node.component);
  let className: string = attrString(node, 'className', defaultClass(node.component, preset));
  let actions: Record<string, UiAction> = {};
  let attributes: ReactLiteAstAttribute[] = node.attributes;
  for (let i: number = 0; i < attributes.length; i++) {
    let attribute: ReactLiteAstAttribute = attributes[i];
    if (attribute.value !== undefined && ['onPress', 'onSubmit', 'onDismiss', 'onSelect', 'onReachEnd', 'onLongPress', 'onChange'].indexOf(attribute.name) >= 0) {
      actions[eventName(attribute.name)] = compileAction(attribute.value, node.line, node.column);
    }
  }
  let children: UiIrNode[] = compileChildren(node.children, preset, diagnostics);
  let binding: string = attrString(node, 'bind', '');
  if (binding.length === 0 && ['ChoiceChips', 'SegmentedControl', 'Tabs'].indexOf(node.component) >= 0) {
    let valueExpression = attrExpression(node, 'value');
    if (valueExpression !== undefined && valueExpression.kind === 'path') { binding = valueExpression.path.join('.'); }
  }
  return elementNode('node-' + node.line.toString() + '-' + node.column.toString(), component, propsFrom(node), className,
    actions, children, binding);
}

function compileChildren(children: ReactLiteAstNode[], preset: string, diagnostics: ReactLiteDiagnostic[] = []): UiIrNode[] {
  let result: UiIrNode[] = []; for (let i: number = 0; i < children.length; i++) { result.push(compileNode(children[i], preset, diagnostics)); } return result;
}

function compileExpressionNode(expression: ReactLiteExpression, preset: string, sourceNode: ReactLiteAstNode,
  diagnostics: ReactLiteDiagnostic[]): UiIrNode {
  if (expression.kind === 'jsx' && expression.jsxNode !== undefined) { return compileNode(expression.jsxNode, preset, diagnostics); }
  if (expression.kind === 'binary' && expression.operator === '&&' && expression.right !== undefined &&
    expression.right.kind === 'jsx' && expression.right.jsxNode !== undefined) {
    let child: UiIrNode = compileNode(expression.right.jsxNode, preset, diagnostics);
    return { kind: 'if', id: 'if-' + sourceNode.line.toString() + '-' + sourceNode.column.toString(), component: 'Column', props: {}, binding: '', className: '', actions: {},
      children: [child], condition: compileExpression(expression.left), itemAlias: '', keyPath: '' };
  }
  if (expression.kind === 'conditional' && expression.consequent !== undefined && expression.alternate !== undefined) {
    if (expression.consequent.kind === 'jsx' && expression.consequent.jsxNode !== undefined &&
      expression.alternate.kind === 'literal' && expression.alternate.value === 'null') {
      let child: UiIrNode = compileNode(expression.consequent.jsxNode, preset, diagnostics);
      return { kind: 'if', id: 'if-' + sourceNode.line.toString() + '-' + sourceNode.column.toString(), component: 'Column', props: {}, binding: '', className: '', actions: {},
        children: [child], condition: compileExpression(expression.test), itemAlias: '', keyPath: '' };
    }
    diagnostics.push(diagnostic('RL_CONDITIONAL_BRANCH_UNSUPPORTED', '仅支持 condition ? <Component/> : null。', sourceNode));
    return elementNode('invalid-conditional-' + sourceNode.line.toString(), 'EmptyState', {}, 'w-full p-4 bg-card rounded-xl', {}, []);
  }
  if (expression.kind === 'map' && expression.source !== undefined && expression.template !== undefined) {
    let template: ReactLiteAstNode = expression.template;
    let keyExpression: ReactLiteExpression | undefined = attrExpression(template, 'key');
    let keyPath: string = expression.keyPath === undefined ? '' : expression.keyPath;
    if (keyExpression !== undefined && keyExpression.kind === 'path') {
      let parts: string[] = keyExpression.path;
      if (parts.length > 1 && parts[0] === expression.parameter) { keyPath = parts.slice(1).join('.'); }
    }
    if (keyPath.length === 0) {
      diagnostics.push(diagnostic('RL_MAP_KEY_REQUIRED', 'map 列表必须通过 key={item.id} 或 keyBy 提供稳定身份。', sourceNode));
      keyPath = 'id';
    }
    return { kind: 'forEach', id: 'map-' + sourceNode.line.toString() + '-' + sourceNode.column.toString(), component: 'Column', props: {}, binding: '', className: '', actions: {},
      children: [compileNode(template, preset, diagnostics)], source: compileExpression(expression.source), condition: undefined,
      itemAlias: expression.parameter === undefined ? 'item' : expression.parameter, keyPath: keyPath };
  }
  diagnostics.push(diagnostic('RL_EXPRESSION_NODE_UNSUPPORTED', '表达式只能生成 JSX、条件 JSX 或 map 列表模板。', sourceNode));
  return elementNode('invalid-expression-' + sourceNode.line.toString(), 'EmptyState', {}, 'w-full p-4 bg-card rounded-xl', {}, []);
}

function elementNode(id: string, componentName: string, props: Record<string, UiExpression>, className: string,
  actions: Record<string, UiAction>, children: UiIrNode[], binding: string = ''): UiIrNode {
  return { kind: 'element', id: id, component: componentName as UiComponentType, props: props, binding: binding,
    className: className, actions: actions, children: children, itemAlias: '', keyPath: '' };
}

function propsFrom(node: ReactLiteAstNode): Record<string, UiExpression> {
  let props: Record<string, UiExpression> = {};
  for (let i: number = 0; i < node.attributes.length; i++) {
    let item: ReactLiteAstAttribute = node.attributes[i];
    if (item.name === 'className' || item.name === 'bind' || item.name === 'key' || isCompilerOnlyAttribute(node.component, item.name) || item.name === 'onPress' || item.name === 'onSubmit' ||
      item.name === 'onDismiss' || item.name === 'onSelect' || item.name === 'onReachEnd' || item.name === 'onLongPress' ||
      item.name === 'onChange' || item.name === 'item' || item.name === 'keyBy') { continue; }
    let propName: string = isChoiceComponent(node.component) && item.name === 'options' ? 'items' : item.name;
    if (item.value !== undefined) { props[propName] = compileExpression(item.value); }
    else if (item.booleanValue) { props[item.name] = literal(booleanValue(true)); }
    else if (item.stringValue.length > 0) { props[item.name] = literal(stringValue(item.stringValue)); }
  }
  return props;
}

function isChoiceComponent(component: string): boolean { return ['ChoiceChips', 'SegmentedControl', 'Tabs'].indexOf(component) >= 0; }
function isCompilerOnlyAttribute(component: string, attribute: string): boolean { return isChoiceComponent(component) && attribute === 'value'; }

function compileAction(expression: ReactLiteExpression, line: number, column: number): UiAction {
  let kind: UiActionKind = 'state.set'; let args: ReactLiteExpression[] = expression.args;
  let action: UiAction = { id: 'action-' + line.toString() + '-' + column.toString(), kind: kind, targetPageId: '', path: '', keyField: '',
    targetField: '', idPrefix: '', toolName: '', toolArgs: literal(nullValue()), resultBindings: {}, intent: '', assetSlotId: '', steps: [] };
  if (expression.kind === 'lambda' && expression.body !== undefined) { return compileAction(expression.body, line, column); }
  if (expression.kind !== 'call') { return action; }
  let name: string = expression.callee;
  if (name === 'navigate') { action.kind = 'navigation.push'; action.targetPageId = literalText(args, 0); }
  else if (name === 'popTo') { action.kind = 'navigation.popTo'; action.targetPageId = literalText(args, 0); }
  else if (name === 'replace') { action.kind = 'navigation.replace'; action.targetPageId = literalText(args, 0); }
  else if (name === 'back') { action.kind = 'navigation.back'; }
  else if (name === 'resetApp') { action.kind = 'app.reset'; }
  else if (name === 'toggleState') { action.kind = 'state.toggle'; action.path = literalText(args, 0); }
  else if (name === 'incrementState') { action.kind = 'state.increment'; action.path = literalText(args, 0); action.amount = args[1] === undefined ? literal(numberValue(1)) : compileExpression(args[1]); }
  else if (name === 'setState') { action.kind = 'state.set'; action.path = literalText(args, 0); action.value = args[1] === undefined ? literal(nullValue()) : compileExpression(args[1]); }
  else if (name === 'appendState') { action.kind = 'list.append'; action.path = literalText(args, 0); action.value = args[1] === undefined ? literal(nullValue()) : compileExpression(args[1]); }
  else if (name === 'appendWithId') { action.kind = 'list.appendWithId'; action.path = literalText(args, 0); action.idPrefix = literalText(args, 1); action.keyField = 'id'; action.value = args[2] === undefined ? literal(nullValue()) : compileExpression(args[2]); }
  else if (name === 'updateWhere') { action.kind = 'list.updateWhere'; action.path = literalText(args, 0); action.keyField = literalText(args, 1); action.keyValue = args[2] === undefined ? literal(nullValue()) : compileExpression(args[2]); action.value = args[3] === undefined ? literal(nullValue()) : compileExpression(args[3]); }
  else if (name === 'removeWhere') { action.kind = 'list.removeWhere'; action.path = literalText(args, 0); action.keyField = literalText(args, 1); action.keyValue = args[2] === undefined ? literal(nullValue()) : compileExpression(args[2]); }
  else if (name === 'toggleWhere') { action.kind = 'list.toggleWhere'; action.path = literalText(args, 0); action.keyField = literalText(args, 1); action.keyValue = args[2] === undefined ? literal(nullValue()) : compileExpression(args[2]); action.targetField = literalText(args, 3); }
  else if (name === 'pickLocalImage') { action.kind = 'asset.pickLocalImage'; action.assetSlotId = literalText(args, 0); }
  else if (name === 'invokeTool') { action.kind = 'tool.invoke'; action.toolName = literalText(args, 0); action.toolArgs = args[1] === undefined ? literal(nullValue()) : compileExpression(args[1]); action.targetPageId = literalText(args, 3); }
  else if (name === 'invokeAgent') { compileAgentAction(action, args); }
  else if (name === 'transaction') { action.kind = 'action.transaction'; for (let i: number = 0; i < args.length; i++) { action.steps.push(compileAction(args[i], line, column)); } }
  else if (name === 'sequence') { action.kind = 'action.sequence'; for (let i: number = 0; i < args.length; i++) { action.steps.push(compileAction(args[i], line, column)); } }
  return action;
}

function compileAgentAction(action: UiAction, args: ReactLiteExpression[]): void {
  action.kind = 'agent.invoke';
  if (args.length === 1 && args[0].kind === 'object') {
    let intent = objectProperty(args[0], 'intent');
    let agentArgs = objectProperty(args[0], 'args');
    let bind = objectProperty(args[0], 'bind');
    let status = objectProperty(args[0], 'status');
    action.intent = expressionText(intent);
    action.toolArgs = agentArgs === undefined ? literal(objectValue({})) : compileExpression(agentArgs);
    action.statusPath = expressionText(status);
    if (bind !== undefined && bind.kind === 'object') {
      for (let i: number = 0; i < bind.properties.length; i++) {
        action.resultBindings[bind.properties[i].key] = expressionText(bind.properties[i].value);
      }
    }
    let success = objectProperty(args[0], 'onSuccess');
    let failure = objectProperty(args[0], 'onError');
    if (success !== undefined) { action.successSteps = [compileAction(success, 0, 0)]; }
    if (failure !== undefined) { action.errorSteps = [compileAction(failure, 0, 0)]; }
  } else {
    action.intent = literalText(args, 0);
    action.toolArgs = args[1] === undefined ? literal(objectValue({})) : compileExpression(args[1]);
    action.targetPageId = literalText(args, 2);
  }
}

function objectProperty(expression: ReactLiteExpression, name: string): ReactLiteExpression | undefined {
  for (let i: number = 0; i < expression.properties.length; i++) { if (expression.properties[i].key === name) { return expression.properties[i].value; } }
  return undefined;
}

function expressionText(expression: ReactLiteExpression | undefined): string {
  if (expression === undefined) { return ''; }
  if (expression.kind === 'literal') { return expression.value; }
  return expression.kind === 'path' ? expression.path.join('.') : '';
}

function compileExpression(expression: ReactLiteExpression | undefined): UiExpression {
  if (expression === undefined) { return literal(nullValue()); }
  let result: UiExpression = { kind: expression.kind === 'call' ? 'intrinsicCall' : expression.kind, root: '', segments: expression.path,
    operator: expression.operator, items: [], properties: [], callee: expression.callee, args: [], };
  if (expression.kind === 'literal') { result.literalValue = literalUiValue(expression.value); }
  if (expression.kind === 'path') { result.root = expression.path.length > 0 ? expression.path[0] : ''; result.segments = expression.path.slice(1); }
  if (expression.kind === 'map' || expression.kind === 'lambda' || expression.kind === 'jsx') { result.kind = 'literal'; result.literalValue = nullValue(); }
  if (expression.left !== undefined) { result.left = compileExpression(expression.left); }
  if (expression.right !== undefined) { result.right = compileExpression(expression.right); }
  if (expression.test !== undefined) { result.test = compileExpression(expression.test); }
  if (expression.consequent !== undefined) { result.consequent = compileExpression(expression.consequent); }
  if (expression.alternate !== undefined) { result.alternate = compileExpression(expression.alternate); }
  for (let i: number = 0; i < expression.items.length; i++) { result.items.push(compileExpression(expression.items[i])); }
  for (let i: number = 0; i < expression.properties.length; i++) { result.properties.push({ key: expression.properties[i].key, value: compileExpression(expression.properties[i].value) }); }
  for (let i: number = 0; i < expression.args.length; i++) { result.args.push(compileExpression(expression.args[i])); }
  return result;
}

function compileInitialState(expression: ReactLiteExpression): Record<string, UiValue> {
  let result: Record<string, UiValue> = {};
  for (let i: number = 0; i < expression.properties.length; i++) { result[expression.properties[i].key] = expressionToValue(expression.properties[i].value); }
  return result;
}

function expressionToValue(expression: ReactLiteExpression): UiValue {
  if (expression.kind === 'literal') { return literalUiValue(expression.value); }
  if (expression.kind === 'array') { let values: UiValue[] = []; for (let i: number = 0; i < expression.items.length; i++) { values.push(expressionToValue(expression.items[i])); } return arrayValue(values); }
  if (expression.kind === 'object') { let values: Record<string, UiValue> = {}; for (let i: number = 0; i < expression.properties.length; i++) { values[expression.properties[i].key] = expressionToValue(expression.properties[i].value); } return objectValue(values); }
  return stringValue('');
}

function literal(value: UiValue): UiExpression { return { kind: 'literal', literalValue: value, root: '', segments: [], operator: '', items: [], properties: [], callee: '', args: [] }; }
function literalUiValue(value: string): UiValue {
  if (value === 'true') { return booleanValue(true); } if (value === 'false') { return booleanValue(false); } if (value === 'null') { return nullValue(); }
  let number: number = Number(value); return value.length > 0 && !isNaN(number) && /^-?[0-9.]+$/.test(value) ? numberValue(number) : stringValue(value);
}
function literalText(args: ReactLiteExpression[], index: number): string {
  let value: ReactLiteExpression | undefined = args[index]; return value === undefined ? '' : value.kind === 'literal' ? value.value : value.path.join('.');
}
function attrExpression(node: ReactLiteAstNode, name: string): ReactLiteExpression | undefined { for (let i: number = 0; i < node.attributes.length; i++) { if (node.attributes[i].name === name) { return node.attributes[i].value; } } return undefined; }
function attrString(node: ReactLiteAstNode, name: string, fallback: string): string { for (let i: number = 0; i < node.attributes.length; i++) { let a = node.attributes[i]; if (a.name === name) { return a.stringValue.length > 0 ? a.stringValue : a.value === undefined ? fallback : literalText([a.value], 0); } } return fallback; }
function attrBoolean(node: ReactLiteAstNode, name: string, fallback: boolean): boolean { for (let i: number = 0; i < node.attributes.length; i++) { let a = node.attributes[i]; if (a.name === name) { return a.booleanValue || a.stringValue === 'true' || (a.value !== undefined && a.value.value === 'true'); } } return fallback; }
function canonicalComponent(component: string): string {
  if (component === 'Hero') { return 'Stack'; }
  if (component === 'Section' || component === 'FormGroup') { return 'Column'; }
  if (component === 'InfoCard' || component === 'StatusBanner' || component === 'EmptyState') { return 'Card'; }
  if (component === 'ActionBar') { return 'Row'; }
  if (component === 'MetricGrid' || component === 'MediaGallery') { return 'Grid'; }
  if (component === 'Timeline') { return 'List'; }
  if (component === 'Tabs') { return 'ChoiceChips'; }
  return component;
}
function eventName(attribute: string): string {
  if (attribute === 'onPress') { return 'press'; }
  if (attribute === 'onSubmit') { return 'submit'; }
  if (attribute === 'onDismiss') { return 'dismiss'; }
  if (attribute === 'onSelect') { return 'select'; }
  if (attribute === 'onReachEnd') { return 'reachEnd'; }
  if (attribute === 'onChange') { return 'change'; }
  return 'longPress';
}
function defaultClass(component: string, preset: string): string {
  if (component === 'Page') { return 'w-full gap-4 p-4 bg-surface'; }
  if (component === 'Hero') { return 'w-full h-32 rounded-2xl bg-primary shadow-lg'; }
  if (component === 'Card' || component === 'InfoCard' || component === 'StatusBanner' || component === 'EmptyState') { return 'w-full gap-3 p-4 bg-card rounded-xl shadow-sm backdrop-blur-sm'; }
  if (component === 'Button' || component === 'ActionBar') { return 'w-full gap-3 p-3 bg-primary text-white rounded-xl'; }
  if (component === 'TextInput' || component === 'TextArea') { return 'w-full p-3 bg-card rounded-lg border border-border'; }
  if (component === 'MetricGrid') { return 'w-full gap-3'; }
  if (component === 'Sheet') { return 'w-full p-4 bg-card rounded-2xl shadow-lg'; }
  if (component === 'Image') { return 'w-full h-32 object-cover rounded-xl'; }
  return preset === 'result' ? 'w-full gap-3' : 'w-full gap-2';
}
function inferPreset(page: ReactLiteAstNode): string { let title: string = attrString(page, 'title', '').toLowerCase(); return title.indexOf('表单') >= 0 || title.indexOf('输入') >= 0 ? 'guided-form' : title.indexOf('结果') >= 0 || title.indexOf('方案') >= 0 ? 'result' : 'dashboard'; }
function morandiTheme(): UiIrTheme {
  let tokens: Record<string, string> = {};
  tokens['surface'] = '#FFF1F2EE'; tokens['card'] = '#EAF8FAF4'; tokens['primary'] = '#6D7E73'; tokens['secondary'] = '#C89B91';
  tokens['accent'] = '#7A8A99'; tokens['ink'] = '#2E3A35'; tokens['muted'] = '#68756E'; tokens['border'] = '#AAC0B8'; tokens['white'] = '#FFFFFFFF';
  return { name: 'morandi-glass', tokens: tokens };
}
function diagnostic(code: string, message: string, node: ReactLiteAstNode): ReactLiteDiagnostic { return { code: code, severity: 'error', message: message, line: node.line, column: node.column, length: node.component.length, suggestion: '检查 AppShell 和 Page 结构。' }; }
