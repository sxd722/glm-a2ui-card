import { ArkUiSpec } from './ArkUiTypes';
import { defaultTravelNestedApp, defaultWeatherArkUiSpec, normalizeArkUiSpec } from './NestedAppService';
import {
  AppBlueprint,
  AppBlueprintParseResult,
  AppPagePlan,
  ForgeDraft,
  InstalledSkillApp,
  SkillInputField,
  SkillManifest,
  SkillSource,
  ToolContract
} from './SkillAppTypes';
import { ReactLiteDiagnostic } from './ReactLiteTypes';
import { UiIrSpec } from './UiIrTypes';

const SCHEMA_VERSION: string = 'skill-app-mvp-2';

export function createSkillSource(kind: string, value: string, localAssetIds: string[]): SkillSource {
  let sourceKind: 'image' | 'file' | 'repository' | 'text' = 'text';
  if (kind === 'image' || kind === 'file' || kind === 'repository') { sourceKind = kind; }
  return { id: 'source-' + Date.now().toString(), kind: sourceKind,
    displayName: sourceKind === 'repository' ? '公开 Skill 仓库' : '用户提供的 Skill',
    uri: sourceKind === 'repository' ? value : '', textContent: sourceKind === 'repository' ? '' : value,
    localAssetIds: localAssetIds, importedAt: Date.now() };
}

export function createForgeDraft(source: SkillSource): ForgeDraft {
  let manifest: SkillManifest = localManifestForSource(source);
  let blueprint: AppBlueprint = localBlueprintForManifest(manifest);
  return { draftId: 'forge-' + Date.now().toString(), source: source, manifest: manifest, blueprint: blueprint,
    uiSpec: localArkUiSpecForManifest(manifest), status: 'import', trace: 'Skill 来源已就绪，可开始分析。',
    errorMessage: '', updatedAt: Date.now(), generationMode: 'legacyArkUiSpec', reactLiteSource: '',
    repairedReactLiteSource: '', reactLiteDiagnostics: [] };
}

export function localManifestForSource(source: SkillSource): SkillManifest {
  let probe: string = (source.uri + ' ' + source.textContent + ' ' + source.displayName).toLowerCase();
  return probe.indexOf('seniverse') >= 0 || probe.indexOf('weather') >= 0 || probe.indexOf('天气') >= 0 ?
    weatherManifest() : travelManifest();
}

export function localBlueprintForManifest(manifest: SkillManifest): AppBlueprint {
  let weather: boolean = manifest.skillId.indexOf('WEATHER') >= 0 || manifest.skillName.indexOf('天气') >= 0;
  let plans: AppPagePlan[] = weather ? [
    plan('home', '当前天气', '显示情境摘要和少量快捷任务', '查询天气'),
    plan('forecast', '天气趋势', '浏览未来时段和风险', '返回'),
    plan('decision', 'Agent 建议', '结合用户动作与工具数据给出建议', '返回首页')
  ] : [
    plan('home', '旅行首页', '用封面和摘要建立任务入口', '开始规划'),
    plan('editor', '行程偏好', '通过最少输入收集关键约束', '生成方案'),
    plan('plan', '旅行方案', '展示行程并支持继续调整', '预算与清单'),
    plan('budget', '预算与清单', '汇总预算、清单和本地图片', '重新开始')
  ];
  return { schemaVersion: SCHEMA_VERSION, appId: safeId(manifest.skillId), skillId: manifest.skillId,
    title: manifest.skillName, summary: manifest.description, homePattern: weather ? 'context-dashboard' : 'guided-workbench',
    palette: ['#6D7E73', '#C89B91', '#E8E3DC', '#7A8A99'], runtimePrompt: runtimePrompt(manifest),
    dynamicSlots: [], componentRecipes: [], pages: plans };
}

