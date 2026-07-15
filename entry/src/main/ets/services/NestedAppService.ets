import { compileArkUiSpec } from './ArkUiCompiler';
import {
  ArkUiAction,
  ArkUiActionKind,
  ArkUiNode,
  ArkUiNodeType,
  ArkUiPage,
  ArkUiSessionState,
  ArkUiSpec,
  ArkUiToolAction,
  CompiledArkUiPage,
  LocalImageAsset,
  LocalCondition,
  LocalMutation,
  LocalMutationOp
} from './ArkUiTypes';
import { TravelInputs, ToolResult } from './SkillTypes';
import { runTravelTool } from './SkillWorkbench';

const NODE_TYPES: string[] = ['Column', 'Row', 'Stack', 'Scroll', 'Grid', 'List', 'Text', 'Image', 'Button',
  'TextInput', 'TextArea', 'Toggle', 'ChoiceChips', 'SegmentedControl', 'Progress', 'Divider', 'Spacer', 'Badge', 'DynamicSlot'];
const ACTION_KINDS: string[] = ['navigate', 'back', 'localMutate', 'invokeTool', 'invokeAgent', 'pickLocalImage', 'reset'];
const MUTATION_OPS: string[] = ['set', 'toggle', 'increment', 'append', 'remove', 'merge', 'clear'];
const CONDITION_OPS: string[] = ['exists', 'eq', 'neq', 'truthy', 'contains', 'gt', 'gte', 'lt', 'lte'];

export const TRAVEL_DEMO_ARK_UI_SPEC: ArkUiSpec = {
    schemaVersion: 'arkui-tailwind-2', appId: 'travel-skill-app', title: '成都轻旅行',
    subtitle: '由 Agent Skill 驱动的原生行程工作台', initialPageId: 'home',
    theme: { colors: morandiColors() },
    pages: [
      page('home', '旅行首页', node('home-root', 'Column', 'w-full gap-4 p-4 bg-surface', {}, '', [], [
        node('home-hero', 'Stack', 'w-full h-32 rounded-2xl overflow-hidden bg-primary shadow-md', {}, '', [], [
          node('cover', 'Image', 'w-full h-32 object-cover rounded-2xl', prop('assetId', 'cover'), '', [], []),
          node('hero-copy', 'Column', 'w-full gap-2 p-5 bg-black/40', {}, '', [], [
            node('hero-title', 'Text', 'text-2xl font-bold text-white', prop('text', '把周末留给好风景'), '', [], []),
            node('hero-subtitle', 'Text', 'text-sm text-white/90', prop('text', '从灵感到可执行行程'), '', [], [])
          ])
        ]),
        node('welcome', 'Column', 'w-full gap-3 p-5 bg-card/90 border border-border rounded-2xl shadow-sm backdrop-blur-sm', {}, '', [], [
          node('welcome-title', 'Text', 'text-xl font-semibold text-ink', prop('text', '成都，慢一点刚刚好'), '', [], []),
          node('welcome-body', 'Text', 'text-sm text-muted', prop('text', '填写关键偏好，Agent 将生成行程、预算与清单。'), '', [], []),
          button('start', '开始规划', 'navigate', 'editor', '')
        ]),
        node('home-status', 'Badge', 'p-3 bg-secondary/30 rounded-xl text-ink', prop('text', '准备开始'), 'status', [], [])
      ])),
      page('editor', '行程偏好', node('editor-root', 'Column', 'w-full gap-4 p-4 bg-surface', {}, '', [], [
        node('editor-title', 'Text', 'text-2xl font-bold text-ink', prop('text', '把旅程交代清楚'), '', [], []),
        input('departure', '出发地', '例如 上海'), input('destination', '目的地', '例如 成都'),
        input('dates', '出行日期', '例如 3 天 2 晚'), input('budget', '预算', '例如 5000 元'),
        input('preferences', '偏好', '例如 美食、慢游'),
        node('editor-actions', 'Row', 'w-full gap-3', {}, '', [], [
          button('back-home', '返回', 'back', '', ''), button('generate-plan', '生成方案', 'invokeAgent', 'plan', '')
        ])
      ])),
      page('plan', '旅行方案', node('plan-root', 'Column', 'w-full gap-4 p-4 bg-surface', {}, '', [], [
        node('plan-title', 'Text', 'text-2xl font-bold text-ink', prop('text', '三天两晚的节奏'), '', [], []),
        node('plan-status', 'Badge', 'p-3 bg-primary/20 rounded-xl text-ink', prop('text', '等待执行'), 'status', [], []),
        panel('itinerary-panel', '每日行程', 'itinerary'),
        node('plan-actions', 'Row', 'w-full gap-3', {}, '', [], [
          button('open-budget', '预算与清单', 'navigate', 'budget', ''),
          button('edit-plan', '编辑参数', 'navigate', 'editor', '')
        ])
      ])),
      page('budget', '预算与清单', node('budget-root', 'Column', 'w-full gap-4 p-4 bg-surface', {}, '', [], [
        node('budget-title', 'Text', 'text-2xl font-bold text-ink', prop('text', '出发前最后确认'), '', [], []),
        panel('budget-panel', '预算估算', 'budgetSummary'), panel('checklist-panel', '出行清单', 'checklist'),
        node('gallery', 'Image', 'w-full h-24 rounded-xl object-cover bg-secondary/30', prop('assetId', 'gallery'), '',
          [action('pick-gallery', '添加本地图片', 'pickLocalImage', '', 'gallery')], []),
        node('finish-actions', 'Row', 'w-full gap-3', {}, '', [], [
          button('back-plan', '返回方案', 'back', '', ''), button('restart', '重新开始', 'reset', 'home', '')
        ])
      ]))
    ]
};

