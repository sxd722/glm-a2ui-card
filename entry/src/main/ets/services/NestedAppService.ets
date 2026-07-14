import { NestedAction, NestedActionHandling, NestedActionKind, NestedAppSpec, NestedNode, NestedNodeKind, NestedPageSpec, NestedSessionState } from './NestedAppTypes';
import { TravelInputs, ToolResult } from './SkillTypes';
import { runTravelTool } from './SkillWorkbench';

const NODE_KINDS: string[] = ['heroMedia', 'glassPanel', 'sectionHeader', 'formField', 'choiceChips', 'timeline',
  'metric', 'mediaGallery', 'actionBar', 'statusBanner', 'resultList', 'dataChart', 'compareTable', 'entityPicker',
  'conversationPanel', 'credentialForm', 'dynamicSlot'];
const ACTION_KINDS: string[] = ['navigate', 'back', 'invokeAgent', 'pickLocalImage', 'reset'];
const ACTION_HANDLINGS: string[] = ['local', 'agent', 'localThenAgent'];

export function defaultTravelNestedApp(): NestedAppSpec {
  return {
    appId: 'travel-nested-demo',
    title: '成都轻旅行',
    subtitle: '由 Agent Skill 驱动的行程工作台',
    initialPageId: 'home',
    pages: [
      page('home', '旅行首页', '从灵感到可执行行程', [
        node('hero', 'heroMedia', '把周末留给好风景', '选择一张本地图片作为旅行封面。', '', 'cover', [], [action('pick-cover', '添加本地封面', 'pickLocalImage', '', 'cover')], 'calm'),
        node('welcome', 'glassPanel', '成都，慢一点刚刚好', '填好参数后，Agent 会在本地工具白名单内生成交通、住宿、行程和预算建议。', '', '', [], [action('start', '开始规划', 'navigate', 'editor', '')], 'accent'),
        node('home-status', 'statusBanner', '当前进度', '尚未生成方案', 'status', '', [], [], 'calm')
      ]),
      page('editor', '行程偏好', '把旅程交代清楚', [
        node('origin', 'formField', '出发地', '例如 上海', 'departure', '', [], [], 'calm'),
        node('destination', 'formField', '目的地', '例如 成都', 'destination', '', [], [], 'calm'),
        node('dates', 'formField', '出行日期', '例如 2026-08-01 至 2026-08-03', 'dates', '', [], [], 'calm'),
        node('budget', 'formField', '预算', '例如 5000 元', 'budget', '', [], [], 'calm'),
        node('preference', 'choiceChips', '旅行偏好', '选择或输入最在意的体验', 'preferences', '', ['美食', '慢游', '人文', '自然'], [], 'accent'),
        node('editor-actions', 'actionBar', '', '', '', '', [], [action('back-home', '返回', 'back', '', ''), action('generate-plan', '生成方案', 'invokeAgent', 'plan', '')], 'accent')
      ]),
      page('plan', '旅行方案', 'Agent 正在为你整理', [
        node('plan-status', 'statusBanner', '规划状态', '等待执行', 'status', '', [], [], 'accent'),
        node('timeline', 'timeline', '三天两晚的节奏', '生成后会呈现每天的重点安排。', 'itinerary', '', [], [], 'calm'),
        node('plan-actions', 'actionBar', '', '', '', '', [], [action('open-budget', '查看预算与清单', 'navigate', 'budget', ''), action('edit-plan', '编辑参数', 'navigate', 'editor', '')], 'accent')
      ]),
      page('budget', '预算与清单', '让出发更从容', [
        node('budget-metric', 'metric', '旅行预算', '预算与本地估算', 'budgetSummary', '', [], [], 'accent'),
        node('checklist', 'resultList', '出行清单', '为出发前最后确认准备', 'checklist', '', [], [], 'calm'),
        node('gallery', 'mediaGallery', '旅行灵感', '所有图片均来自本机选择。', '', '', [], [action('pick-gallery', '添加本地图片', 'pickLocalImage', '', 'gallery')], 'calm'),
        node('finish-actions', 'actionBar', '', '', '', '', [], [action('back-plan', '返回方案', 'back', '', ''), action('restart', '重新开始', 'reset', 'home', '')], 'accent')
      ])
    ]
  };
}