export function localArkUiSpecForManifest(manifest: SkillManifest): ArkUiSpec {
  return manifest.skillId.indexOf('WEATHER') >= 0 || manifest.skillName.indexOf('天气') >= 0 ?
    defaultWeatherArkUiSpec() : defaultTravelNestedApp();
}

export function normalizeSkillManifest(raw: string, fallback: SkillManifest): SkillManifest {
  try {
    let parsed: SkillManifest = JSON.parse(cleanJson(raw)) as SkillManifest;
    if (parsed !== undefined && parsed !== null && typeof parsed.skillId === 'string' && parsed.skillId.length > 0 &&
      typeof parsed.skillName === 'string' && parsed.skillName.length > 0) { return sanitizeManifest(parsed, fallback); }
  } catch (e) {
  }
  return fallback;
}

export function normalizeAppBlueprint(raw: string, fallback: AppBlueprint): AppBlueprintParseResult {
  let repairedFields: string[] = [];
  try {
    let parsed: AppBlueprint = JSON.parse(cleanJson(raw)) as AppBlueprint;
    let repaired: AppBlueprint = sanitizeAppBlueprint(parsed, fallback, repairedFields);
    if (isValidAppBlueprint(repaired)) {
      return { ok: true, value: repaired, diagnostics: [], repairedFields: repairedFields };
    }
    return { ok: false, value: undefined, diagnostics: ['AppBlueprint 缺少有效 pages 或关键元数据。'], repairedFields: repairedFields };
  } catch (e) {
    return { ok: false, value: undefined, diagnostics: ['AppBlueprint JSON 无法解析。'], repairedFields: repairedFields };
  }
}

export function compileBlueprint(blueprint: AppBlueprint, spec: ArkUiSpec): ArkUiSpec {
  let normalized: ArkUiSpec = normalizeArkUiSpec(JSON.stringify(spec), spec);
  normalized.appId = blueprint.appId;
  return normalized;
}

export function installBlueprint(draft: ForgeDraft): InstalledSkillApp {
  return { appId: draft.blueprint.appId, schemaVersion: draft.blueprint.schemaVersion,
    skillVersion: draft.manifest.version, generatedAt: Date.now(), manifest: draft.manifest,
    blueprint: draft.blueprint, uiSpec: draft.uiSpec, runtimePrompt: draft.blueprint.runtimePrompt,
    credentialRefs: credentialRefs(draft.manifest), reactLiteSource: draft.reactLiteSource,
    uiIrSpec: draft.uiIrSpec, runtimeSchemaVersion: draft.uiIrSpec === undefined ? 'arkui-legacy' : 'ui-ir-1' };
}

export function updateDraftManifest(draft: ForgeDraft, manifest: SkillManifest, trace: string): ForgeDraft {
  let next: ForgeDraft = cloneDraft(draft); next.manifest = manifest; next.blueprint = localBlueprintForManifest(manifest);
  next.uiSpec = localArkUiSpecForManifest(manifest); next.status = 'analyzed'; next.trace = trace; next.errorMessage = '';
  next.updatedAt = Date.now(); return next;
}

export function updateDraftBlueprint(draft: ForgeDraft, blueprint: AppBlueprint, trace: string): ForgeDraft {
  let next: ForgeDraft = cloneDraft(draft); next.blueprint = blueprint; next.status = 'configured'; next.trace = trace;
  next.errorMessage = ''; next.updatedAt = Date.now(); return next;
}

export function updateDraftUiSpec(draft: ForgeDraft, uiSpec: ArkUiSpec, trace: string): ForgeDraft {
  let next: ForgeDraft = cloneDraft(draft); next.uiSpec = uiSpec; next.status = 'preview'; next.trace = trace;
  next.errorMessage = ''; next.updatedAt = Date.now(); return next;
}

