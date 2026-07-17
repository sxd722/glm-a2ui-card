import { AppBlueprint, AppPagePlan, ComponentRecipe, DynamicSlotPolicy, SkillInputField, SkillManifest, ToolContract } from './SkillAppTypes';
import { compileTravelReactLite, TRAVEL_REACT_LITE_SOURCE } from './ReactLiteExamples';
import { UiAction, UiActionKind, UiExpression, UiEvaluationScope, UiIrNode, UiIrPage, UiIrSessionState, UiIrSpec, UiIrTheme,
  UiComputedDefinition, UiValue } from './UiIrTypes';
import { UiValueKind } from './UiIrTypes';
import { createUiIrSession, evaluateUiExpression, reduceUiAction } from './UiIrRuntime';
import { normalizeUiIrAgentTurnResult } from './NestedAgentRuntime';
import { arrayValue, booleanValue, numberValue, objectValue, stringValue, uiRecordToPlainObject, uiValueToDisplayString } from './UiValue';

export interface TravelReactLiteAcceptanceResult {
  ok: boolean;
  compileOk: boolean;
  diagnostics: string[];
  pageIds: string[];
  hasDateBinding: boolean;
  hasStableRepeatKey: boolean;
  hasControlledDone: boolean;
  hasDynamicLikedText: boolean;
  hasStructuredAgent: boolean;
  agentIntent: string;
  agentBindings: Record<string, string>;
  agentHasSuccess: boolean;
  agentHasError: boolean;
  summary: string;
  details: string[];
  wire: string;
}

export type UiIrSelfTestResult = TravelReactLiteAcceptanceResult;

export function runTravelReactLiteAcceptance(): TravelReactLiteAcceptanceResult {
  let compile = compileTravelReactLite(testManifest(), testBlueprint());
  let diagnostics: string[] = [];
  for (let i: number = 0; i < compile.diagnostics.length; i++) { diagnostics.push(compile.diagnostics[i].code + ':' + compile.diagnostics[i].message); }
  for (let i: number = 0; i < compile.uiDiagnostics.length; i++) { diagnostics.push('UI:' + compile.uiDiagnostics[i]); }
  let contract = inspectTravelContract(compile.value);
  let compileOk: boolean = compile.ok && contract.pageIds.indexOf('home') >= 0 && contract.pageIds.indexOf('plan') >= 0 &&
    contract.pageIds.indexOf('budget') >= 0 && contract.hasDateBinding && contract.hasStableRepeatKey && contract.hasControlledDone &&
    contract.hasDynamicLikedText && contract.hasStructuredAgent && contract.agentHasSuccess && contract.agentHasError;
  if (!compileOk) { diagnostics.push('TRAVEL_REACT_LITE_CONTRACT_FAILED'); }
  let session = createUiIrSession(testSpec());
  let details: string[] = [];
  let scope: UiEvaluationScope = { aliases: {}, event: {} };
  let first = reduceUiAction(session, action('state.set', 'selectedDay', literalString('10.18')), scope);
  session = first.session;
  let visible = computedItems(session);
  let dateOk: boolean = uiValueToDisplayString(session.state['selectedDay']) === '10.18' && visible.length === 1 && itemId(visible[0]) === 'act-4';
  let visibleId: string = visible.length > 0 ? itemId(visible[0]) : '';
  details.push('date=' + (dateOk ? 'pass' : 'fail') + '(' + uiValueToDisplayString(session.state['selectedDay']) + ',' + visible.length.toString() + ',' + visibleId + ')');

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
  let agentResponseOk: boolean = testUiIrAgentResponseContract(details);
  let ok: boolean = compileOk && dateOk && doneOk && likedOk && removeOk && wireOk && agentResponseOk;
  return { ok: ok, compileOk: compileOk, diagnostics: diagnostics, pageIds: contract.pageIds,
    hasDateBinding: contract.hasDateBinding, hasStableRepeatKey: contract.hasStableRepeatKey,
    hasControlledDone: contract.hasControlledDone, hasDynamicLikedText: contract.hasDynamicLikedText,
    hasStructuredAgent: contract.hasStructuredAgent, agentIntent: contract.agentIntent,
    agentBindings: contract.agentBindings, agentHasSuccess: contract.agentHasSuccess, agentHasError: contract.agentHasError,
    summary: ok ? 'Travel React Lite acceptance passed' : 'Travel React Lite acceptance failed', details: details, wire: wire };
}

function testUiIrAgentResponseContract(details: string[]): boolean {
  let expected: string[] = ['summary'];
  let kinds: Record<string, UiValueKind> = {};
  kinds['summary'] = 'string';
  let success = normalizeUiIrAgentTurnResult('{"assistantText":"ok","state":{"summary":"ready"},"status":"complete","errorMessage":""}', expected, kinds);
  let missing = normalizeUiIrAgentTurnResult('{"assistantText":"bad","state":{},"status":"complete","errorMessage":""}', expected, kinds);
  let wrongType = normalizeUiIrAgentTurnResult('{"assistantText":"bad","state":{"summary":3},"status":"complete","errorMessage":""}', expected, kinds);
  let extra = normalizeUiIrAgentTurnResult('{"assistantText":"bad","state":{"summary":"ok","extra":"x"},"status":"complete","errorMessage":""}', expected, kinds);
  let tagged = normalizeUiIrAgentTurnResult('{"assistantText":"bad","state":{"summary":{"kind":"string","stringValue":"ok"}},"status":"complete","errorMessage":""}', expected, kinds);
  let empty = normalizeUiIrAgentTurnResult('{"assistantText":"no output","status":"complete","errorMessage":""}', [], {});
  let invalid = normalizeUiIrAgentTurnResult('{not-json}', expected, kinds);
  let fenced = normalizeUiIrAgentTurnResult('```json\n{"assistantText":"ok","state":{"summary":"ready"},"status":"complete","errorMessage":""}\n```', expected, kinds);
  let ok: boolean = success.status === 'complete' && missing.status === 'error' && wrongType.status === 'error' &&
    extra.status === 'error' && tagged.status === 'error' && empty.status !== 'error' && invalid.status === 'error' && fenced.status === 'complete';
  details.push('agentResponseContract=' + (ok ? 'pass' : 'fail'));
  return ok;
}