export function defaultTravelNestedApp(): ArkUiSpec {
  return JSON.parse(JSON.stringify(TRAVEL_DEMO_ARK_UI_SPEC)) as ArkUiSpec;
}

export function defaultWeatherArkUiSpec(): ArkUiSpec {
  return {
    schemaVersion: 'arkui-tailwind-2', appId: 'weather-skill-app', title: '天气决策助手',
    subtitle: '情境优先的天气工作台', initialPageId: 'home', theme: { colors: morandiColors() },
    pages: [page('home', '当前天气', node('weather-root', 'Column', 'w-full gap-4 p-4 bg-surface', {}, '', [], [
      node('weather-title', 'Text', 'text-3xl font-bold text-ink', prop('text', '今天适合出门吗？'), '', [], []),
      panel('weather-summary', '当前天气', 'weatherSummary'),
      node('weather-actions', 'Row', 'w-full gap-3', {}, '', [], [
        button('walking', '适合散步吗', 'invokeAgent', 'decision', 'walking'),
        button('forecast', '未来三天', 'navigate', 'forecast', '')
      ])
    ])), page('forecast', '未来三天', node('forecast-root', 'Column', 'w-full gap-4 p-4 bg-surface', {}, '', [], [
      node('forecast-title', 'Text', 'text-2xl font-bold text-ink', prop('text', '未来三天'), '', [], []),
      panel('forecast-panel', '天气趋势', 'forecast'), button('forecast-back', '返回', 'back', '', '')
    ])), page('decision', '天气建议', node('decision-root', 'Column', 'w-full gap-4 p-4 bg-surface', {}, '', [], [
      node('decision-title', 'Text', 'text-2xl font-bold text-ink', prop('text', 'Agent 建议'), '', [], []),
      panel('decision-panel', '结论', 'agentSummary'), button('decision-home', '返回首页', 'navigate', 'home', '')
    ]))]
  };
}

export function createNestedSession(spec: ArkUiSpec): ArkUiSessionState {
  let data: Record<string, string> = {};
  return { app: compileArkUiSpec(spec), activePageId: spec.initialPageId, routeStack: [spec.initialPageId], data: data,
    assets: [], status: 'idle', agentTrace: 'ArkUiSpec 已编译为原生 UI。', errorMessage: '' };
}

export function normalizeNestedApp(raw: string, current: ArkUiSpec): ArkUiSpec {
  return normalizeArkUiSpec(raw, current);
}

export function normalizeArkUiSpec(raw: string, fallback: ArkUiSpec): ArkUiSpec {
  try {
    let parsed: ArkUiSpec = JSON.parse(cleanJson(raw)) as ArkUiSpec;
    let repaired: ArkUiSpec = sanitizeSpec(parsed, fallback);
    if (isValidArkUiSpec(repaired)) { return repaired; }
  } catch (e) {
  }
  return fallback;
}

