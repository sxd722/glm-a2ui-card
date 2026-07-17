import { UiAction, UiActionKind, UiExpression, UiEvaluationScope, UiIrNode, UiIrPage, UiIrSessionState, UiIrSpec, UiIrTheme,
  UiComputedDefinition, UiValue } from './UiIrTypes';
import { createUiIrSession, evaluateUiExpression, reduceUiAction } from './UiIrRuntime';
import { arrayValue, booleanValue, numberValue, objectValue, stringValue, uiRecordToPlainObject, uiValueToDisplayString } from './UiValue';

export interface UiIrSelfTestResult {
  ok: boolean;
  summary: string;
  details: string[];
  wire: string;
}

export function runTravelReactLiteAcceptance(): UiIrSelfTestResult {
  let session = createUiIrSession(testSpec());
  let details: string[] = [];
  let scope: UiEvaluationScope = { aliases: {}, event: {} };
  let first = reduceUiAction(session, action('state.set', 'selectedDay', literalString('10.18')), scope);
  session = first.session;
  let visible = computedItems(session);
  let dateOk: boolean = uiValueToDisplayString(session.state['selectedDay']) === '10.18' && visible.length === 1 && itemId(visible[0]) === 'act-4';
  details.push('date=' + (dateOk ? 'pass' : 'fail'));

  session = reduceUiAction(session, listAction('list.toggleWhere', 'act-1', 'done'), scope).session;
  let doneOk: boolean = itemBoolean(session, 'act-1', 'done');
  details.push('toggle.done=' + (doneOk ? 'pass' : 'fail'));

  session = reduceUiAction(session, listAction('list.toggleWhere', 'act-2', 'liked'), scope).session;
  let likedOk: boolean = itemBoolean(session, 'act-2', 'liked');
  details.push('toggle.liked=' + (likedOk ? 'pass' : 'fail'));

  let beforeRemove: number = list(session).arrayValue.length;
  session = reduceUiAction(session, listAction('list.removeWhere', 'act-2', ''), scope).session;
  let removeOk: boolean = list(session).arrayValue.length === beforeRemove - 1 && !hasItem(session, 'act-2');
  details.push('remove=' + (removeOk ? 'pass' : 'fail'));

  let wireState: Record<string, UiValue> = {};
  wireState['destination'] = stringValue('京都'); wireState['selectedDay'] = stringValue('10.19');
  wireState['travelers'] = numberValue(2); wireState['flexible'] = booleanValue(true);
  let plain = uiRecordToPlainObject(wireState);
  let wire: string = JSON.stringify(plain);
  let wireOk: boolean = wire.indexOf('kind') < 0 && wire.indexOf('stringValue') < 0 && wire.indexOf('numberValue') < 0 &&
    wire.indexOf('booleanValue') < 0 && wire.indexOf('arrayValue') < 0 && wire.indexOf('objectValue') < 0;
  details.push('agentPlainJson=' + (wireOk ? 'pass' : 'fail'));
  let ok: boolean = dateOk && doneOk && likedOk && removeOk && wireOk;
  return { ok: ok, summary: ok ? 'Travel React Lite acceptance passed' : 'Travel React Lite acceptance failed', details: details, wire: wire };
}

function testSpec(): UiIrSpec {
  let itinerary: UiValue[] = [
    item('act-1', '10.19', false, false), item('act-2', '10.19', false, false), item('act-3', '10.19', false, false),
    item('act-4', '10.18', false, false), item('act-5', '10.20', false, false)
  ];
  let theme: UiIrTheme = { name: 'test', tokens: {} };
  let initialState: Record<string, UiValue> = {};
  initialState['selectedDay'] = stringValue('10.19'); initialState['itinerary'] = arrayValue(itinerary);
  let computedDefinition: UiComputedDefinition = { name: 'currentItinerary', expression: { kind: 'intrinsicCall', root: '', segments: [], operator: '', items: [],
    properties: [], callee: 'filterEq', args: [path('state', ['itinerary']), literalString('day'), path('state', ['selectedDay'])] } };
  let root: UiIrNode = { kind: 'element', id: 'root', component: 'Column', props: {}, binding: '', className: '', actions: {}, children: [], itemAlias: '', keyPath: '' };
  let page: UiIrPage = { id: 'home', title: 'Home', scroll: true, layoutPreset: 'default', overlays: [], root: root };
  return { schemaVersion: 'ui-ir-1', appId: 'travel-self-test', title: 'Travel', subtitle: '', initialPageId: 'home',
    theme: theme, initialState: initialState, computed: [computedDefinition], pages: [page] };
}

function item(id: string, day: string, done: boolean, liked: boolean): UiValue {
  let fields: Record<string, UiValue> = {};
  fields['id'] = stringValue(id); fields['day'] = stringValue(day); fields['done'] = booleanValue(done); fields['liked'] = booleanValue(liked);
  return objectValue(fields);
}

function action(kind: 'state.set', pathName: string, value: UiExpression): UiAction {
  return baseAction(kind, pathName, value, '', '');
}

function listAction(kind: 'list.toggleWhere' | 'list.removeWhere', id: string, target: string): UiAction {
  return baseAction(kind, 'itinerary', literalString(id), 'id', target);
}

function baseAction(kind: UiActionKind, pathName: string, value: UiExpression, keyField: string, targetField: string): UiAction {
  return { id: 'self-test-' + kind, kind: kind, targetPageId: '', path: pathName, keyField: keyField, keyValue: value,
    targetField: targetField, idPrefix: '', toolName: '', toolArgs: literalString(''), resultBindings: {}, intent: '', assetSlotId: '', steps: [] };
}

function literalString(value: string): UiExpression {
  return { kind: 'literal', root: '', segments: [], operator: '', items: [], properties: [], callee: '', args: [], literalValue: stringValue(value) };
}

function path(root: string, segments: string[]): UiExpression {
  return { kind: 'path', root: root, segments: segments, operator: '', items: [], properties: [], callee: '', args: [] };
}

function list(session: UiIrSessionState): UiValue { return session.state['itinerary']; }

function computedItems(session: UiIrSessionState): UiValue[] {
  let expression: UiExpression = path('computed', ['currentItinerary']);
  let value: UiValue = evaluateUiExpression(expression, session);
  return value.kind === 'array' ? value.arrayValue : [];
}

function itemId(itemValue: UiValue): string {
  return itemValue.kind === 'object' ? uiValueToDisplayString(itemValue.objectValue['id']) : '';
}

function itemBoolean(session: UiIrSessionState, id: string, field: string): boolean {
  let values: UiValue[] = list(session).arrayValue;
  for (let i: number = 0; i < values.length; i++) {
    if (itemId(values[i]) === id && values[i].kind === 'object') { return values[i].objectValue[field].booleanValue; }
  }
  return false;
}

function hasItem(session: UiIrSessionState, id: string): boolean {
  let values: UiValue[] = list(session).arrayValue;
  for (let i: number = 0; i < values.length; i++) { if (itemId(values[i]) === id) { return true; } }
  return false;
}