interface TravelContractInspection {
  pageIds: string[];
  hasDateBinding: boolean;
  hasStableRepeatKey: boolean;
  hasControlledDone: boolean;
  hasDynamicLikedText: boolean;
  hasStructuredAgent: boolean;
  agentIntent: string;
  agentBindings: Record<string, string>;
  agentHasSuccess: boolean;
  agentHasError: boolean;
}

function inspectTravelContract(spec: UiIrSpec | undefined): TravelContractInspection {
  let result: TravelContractInspection = { pageIds: [], hasDateBinding: false, hasStableRepeatKey: false, hasControlledDone: false,
    hasDynamicLikedText: false, hasStructuredAgent: false, agentIntent: '', agentBindings: {}, agentHasSuccess: false, agentHasError: false };
  if (spec === undefined) { return result; }
  for (let i: number = 0; i < spec.pages.length; i++) {
    result.pageIds.push(spec.pages[i].id);
    inspectNode(spec.pages[i].root, result);
    let overlays = spec.pages[i].overlays === undefined ? [] : spec.pages[i].overlays as UiIrNode[];
    for (let j: number = 0; j < overlays.length; j++) { inspectNode(overlays[j], result); }
  }
  return result;
}

function inspectNode(node: UiIrNode, result: TravelContractInspection): void {
  if (node.component === 'SegmentedControl' || node.component === 'ChoiceChips' || node.component === 'Tabs') {
    if (node.binding === 'selectedDay') { result.hasDateBinding = true; }
  }
  if (node.kind === 'forEach' && node.source !== undefined) {
    if (node.keyPath === 'id') { result.hasStableRepeatKey = true; }
    if (node.source.kind === 'path' && node.source.root === 'computed' && node.source.segments.join('.') === 'currentItinerary') {
      result.hasStableRepeatKey = result.hasStableRepeatKey && true;
    }
  }
  if (node.component === 'Checkbox') {
    let checked = node.props['checked'];
    if (checked !== undefined && checked.kind === 'path' && checked.root === 'stop' && checked.segments.join('.') === 'done') {
      result.hasControlledDone = true;
    }
    let change = node.actions['change'];
    if (change !== undefined && change.kind === 'list.toggleWhere') { result.hasControlledDone = result.hasControlledDone && true; }
  }
  if (node.component === 'Button') {
    let text = node.props['text'];
    if (text !== undefined && text.kind === 'conditional') { result.hasDynamicLikedText = true; }
  }
  let press = node.actions['press'];
  if (press !== undefined && press.kind === 'agent.invoke') {
    result.hasStructuredAgent = press.intent.length > 0 && press.toolArgs.kind === 'object';
    result.agentIntent = press.intent;
    result.agentBindings = press.resultBindings;
    result.agentHasSuccess = press.successSteps !== undefined && press.successSteps.length > 0 && press.successSteps[0].kind === 'navigation.replace';
    result.agentHasError = press.errorSteps !== undefined && press.errorSteps.length > 0 && press.errorSteps[0].kind === 'state.set';
  }
  for (let i: number = 0; i < node.children.length; i++) { inspectNode(node.children[i], result); }
}

function testManifest(): SkillManifest {
  let tools: ToolContract[] = [];
  let tool: ToolContract = { name: 'travel.generate', description: 'local test', adapterId: 'local', inputFields: [], outputFields: [],
    allowedOrigins: [], credentialRef: '', confirmation: 'none', implemented: true };
  tools.push(tool);
  let fields: SkillInputField[] = [];
  return { schemaVersion: 'skill-manifest-1', skillId: 'TRAVEL_PLANNER_V1', skillName: '旅行规划助手', version: '1', description: 'test',
    goals: [], inputFields: fields, outputFields: [], workflow: [], decisionPoints: [], toolContracts: tools, permissions: [], constraints: [], examples: [] };
}

function testBlueprint(): AppBlueprint {
  let pages: AppPagePlan[] = [];
  pages.push({ id: 'home', title: '首页', purpose: '旅行', primaryAction: '生成方案' });
  pages.push({ id: 'plan', title: '方案', purpose: '结果', primaryAction: '返回首页' });
  pages.push({ id: 'budget', title: '清单', purpose: '准备', primaryAction: '返回' });
  let slots: DynamicSlotPolicy[] = [];
  let recipes: ComponentRecipe[] = [];
  return { schemaVersion: 'app-blueprint-1', appId: 'travel-self-test', skillId: 'TRAVEL_PLANNER_V1', title: '旅行', summary: '旅行',
    homePattern: 'travel', palette: [], runtimePrompt: '', dynamicSlots: slots, componentRecipes: recipes, pages: pages };
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
  let result = baseAction(kind, pathName, value, '', '');
  result.value = value;
  return result;
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
