import { UiAction, UiComponentType, UiComputedDefinition, UiExpression, UiIrDiagnostic, UiIrNode, UiIrSpec, UiIrValidationResult, UiValue } from './UiIrTypes';
import { isSupportedUtilityToken } from './UiStyleRegistry';

const COMPONENTS: UiComponentType[] = ['SafeArea', 'Scroll', 'Column', 'Row', 'Stack', 'Grid', 'List', 'Card',
  'Text', 'Image', 'Icon', 'Badge', 'Progress', 'Divider', 'Spacer', 'Button', 'IconButton', 'TextInput',
  'TextArea', 'Toggle', 'Checkbox', 'ChoiceChips', 'SegmentedControl', 'Hero', 'Section', 'InfoCard', 'FormGroup',
  'MetricGrid', 'Timeline', 'ResultList', 'MediaGallery', 'StatusBanner', 'Tabs', 'ActionBar', 'EmptyState', 'Sheet'];
const ACTIONS: string[] = ['state.set', 'state.toggle', 'state.increment', 'list.append', 'list.appendWithId', 'list.updateWhere', 'list.removeWhere',
  'list.toggleWhere', 'navigation.push', 'navigation.back', 'navigation.popTo', 'navigation.replace', 'app.reset',
  'asset.pickLocalImage', 'tool.invoke', 'agent.invoke', 'action.sequence', 'action.transaction'];
const MAX_NODES: number = 320;
const MAX_EXPRESSION_DEPTH: number = 16;
const MAX_STATE_DEPTH: number = 8;
const MAX_INITIAL_ARRAY_ITEMS: number = 200;
const MAX_TEXT_LENGTH: number = 20000;
const MAX_ACTION_NODES: number = 128;
const MAX_STATE_JSON_LENGTH: number = 200000;

interface ValidationBudget {
  nodes: number;
  actions: number;
  nodeIds: string[];
}

export function validateUiIrSpec(spec: UiIrSpec, toolNames: string[] = [], assetIds: string[] = []): UiIrValidationResult {
  let diagnostics: UiIrDiagnostic[] = [];
  if (spec === undefined || spec === null) { diagnostics.push(error('UI1001', 'UI IR 为空', '', '')); return { ok: false, diagnostics: diagnostics }; }
  if (spec.schemaVersion !== 'ui-ir-1') { diagnostics.push(error('UI1002', '不支持的 UI IR 版本', '', 'schemaVersion')); }
  if (spec.appId.length === 0 || spec.title.length === 0) { diagnostics.push(error('UI1003', '应用元数据缺失', '', 'appId')); }
  if (spec.pages.length === 0 || spec.pages.length > 5) { diagnostics.push(error('UI1004', '页面数量必须为 1 到 5', '', 'pages')); }
  let pageIds: string[] = [];
  for (let i: number = 0; i < spec.pages.length; i++) {
    let page = spec.pages[i];
    if (pageIds.indexOf(page.id) >= 0) { diagnostics.push(error('UI1005', '页面 ID 重复', page.id, 'pages')); }
    pageIds.push(page.id);
  }
  let budget: ValidationBudget = { nodes: 0, actions: 0, nodeIds: [] };
  if (JSON.stringify(spec.initialState).length > MAX_STATE_JSON_LENGTH) {
    diagnostics.push(error('UI1045', '初始状态总大小超过限制', '', 'initialState'));
  }
  let initialStateKeys: string[] = Object.keys(spec.initialState);
  for (let i: number = 0; i < initialStateKeys.length; i++) { validateState(spec.initialState[initialStateKeys[i]], initialStateKeys[i], 0, diagnostics); }
  for (let i: number = 0; i < spec.pages.length; i++) {
    validateNode(spec.pages[i].root, 0, 0, pageIds, spec.initialState, [], diagnostics, toolNames, assetIds, budget);
  }
  if (pageIds.indexOf(spec.initialPageId) < 0) { diagnostics.push(error('UI1006', '初始页面不存在', '', 'initialPageId')); }
  let stateKeys: string[] = Object.keys(spec.initialState);
  if (stateKeys.length > 64) { diagnostics.push(error('UI1007', '初始状态字段过多', '', 'initialState')); }
  for (let i: number = 0; i < stateKeys.length; i++) { if (!safePath(stateKeys[i])) { diagnostics.push(error('UI1008', '状态路径不安全', '', stateKeys[i])); } }
  if (budget.nodes > MAX_NODES) { diagnostics.push(error('UI1025', '节点总数超过限制', '', 'pages')); }
  if (budget.actions > MAX_ACTION_NODES) { diagnostics.push(error('UI1026', 'Action 总数超过限制', '', 'actions')); }
  if (spec.computed.length > 30) { diagnostics.push(error('UI1009', 'computed 数量超过限制', '', 'computed')); }
  validateComputed(spec.computed, diagnostics);
  return { ok: diagnostics.filter((item: UiIrDiagnostic) => item.severity === 'error').length === 0, diagnostics: diagnostics };
}