export function normalizeArkUiPage(raw: string, fallback: ArkUiPage): ArkUiPage {
  try {
    let parsed: ArkUiPage = JSON.parse(cleanJson(raw)) as ArkUiPage;
    let repaired: ArkUiPage = sanitizePage(parsed, 0);
    if (repaired.id.length > 0 && validNode(repaired.root, 0)) { return repaired; }
  } catch (e) {
  }
  return fallback;
}

export function composeArkUiSpec(blueprintAppId: string, title: string, subtitle: string,
  pages: ArkUiPage[], fallback: ArkUiSpec): ArkUiSpec {
  if (pages.length === 0) { return fallback; }
  return { schemaVersion: 'arkui-tailwind-2', appId: blueprintAppId, title: title, subtitle: subtitle,
    initialPageId: pages[0].id, theme: fallback.theme, pages: pages };
}

export function activeNestedPage(session: ArkUiSessionState): CompiledArkUiPage {
  for (let i: number = 0; i < session.app.pages.length; i++) {
    if (session.app.pages[i].id === session.activePageId) { return session.app.pages[i]; }
  }
  return session.app.pages[0];
}

export function updateNestedField(session: ArkUiSessionState, key: string, value: string): ArkUiSessionState {
  let next: ArkUiSessionState = cloneSession(session); next.data[key] = value; return next;
}

export function addNestedAsset(session: ArkUiSessionState, name: string, dataUrl: string, slot: string): ArkUiSessionState {
  let next: ArkUiSessionState = cloneSession(session); let id: string = slot.length > 0 ? slot : 'image-' + Date.now().toString();
  next.assets = next.assets.filter((asset: LocalImageAsset) => asset.id !== id);
  next.assets.push({ id: id, name: name, dataUrl: dataUrl }); next.agentTrace = '已添加本地图片：' + name; return next;
}

export function reduceNestedAction(session: ArkUiSessionState, current: ArkUiAction): ArkUiSessionState {
  let next: ArkUiSessionState = cloneSession(session); next.errorMessage = '';
  if (current.kind === 'navigate') { navigate(next, current.targetPageId); }
  else if (current.kind === 'back' && next.routeStack.length > 1) { next.routeStack.pop(); next.activePageId = next.routeStack[next.routeStack.length - 1]; }
  else if (current.kind === 'reset') { return resetNestedSession(next); }
  else if (current.kind === 'localMutate') { applyLocalMutationAction(next, current); }
  else if (current.kind === 'invokeTool') { applyDirectToolAction(next, current); }
  else if (current.kind === 'invokeAgent') { applyTravelDemoAgent(next); navigate(next, current.targetPageId); }
  return next;
}

export function assetDataUrl(session: ArkUiSessionState, assetId: string): string {
  for (let i: number = 0; i < session.assets.length; i++) { if (session.assets[i].id === assetId) { return session.assets[i].dataUrl; } }
  return '';
}

export function isValidArkUiSpec(spec: ArkUiSpec): boolean {
  if (spec === undefined || spec === null || typeof spec.appId !== 'string' || spec.appId.length === 0 ||
    typeof spec.initialPageId !== 'string' || !Array.isArray(spec.pages) || spec.pages.length === 0) { return false; }
  let hasInitial: boolean = false;
  for (let i: number = 0; i < spec.pages.length; i++) {
    if (spec.pages[i].id === spec.initialPageId) { hasInitial = true; }
    if (!validNode(spec.pages[i].root, 0)) { return false; }
  }
  return hasInitial;
}

function sanitizeSpec(spec: ArkUiSpec, fallback: ArkUiSpec): ArkUiSpec {
  let repaired: ArkUiSpec = JSON.parse(JSON.stringify(spec)) as ArkUiSpec;
  if (typeof repaired.schemaVersion !== 'string') { repaired.schemaVersion = 'arkui-tailwind-2'; }
  if (typeof repaired.appId !== 'string' || repaired.appId.length === 0) { repaired.appId = fallback.appId; }
  if (typeof repaired.title !== 'string') { repaired.title = fallback.title; }
  if (typeof repaired.subtitle !== 'string') { repaired.subtitle = ''; }
  if (repaired.theme === undefined || repaired.theme === null || repaired.theme.colors === undefined) { repaired.theme = fallback.theme; }
  if (!Array.isArray(repaired.pages) || repaired.pages.length === 0) { return fallback; }
  repaired.pages = repaired.pages.slice(0, 5);
  if (typeof repaired.initialPageId !== 'string' || repaired.initialPageId.length === 0) { repaired.initialPageId = repaired.pages[0].id; }
  for (let i: number = 0; i < repaired.pages.length; i++) { repaired.pages[i] = sanitizePage(repaired.pages[i], i); }
  return repaired;
}

