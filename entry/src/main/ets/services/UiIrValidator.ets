import { UiAction, UiComponentType, UiExpression, UiIrDiagnostic, UiIrNode, UiIrSpec, UiIrValidationResult } from './UiIrTypes';

const COMPONENTS: UiComponentType[] = ['SafeArea', 'Scroll', 'Column', 'Row', 'Stack', 'Grid', 'List', 'Card',
  'Text', 'Image', 'Icon', 'Badge', 'Progress', 'Divider', 'Spacer', 'Button', 'IconButton', 'TextInput',
  'TextArea', 'Toggle', 'Checkbox', 'ChoiceChips', 'SegmentedControl'];
const ACTIONS: string[] = ['state.set', 'state.toggle', 'state.increment', 'list.append', 'list.removeWhere',
  'list.updateWhere', 'list.toggleWhere', 'navigation.push', 'navigation.back', 'app.reset',
  'asset.pickLocalImage', 'tool.invoke', 'agent.invoke', 'action.sequence'];
const STYLE_TOKENS: string[] = ['w-full', 'h-full', 'flex-1', 'flex-col', 'flex-row', 'items-center', 'items-end',
  'justify-center', 'justify-between', 'justify-end', 'text-center', 'text-right', 'object-cover', 'object-contain',
  'bg-surface', 'bg-card', 'bg-primary', 'bg-secondary', 'bg-accent', 'text-ink', 'text-muted', 'text-white',
  'border', 'rounded', 'rounded-md', 'rounded-lg', 'rounded-xl', 'rounded-2xl', 'rounded-full', 'shadow-sm',
  'shadow-md', 'shadow-lg', 'backdrop-blur-sm', 'backdrop-blur-md'];

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
  for (let i: number = 0; i < spec.pages.length; i++) {
    validateNode(spec.pages[i].root, 0, 0, pageIds, diagnostics, toolNames, assetIds);
  }
  if (pageIds.indexOf(spec.initialPageId) < 0) { diagnostics.push(error('UI1006', '初始页面不存在', '', 'initialPageId')); }
  let stateKeys: string[] = Object.keys(spec.initialState);
  if (stateKeys.length > 64) { diagnostics.push(error('UI1007', '初始状态字段过多', '', 'initialState')); }
  for (let i: number = 0; i < stateKeys.length; i++) { if (!safePath(stateKeys[i])) { diagnostics.push(error('UI1008', '状态路径不安全', '', stateKeys[i])); } }
  if (spec.computed.length > 30) { diagnostics.push(error('UI1009', 'computed 数量超过限制', '', 'computed')); }
  return { ok: diagnostics.filter((item: UiIrDiagnostic) => item.severity === 'error').length === 0, diagnostics: diagnostics };
}