function validateNode(node: UiIrNode, depth: number, forEachDepth: number, pageIds: string[], state: Record<string, UiValue>,
  aliases: string[], diagnostics: UiIrDiagnostic[], toolNames: string[], assetIds: string[], budget: ValidationBudget): void {
  if (depth > 16) { diagnostics.push(error('UI1010', '节点树深度超过限制', node.id, node.id)); return; }
  budget.nodes++;
  if (node.id.length === 0) { diagnostics.push(error('UI1011', '节点缺少 ID', '', 'id')); }
  if (countNodeId(node.id, budget) > 1) { diagnostics.push(error('UI1027', '节点 ID 重复：' + node.id, node.id, 'id')); }
  if (node.kind === 'element' && COMPONENTS.indexOf(node.component) < 0) {
    diagnostics.push(error('UI1012', '未知组件：' + node.component, node.id, 'component'));
  }
  if (node.className.length > 0) {
    let tokens: string[] = node.className.split(/\s+/);
    for (let i: number = 0; i < tokens.length; i++) { if (!isSupportedUtilityToken(tokens[i])) { diagnostics.push(error('UI1028', '不支持的样式 token：' + tokens[i], node.id, 'className')); } }
  }
  if (node.binding.length > 0 && !safePath(node.binding)) { diagnostics.push(error('UI1013', '绑定路径不安全', node.id, 'binding')); }
  if (node.binding.length > 0 && !bindingRootExists(node.binding, state, aliases)) { diagnostics.push(error('UI1029', '绑定字段不存在：' + node.binding, node.id, 'binding')); }
  if (node.binding.length > 0 && ((node.component === 'Checkbox' && node.props['checked'] !== undefined) ||
    (node.component === 'Toggle' && node.props['value'] !== undefined))) {
    diagnostics.push(error('UI1053', '受控组件不能同时使用 bind', node.id, 'binding'));
  }
  validateNodeProps(node, diagnostics);
  if (node.kind === 'if' && node.condition === undefined) { diagnostics.push(error('UI1014', 'If 缺少条件', node.id, 'condition')); }
  if (node.kind === 'forEach') {
    if (node.source === undefined || node.itemAlias.length === 0 || node.keyPath.length === 0) {
      diagnostics.push(error('UI1015', 'ForEach 缺少 source/item/keyBy', node.id, 'forEach'));
    }
    if (forEachDepth >= 3) { diagnostics.push(error('UI1016', 'ForEach 嵌套超过限制', node.id, 'forEach')); }
    validateRepeatKey(node, state, diagnostics);
  }
  let actionKeys: string[] = Object.keys(node.actions);
  if (actionKeys.length > 16) { diagnostics.push(error('UI1017', '节点 Action 过多', node.id, 'actions')); }
  for (let i: number = 0; i < actionKeys.length; i++) { validateAction(node.actions[actionKeys[i]], pageIds, state, diagnostics, toolNames, budget); }
  let childForEachDepth: number = node.kind === 'forEach' ? forEachDepth + 1 : forEachDepth;
  let childAliases: string[] = aliases.slice(); if (node.kind === 'forEach') { childAliases.push(node.itemAlias); }
  for (let i: number = 0; i < node.children.length; i++) {
    validateNode(node.children[i], depth + 1, childForEachDepth, pageIds, state, childAliases, diagnostics, toolNames, assetIds, budget);
  }
  let assetId: UiExpression | undefined = node.props['assetId'];
  if (assetId !== undefined && assetId.kind === 'literal' && assetId.literalValue !== undefined &&
    assetId.literalValue.stringValue.length > 0 && assetIds.length > 0 && assetIds.indexOf(assetId.literalValue.stringValue) < 0) {
    diagnostics.push(warning('UI2002', '图片资源未在当前 Session 中提供', node.id, 'assetId'));
  }
}

