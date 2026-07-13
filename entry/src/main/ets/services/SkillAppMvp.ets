import {
  NestedAction,
  NestedActionHandling,
  NestedActionKind,
  NestedAppSpec,
  NestedNode,
  NestedNodeKind,
  NestedPageSpec
} from './NestedAppTypes';
import { defaultTravelNestedApp, normalizeNestedApp } from './NestedAppService';
import {
  AppBlueprint,
  ComponentRecipe,
  DynamicSlotPolicy,
  ForgeDraft,
  InstalledNestedApp,
  SkillInputField,
  SkillManifest,
  SkillSource,
  ToolContract
} from './SkillAppTypes';

const SCHEMA_VERSION: string = 'skill-app-mvp-1';

export function createSkillSource(kind: string, value: string, localAssetIds: string[]): SkillSource {
  let sourceKind: 'image' | 'file' | 'repository' | 'text' = 'text';
  if (kind === 'image' || kind === 'file' || kind === 'repository') {
    sourceKind = kind;
  }
  return {
    id: 'source-' + Date.now().toString(),
    kind: sourceKind,
    displayName: sourceKind === 'repository' ? '公开 Skill 仓库' : '用户提供的 Skill',
    uri: sourceKind === 'repository' ? value : '',
    textContent: sourceKind === 'repository' ? '' : value,
    localAssetIds: localAssetIds,
    importedAt: Date.now()
  };
}

export function createForgeDraft(source: SkillSource): ForgeDraft {
  let manifest: SkillManifest = localManifestForSource(source);
  let blueprint: AppBlueprint = localBlueprintForManifest(manifest);
  return {
    draftId: 'forge-' + Date.now().toString(),
    source: source,
    manifest: manifest,
    blueprint: blueprint,
    status: 'import',
    trace: 'Skill 来源已就绪，可开始分析。',
    errorMessage: '',
    updatedAt: Date.now()
  };
}

export function localManifestForSource(source: SkillSource): SkillManifest {
  let probe: string = (source.uri + ' ' + source.textContent + ' ' + source.displayName).toLowerCase();
  if (probe.indexOf('seniverse') >= 0 || probe.indexOf('weather') >= 0 || probe.indexOf('天气') >= 0) {
    return weatherManifest();
  }
  return travelManifest();
}

export function localBlueprintForManifest(manifest: SkillManifest): AppBlueprint {
  if (manifest.skillId === 'SENIVERSE_WEATHER_V1') {
    return weatherBlueprint(manifest);
  }
  return travelBlueprint(manifest);
}

export function normalizeSkillManifest(raw: string, fallback: SkillManifest): SkillManifest {
  try {
    let manifest: SkillManifest = JSON.parse(cleanJson(raw)) as SkillManifest;
    if (isValidManifest(manifest)) {
      return manifest;
    }
  } catch (e) {
  }
  return fallback;
}

export function normalizeAppBlueprint(raw: string, fallback: AppBlueprint): AppBlueprint {
  try {
    let blueprint: AppBlueprint = JSON.parse(cleanJson(raw)) as AppBlueprint;
    if (isValidBlueprint(blueprint)) {
      return blueprint;
    }
  } catch (e) {
  }
  return fallback;
}

export function compileBlueprint(blueprint: AppBlueprint): NestedAppSpec {
  return normalizeNestedApp(JSON.stringify(blueprint.nestedApp));
}

export function installBlueprint(draft: ForgeDraft): InstalledNestedApp {
  return {
    appId: draft.blueprint.appId,
    schemaVersion: draft.blueprint.schemaVersion,
    skillVersion: draft.manifest.version,
    generatedAt: Date.now(),
    manifest: draft.manifest,
    blueprint: draft.blueprint,
    runtimePrompt: draft.blueprint.runtimePrompt,
    credentialRefs: credentialRefs(draft.manifest)
  };
}

export function updateDraftManifest(draft: ForgeDraft, manifest: SkillManifest, trace: string): ForgeDraft {
  let next: ForgeDraft = cloneDraft(draft);
  next.manifest = manifest;
  next.blueprint = localBlueprintForManifest(manifest);
  next.status = 'analyzed';
  next.trace = trace;
  next.errorMessage = '';
  next.updatedAt = Date.now();
  return next;
}