export function updateDraftUiIrSpec(draft: ForgeDraft, uiSpec: UiIrSpec, source: string,
  repairedSource: string, diagnostics: ReactLiteDiagnostic[], trace: string): ForgeDraft {
  let next: ForgeDraft = cloneDraft(draft);
  next.uiIrSpec = uiSpec;
  next.reactLiteSource = source;
  next.repairedReactLiteSource = repairedSource;
  next.reactLiteDiagnostics = diagnostics;
  next.generationMode = 'reactLite';
  next.status = 'preview';
  next.trace = trace;
  next.errorMessage = '';
  next.updatedAt = Date.now();
  return next;
}

function travelManifest(): SkillManifest {
  return { schemaVersion: SCHEMA_VERSION, skillId: 'TRAVEL_PLANNER_V1', skillName: '旅行规划助手', version: '1',
    description: '根据用户约束生成可执行的旅行方案。', goals: ['收集旅行约束', '生成交通、住宿、行程、预算和清单'],
    inputFields: [field('departure', '出发地', 'entity', true, []), field('destination', '目的地', 'entity', true, []),
      field('dates', '出行日期', 'dateRange', true, []), field('budget', '预算', 'choiceOrText', true, ['低', '中', '高']),
      field('preferences', '旅行偏好', 'multiChoice', false, ['美食', '自然', '人文', '亲子', '轻松节奏'])],
    outputFields: ['overview', 'transport', 'lodging', 'itinerary', 'budget', 'checklist'],
    workflow: ['校验输入', '生成交通', '生成住宿', '规划行程', '估算预算', '生成清单'],
    decisionPoints: ['确认目的地与日期', '接受或调整方案'], toolContracts: travelTools(), permissions: [],
    constraints: ['只执行本地旅行白名单工具', '不承诺实时价格或库存'],
    examples: ['上海到成都，3 天 2 晚，2 人，预算 5000 元，偏好美食和轻松游。'] };
}

function weatherManifest(): SkillManifest {
  return { schemaVersion: SCHEMA_VERSION, skillId: 'SENIVERSE_WEATHER_V1', skillName: '天气决策助手', version: '1',
    description: '把实时天气、预报、生活指数和预警转成可执行建议。', goals: ['快速查看天气', '帮助用户做活动决策'],
    inputFields: [field('location', '地点', 'entity', true, []),
      field('dateRange', '时间范围', 'choice', false, ['今天', '未来 24 小时', '未来 7 天']),
      field('activity', '关注事项', 'choice', false, ['通勤', '散步', '户外活动', '空气质量'])],
    outputFields: ['current', 'hourly', 'daily', 'lifeIndices', 'alerts', 'decision'],
    workflow: ['确定地点', '查询天气', '识别风险', '解释影响', '给出快捷下一步'],
    decisionPoints: ['位置消歧', '选择关注时段', '确认高风险建议'], toolContracts: weatherTools(),
    permissions: [], constraints: ['实时事实必须来自天气工具', 'API Key 不进入 GLM Prompt'],
    examples: ['今天适合散步吗？', '比较上海和杭州周末天气。'] };
}

function travelTools(): ToolContract[] {
  let names: string[] = ['travel.validateInputs', 'travel.suggestTransport', 'travel.suggestLodging',
    'travel.planDailyItinerary', 'travel.estimateBudget', 'travel.generateChecklist', 'travel.finalizePlan'];
  let tools: ToolContract[] = [];
  for (let i: number = 0; i < names.length; i++) { tools.push(tool(names[i], 'local.travel', true)); }
  return tools;
}

function weatherTools(): ToolContract[] {
  return [tool('weather.current', 'seniverse.weather', false), tool('weather.forecast', 'seniverse.weather', false),
    tool('weather.lifeIndex', 'seniverse.weather', false), tool('weather.alert', 'seniverse.weather', false)];
}