function sanitizePage(pageValue: ArkUiPage, index: number): ArkUiPage {
  let current: ArkUiPage = pageValue;
  if (typeof current.id !== 'string' || current.id.length === 0) { current.id = 'page-' + index.toString(); }
  if (typeof current.title !== 'string') { current.title = ''; }
  if (typeof current.scroll !== 'boolean') { current.scroll = true; }
  current.root = sanitizeNode(current.root, current.id + '-root', 0); return current;
}

function sanitizeNode(value: ArkUiNode, fallbackId: string, depth: number): ArkUiNode {
  let current: ArkUiNode = value;
  if (current === undefined || current === null) { return node(fallbackId, 'Column', 'w-full', {}, '', [], []); }
  if (typeof current.id !== 'string' || current.id.length === 0) { current.id = fallbackId; }
  if (typeof current.type !== 'string' || NODE_TYPES.indexOf(current.type) < 0) { current.type = 'Column'; }
  if (typeof current.className !== 'string') { current.className = ''; }
  if (current.props === undefined || current.props === null) { current.props = {}; }
  if (typeof current.binding !== 'string') { current.binding = ''; }
  if (!Array.isArray(current.actions)) { current.actions = []; }
  if (current.visibleWhen !== undefined) { current.visibleWhen = sanitizeCondition(current.visibleWhen); }
  if (current.enabledWhen !== undefined) { current.enabledWhen = sanitizeCondition(current.enabledWhen); }
  if (current.selectedWhen !== undefined) { current.selectedWhen = sanitizeCondition(current.selectedWhen); }
  if (!Array.isArray(current.children) || depth >= 12) { current.children = []; }
  for (let i: number = 0; i < current.actions.length; i++) {
    let a: ArkUiAction = current.actions[i];
    if (typeof a.id !== 'string') { a.id = current.id + '-action-' + i.toString(); }
    if (typeof a.label !== 'string') { a.label = ''; }
    if (ACTION_KINDS.indexOf(a.kind) < 0) { a.kind = 'navigate'; }
    if (typeof a.targetPageId !== 'string') { a.targetPageId = ''; }
    if (typeof a.payload !== 'string') { a.payload = a.payload === undefined ? '' : JSON.stringify(a.payload); }
    if (a.handling !== 'local' && a.handling !== 'agent' && a.handling !== 'localThenAgent') { a.handling = a.kind === 'invokeAgent' ? 'agent' : 'local'; }
    if (a.kind === 'invokeAgent') { a.handling = 'agent'; } else { a.handling = 'local'; }
    a.effects = sanitizeMutations(a.effects);
    a.guards = sanitizeConditions(a.guards);
    if (a.tool !== undefined) { a.tool = sanitizeTool(a.tool); }
  }
  for (let j: number = 0; j < current.children.length; j++) { current.children[j] = sanitizeNode(current.children[j], current.id + '-' + j.toString(), depth + 1); }
  return current;
}

function validNode(current: ArkUiNode, depth: number): boolean {
  if (current === undefined || current === null || depth > 12 || typeof current.id !== 'string' ||
    NODE_TYPES.indexOf(current.type) < 0 || !Array.isArray(current.children) || !Array.isArray(current.actions)) { return false; }
  for (let i: number = 0; i < current.children.length; i++) { if (!validNode(current.children[i], depth + 1)) { return false; } }
  return true;
}

function resetNestedSession(session: ArkUiSessionState): ArkUiSessionState {
  let data: Record<string, string> = {};
  return { app: session.app, activePageId: session.app.initialPageId, routeStack: [session.app.initialPageId],
    data: data, assets: [], status: 'idle', agentTrace: '应用状态已重置。', errorMessage: '' };
}