function validateAction(action: UiAction, pageIds: string[], state: Record<string, UiValue>, diagnostics: UiIrDiagnostic[], toolNames: string[], budget: ValidationBudget): void {
  budget.actions++;
  if (ACTIONS.indexOf(action.kind) < 0) { diagnostics.push(error('UI1020', '未知 Action：' + action.kind, action.id, 'kind')); }
  if (['navigation.push', 'navigation.popTo', 'navigation.replace'].indexOf(action.kind) >= 0 && pageIds.indexOf(action.targetPageId) < 0) {
    diagnostics.push(error('UI1021', '导航目标不存在', action.id, 'targetPageId'));
  }
  if (action.kind === 'tool.invoke' && toolNames.indexOf(action.toolName) < 0) {
    diagnostics.push(error('UI1022', '工具未注册：' + action.toolName, action.id, 'toolName'));
  }
  if (action.path.length > 0 && !safePath(action.path)) { diagnostics.push(error('UI1023', 'Action 状态路径不安全', action.id, 'path')); }
  if (action.path.length > 0 && safePath(action.path)) { validateActionPath(action, state, diagnostics); }
  if (action.steps.length > 8) { diagnostics.push(error('UI1024', 'Action sequence 超过 8 步', action.id, 'steps')); }
  validateExpression(action.keyValue, 0, diagnostics, action.id);
  validateExpression(action.amount, 0, diagnostics, action.id);
  validateExpression(action.value, 0, diagnostics, action.id);
  validateExpression(action.toolArgs, 0, diagnostics, action.id);
  if (action.kind === 'action.sequence') { validateSequence(action, diagnostics); }
  if (action.kind === 'action.transaction') { validateTransaction(action, diagnostics); }
  if (action.kind === 'agent.invoke') { validateAgentAction(action, state, diagnostics); }
  if (action.kind === 'agent.invoke') {
    validateLocalLifecycleSteps(action.successSteps, pageIds, state, diagnostics, toolNames, budget, action.id);
    validateLocalLifecycleSteps(action.errorSteps, pageIds, state, diagnostics, toolNames, budget, action.id);
  }
  if ((action.kind === 'list.appendWithId' || action.kind === 'list.updateWhere') &&
    (action.value === undefined || action.value.kind !== 'object')) {
    diagnostics.push(error('UI1046', action.kind === 'list.appendWithId' ? 'appendWithId 需要对象值' : 'updateWhere 需要对象 patch', action.id, 'value'));
  }
  let idPrefix: string = action.idPrefix === undefined ? '' : action.idPrefix;
  if (action.kind === 'list.appendWithId' && idPrefix.length === 0) {
    diagnostics.push(error('UI1047', 'appendWithId 缺少稳定 ID 前缀', action.id, 'idPrefix'));
  }
  for (let i: number = 0; i < action.steps.length; i++) { validateAction(action.steps[i], pageIds, state, diagnostics, toolNames, budget); }
}

function validateLocalLifecycleSteps(steps: UiAction[] | undefined, pageIds: string[], state: Record<string, UiValue>,
  diagnostics: UiIrDiagnostic[], toolNames: string[], budget: ValidationBudget, parentId: string): void {
  if (steps === undefined) { return; }
  for (let i: number = 0; i < steps.length; i++) {
    if (isExternalEffect(steps[i])) { diagnostics.push(error('UI1054', 'Agent success/error steps 只能包含本地 Action', parentId, 'steps')); }
    validateAction(steps[i], pageIds, state, diagnostics, toolNames, budget);
  }
}

function countNodeId(id: string, budget: ValidationBudget): number {
  let count: number = 0;
  for (let i: number = 0; i < budget.nodeIds.length; i++) { if (budget.nodeIds[i] === id) { count++; } }
  budget.nodeIds.push(id); return count + 1;
}