function sanitizeManifest(value: SkillManifest, fallback: SkillManifest): SkillManifest {
  let m: SkillManifest = JSON.parse(JSON.stringify(value)) as SkillManifest;
  if (typeof m.schemaVersion !== 'string') { m.schemaVersion = SCHEMA_VERSION; }
  if (typeof m.version !== 'string') { m.version = '1'; }
  if (typeof m.description !== 'string') { m.description = ''; }
  m.goals = strings(m.goals); m.outputFields = strings(m.outputFields); m.workflow = strings(m.workflow);
  m.decisionPoints = strings(m.decisionPoints); m.permissions = strings(m.permissions); m.constraints = strings(m.constraints);
  m.examples = strings(m.examples);
  if (!Array.isArray(m.inputFields)) { m.inputFields = fallback.inputFields; }
  if (!Array.isArray(m.toolContracts)) { m.toolContracts = []; }
  for (let i: number = 0; i < m.inputFields.length; i++) {
    let f: SkillInputField = m.inputFields[i]; if (typeof f.id !== 'string') { f.id = 'field' + i.toString(); }
    if (typeof f.label !== 'string') { f.label = f.id; } if (typeof f.kind !== 'string') { f.kind = 'text'; }
    if (typeof f.required !== 'boolean') { f.required = false; } f.options = strings(f.options);
  }
  for (let j: number = 0; j < m.toolContracts.length; j++) {
    let t: ToolContract = m.toolContracts[j]; if (typeof t.name !== 'string') { t.name = 'unknown.' + j.toString(); }
    if (typeof t.description !== 'string') { t.description = ''; } if (typeof t.adapterId !== 'string') { t.adapterId = ''; }
    t.inputFields = strings(t.inputFields); t.outputFields = strings(t.outputFields); t.allowedOrigins = strings(t.allowedOrigins);
    if (typeof t.credentialRef !== 'string') { t.credentialRef = ''; } if (typeof t.confirmation !== 'string') { t.confirmation = 'none'; }
    t.implemented = registeredTool(t.name);
  }
  return m;
}

export function sanitizeAppBlueprint(value: AppBlueprint, fallback: AppBlueprint,
  repairedFields: string[] = []): AppBlueprint {
  let b: AppBlueprint = JSON.parse(JSON.stringify(value)) as AppBlueprint;
  if (typeof b.schemaVersion !== 'string') { b.schemaVersion = SCHEMA_VERSION; repairedFields.push('schemaVersion'); }
  if (typeof b.appId !== 'string' || b.appId.length === 0) { b.appId = fallback.appId; repairedFields.push('appId'); }
  if (typeof b.skillId !== 'string' || b.skillId.length === 0) { b.skillId = fallback.skillId; repairedFields.push('skillId'); }
  if (typeof b.title !== 'string' || b.title.length === 0) { b.title = fallback.title; repairedFields.push('title'); }
  if (typeof b.summary !== 'string') { b.summary = ''; repairedFields.push('summary'); }
  if (typeof b.homePattern !== 'string') { b.homePattern = ''; repairedFields.push('homePattern'); }
  if (typeof b.runtimePrompt !== 'string') { b.runtimePrompt = ''; repairedFields.push('runtimePrompt'); }
  if (!Array.isArray(b.palette)) { b.palette = fallback.palette; repairedFields.push('palette'); }
  b.palette = strings(b.palette);
  if (!Array.isArray(b.dynamicSlots)) { b.dynamicSlots = []; repairedFields.push('dynamicSlots'); }
  if (!Array.isArray(b.componentRecipes)) { b.componentRecipes = []; repairedFields.push('componentRecipes'); }
  // Missing page plans are not repairable metadata. Keep them invalid so the caller can stop instead of
  // silently replacing an unrelated Skill with the local travel/weather blueprint.
  if (!Array.isArray(b.pages)) { b.pages = []; }
  b.pages = b.pages.slice(0, 5);
  let pageIds: string[] = [];
  for (let i: number = 0; i < b.pages.length; i++) {
    let p: AppPagePlan = b.pages[i];
    if (typeof p.id !== 'string' || p.id.length === 0) { p.id = 'page-' + i.toString(); repairedFields.push('pages[' + i.toString() + '].id'); }
    let baseId: string = p.id;
    let suffix: number = 2;
    while (pageIds.indexOf(p.id) >= 0) { p.id = baseId + '-' + suffix.toString(); suffix++; }
    if (p.id !== baseId) { repairedFields.push('pages[' + i.toString() + '].id'); }
    pageIds.push(p.id);
    if (typeof p.title !== 'string' || p.title.length === 0) { p.title = p.id; repairedFields.push('pages[' + i.toString() + '].title'); }
    if (typeof p.purpose !== 'string') { p.purpose = ''; repairedFields.push('pages[' + i.toString() + '].purpose'); }
    if (typeof p.primaryAction !== 'string') { p.primaryAction = ''; repairedFields.push('pages[' + i.toString() + '].primaryAction'); }
  }
  return b;
}