function applyTravelDemoAgent(session: ArkUiSessionState): void {
  let inputs: TravelInputs = { departure: sessionValue(session, 'departure'), destination: sessionValue(session, 'destination'),
    startDate: sessionValue(session, 'dates'), endDate: sessionValue(session, 'dates'), adults: '2', children: '0',
    budget: sessionValue(session, 'budget'), preferences: sessionValue(session, 'preferences'), lodging: '', transport: '' };
  let itinerary: ToolResult = runTravelTool('travel.planDailyItinerary', inputs);
  let budget: ToolResult = runTravelTool('travel.estimateBudget', inputs);
  let checklist: ToolResult = runTravelTool('travel.generateChecklist', inputs);
  session.data['itinerary'] = itinerary.details.join('\n'); session.data['budgetSummary'] = budget.summary + '\n' + budget.details.join('\n');
  session.data['checklist'] = checklist.details.join('\n'); session.data['status'] = '方案已生成'; session.status = 'complete';
  session.agentTrace = 'Agent 已执行本地旅行工具：行程、预算、清单。';
}

function sessionValue(session: ArkUiSessionState, key: string): string {
  let current: string | undefined = session.data[key];
  return current === undefined ? '' : current;
}

function applyLocalMutationAction(session: ArkUiSessionState, current: ArkUiAction): void {
  let effects: LocalMutation[] = current.effects === undefined ? parseLegacyMutations(current.payload) : current.effects;
  if (!guardsPass(session, current.guards)) {
    session.errorMessage = '本地操作条件不满足。';
    return;
  }
  let candidate: ArkUiSessionState = cloneSession(session);
  for (let i: number = 0; i < effects.length; i++) {
    if (!applyMutation(candidate, effects[i])) {
      session.errorMessage = '已拒绝无效的本地状态操作：' + effects[i].path;
      return;
    }
  }
  session.data = candidate.data;
  if (current.targetPageId.length > 0) { navigate(session, current.targetPageId); }
}

function applyDirectToolAction(session: ArkUiSessionState, current: ArkUiAction): void {
  if (current.tool === undefined || current.tool.name.length === 0) {
    session.errorMessage = '直接工具 Action 缺少工具声明。';
    return;
  }
  if (current.tool.name.indexOf('travel.') !== 0) {
    session.errorMessage = '已拒绝未注册的本地工具：' + current.tool.name;
    return;
  }
  let argKeys: string[] = Object.keys(current.tool.args);
  for (let i: number = 0; i < argKeys.length; i++) {
    let argValue: string = current.tool.args[argKeys[i]];
    session.data[argKeys[i]] = argValue.indexOf('$state.') === 0 ? sessionValue(session, argValue.substring(7)) : argValue;
  }
  let local: ToolResult = runTravelTool(current.tool.name, travelInputsFromSession(session));
  session.data['toolResults'] = local.summary + (local.details.length > 0 ? '\n' + local.details.join('\n') : '');
  session.data['status'] = local.summary;
  let succeeded: boolean = local.summary.indexOf('拒绝') < 0 && local.summary.indexOf('未完整') < 0;
  session.status = succeeded ? 'complete' : 'error';
  session.agentTrace = '已直接执行本地工具：' + local.toolName;
  let resultKeys: string[] = Object.keys(current.tool.resultBindings);
  for (let i: number = 0; i < resultKeys.length; i++) {
    let targetKey: string = resultKeys[i]; let sourcePath: string = current.tool.resultBindings[targetKey];
    if (sourcePath === '$.summary') { session.data[targetKey] = local.summary; }
    else if (sourcePath === '$.details') { session.data[targetKey] = local.details.join('\n'); }
    else { session.data[targetKey] = local.summary; }
  }
  if (succeeded && current.targetPageId.length > 0) { navigate(session, current.targetPageId); }
}

function travelInputsFromSession(session: ArkUiSessionState): TravelInputs {
  return {
    departure: sessionValue(session, 'departure'), destination: sessionValue(session, 'destination'),
    startDate: sessionValue(session, 'startDate'), endDate: sessionValue(session, 'endDate'),
    adults: sessionValue(session, 'adults'), children: sessionValue(session, 'children'),
    budget: sessionValue(session, 'budget'), preferences: sessionValue(session, 'preferences'),
    lodging: sessionValue(session, 'lodging'), transport: sessionValue(session, 'transport')
  };
}