function validateNodeProps(node: UiIrNode, diagnostics: UiIrDiagnostic[]): void {
  let keys: string[] = Object.keys(node.props);
  for (let i: number = 0; i < keys.length; i++) {
    let expression: UiExpression = node.props[keys[i]];
    validateExpression(expression, 0, diagnostics, node.id);
    if (expression.kind === 'literal' && expression.literalValue !== undefined && expression.literalValue.kind === 'string' &&
      expression.literalValue.stringValue.length > MAX_TEXT_LENGTH) {
      diagnostics.push(error('UI1030', '文本长度超过限制', node.id, keys[i]));
    }
  }
}

function validateExpression(expression: UiExpression | undefined, depth: number, diagnostics: UiIrDiagnostic[], nodeId: string): void {
  if (expression === undefined) { return; }
  if (depth > MAX_EXPRESSION_DEPTH) { diagnostics.push(error('UI1031', 'Expression 深度超过限制', nodeId, 'expression')); return; }
  validateExpression(expression.left, depth + 1, diagnostics, nodeId);
  validateExpression(expression.right, depth + 1, diagnostics, nodeId);
  validateExpression(expression.test, depth + 1, diagnostics, nodeId);
  validateExpression(expression.consequent, depth + 1, diagnostics, nodeId);
  validateExpression(expression.alternate, depth + 1, diagnostics, nodeId);
  for (let i: number = 0; i < expression.items.length; i++) { validateExpression(expression.items[i], depth + 1, diagnostics, nodeId); }
  for (let i: number = 0; i < expression.properties.length; i++) { validateExpression(expression.properties[i].value, depth + 1, diagnostics, nodeId); }
  for (let i: number = 0; i < expression.args.length; i++) { validateExpression(expression.args[i], depth + 1, diagnostics, nodeId); }
}

function validateState(value: UiValue, path: string, depth: number, diagnostics: UiIrDiagnostic[]): void {
  if (depth > MAX_STATE_DEPTH) { diagnostics.push(error('UI1032', 'State 对象深度超过限制', '', path)); return; }
  if (value.kind === 'string' && value.stringValue.length > MAX_TEXT_LENGTH) { diagnostics.push(error('UI1033', 'State 文本长度超过限制', '', path)); }
  if (value.kind === 'array') {
    if (value.arrayValue.length > MAX_INITIAL_ARRAY_ITEMS) { diagnostics.push(error('UI1034', '初始数组长度超过限制', '', path)); }
    for (let i: number = 0; i < value.arrayValue.length; i++) { validateState(value.arrayValue[i], path + '[' + i.toString() + ']', depth + 1, diagnostics); }
  }
  if (value.kind === 'object') {
    let keys: string[] = Object.keys(value.objectValue);
    for (let i: number = 0; i < keys.length; i++) { validateState(value.objectValue[keys[i]], path.length === 0 ? keys[i] : path + '.' + keys[i], depth + 1, diagnostics); }
  }
}

function bindingRootExists(path: string, state: Record<string, UiValue>, aliases: string[]): boolean {
  let root: string = path.split('.')[0];
  if (root === 'state') { let parts: string[] = path.split('.'); return parts.length > 1 && state[parts[1]] !== undefined; }
  return state[root] !== undefined || aliases.indexOf(root) >= 0;
}

function validateRepeatKey(node: UiIrNode, state: Record<string, UiValue>, diagnostics: UiIrDiagnostic[]): void {
  if (node.source === undefined || node.keyPath.length === 0) { return; }
  let list: UiValue | undefined = readExpressionStatePath(node.source, state);
  if (list === undefined || list.kind !== 'array') { return; }
  let keys: string[] = [];
  for (let i: number = 0; i < list.arrayValue.length; i++) {
    let key: UiValue | undefined = readUiPath(list.arrayValue[i], node.keyPath);
    if (key === undefined || (key.kind !== 'string' && key.kind !== 'number') || uiKey(key).length === 0) {
      diagnostics.push(error('UI1035', 'ForEach keyPath 无法解析：' + node.keyPath, node.id, 'keyPath'));
      continue;
    }
    if (keys.indexOf(uiKey(key)) >= 0) { diagnostics.push(error('UI1036', 'ForEach keyPath 产生重复 key：' + uiKey(key), node.id, 'keyPath')); }
    keys.push(uiKey(key));
  }
}