function isValidAppBlueprint(value: AppBlueprint): boolean {
  if (value === undefined || value === null || value.appId.length === 0 || value.skillId.length === 0 ||
    value.title.length === 0 || !Array.isArray(value.pages) || value.pages.length === 0) { return false; }
  for (let i: number = 0; i < value.pages.length; i++) {
    let page: AppPagePlan = value.pages[i];
    if (page === undefined || page.id.length === 0 || page.title.length === 0) { return false; }
  }
  return true;
}

function runtimePrompt(manifest: SkillManifest): string { return 'Act as ' + manifest.skillName + '. Use only registered tools and return structured runtime patches.'; }
function registeredTool(name: string): boolean { return name.indexOf('travel.') === 0; }
function safeId(skillId: string): string { return skillId.toLowerCase().replace('_v1', '').replace(/_/g, '-') + '-app'; }
function field(id: string, label: string, kind: string, required: boolean, options: string[]): SkillInputField { return { id: id, label: label, kind: kind, required: required, options: options }; }
function tool(name: string, adapterId: string, implemented: boolean): ToolContract { return { name: name, description: name, adapterId: adapterId, inputFields: [], outputFields: [], allowedOrigins: [], credentialRef: '', confirmation: 'none', implemented: implemented }; }
function plan(id: string, title: string, purpose: string, primaryAction: string): AppPagePlan { return { id: id, title: title, purpose: purpose, primaryAction: primaryAction }; }
function strings(value: string[]): string[] { if (!Array.isArray(value)) { return []; } let out: string[] = []; for (let i: number = 0; i < value.length; i++) { if (typeof value[i] === 'string') { out.push(value[i]); } } return out; }
function credentialRefs(manifest: SkillManifest): string[] { let refs: string[] = []; for (let i: number = 0; i < manifest.toolContracts.length; i++) { let ref: string = manifest.toolContracts[i].credentialRef; if (ref.length > 0 && refs.indexOf(ref) < 0) { refs.push(ref); } } return refs; }
function cleanJson(raw: string): string {
  let cleaned: string = raw.replace('```json', '').replace('```', '').trim();
  let start: number = cleaned.indexOf('{');
  if (start < 0) { return cleaned; }
  let depth: number = 0;
  let inString: boolean = false;
  let escaped: boolean = false;
  for (let i: number = start; i < cleaned.length; i++) {
    let current: string = cleaned.charAt(i);
    if (inString) {
      if (escaped) { escaped = false; }
      else if (current === '\\') { escaped = true; }
      else if (current === '"') { inString = false; }
      continue;
    }
    if (current === '"') { inString = true; }
    else if (current === '{') { depth++; }
    else if (current === '}') {
      depth--;
      if (depth === 0) { return cleaned.substring(start, i + 1); }
    }
  }
  return cleaned;
}
function cloneDraft(draft: ForgeDraft): ForgeDraft { return JSON.parse(JSON.stringify(draft)) as ForgeDraft; }
