import { UiAction, UiEvaluationScope, UiExpression, UiIrPage, UiIrSessionState, UiIrSpec, UiValue } from './UiIrTypes';
import { evaluateExpression } from './UiExpressionEvaluator';
import { arrayValue, booleanValue, cloneUiRecord, cloneUiValue, numberValue, objectValue, stringValue, uiValueToBoolean,
  uiValueToDisplayString, uiValueToNumber } from './UiValue';

export interface UiIrEffect {
  kind: 'asset.pickLocalImage' | 'tool.invoke' | 'agent.invoke';
  action: UiAction;
  args: UiValue;
}

export interface UiIrReductionResult {
  session: UiIrSessionState;
  effect: UiIrEffect | undefined;
}

export function createUiIrSession(spec: UiIrSpec): UiIrSessionState {
  return { app: spec, activePageId: spec.initialPageId, routeStack: [spec.initialPageId], state: cloneUiRecord(spec.initialState),
    assets: [], status: 'idle', agentTrace: 'UI IR 已验证并载入。', errorMessage: '', stateRevision: 0,
    computedCacheRevision: -1, computedCache: {} };
}

export function activeUiIrPage(session: UiIrSessionState): UiIrPage {
  for (let i: number = 0; i < session.app.pages.length; i++) { if (session.app.pages[i].id === session.activePageId) { return session.app.pages[i]; } }
  return session.app.pages[0];
}

export function evaluateUiExpression(expression: UiExpression | undefined, session: UiIrSessionState, scope: UiEvaluationScope = { aliases: {}, event: {} }): UiValue {
  if (session.computedCacheRevision !== session.stateRevision) {
    session.computedCacheRevision = session.stateRevision;
    session.computedCache = {};
  }
  return evaluateExpression(expression, session.state, session.app.computed, scope, { values: session.computedCache });
}

export function updateUiBinding(session: UiIrSessionState, path: string, value: UiValue): UiIrSessionState {
  let next: UiIrSessionState = cloneSession(session);
  if (!safePath(path)) { next.errorMessage = '拒绝不安全状态路径。'; return next; }
  let current: UiValue | undefined = getPath(next.state, path);
  if (current === undefined) { next.errorMessage = '绑定字段不存在：' + path; return next; }
  if (current.kind !== 'null' && current.kind !== value.kind) {
    next.errorMessage = '绑定字段类型不匹配：' + path; return next;
  }
  setPath(next.state, path, value); next.stateRevision++; return next;
}

export function reduceUiAction(session: UiIrSessionState, action: UiAction, scope: UiEvaluationScope = { aliases: {}, event: {} }): UiIrReductionResult {
  let next: UiIrSessionState = cloneSession(session); next.errorMessage = '';
  let effect: UiIrEffect | undefined = applyAction(next, action, scope);
  if (effect === undefined && next.errorMessage.length === 0) { next.stateRevision++; }
  return { session: next, effect: effect };
}

export function applyUiToolResult(session: UiIrSessionState, bindings: Record<string, string>, result: Record<string, UiValue>): UiIrSessionState {
  let next: UiIrSessionState = cloneSession(session); let keys: string[] = Object.keys(bindings);
  for (let i: number = 0; i < keys.length; i++) { let source: UiValue | undefined = result[keys[i]]; if (source !== undefined && safePath(bindings[keys[i]])) { setPath(next.state, bindings[keys[i]], source); } }
  next.stateRevision++; return next;
}

export function addUiIrAsset(session: UiIrSessionState, id: string, name: string, dataUrl: string): UiIrSessionState {
  let next: UiIrSessionState = cloneSession(session); next.assets = next.assets.filter((item) => item.id !== id);
  next.assets.push({ id: id, name: name, dataUrl: dataUrl }); return next;
}

export function resetUiIrSession(session: UiIrSessionState): UiIrSessionState {
  let next: UiIrSessionState = createUiIrSession(session.app); next.agentTrace = '应用状态已重置。'; return next;
}

export function assetDataUrl(session: UiIrSessionState, assetId: string): string {
  for (let i: number = 0; i < session.assets.length; i++) { if (session.assets[i].id === assetId) { return session.assets[i].dataUrl; } } return '';
}