function readExpressionStatePath(expression: UiExpression, state: Record<string, UiValue>): UiValue | undefined {
  if (expression.kind !== 'path') { return undefined; }
  if (expression.root === 'state') { return readStatePath(state, expression.segments); }
  if (expression.segments.length === 0) { return state[expression.root]; }
  return undefined;
}

function readStatePath(state: Record<string, UiValue>, parts: string[]): UiValue | undefined {
  if (parts.length === 0) { return undefined; }
  let current: UiValue | undefined = state[parts[0]];
  for (let i: number = 1; i < parts.length && current !== undefined; i++) { current = current.kind === 'object' ? current.objectValue[parts[i]] : undefined; }
  return current;
}

function readUiPath(value: UiValue, path: string): UiValue | undefined {
  let current: UiValue | undefined = value; let parts: string[] = path.split('.');
  for (let i: number = 0; i < parts.length && current !== undefined; i++) { current = current.kind === 'object' ? current.objectValue[parts[i]] : undefined; }
  return current;
}

function uiKey(value: UiValue): string { return value.kind === 'number' ? value.numberValue.toString() : value.stringValue; }

function validateActionPath(action: UiAction, state: Record<string, UiValue>, diagnostics: UiIrDiagnostic[]): void {
  let target: UiValue | undefined = readStatePath(state, action.path.split('.'));
  if (target === undefined) { diagnostics.push(error('UI1037', 'Action path 不存在：' + action.path, action.id, 'path')); return; }
  if (action.kind === 'state.toggle' && target.kind !== 'boolean') { diagnostics.push(error('UI1038', 'toggle 需要 boolean path', action.id, 'path')); }
  if (action.kind === 'state.increment' && target.kind !== 'number') { diagnostics.push(error('UI1039', 'increment 需要 number path', action.id, 'path')); }
  if (['list.append', 'list.appendWithId', 'list.updateWhere', 'list.removeWhere', 'list.toggleWhere'].indexOf(action.kind) >= 0 && target.kind !== 'array') {
    diagnostics.push(error('UI1040', '列表 Action 需要 array path', action.id, 'path'));
  }
}

function validateSequence(action: UiAction, diagnostics: UiIrDiagnostic[]): void {
  let effectCount: number = 0;
  for (let i: number = 0; i < action.steps.length; i++) {
    if (isExternalEffect(action.steps[i])) {
      effectCount++;
      if (i !== action.steps.length - 1) { diagnostics.push(error('UI1041', 'sequence 外部 Effect 必须是最后一步', action.id, 'steps')); }
    }
  }
  if (effectCount > 1) { diagnostics.push(error('UI1042', 'sequence 最多包含一个外部 Effect', action.id, 'steps')); }
}

function validateTransaction(action: UiAction, diagnostics: UiIrDiagnostic[]): void {
  for (let i: number = 0; i < action.steps.length; i++) {
    if (isExternalEffect(action.steps[i])) {
      diagnostics.push(error('UI1048', 'transaction 只允许本地 Action，外部 Effect 请使用 sequence 并置于末尾', action.id, 'steps'));
    }
  }
}

function validateAgentAction(action: UiAction, state: Record<string, UiValue>, diagnostics: UiIrDiagnostic[]): void {
  if (action.intent.length === 0) { diagnostics.push(error('UI1049', 'Agent intent 不能为空', action.id, 'intent')); }
  if (action.toolArgs.kind !== 'object') { diagnostics.push(error('UI1050', 'Agent args 必须是 object', action.id, 'toolArgs')); }
  if (action.statusPath !== undefined && action.statusPath.length > 0 && !bindingRootExists(action.statusPath, state, [])) {
    diagnostics.push(error('UI1051', 'Agent status 路径不存在：' + action.statusPath, action.id, 'status'));
  }
  let keys: string[] = Object.keys(action.resultBindings);
  for (let i: number = 0; i < keys.length; i++) {
    if (!safePath(action.resultBindings[keys[i]]) || !bindingRootExists(action.resultBindings[keys[i]], state, [])) {
      diagnostics.push(error('UI1052', 'Agent bind 目标不存在：' + action.resultBindings[keys[i]], action.id, 'bind'));
    }
  }
}