function guardsPass(session: ArkUiSessionState, guards: LocalCondition[] | undefined): boolean {
  if (guards === undefined) { return true; }
  for (let i: number = 0; i < guards.length; i++) {
    let condition: LocalCondition = guards[i];
    let actual: string = sessionValue(session, condition.path);
    let expected: string = condition.value;
    if (condition.op === 'exists' && actual.length === 0) { return false; }
    if (condition.op === 'eq' && actual !== expected) { return false; }
    if (condition.op === 'neq' && actual === expected) { return false; }
    if (condition.op === 'truthy' && actual !== 'true' && actual !== '1' && actual.length === 0) { return false; }
    if (condition.op === 'contains' && actual.indexOf(expected) < 0) { return false; }
    if (condition.op === 'gt' && Number(actual) <= Number(expected)) { return false; }
    if (condition.op === 'gte' && Number(actual) < Number(expected)) { return false; }
    if (condition.op === 'lt' && Number(actual) >= Number(expected)) { return false; }
    if (condition.op === 'lte' && Number(actual) > Number(expected)) { return false; }
  }
  return true;
}

function applyMutation(session: ArkUiSessionState, mutation: LocalMutation): boolean {
  let key: string = mutation.path.trim();
  if (key.length === 0 || key.indexOf('.') >= 0 || key.indexOf('$') >= 0 || key.indexOf('/') >= 0) { return false; }
  let current: string = sessionValue(session, key);
  let value: string = mutation.valueFrom.length > 0 ? sessionValue(session, mutation.valueFrom) : mutation.value;
  if (mutation.op === 'set') { session.data[key] = value; return true; }
  if (mutation.op === 'clear') { session.data[key] = ''; return true; }
  if (mutation.op === 'toggle') { session.data[key] = current === 'true' ? 'false' : 'true'; return true; }
  if (mutation.op === 'increment') {
    let amount: number = Number(value.length > 0 ? value : '1');
    let number: number = Number(current.length > 0 ? current : '0');
    if (Number.isNaN(amount) || Number.isNaN(number)) { return false; }
    session.data[key] = (number + amount).toString(); return true;
  }
  if (mutation.op === 'append' || mutation.op === 'remove') {
    let items: string[] = [];
    try { items = JSON.parse(current.length > 0 ? current : '[]') as string[]; } catch (e) { return false; }
    if (!Array.isArray(items)) { return false; }
    if (mutation.op === 'append') { items.push(value); } else { items = items.filter((item: string): boolean => item !== value); }
    session.data[key] = JSON.stringify(items); return true;
  }
  if (mutation.op === 'merge') {
    try {
      let base: Record<string, string> = current.length > 0 ? JSON.parse(current) as Record<string, string> : {};
      let patch: Record<string, string> = value.length > 0 ? JSON.parse(value) as Record<string, string> : {};
      let keys: string[] = Object.keys(patch);
      for (let i: number = 0; i < keys.length; i++) { base[keys[i]] = patch[keys[i]]; }
      session.data[key] = JSON.stringify(base); return true;
    } catch (e) { return false; }
  }
  return false;
}

function parseLegacyMutations(payload: string): LocalMutation[] {
  try {
    let raw: Record<string, Object> = JSON.parse(payload) as Record<string, Object>;
    let operation: string = String(raw['op']);
    let path: string = String(raw['key'] === undefined ? raw['path'] : raw['key']);
    let mutation: LocalMutation = {
      op: operation as LocalMutationOp, path: path,
      value: raw['value'] === undefined ? '' : String(raw['value']),
      valueFrom: raw['valueFrom'] === undefined ? '' : String(raw['valueFrom'])
    };
    return MUTATION_OPS.indexOf(operation) >= 0 && path.length > 0 ? [mutation] : [];
  } catch (e) { return []; }
}

function sanitizeMutations(values: LocalMutation[] | undefined): LocalMutation[] {
  if (!Array.isArray(values)) { return []; }
  let result: LocalMutation[] = [];
  for (let i: number = 0; i < values.length; i++) {
    let value: LocalMutation = values[i];
    if (value === undefined || MUTATION_OPS.indexOf(value.op) < 0 || typeof value.path !== 'string') { continue; }
    if (typeof value.value !== 'string') { value.value = value.value === undefined ? '' : JSON.stringify(value.value); }
    if (typeof value.valueFrom !== 'string') { value.valueFrom = ''; }
    result.push(value);
  }
  return result;
}