export function updateDraftBlueprint(draft: ForgeDraft, blueprint: AppBlueprint, trace: string): ForgeDraft {
  let next: ForgeDraft = cloneDraft(draft);
  next.blueprint = blueprint;
  next.status = 'preview';
  next.trace = trace;
  next.errorMessage = '';
  next.updatedAt = Date.now();
  return next;
}

function travelManifest(): SkillManifest {
  let fields: SkillInputField[] = [
    field('departure', '出发地', 'entity', true, []),
    field('destination', '目的地', 'entity', true, []),
    field('dates', '出行日期', 'dateRange', true, []),
    field('budget', '预算', 'choiceOrText', true, ['低', '中', '高']),
    field('preferences', '旅行偏好', 'multiChoice', false, ['美食', '自然', '人文', '亲子', '轻松节奏'])
  ];
  return {
    schemaVersion: SCHEMA_VERSION,
    skillId: 'TRAVEL_PLANNER_V1',
    skillName: '旅行规划助手',
    version: '1',
    description: '根据用户约束生成可执行的旅行方案。',
    goals: ['收集旅行约束', '生成交通、住宿、行程、预算和清单'],
    inputFields: fields,
    outputFields: ['overview', 'transport', 'lodging', 'itinerary', 'budget', 'checklist'],
    workflow: ['校验输入', '生成交通', '生成住宿', '规划行程', '估算预算', '生成清单'],
    decisionPoints: ['确认目的地与日期', '接受或调整方案'],
    toolContracts: travelTools(),
    permissions: [],
    constraints: ['只执行本地旅行白名单工具', '不承诺实时价格或库存'],
    examples: ['上海到成都，3 天 2 晚，2 人，预算 5000 元，偏好美食和轻松游。']
  };
}

function weatherManifest(): SkillManifest {
  let fields: SkillInputField[] = [
    field('location', '地点', 'entity', true, []),
    field('dateRange', '时间范围', 'choice', false, ['今天', '未来 24 小时', '未来 7 天']),
    field('activity', '关注事项', 'choice', false, ['通勤', '散步', '户外活动', '空气质量'])
  ];
  return {
    schemaVersion: SCHEMA_VERSION,
    skillId: 'SENIVERSE_WEATHER_V1',
    skillName: '天气决策助手',
    version: '1',
    description: '把实时天气、预报、生活指数和预警转成可执行建议。',
    goals: ['快速查看天气', '基于天气帮助用户做出活动决策'],
    inputFields: fields,
    outputFields: ['current', 'hourly', 'daily', 'lifeIndices', 'alerts', 'decision'],
    workflow: ['确定地点', '查询天气', '识别风险', '解释影响', '给出快捷下一步'],
    decisionPoints: ['位置消歧', '选择关注时段', '确认高风险建议'],
    toolContracts: weatherTools(),
    permissions: ['ohos.permission.LOCATION_IN_BACKGROUND（后续按需申请）'],
    constraints: ['实时事实必须来自天气工具', 'API Key 不进入 GLM Prompt'],
    examples: ['今天适合散步吗？', '比较上海和杭州周末天气。']
  };
}

function travelBlueprint(manifest: SkillManifest): AppBlueprint {
  return {
    schemaVersion: SCHEMA_VERSION,
    appId: 'travel-nested-demo',
    skillId: manifest.skillId,
    title: manifest.skillName,
    summary: '旅行规划的本地可运行回退应用。',
    homePattern: 'guided-workbench',
    palette: ['#6D7E73', '#C89B91', '#E8E3DC', '#7A8A99'],
    runtimePrompt: runtimePrompt(manifest),
    dynamicSlots: [slot('travel-detail-slot', 'plan')],
    componentRecipes: [],
    nestedApp: defaultTravelNestedApp()
  };
}