function isExternalEffect(action: UiAction): boolean {
  return action.kind === 'tool.invoke' || action.kind === 'agent.invoke' || action.kind === 'asset.pickLocalImage' ||
    (action.kind === 'action.sequence' && action.steps.some((step: UiAction) => isExternalEffect(step)));
}

function validateComputed(definitions: UiComputedDefinition[], diagnostics: UiIrDiagnostic[]): void {
  let names: string[] = [];
  for (let i: number = 0; i < definitions.length; i++) {
    if (names.indexOf(definitions[i].name) >= 0) { diagnostics.push(error('UI1043', 'computed 名称重复：' + definitions[i].name, '', 'computed')); }
    names.push(definitions[i].name); validateExpression(definitions[i].expression, 0, diagnostics, definitions[i].name);
  }
  let visiting: string[] = []; let visited: string[] = [];
  for (let i: number = 0; i < definitions.length; i++) { visitComputed(definitions[i].name, definitions, names, visiting, visited, diagnostics); }
}

function visitComputed(name: string, definitions: UiComputedDefinition[], names: string[], visiting: string[], visited: string[], diagnostics: UiIrDiagnostic[]): void {
  if (visiting.indexOf(name) >= 0) { diagnostics.push(error('UI1044', 'computed 存在循环依赖：' + name, '', 'computed')); return; }
  if (visited.indexOf(name) >= 0) { return; }
  let definition: UiExpression | undefined = undefined;
  for (let i: number = 0; i < definitions.length; i++) { if (definitions[i].name === name) { definition = definitions[i].expression; } }
  if (definition === undefined) { return; }
  visiting.push(name); let dependencies: string[] = []; collectComputedDependencies(definition, names, dependencies);
  for (let i: number = 0; i < dependencies.length; i++) { visitComputed(dependencies[i], definitions, names, visiting, visited, diagnostics); }
  visiting.pop(); visited.push(name);
}

function collectComputedDependencies(expression: UiExpression, names: string[], result: string[]): void {
  if (expression.kind === 'path') {
    if (expression.root === 'computed' && expression.segments.length > 0 && names.indexOf(expression.segments[0]) >= 0) { result.push(expression.segments[0]); }
    if (expression.segments.length === 0 && names.indexOf(expression.root) >= 0) { result.push(expression.root); }
  }
  if (expression.left !== undefined) { collectComputedDependencies(expression.left, names, result); }
  if (expression.right !== undefined) { collectComputedDependencies(expression.right, names, result); }
  if (expression.test !== undefined) { collectComputedDependencies(expression.test, names, result); }
  if (expression.consequent !== undefined) { collectComputedDependencies(expression.consequent, names, result); }
  if (expression.alternate !== undefined) { collectComputedDependencies(expression.alternate, names, result); }
  for (let i: number = 0; i < expression.items.length; i++) { collectComputedDependencies(expression.items[i], names, result); }
  for (let i: number = 0; i < expression.properties.length; i++) { collectComputedDependencies(expression.properties[i].value, names, result); }
  for (let i: number = 0; i < expression.args.length; i++) { collectComputedDependencies(expression.args[i], names, result); }
}

function safePath(path: string): boolean {
  if (path.length === 0 || path.indexOf('__proto__') >= 0 || path.indexOf('constructor') >= 0 || path.indexOf('prototype') >= 0) { return false; }
  return /^[A-Za-z_][A-Za-z0-9_]*(\.[A-Za-z_][A-Za-z0-9_]*|\[[0-9]+\])*$/.test(path);
}

function error(code: string, message: string, nodeId: string, path: string): UiIrDiagnostic {
  return { code: code, severity: 'error', message: message, nodeId: nodeId, path: path };
}

function warning(code: string, message: string, nodeId: string, path: string): UiIrDiagnostic {
  return { code: code, severity: 'warning', message: message, nodeId: nodeId, path: path };
}