function applyAction(session: UiIrSessionState, action: UiAction, scope: UiEvaluationScope): UiIrEffect | undefined {
  if (action.kind === 'action.sequence') {
    for (let i: number = 0; i < action.steps.length; i++) {
      let effect = applyAction(session, action.steps[i], scope);
      if (effect !== undefined) {
        if (i !== action.steps.length - 1) { session.errorMessage = 'sequence 外部 Effect 必须是最后一步。'; return undefined; }
        return effect;
      }
      if (session.errorMessage.length > 0) { return undefined; }
    }
    return undefined;
  }
  if (action.kind === 'state.set') { if (!safePath(action.path)) { session.errorMessage = '拒绝不安全状态路径。'; return undefined; } setPath(session.state, action.path, evaluateUiExpression(action.value, session, scope)); return undefined; }
  if (action.kind === 'state.toggle') { mutateBoolean(session, action.path); return undefined; }
  if (action.kind === 'state.increment') { let current: number = uiValueToNumber(getPath(session.state, action.path)); let amount: number = uiValueToNumber(evaluateUiExpression(action.amount, session, scope)); setPath(session.state, action.path, numberValue(current + amount)); return undefined; }
  if (action.kind === 'list.append') { let list = getPath(session.state, action.path); if (list === undefined || list.kind !== 'array') { session.errorMessage = '目标不是列表。'; return undefined; } list.arrayValue.push(evaluateUiExpression(action.value, session, scope)); return undefined; }
  if (action.kind === 'list.appendWithId') { applyAppendWithId(session, action, scope); return undefined; }
  if (action.kind === 'list.updateWhere' || action.kind === 'list.removeWhere' || action.kind === 'list.toggleWhere') { return applyListAction(session, action, scope); }
  if (action.kind === 'navigation.push') { if (pageExists(session.app, action.targetPageId)) { session.routeStack.push(action.targetPageId); session.activePageId = action.targetPageId; } else { session.errorMessage = '导航目标不存在。'; } return undefined; }
  if (action.kind === 'navigation.back') { if (session.routeStack.length > 1) { session.routeStack.pop(); session.activePageId = session.routeStack[session.routeStack.length - 1]; } return undefined; }
  if (action.kind === 'app.reset') { let reset = resetUiIrSession(session); session.activePageId = reset.activePageId; session.routeStack = reset.routeStack; session.state = reset.state; session.assets = reset.assets; return undefined; }
  if (action.kind === 'asset.pickLocalImage') { return { kind: 'asset.pickLocalImage', action: action, args: stringValue(action.assetSlotId) }; }
  if (action.kind === 'tool.invoke') { return { kind: 'tool.invoke', action: action, args: evaluateUiExpression(action.toolArgs, session, scope) }; }
  if (action.kind === 'agent.invoke') { return { kind: 'agent.invoke', action: action, args: evaluateUiExpression(action.toolArgs, session, scope) }; }
  return undefined;
}

function applyListAction(session: UiIrSessionState, action: UiAction, scope: UiEvaluationScope): undefined {
  let list = getPath(session.state, action.path); if (list === undefined || list.kind !== 'array') { session.errorMessage = '目标不是列表。'; return undefined; }
  let expected = evaluateUiExpression(action.keyValue, session, scope); let output: UiValue[] = [];
  for (let i: number = 0; i < list.arrayValue.length; i++) {
    let item = list.arrayValue[i]; let actual = item.kind === 'object' ? item.objectValue[action.keyField] : undefined;
    if (action.kind === 'list.removeWhere' && actual !== undefined && JSON.stringify(actual) === JSON.stringify(expected)) { continue; }
    if (action.kind === 'list.updateWhere' && actual !== undefined && JSON.stringify(actual) === JSON.stringify(expected) && item.kind === 'object') {
      let patch = evaluateUiExpression(action.value, session, scope);
      if (patch.kind === 'object') {
        let copy = cloneUiValue(item);
        let keys: string[] = Object.keys(patch.objectValue);
        for (let j: number = 0; j < keys.length; j++) { if (keys[j] !== action.keyField) { copy.objectValue[keys[j]] = cloneUiValue(patch.objectValue[keys[j]]); } }
        output.push(copy);
      } else { output.push(item); }
      continue;
    }
    if (action.kind === 'list.toggleWhere' && actual !== undefined && JSON.stringify(actual) === JSON.stringify(expected) && item.kind === 'object') {
      let copy = JSON.parse(JSON.stringify(item)) as UiValue; let old = copy.objectValue[action.targetField]; copy.objectValue[action.targetField] = booleanValue(!uiValueToBoolean(old)); output.push(copy);
    } else { output.push(item); }
  }
  list.arrayValue = output; return undefined;
}