function weatherBlueprint(manifest: SkillManifest): AppBlueprint {
  return {
    schemaVersion: SCHEMA_VERSION,
    appId: 'seniverse-weather-demo',
    skillId: manifest.skillId,
    title: manifest.skillName,
    summary: '情境仪表盘优先、点选优先的天气 Nested App 骨架。',
    homePattern: 'context-dashboard',
    palette: ['#6F7E77', '#B8C9CA', '#C8B8AA', '#E9ECE7'],
    runtimePrompt: runtimePrompt(manifest),
    dynamicSlots: [slot('weather-decision-slot', 'decision')],
    componentRecipes: recipeList(),
    nestedApp: weatherNestedApp()
  };
}

function weatherNestedApp(): NestedAppSpec {
  return {
    appId: 'seniverse-weather-demo',
    title: '天气决策助手',
    subtitle: '由 Skill 生成的情境天气工作台',
    initialPageId: 'home',
    pages: [
      weatherPage('home', '当前天气', '自动定位与实时天气将在工具适配器接入后启用', [
        weatherNode('weather-status', 'statusBanner', '服务状态', '当前为可交互骨架，未请求实时天气。', 'status', [], [], 'calm'),
        weatherNode('weather-metrics', 'dataChart', '天气概览', '温度、降雨、风力和空气质量将在此展示。', 'weatherSummary', ['温度 --', '降雨 --', '空气 --'], [], 'accent'),
        weatherNode('weather-actions', 'actionBar', '', '', '', [], [
          weatherAction('walking', '适合散步吗', 'invokeAgent', 'decision', 'walking', 'agent'),
          weatherAction('forecast', '未来三天', 'navigate', 'forecast', '', 'local'),
          weatherAction('settings', '设置地点与服务', 'navigate', 'settings', '', 'local')
        ], 'accent')
      ]),
      weatherPage('forecast', '天气预报', '时间线和趋势骨架', [
        weatherNode('forecast-chart', 'dataChart', '逐小时与未来 7 天', '天气工具接入后替换为真实数据。', 'forecast', ['今天', '明天', '后天'], [], 'calm'),
        weatherNode('forecast-actions', 'actionBar', '', '', '', [], [weatherAction('forecast-back', '返回', 'back', '', '', 'local')], 'calm')
      ]),
      weatherPage('decision', 'Agent 决策', '结合天气数据生成建议', [
        weatherNode('decision-panel', 'conversationPanel', '建议', '点击首页快捷任务后，GLM 结论会更新这里。', 'agentSummary', [], [], 'accent'),
        weatherNode('decision-slot', 'dynamicSlot', '临时详情', '位置消歧或专项详情可以挂载在此插槽。', 'dynamicSlot', [], [], 'calm'),
        weatherNode('decision-actions', 'actionBar', '', '', '', [], [weatherAction('decision-back', '返回首页', 'navigate', 'home', '', 'local')], 'calm')
      ]),
      weatherPage('settings', '地点与服务', '凭据只由 App Tool Gateway 使用', [
        weatherNode('location-picker', 'entityPicker', '地点', '选择当前位置或最近地点。', 'location', ['当前位置', '上海', '杭州'], [], 'calm'),
        weatherNode('credential', 'credentialForm', 'Seniverse API Key', 'MVP 骨架暂由 Forge 设置页接收。', 'credentialStatus', [], [], 'accent'),
        weatherNode('settings-actions', 'actionBar', '', '', '', [], [weatherAction('settings-back', '完成', 'navigate', 'home', '', 'local')], 'calm')
      ])
    ]
  };
}

function weatherPage(id: string, title: string, subtitle: string, nodes: NestedNode[]): NestedPageSpec {
  return { id: id, title: title, subtitle: subtitle, nodes: nodes };
}

function weatherNode(id: string, kind: NestedNodeKind, title: string, text: string, binding: string, items: string[],
  actions: NestedAction[], tone: string): NestedNode {
  return {
    id: id,
    kind: kind,
    title: title,
    text: text,
    binding: binding,
    assetId: '',
    items: items,
    actions: actions,
    tone: tone
  };
}

function weatherAction(id: string, label: string, kind: NestedActionKind, targetPageId: string, payload: string,
  handling: NestedActionHandling): NestedAction {
  return {
    id: id,
    label: label,
    kind: kind,
    targetPageId: targetPageId,
    payload: payload,
    handling: handling
  };
}