function validateNode(node: UiIrNode, depth: number, forEachDepth: number, pageIds: string[], diagnostics: UiIrDiagnostic[],
  toolNames: string[], assetIds: string[]): void {
  if (depth > 16) { diagnostics.push(error('UI1010', '节点树深度超过限制', node.id, node.id)); return; }
  if (node.id.length === 0) { diagnostics.push(error('UI1011', '节点缺少 ID', '', 'id')); }
  if (node.kind === 'element' && COMPONENTS.indexOf(node.component) < 0) {
    diagnostics.push(error('UI1012', '未知组件：' + node.component, node.id, 'component'));
  }
  if (node.className.length > 0) {
    let tokens: string[] = node.className.split(/\s+/);
    for (let i: number = 0; i < tokens.length; i++) {
      if (!allowedStyle(tokens[i])) { diagnostics.push(warning('UI2001', '未识别样式 token：' + tokens[i], node.id, 'className')); }
    }
  }
  if (node.binding.length > 0 && !safePath(node.binding)) { diagnostics.push(error('UI1013', '绑定路径不安全', node.id, 'binding')); }
  if (node.kind === 'if' && node.condition === undefined) { diagnostics.push(error('UI1014', 'If 缺少条件', node.id, 'condition')); }
  if (node.kind === 'forEach') {
    if (node.source === undefined || node.itemAlias.length === 0 || node.keyPath.length === 0) {
      diagnostics.push(error('UI1015', 'ForEach 缺少 source/item/keyBy', node.id, 'forEach'));
    }
    if (forEachDepth >= 3) { diagnostics.push(error('UI1016', 'ForEach 嵌套超过限制', node.id, 'forEach')); }
  }
  let actionKeys: string[] = Object.keys(node.actions);
  if (actionKeys.length > 16) { diagnostics.push(error('UI1017', '节点 Action 过多', node.id, 'actions')); }
  for (let i: number = 0; i < actionKeys.length; i++) { validateAction(node.actions[actionKeys[i]], pageIds, diagnostics, toolNames); }
  let childForEachDepth: number = node.kind === 'forEach' ? forEachDepth + 1 : forEachDepth;
  for (let i: number = 0; i < node.children.length; i++) {
    validateNode(node.children[i], depth + 1, childForEachDepth, pageIds, diagnostics, toolNames, assetIds);
  }
  let assetId: UiExpression | undefined = node.props['assetId'];
  if (assetId !== undefined && assetId.kind === 'literal' && assetId.literalValue !== undefined &&
    assetId.literalValue.stringValue.length > 0 && assetIds.length > 0 && assetIds.indexOf(assetId.literalValue.stringValue) < 0) {
    diagnostics.push(warning('UI2002', '图片资源未在当前 Session 中提供', node.id, 'assetId'));
  }
}

function validateAction(action: UiAction, pageIds: string[], diagnostics: UiIrDiagnostic[], toolNames: string[]): void {
  if (ACTIONS.indexOf(action.kind) < 0) { diagnostics.push(error('UI1020', '未知 Action：' + action.kind, action.id, 'kind')); }
  if (action.kind === 'navigation.push' && pageIds.indexOf(action.targetPageId) < 0) {
    diagnostics.push(error('UI1021', '导航目标不存在', action.id, 'targetPageId'));
  }
  if (action.kind === 'tool.invoke' && toolNames.indexOf(action.toolName) < 0) {
    diagnostics.push(error('UI1022', '工具未注册：' + action.toolName, action.id, 'toolName'));
  }
  if (action.path.length > 0 && !safePath(action.path)) { diagnostics.push(error('UI1023', 'Action 状态路径不安全', action.id, 'path')); }
  if (action.steps.length > 8) { diagnostics.push(error('UI1024', 'Action sequence 超过 8 步', action.id, 'steps')); }
  for (let i: number = 0; i < action.steps.length; i++) { validateAction(action.steps[i], pageIds, diagnostics, toolNames); }
}

function safePath(path: string): boolean {
  if (path.length === 0 || path.indexOf('__proto__') >= 0 || path.indexOf('constructor') >= 0 || path.indexOf('prototype') >= 0) { return false; }
  return /^[A-Za-z_][A-Za-z0-9_]*(\.[A-Za-z_][A-Za-z0-9_]*|\[[0-9]+\])*$/.test(path);
}

function allowedStyle(token: string): boolean {
  if (STYLE_TOKENS.indexOf(token) >= 0) { return true; }
  return /^(p|px|py|pt|pr|pb|pl|m|mx|my|mt|mr|mb|ml|gap|text|h|w|rounded|opacity)-[0-9]+$/.test(token) ||
    /^text-(xs|sm|base|lg|xl|2xl|3xl)$/.test(token) || /^font-(medium|semibold|bold)$/.test(token);
}

function error(code: string, message: string, nodeId: string, path: string): UiIrDiagnostic {
  return { code: code, severity: 'error', message: message, nodeId: nodeId, path: path };
}

function warning(code: string, message: string, nodeId: string, path: string): UiIrDiagnostic {
  return { code: code, severity: 'warning', message: message, nodeId: nodeId, path: path };
}