export function createNestedSession(app: NestedAppSpec): NestedSessionState {
  let data: Record<string, string> = {};
  data['departure'] = '上海';
  data['destination'] = '成都';
  data['dates'] = '3 天 2 晚';
  data['budget'] = '5000 元';
  data['preferences'] = '美食、慢游';
  data['status'] = '准备开始';
  data['itinerary'] = '';
  data['budgetSummary'] = '';
  data['checklist'] = '';
  let session: NestedSessionState = {
    app: app,
    activePageId: app.initialPageId,
    routeStack: [app.initialPageId],
    data: data,
    assets: [],
    status: 'idle',
    agentTrace: 'Nested App 已就绪，可选择本地图片或开始规划。',
    errorMessage: ''
  };
  return session;
}

export function normalizeNestedApp(raw: string): NestedAppSpec {
  try {
    let app: NestedAppSpec = JSON.parse(raw.replace('```json', '').replace('```', '').trim()) as NestedAppSpec;
    if (isValidNestedAppSpec(app)) {
      return app;
    }
  } catch (e) {
  }
  return defaultTravelNestedApp();
}

export function activeNestedPage(session: NestedSessionState): NestedPageSpec {
  for (let i = 0; i < session.app.pages.length; i++) {
    if (session.app.pages[i].id === session.activePageId) {
      return session.app.pages[i];
    }
  }
  return session.app.pages[0];
}

export function updateNestedField(session: NestedSessionState, key: string, value: string): NestedSessionState {
  let next: NestedSessionState = cloneSession(session);
  next.data[key] = value;
  return next;
}

export function addNestedAsset(session: NestedSessionState, name: string, dataUrl: string, slot: string): NestedSessionState {
  let next: NestedSessionState = cloneSession(session);
  let id: string = slot.length > 0 ? slot : 'image-' + Date.now().toString();
  next.assets = next.assets.filter((asset) => asset.id !== id);
  next.assets.push({ id: id, name: name, dataUrl: dataUrl });
  next.agentTrace = '已添加本地图片：' + name;
  return next;
}

export function reduceNestedAction(session: NestedSessionState, current: NestedAction): NestedSessionState {
  let next: NestedSessionState = cloneSession(session);
  next.errorMessage = '';
  if (current.kind === 'navigate') {
    navigate(next, current.targetPageId);
  } else if (current.kind === 'back') {
    if (next.routeStack.length > 1) {
      next.routeStack.pop();
      next.activePageId = next.routeStack[next.routeStack.length - 1];
    }
  } else if (current.kind === 'reset') {
    return createNestedSession(next.app);
  } else if (current.kind === 'invokeAgent') {
    applyTravelDemoAgent(next);
    navigate(next, current.targetPageId);
  }
  return next;
}

export function assetDataUrl(session: NestedSessionState, assetId: string): string {
  for (let i = 0; i < session.assets.length; i++) {
    if (session.assets[i].id === assetId) {
      return session.assets[i].dataUrl;
    }
  }
  return '';
}

function applyTravelDemoAgent(session: NestedSessionState): void {
  let inputs: TravelInputs = {
    departure: session.data['departure'], destination: session.data['destination'], startDate: session.data['dates'], endDate: session.data['dates'],
    adults: '2', children: '0', budget: session.data['budget'], preferences: session.data['preferences'], lodging: '', transport: ''
  };
  let itinerary: ToolResult = runTravelTool('travel.planDailyItinerary', inputs);
  let budget: ToolResult = runTravelTool('travel.estimateBudget', inputs);
  let checklist: ToolResult = runTravelTool('travel.generateChecklist', inputs);
  session.data['itinerary'] = itinerary.details.join('\n');
  session.data['budgetSummary'] = budget.summary + '\n' + budget.details.join('\n');
  session.data['checklist'] = checklist.details.join('\n');
  session.data['status'] = '方案已生成';
  session.status = 'complete';
  session.agentTrace = 'Agent 已执行本地旅行工具：行程、预算、清单。';
}