function applyAppendWithId(session: UiIrSessionState, action: UiAction, scope: UiEvaluationScope): void {
  let list = getPath(session.state, action.path);
  if (list === undefined || list.kind !== 'array') { session.errorMessage = '目标不是列表。'; return; }
  let value = evaluateUiExpression(action.value, session, scope);
  if (value.kind !== 'object') { session.errorMessage = 'appendWithId 需要对象值。'; return; }
  // Older generated UI IR may omit idPrefix. Treat it as a compatibility
  // default instead of letting malformed model output crash the runtime.
  let configuredPrefix: string = action.idPrefix === undefined ? '' : action.idPrefix;
  let prefix: string = configuredPrefix.length > 0 ? configuredPrefix : 'item';
  let id: string = allocateListId(list, prefix);
  let item = cloneUiValue(value);
  item.objectValue['id'] = stringValue(id);
  list.arrayValue.push(item);
}

function allocateListId(list: UiValue, prefix: string): string {
  let next: number = 1;
  let used: string[] = [];
  for (let i: number = 0; i < list.arrayValue.length; i++) {
    if (list.arrayValue[i].kind !== 'object') { continue; }
    let idValue: UiValue | undefined = list.arrayValue[i].objectValue['id'];
    if (idValue === undefined) { continue; }
    let id: string = uiValueToDisplayString(idValue); used.push(id);
    let marker: string = prefix + '-';
    if (id.indexOf(marker) === 0) { let suffix: number = Number(id.substring(marker.length)); if (!isNaN(suffix) && suffix >= next) { next = suffix + 1; } }
  }
  let candidate: string = prefix + '-' + next.toString();
  while (used.indexOf(candidate) >= 0) { next++; candidate = prefix + '-' + next.toString(); }
  return candidate;
}

function cloneSession(session: UiIrSessionState): UiIrSessionState { return JSON.parse(JSON.stringify(session)) as UiIrSessionState; }
function pageExists(spec: UiIrSpec, id: string): boolean { for (let i: number = 0; i < spec.pages.length; i++) { if (spec.pages[i].id === id) { return true; } } return false; }
function safePath(path: string): boolean { return path.length > 0 && path.indexOf('__proto__') < 0 && path.indexOf('constructor') < 0 && path.indexOf('prototype') < 0 && /^[A-Za-z_][A-Za-z0-9_]*(\.[A-Za-z_][A-Za-z0-9_]*)*$/.test(path); }
function pathParts(path: string): string[] { return path.split('.'); }
function getPath(state: Record<string, UiValue>, path: string): UiValue | undefined { if (!safePath(path)) { return undefined; } let parts = pathParts(path); let current: UiValue | undefined = state[parts[0]]; for (let i: number = 1; i < parts.length && current !== undefined; i++) { current = current.kind === 'object' ? current.objectValue[parts[i]] : undefined; } return current; }
function setPath(state: Record<string, UiValue>, path: string, value: UiValue): void { if (!safePath(path)) { return; } let parts = pathParts(path); if (parts.length === 1) { state[parts[0]] = cloneUiValue(value); return; } let root = state[parts[0]]; if (root === undefined || root.kind !== 'object') { root = objectValue({}); state[parts[0]] = root; } let current = root; for (let i: number = 1; i < parts.length - 1; i++) { let child = current.objectValue[parts[i]]; if (child === undefined || child.kind !== 'object') { child = objectValue({}); current.objectValue[parts[i]] = child; } current = child; } current.objectValue[parts[parts.length - 1]] = cloneUiValue(value); }
function mutateBoolean(session: UiIrSessionState, path: string): void { setPath(session.state, path, booleanValue(!uiValueToBoolean(getPath(session.state, path)))); }