function field(id: string, label: string, kind: string, required: boolean, options: string[]): SkillInputField {
  return { id: id, label: label, kind: kind, required: required, options: options };
}

function tool(name: string, description: string, adapterId: string, implemented: boolean, origin: string): ToolContract {
  return {
    name: name,
    description: description,
    adapterId: adapterId,
    inputFields: [],
    outputFields: ['summary', 'details'],
    allowedOrigins: origin.length > 0 ? [origin] : [],
    credentialRef: '',
    confirmation: 'none',
    implemented: implemented
  };
}

function travelTools(): ToolContract[] {
  return [
    tool('travel.validateInputs', '校验旅行输入', 'local.travel', true, ''),
    tool('travel.suggestTransport', '生成交通建议', 'local.travel', true, ''),
    tool('travel.suggestLodging', '生成住宿建议', 'local.travel', true, ''),
    tool('travel.planDailyItinerary', '生成每日行程', 'local.travel', true, ''),
    tool('travel.estimateBudget', '估算旅行预算', 'local.travel', true, ''),
    tool('travel.generateChecklist', '生成出行清单', 'local.travel', true, ''),
    tool('travel.finalizePlan', '汇总最终方案', 'local.travel', true, '')
  ];
}

function weatherTools(): ToolContract[] {
  let origin: string = 'https://api.seniverse.com';
  return [
    tool('weather.searchLocation', '搜索和消歧地点', 'http.seniverse', false, origin),
    tool('weather.getNow', '查询当前天气', 'http.seniverse', false, origin),
    tool('weather.getDailyForecast', '查询逐日预报', 'http.seniverse', false, origin),
    tool('weather.getHourlyForecast', '查询逐小时预报', 'http.seniverse', false, origin),
    tool('weather.getLifeIndices', '查询生活指数', 'http.seniverse', false, origin),
    tool('weather.getAlerts', '查询天气预警', 'http.seniverse', false, origin)
  ];
}

function slot(id: string, pageId: string): DynamicSlotPolicy {
  return {
    id: id,
    pageId: pageId,
    allowedNodeKinds: ['glassPanel', 'resultList', 'conversationPanel', 'compareTable'],
    maxInstances: 1
  };
}

function recipeList(): ComponentRecipe[] {
  return [{
    id: 'weather-summary-strip',
    description: '使用指标和列表组合的天气摘要条。',
    rootNodeKind: 'dataChart',
    fallbackNodeKind: 'resultList'
  }];
}

function runtimePrompt(manifest: SkillManifest): string {
  return 'Serve skill ' + manifest.skillName + '. Prefer structured choices, use only available tools, and return strict RuntimeAgentTurnResult JSON.';
}

function isValidManifest(manifest: SkillManifest): boolean {
  return manifest !== undefined && manifest !== null && typeof manifest.skillId === 'string' &&
    typeof manifest.skillName === 'string' && manifest.skillId.length > 0 && manifest.skillName.length > 0 &&
    Array.isArray(manifest.inputFields) && Array.isArray(manifest.toolContracts) && Array.isArray(manifest.workflow);
}

function isValidBlueprint(blueprint: AppBlueprint): boolean {
  return blueprint !== undefined && blueprint !== null && typeof blueprint.appId === 'string' &&
    typeof blueprint.skillId === 'string' && typeof blueprint.title === 'string' && blueprint.appId.length > 0 &&
    blueprint.nestedApp !== undefined && blueprint.nestedApp !== null && Array.isArray(blueprint.nestedApp.pages) &&
    blueprint.nestedApp.pages.length > 0;
}

function credentialRefs(manifest: SkillManifest): string[] {
  let refs: string[] = [];
  for (let i = 0; i < manifest.toolContracts.length; i++) {
    let ref: string = manifest.toolContracts[i].credentialRef;
    if (ref.length > 0 && refs.indexOf(ref) < 0) {
      refs.push(ref);
    }
  }
  return refs;
}

function cleanJson(raw: string): string {
  return raw.replace('```json', '').replace('```', '').trim();
}

function cloneDraft(draft: ForgeDraft): ForgeDraft {
  return JSON.parse(JSON.stringify(draft)) as ForgeDraft;
}