function sanitizeConditions(values: LocalCondition[] | undefined): LocalCondition[] {
  if (!Array.isArray(values)) { return []; }
  let result: LocalCondition[] = [];
  for (let i: number = 0; i < values.length; i++) {
    let value: LocalCondition = values[i];
    if (value === undefined || CONDITION_OPS.indexOf(value.op) < 0 || typeof value.path !== 'string') { continue; }
    if (typeof value.value !== 'string') { value.value = value.value === undefined ? '' : JSON.stringify(value.value); }
    result.push(value);
  }
  return result;
}

function sanitizeCondition(value: LocalCondition): LocalCondition {
  let values: LocalCondition[] = sanitizeConditions([value]);
  return values.length > 0 ? values[0] : { path: '', op: 'exists', value: '' };
}

function sanitizeTool(value: ArkUiToolAction): ArkUiToolAction {
  if (typeof value.name !== 'string') { value.name = ''; }
  if (value.args === undefined || value.args === null) { value.args = {}; }
  if (value.resultBindings === undefined || value.resultBindings === null) { value.resultBindings = {}; }
  return value;
}

function navigate(session: ArkUiSessionState, pageId: string): void {
  for (let i: number = 0; i < session.app.pages.length; i++) { if (session.app.pages[i].id === pageId) { session.activePageId = pageId; session.routeStack.push(pageId); return; } }
  session.errorMessage = '已拒绝未知页面跳转：' + pageId;
}

function morandiColors(): Record<string, string> { let colors: Record<string, string> = {}; colors['surface'] = '#FFF1F2EE'; colors['card'] = '#E8FFFFFF'; colors['primary'] = '#FF6D7E73'; colors['secondary'] = '#FFC89B91'; colors['accent'] = '#FF7A8A99'; colors['ink'] = '#FF2E3A35'; colors['muted'] = '#FF5B675F'; colors['border'] = '#99FFFFFF'; colors['white'] = '#FFFFFFFF'; colors['black'] = '#FF111513'; return colors; }
function page(id: string, title: string, root: ArkUiNode): ArkUiPage { return { id: id, title: title, scroll: true, root: root }; }
function node(id: string, type: ArkUiNodeType, className: string, props: Record<string, string>, binding: string, actions: ArkUiAction[], children: ArkUiNode[]): ArkUiNode { return { id: id, type: type, className: className, props: props, binding: binding, actions: actions, children: children }; }
function action(id: string, label: string, kind: ArkUiActionKind, target: string, payload: string): ArkUiAction { return { id: id, label: label, kind: kind, targetPageId: target, payload: payload, handling: kind === 'invokeAgent' ? 'agent' : 'local' }; }
function button(id: string, label: string, kind: ArkUiActionKind, target: string, payload: string): ArkUiNode { return node(id, 'Button', 'flex-1 h-12 px-4 bg-primary rounded-xl text-white font-semibold', prop('text', label), '', [action(id, label, kind, target, payload)], []); }
function input(id: string, label: string, placeholder: string): ArkUiNode { return node(id + '-group', 'Column', 'w-full gap-2 p-4 bg-card/90 rounded-xl border border-border', {}, '', [], [node(id + '-label', 'Text', 'text-sm font-medium text-muted', prop('text', label), '', [], []), node(id, 'TextInput', 'w-full h-12 px-3 bg-white/80 rounded-lg text-ink', prop('placeholder', placeholder), id, [], [])]); }
function panel(id: string, title: string, binding: string): ArkUiNode { return node(id, 'Column', 'w-full gap-2 p-5 bg-card/90 rounded-2xl border border-border shadow-sm backdrop-blur-sm', {}, '', [], [node(id + '-title', 'Text', 'text-lg font-semibold text-ink', prop('text', title), '', [], []), node(id + '-body', 'Text', 'text-sm text-muted', prop('text', '等待生成'), binding, [], [])]); }
function prop(key: string, value: string): Record<string, string> { let result: Record<string, string> = {}; result[key] = value; return result; }
function cleanJson(raw: string): string { let cleaned: string = raw.replace('```json', '').replace('```', '').trim(); let start: number = cleaned.indexOf('{'); let end: number = cleaned.lastIndexOf('}'); return start >= 0 && end > start ? cleaned.substring(start, end + 1) : cleaned; }
function cloneSession(session: ArkUiSessionState): ArkUiSessionState { return JSON.parse(JSON.stringify(session)) as ArkUiSessionState; }