export function isValidNestedAppSpec(app: NestedAppSpec): boolean {
  if (app === undefined || app === null || typeof app.appId !== 'string' || typeof app.title !== 'string' ||
    typeof app.subtitle !== 'string' || typeof app.initialPageId !== 'string' || !Array.isArray(app.pages) ||
    app.appId.length === 0 || app.pages.length === 0 || app.initialPageId.length === 0) {
    return false;
  }
  let pageIds: string[] = [];
  for (let i = 0; i < app.pages.length; i++) {
    let pageSpec: NestedPageSpec = app.pages[i];
    if (pageSpec === undefined || pageSpec === null || typeof pageSpec.id !== 'string' || typeof pageSpec.title !== 'string' ||
      typeof pageSpec.subtitle !== 'string' || !Array.isArray(pageSpec.nodes) || pageSpec.id.length === 0) {
      return false;
    }
    pageIds.push(pageSpec.id);
    for (let j = 0; j < pageSpec.nodes.length; j++) {
      let nestedNode: NestedNode = pageSpec.nodes[j];
      if (nestedNode === undefined || nestedNode === null || typeof nestedNode.id !== 'string' ||
        typeof nestedNode.kind !== 'string' || typeof nestedNode.title !== 'string' || typeof nestedNode.text !== 'string' ||
        typeof nestedNode.binding !== 'string' || typeof nestedNode.assetId !== 'string' || typeof nestedNode.tone !== 'string' ||
        !Array.isArray(nestedNode.items) || !Array.isArray(nestedNode.actions) || NODE_KINDS.indexOf(nestedNode.kind) < 0) {
        return false;
      }
      for (let k = 0; k < nestedNode.actions.length; k++) {
        let nestedAction: NestedAction = nestedNode.actions[k];
        if (nestedAction === undefined || nestedAction === null || typeof nestedAction.id !== 'string' ||
          typeof nestedAction.label !== 'string' || typeof nestedAction.kind !== 'string' ||
          typeof nestedAction.targetPageId !== 'string' || typeof nestedAction.payload !== 'string' ||
          ACTION_KINDS.indexOf(nestedAction.kind) < 0) {
          return false;
        }
        if (nestedAction.handling !== undefined && ACTION_HANDLINGS.indexOf(nestedAction.handling) < 0) {
          return false;
        }
      }
    }
  }
  return pageIds.indexOf(app.initialPageId) >= 0;
}

function navigate(session: NestedSessionState, pageId: string): void {
  for (let i = 0; i < session.app.pages.length; i++) {
    if (session.app.pages[i].id === pageId) {
      session.activePageId = pageId;
      session.routeStack.push(pageId);
      return;
    }
  }
  session.errorMessage = '已拒绝未知页面跳转：' + pageId;
}

function cloneSession(session: NestedSessionState): NestedSessionState {
  return JSON.parse(JSON.stringify(session)) as NestedSessionState;
}

function page(id: string, title: string, subtitle: string, nodes: NestedNode[]): NestedPageSpec {
  return { id: id, title: title, subtitle: subtitle, nodes: nodes };
}

function node(id: string, kind: NestedNodeKind, title: string, text: string, binding: string, assetId: string,
  items: string[], actions: NestedAction[], tone: string): NestedNode {
  return { id: id, kind: kind, title: title, text: text, binding: binding, assetId: assetId, items: items, actions: actions, tone: tone };
}

function action(id: string, label: string, kind: NestedActionKind, targetPageId: string, payload: string): NestedAction {
  let handling: NestedActionHandling = kind === 'invokeAgent' ? 'agent' : 'local';
  return { id: id, label: label, kind: kind, targetPageId: targetPageId, payload: payload, handling: handling };
}
