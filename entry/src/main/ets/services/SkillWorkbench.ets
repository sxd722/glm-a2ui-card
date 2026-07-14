import { common } from '@kit.AbilityKit';
import { fileIo, picker } from '@kit.CoreFileKit';
import { preferences } from '@kit.ArkData';
import { photoAccessHelper } from '@kit.MediaLibraryKit';
import { util } from '@kit.ArkTS';
import { CardPreviewModel } from './A2uiTypes';
import {
  SkillCard,
  SkillCardAction,
  SkillFieldSpec,
  SkillInputValue,
  SkillSessionState,
  SkillSpec,
  ToolResult,
  TravelInputs
} from './SkillTypes';

const STORE_NAME: string = 'skillWorkbenchStore';
const LATEST_SESSION_KEY: string = 'latestSkillSession';

export interface SkillMarkdownFile {
  displayName: string;
  content: string;
}

export const TRAVEL_TOOL_NAMES: string[] = [
  'travel.validateInputs',
  'travel.suggestTransport',
  'travel.suggestLodging',
  'travel.planDailyItinerary',
  'travel.estimateBudget',
  'travel.generateChecklist',
  'travel.finalizePlan'
];

export function defaultTravelSkillSpec(): SkillSpec {
  let fields: SkillFieldSpec[] = [
    { id: 'departure', label: '出发地', placeholder: '城市 / 机场', required: true },
    { id: 'destination', label: '目的地', placeholder: '城市 / 国家', required: true },
    { id: 'startDate', label: '开始日期', placeholder: '例如 2026-08-01', required: true },
    { id: 'endDate', label: '结束日期', placeholder: '例如 2026-08-03', required: true },
    { id: 'adults', label: '成人', placeholder: '例如 2', required: true },
    { id: 'children', label: '儿童', placeholder: '例如 0', required: false },
    { id: 'budget', label: '预算', placeholder: '低 / 中 / 高 / 金额', required: true },
    { id: 'preferences', label: '偏好', placeholder: '美食、自然、人文、购物、亲子、轻松节奏', required: false },
    { id: 'lodging', label: '住宿要求', placeholder: '酒店星级 / 民宿 / 地理位置', required: false },
    { id: 'transport', label: '交通偏好', placeholder: '飞机、高铁、自驾、公共交通', required: false }
  ];

  return {
    skillName: '旅行规划助手',
    skillId: 'TRAVEL_PLANNER_V1',
    goal: '根据用户需求自动生成可执行的旅行方案',
    scenarios: ['周末出游', '城市旅行', '亲子游', '商务出行', '自由行攻略'],
    inputFields: fields,
    flow: ['解析用户需求', '检查时间、预算与目的地匹配度', '生成交通建议', '生成住宿建议', '规划每日行程', '汇总预算估算', '输出完整旅行方案'],
    outputs: ['行程总览', '每日 itinerary', '推荐交通方式', '推荐住宿', '预算拆分', '注意事项与备选方案'],
    rules: ['优先满足预算与时间限制', '行程安排避免过度紧凑', '提供至少 2 个备选建议', '标注关键时间节点', '输出结构清晰，便于直接执行'],
    actions: ['查询交通', '筛选住宿', '生成路线', '估算预算', '整理清单', '输出最终方案'],
    examplePrompt: '帮我规划一个从上海出发去成都的 3 天 2 晚旅行，2 人同行，预算 5000 元，偏好美食和轻松游。'
  };
}

export function normalizeSkillSpec(raw: string): SkillSpec {
  let normalized: string = cleanSkillJson(raw);
  try {
    let parsed: RawSkillSpec = JSON.parse(normalized) as RawSkillSpec;
    return sanitizeSkillSpec(parsed);
  } catch (error) {
    let err: Error = error as Error;
    throw new Error('SkillSpec 解析失败：' + err.message);
  }
}

interface RawSkillFieldSpec {
  id?: string;
  label?: string;
  name?: string;
  placeholder?: string;
  description?: string;
  required?: boolean;
}

interface RawSkillSpec {
  skillName?: string;
  title?: string;
  skillId?: string;
  goal?: string;
  description?: string;
  scenarios?: string[];
  inputFields?: RawSkillFieldSpec[];
  flow?: string[];
  workflow?: string[];
  outputs?: string[];
  outputFields?: string[];
  rules?: string[];
  constraints?: string[];
  actions?: string[];
  examplePrompt?: string;
  examples?: string[];
}

interface RawSkillTextObject {
  id?: string;
  label?: string;
  name?: string;
  step?: string;
  description?: string;
  action?: string;
  output?: string;
  example?: string;
}

function sanitizeSkillSpec(raw: RawSkillSpec): SkillSpec {
  let skillName: string = firstNonEmpty(raw.skillName, raw.title);
  let skillId: string = typeof raw.skillId === 'string' ? raw.skillId.trim() : '';
  if (skillName.length === 0 || skillId.length === 0) {
    throw new Error('缺少非空 skillName 或 skillId');
  }
  let examplePrompt: string = typeof raw.examplePrompt === 'string' ? raw.examplePrompt.trim() : '';
  if (examplePrompt.length === 0) {
    let examples: string[] = normalizeSkillTextArray(raw.examples);
    examplePrompt = examples.length > 0 ? examples[0] : '';
  }
  return {
    skillName: skillName,
    skillId: skillId,
    goal: firstNonEmpty(raw.goal, raw.description),
    scenarios: normalizeSkillTextArray(raw.scenarios),
    inputFields: normalizeSkillFields(raw.inputFields),
    flow: normalizeSkillTextArray(Array.isArray(raw.flow) ? raw.flow : raw.workflow),
    outputs: normalizeSkillTextArray(Array.isArray(raw.outputs) ? raw.outputs : raw.outputFields),
    rules: normalizeSkillTextArray(Array.isArray(raw.rules) ? raw.rules : raw.constraints),
    actions: normalizeSkillTextArray(raw.actions),
    examplePrompt: examplePrompt
  };
}

function normalizeSkillFields(values: RawSkillFieldSpec[] | undefined): SkillFieldSpec[] {
  if (!Array.isArray(values)) {
    return [];
  }
  let fields: SkillFieldSpec[] = [];
  for (let i: number = 0; i < values.length; i++) {
    let raw: RawSkillFieldSpec = values[i];
    let id: string = typeof raw.id === 'string' ? raw.id.trim() : '';
    let label: string = firstNonEmpty(raw.label, raw.name);
    if (id.length === 0) {
      id = 'field' + (i + 1).toString();
    }
    if (label.length === 0) {
      label = id;
    }
    fields.push({
      id: id,
      label: label,
      placeholder: firstNonEmpty(raw.placeholder, raw.description),
      required: raw.required === true
    });
  }
  return fields;
}

function normalizeSkillTextArray(values: string[] | undefined): string[] {
  if (!Array.isArray(values)) {
    return [];
  }
  let result: string[] = [];
  for (let i: number = 0; i < values.length; i++) {
    let value: string = values[i];
    if (typeof value === 'string' && value.trim().length > 0) {
      result.push(value.trim());
      continue;
    }
    let objectValue: RawSkillTextObject = JSON.parse(JSON.stringify(value)) as RawSkillTextObject;
    let text: string = firstNonEmpty(objectValue.step, objectValue.label);
    text = firstNonEmpty(text, objectValue.name);
    text = firstNonEmpty(text, objectValue.description);
    text = firstNonEmpty(text, objectValue.action);
    text = firstNonEmpty(text, objectValue.output);
    text = firstNonEmpty(text, objectValue.example);
    text = firstNonEmpty(text, objectValue.id);
    if (text.length > 0) {
      result.push(text);
    }
  }
  return result;
}

function firstNonEmpty(primary: string | undefined, secondary: string | undefined): string {
  if (typeof primary === 'string' && primary.trim().length > 0) {
    return primary.trim();
  }
  return typeof secondary === 'string' ? secondary.trim() : '';
}

function cleanSkillJson(raw: string): string {
  let cleaned: string = raw.replace('```json', '').replace('```', '').trim();
  let start: number = cleaned.indexOf('{');
  let end: number = cleaned.lastIndexOf('}');
  if (start >= 0 && end > start) {
    return cleaned.substring(start, end + 1);
  }
  return cleaned;
}

export function createTravelInputs(): TravelInputs {
  return {
    departure: '',
    destination: '',
    startDate: '',
    endDate: '',
    adults: '2',
    children: '0',
    budget: '',
    preferences: '',
    lodging: '',
    transport: ''
  };
}

export function createSkillSession(spec: SkillSpec): SkillSessionState {
  let now: string = new Date().toLocaleString();
  let cards: SkillCard[] = compileSkillCards(spec);
  return {
    sessionId: 'skill-' + Date.now().toString(),
    skillSpec: spec,
    cards: cards,
    activeCardId: cards[0].id,
    inputs: createTravelInputs(),
    fieldValues: createSkillInputValues(spec),
    toolResults: [],
    finalPlan: '',
    progress: 0,
    status: 'collecting',
    nextAction: spec.skillId === 'TRAVEL_PLANNER_V1' ? '确认 Skill 并填写旅行参数' : '确认 Skill 并填写输入',
    updatedAt: now,
    errorMessage: ''
  };
}

export function compileSkillCards(spec: SkillSpec): SkillCard[] {
  if (spec.skillId !== 'TRAVEL_PLANNER_V1') {
    return compileGenericSkillCards(spec);
  }
  return [
    makeCard('skill_overview', 'overview', spec.skillName, spec.skillId, spec.goal, [], ['开始填写']),
    makeCard('input_departure_destination', 'input', '出发与目的地', '第一步', '填写出发地和目的地。', ['departure', 'destination'], ['下一步']),
    makeCard('input_dates_people_budget', 'input', '日期、人数与预算', '第二步', '补齐时间、同行人数和预算。', ['startDate', 'endDate', 'adults', 'children', 'budget'], ['下一步', '返回']),
    makeCard('input_preferences_lodging_transport', 'input', '偏好设置', '第三步', '输入旅行偏好、住宿和交通偏好。', ['preferences', 'lodging', 'transport'], ['生成方案', '返回']),
    makeCard('plan_progress', 'progress', 'Agent 执行进度', '白名单工具执行', '按步骤生成交通、住宿、行程、预算和清单。', [], ['执行下一步', '重新生成']),
    makeCard('transport_card', 'result', '交通建议', 'travel.suggestTransport', '等待 Agent 生成。', [], ['执行下一步', '编辑输入']),
    makeCard('lodging_card', 'result', '住宿建议', 'travel.suggestLodging', '等待 Agent 生成。', [], ['执行下一步', '编辑输入']),
    makeCard('itinerary_card', 'result', '每日行程', 'travel.planDailyItinerary', '等待 Agent 生成。', [], ['执行下一步', '编辑输入']),
    makeCard('budget_card', 'result', '预算拆分', 'travel.estimateBudget', '等待 Agent 生成。', [], ['执行下一步', '编辑输入']),
    makeCard('checklist_card', 'result', '出行清单', 'travel.generateChecklist', '等待 Agent 生成。', [], ['生成最终方案', '编辑输入']),
    makeCard('final_plan_card', 'final', '最终旅行方案', spec.skillName, '等待输出完整方案。', [], ['加到桌面', '重新生成'])
  ];
}

function compileGenericSkillCards(spec: SkillSpec): SkillCard[] {
  let cards: SkillCard[] = [
    makeCard('skill_overview', 'overview', spec.skillName, spec.skillId, spec.goal, [], ['开始'])
  ];
  if (spec.inputFields.length > 0) {
    let fieldIds: string[] = [];
    for (let i: number = 0; i < spec.inputFields.length; i++) {
      fieldIds.push(spec.inputFields[i].id);
    }
    cards.push(makeCard('skill_inputs', 'input', '输入信息', spec.skillName,
      '填写图片中识别出的 Skill 输入字段。', fieldIds, ['继续', '返回']));
  }
  if (spec.flow.length > 0) {
    cards.push(makeCard('skill_flow', 'progress', '执行流程', spec.flow.length.toString() + ' 步',
      spec.flow.join('\n'), [], ['继续', '返回']));
  }
  if (spec.outputs.length > 0) {
    cards.push(makeCard('skill_outputs', 'result', '预期输出', spec.skillName,
      spec.outputs.join('\n'), [], ['完成', '返回']));
  }
  cards.push(makeCard('skill_complete', 'final', spec.skillName, spec.skillId,
    'Skill 已识别并生成通用交互界面。', [], ['重新开始']));
  return cards;
}

function createSkillInputValues(spec: SkillSpec): SkillInputValue[] {
  let values: SkillInputValue[] = [];
  for (let i: number = 0; i < spec.inputFields.length; i++) {
    values.push({ id: spec.inputFields[i].id, value: '' });
  }
  return values;
}

function makeCard(id: string, kind: string, title: string, subtitle: string, body: string, fields: string[],
  actionLabels: string[]): SkillCard {
  let actions: SkillCardAction[] = [];
  for (let i = 0; i < actionLabels.length; i++) {
    actions.push({ id: actionLabels[i], label: actionLabels[i] });
  }
  return {
    id: id,
    kind: kind,
    title: title,
    subtitle: subtitle,
    body: body,
    fields: fields,
    actions: actions,
    status: 'pending'
  };
}

export function runTravelTool(toolName: string, inputs: TravelInputs): ToolResult {
  if (TRAVEL_TOOL_NAMES.indexOf(toolName) < 0) {
    return { toolName: toolName, summary: '已拒绝未知工具调用', details: ['只允许旅行规划白名单工具。'] };
  }
  if (toolName === 'travel.validateInputs') {
    let missing: string[] = [];
    if (inputs.departure.trim().length === 0) {
      missing.push('出发地');
    }
    if (inputs.destination.trim().length === 0) {
      missing.push('目的地');
    }
    if (inputs.startDate.trim().length === 0 || inputs.endDate.trim().length === 0) {
      missing.push('出行日期');
    }
    if (inputs.budget.trim().length === 0) {
      missing.push('预算');
    }
    if (missing.length > 0) {
      return { toolName: toolName, summary: '参数未完整', details: ['缺少：' + missing.join('、')] };
    }
    return { toolName: toolName, summary: '参数完整，可以生成方案', details: ['优先满足预算与时间限制。'] };
  }
  if (toolName === 'travel.suggestTransport') {
    let preferred: string = inputs.transport.length > 0 ? inputs.transport : '高铁 / 飞机二选一';
    return {
      toolName: toolName,
      summary: '推荐交通：' + preferred,
      details: ['主方案：按 ' + preferred + ' 从 ' + inputs.departure + ' 前往 ' + inputs.destination, '备选：公共交通接驳，避免行程过紧。']
    };
  }
  if (toolName === 'travel.suggestLodging') {
    let lodging: string = inputs.lodging.length > 0 ? inputs.lodging : '目的地核心商圈或交通枢纽附近';
    return {
      toolName: toolName,
      summary: '推荐住宿：' + lodging,
      details: ['优先选择交通便利区域。', '保留至少 2 个备选住宿方案。']
    };
  }
  if (toolName === 'travel.planDailyItinerary') {
    let pref: string = inputs.preferences.length > 0 ? inputs.preferences : '轻松节奏';
    return {
      toolName: toolName,
      summary: '已生成每日行程',
      details: ['D1：抵达 ' + inputs.destination + '，办理入住，安排 ' + pref + ' 主题活动。', 'D2：核心景点 + 当地美食，下午留出弹性时间。', 'D3：轻量补充游览，预留返程时间。']
    };
  }
  if (toolName === 'travel.estimateBudget') {
    return {
      toolName: toolName,
      summary: '预算估算完成：' + inputs.budget,
      details: ['交通约 35%。', '住宿约 30%。', '餐饮与门票约 25%。', '机动预算约 10%。']
    };
  }
  if (toolName === 'travel.generateChecklist') {
    return {
      toolName: toolName,
      summary: '已整理出行清单',
      details: ['证件与订单截图。', '交通与酒店确认信息。', '天气适配衣物。', '关键时间节点提醒。']
    };
  }
  return {
    toolName: toolName,
    summary: '最终方案已生成',
    details: ['包含总览、交通、住宿、每日行程、预算拆分、注意事项和备选方案。']
  };
}

export function advanceSkillSession(session: SkillSessionState, actionId: string): SkillSessionState {
  if (session.skillSpec.skillId !== 'TRAVEL_PLANNER_V1') {
    return advanceGenericSkillSession(session, actionId);
  }
  let next: SkillSessionState = cloneSession(session);
  next.errorMessage = '';
  if (actionId === '返回') {
    moveBack(next);
    return touch(next);
  }
  if (actionId === '编辑输入') {
    next.activeCardId = 'input_departure_destination';
    next.status = 'collecting';
    next.nextAction = '编辑旅行参数';
    return touch(next);
  }
  if (actionId === '重新生成') {
    next.toolResults = [];
    next.finalPlan = '';
    next.progress = 0;
    next.status = 'collecting';
    next.activeCardId = 'input_departure_destination';
    next.nextAction = '重新填写或确认旅行参数';
    return touch(next);
  }
  if (next.activeCardId === 'skill_overview') {
    next.activeCardId = 'input_departure_destination';
    next.nextAction = '填写出发地和目的地';
    return touch(next);
  }
  if (next.activeCardId === 'input_departure_destination') {
    next.activeCardId = 'input_dates_people_budget';
    next.nextAction = '填写日期、人数与预算';
    return touch(next);
  }
  if (next.activeCardId === 'input_dates_people_budget') {
    next.activeCardId = 'input_preferences_lodging_transport';
    next.nextAction = '填写偏好后生成方案';
    return touch(next);
  }
  if (next.activeCardId === 'input_preferences_lodging_transport') {
    let validation: ToolResult = runTravelTool('travel.validateInputs', next.inputs);
    replaceToolResult(next, validation);
    if (validation.summary === '参数未完整') {
      next.status = 'error';
      next.errorMessage = validation.details.join('\n');
      next.nextAction = '补齐必填字段';
      return touch(next);
    }
    next.activeCardId = 'plan_progress';
    next.status = 'running';
    next.progress = 10;
    next.nextAction = '执行下一步';
    return touch(next);
  }
  if (actionId === '生成最终方案') {
    runAndApplyTool(next, 'travel.finalizePlan');
    next.activeCardId = 'final_plan_card';
    next.status = 'complete';
    next.progress = 100;
    next.nextAction = '可加到桌面';
    return touch(next);
  }
  runNextTravelStep(next);
  return touch(next);
}

function advanceGenericSkillSession(session: SkillSessionState, actionId: string): SkillSessionState {
  let next: SkillSessionState = cloneSession(session);
  next.errorMessage = '';
  if (!Array.isArray(next.fieldValues)) {
    next.fieldValues = createSkillInputValues(next.skillSpec);
  }
  if (actionId === '重新开始') {
    next.activeCardId = next.cards[0].id;
    next.progress = 0;
    next.status = 'collecting';
    next.nextAction = '确认 Skill';
    return touch(next);
  }
  let currentIndex: number = activeCardIndex(next);
  if (actionId === '返回') {
    currentIndex = currentIndex > 0 ? currentIndex - 1 : 0;
    next.activeCardId = next.cards[currentIndex].id;
    next.nextAction = '继续上一步';
    return touch(next);
  }
  if (next.activeCardId === 'skill_inputs') {
    let missing: string[] = missingRequiredSkillFields(next);
    if (missing.length > 0) {
      next.status = 'error';
      next.errorMessage = '请填写：' + missing.join('、');
      next.nextAction = '补齐必填字段';
      return touch(next);
    }
  }
  let nextIndex: number = currentIndex + 1;
  if (nextIndex >= next.cards.length) {
    nextIndex = next.cards.length - 1;
  }
  next.activeCardId = next.cards[nextIndex].id;
  next.progress = Math.round(nextIndex * 100 / (next.cards.length - 1));
  next.status = nextIndex === next.cards.length - 1 ? 'complete' : 'running';
  next.nextAction = next.status === 'complete' ? 'Skill 已完成' : '继续';
  return touch(next);
}

function activeCardIndex(session: SkillSessionState): number {
  for (let i: number = 0; i < session.cards.length; i++) {
    if (session.cards[i].id === session.activeCardId) {
      return i;
    }
  }
  return 0;
}

function missingRequiredSkillFields(session: SkillSessionState): string[] {
  let missing: string[] = [];
  for (let i: number = 0; i < session.skillSpec.inputFields.length; i++) {
    let field: SkillFieldSpec = session.skillSpec.inputFields[i];
    if (field.required && skillInputValue(session, field.id).trim().length === 0) {
      missing.push(field.label);
    }
  }
  return missing;
}

function skillInputValue(session: SkillSessionState, fieldId: string): string {
  if (!Array.isArray(session.fieldValues)) {
    return '';
  }
  for (let i: number = 0; i < session.fieldValues.length; i++) {
    if (session.fieldValues[i].id === fieldId) {
      return session.fieldValues[i].value;
    }
  }
  return '';
}

export function applyWhitelistedTravelTool(session: SkillSessionState, toolName: string): SkillSessionState {
  let next: SkillSessionState = cloneSession(session);
  if (TRAVEL_TOOL_NAMES.indexOf(toolName) < 0) {
    let rejected: ToolResult = runTravelTool(toolName, next.inputs);
    replaceToolResult(next, rejected);
    next.status = 'error';
    next.errorMessage = rejected.summary + '\n' + rejected.details.join('\n');
    next.nextAction = '拒绝未知工具调用';
    return touch(next);
  }
  runAndApplyTool(next, toolName);
  return touch(next);
}

function runNextTravelStep(session: SkillSessionState): void {
  let toolName: string = 'travel.suggestTransport';
  if (hasTool(session, 'travel.suggestTransport')) {
    toolName = 'travel.suggestLodging';
  }
  if (hasTool(session, 'travel.suggestLodging')) {
    toolName = 'travel.planDailyItinerary';
  }
  if (hasTool(session, 'travel.planDailyItinerary')) {
    toolName = 'travel.estimateBudget';
  }
  if (hasTool(session, 'travel.estimateBudget')) {
    toolName = 'travel.generateChecklist';
  }
  if (hasTool(session, 'travel.generateChecklist')) {
    toolName = 'travel.finalizePlan';
  }
  runAndApplyTool(session, toolName);
}

function runAndApplyTool(session: SkillSessionState, toolName: string): void {
  let result: ToolResult = runTravelTool(toolName, session.inputs);
  replaceToolResult(session, result);
  if (toolName === 'travel.suggestTransport') {
    applyCard(session, 'transport_card', result, 25);
  } else if (toolName === 'travel.suggestLodging') {
    applyCard(session, 'lodging_card', result, 40);
  } else if (toolName === 'travel.planDailyItinerary') {
    applyCard(session, 'itinerary_card', result, 58);
  } else if (toolName === 'travel.estimateBudget') {
    applyCard(session, 'budget_card', result, 72);
  } else if (toolName === 'travel.generateChecklist') {
    applyCard(session, 'checklist_card', result, 86);
  } else {
    session.finalPlan = buildFinalPlan(session);
    applyCard(session, 'final_plan_card', { toolName: toolName, summary: '最终方案', details: [session.finalPlan] }, 100);
    session.status = 'complete';
  }
}

function applyCard(session: SkillSessionState, cardId: string, result: ToolResult, progress: number): void {
  session.activeCardId = cardId;
  session.progress = progress;
  session.nextAction = progress >= 100 ? '可加到桌面' : '执行下一步';
  for (let i = 0; i < session.cards.length; i++) {
    if (session.cards[i].id === cardId) {
      session.cards[i].body = result.summary + '\n' + result.details.join('\n');
      session.cards[i].status = 'done';
    }
    if (session.cards[i].id === 'plan_progress') {
      session.cards[i].body = '进度 ' + progress.toString() + '%\n' + result.summary;
    }
  }
}

export function buildFinalPlan(session: SkillSessionState): string {
  let lines: string[] = [
    session.inputs.departure + ' -> ' + session.inputs.destination,
    session.inputs.startDate + ' 至 ' + session.inputs.endDate,
    '人数：成人 ' + session.inputs.adults + '，儿童 ' + session.inputs.children,
    '预算：' + session.inputs.budget,
    '偏好：' + session.inputs.preferences
  ];
  for (let i = 0; i < session.toolResults.length; i++) {
    lines.push(session.toolResults[i].summary);
    lines = lines.concat(session.toolResults[i].details);
  }
  return lines.join('\n');
}

export function skillSessionToCardPreview(session: SkillSessionState): CardPreviewModel {
  return {
    title: session.skillSpec.skillName,
    subtitle: session.status === 'complete' ? '旅行方案已生成' : '当前步骤：' + activeCardTitle(session),
    body: session.status === 'complete' ? briefFinalPlan(session) : session.nextAction,
    itemsText: '进度 ' + session.progress.toString() + '%\n' + session.inputs.departure + ' -> ' + session.inputs.destination,
    updatedAt: session.updatedAt
  };
}

export function activeCardTitle(session: SkillSessionState): string {
  for (let i = 0; i < session.cards.length; i++) {
    if (session.cards[i].id === session.activeCardId) {
      return session.cards[i].title;
    }
  }
  return session.skillSpec.skillName;
}

function briefFinalPlan(session: SkillSessionState): string {
  if (session.finalPlan.length === 0) {
    return '打开 App 继续执行 Agent Skill。';
  }
  let lines: string[] = session.finalPlan.split('\n');
  return lines.length > 0 ? lines[0] : session.finalPlan;
}

export async function saveSkillSession(context: common.Context, session: SkillSessionState): Promise<void> {
  let store: preferences.Preferences = preferences.getPreferencesSync(context, { name: STORE_NAME });
  store.putSync(LATEST_SESSION_KEY, JSON.stringify(session));
  await store.flush();
}

export function readSkillSession(context: common.Context): SkillSessionState {
  let store: preferences.Preferences = preferences.getPreferencesSync(context, { name: STORE_NAME });
  let raw: preferences.ValueType = store.getSync(LATEST_SESSION_KEY, '');
  if (typeof raw === 'string' && raw.length > 0) {
    try {
      return JSON.parse(raw) as SkillSessionState;
    } catch (e) {
    }
  }
  return createSkillSession(defaultTravelSkillSpec());
}

export async function pickImageAsDataUrl(): Promise<string> {
  let picker: photoAccessHelper.PhotoViewPicker = new photoAccessHelper.PhotoViewPicker();
  let result: photoAccessHelper.PhotoSelectResult = await picker.select({
    MIMEType: photoAccessHelper.PhotoViewMIMETypes.IMAGE_TYPE,
    maxSelectNumber: 1
  });
  if (result.photoUris.length === 0) {
    throw new Error('未选择图片');
  }
  return readUriAsDataUrl(result.photoUris[0]);
}

export async function pickFileSystemImageAsDataUrl(context: common.UIAbilityContext): Promise<string> {
  let options: picker.DocumentSelectOptions = new picker.DocumentSelectOptions();
  options.maxSelectNumber = 1;
  options.fileSuffixFilters = ['.png', '.jpg', '.jpeg', '.webp'];
  let documentPicker: picker.DocumentViewPicker = new picker.DocumentViewPicker(context);
  let uris: string[] = await documentPicker.select(options);
  if (uris.length === 0) {
    throw new Error('未选择文件系统图片');
  }
  return readUriAsDataUrl(uris[0]);
}

export async function pickSkillMarkdownFile(context: common.UIAbilityContext): Promise<SkillMarkdownFile> {
  let options: picker.DocumentSelectOptions = new picker.DocumentSelectOptions();
  options.maxSelectNumber = 1;
  options.fileSuffixFilters = ['.md'];
  let documentPicker: picker.DocumentViewPicker = new picker.DocumentViewPicker(context);
  let uris: string[] = await documentPicker.select(options);
  if (uris.length === 0) {
    throw new Error('未选择 skill.md 文件');
  }
  let uri: string = uris[0];
  let nameStart: number = uri.lastIndexOf('/');
  let displayName: string = nameStart >= 0 ? uri.substring(nameStart + 1) : 'skill.md';
  return {
    displayName: displayName,
    content: readUriAsUtf8Text(uri)
  };
}

function readUriAsUtf8Text(uri: string): string {
  let file: fileIo.File = fileIo.openSync(uri, fileIo.OpenMode.READ_ONLY);
  try {
    let stat: fileIo.Stat = fileIo.statSync(file.fd);
    if (stat.size <= 0) {
      throw new Error('skill.md 文件为空');
    }
    if (stat.size > 1024 * 1024) {
      throw new Error('skill.md 不能超过 1 MB');
    }
    let buffer: ArrayBuffer = new ArrayBuffer(stat.size);
    let readLen: number = fileIo.readSync(file.fd, buffer);
    let bytes: Uint8Array = new Uint8Array(buffer, 0, readLen);
    let decoder: util.TextDecoder = util.TextDecoder.create('utf-8', { fatal: false, ignoreBOM: true });
    return decoder.decodeToString(bytes).trim();
  } finally {
    fileIo.closeSync(file);
  }
}

function readUriAsDataUrl(uri: string): string {
  let file: fileIo.File = fileIo.openSync(uri, fileIo.OpenMode.READ_ONLY);
  try {
    let stat: fileIo.Stat = fileIo.statSync(file.fd);
    if (stat.size > 10 * 1024 * 1024) {
      throw new Error('图片不能超过 10 MB');
    }
    let buffer: ArrayBuffer = new ArrayBuffer(stat.size);
    let readLen: number = fileIo.readSync(file.fd, buffer);
    let bytes: Uint8Array = new Uint8Array(buffer, 0, readLen);
    let base64Helper: util.Base64Helper = new util.Base64Helper();
    return 'data:' + detectImageMime(bytes) + ';base64,' + base64Helper.encodeToStringSync(bytes, util.Type.BASIC);
  } finally {
    fileIo.closeSync(file);
  }
}

function detectImageMime(bytes: Uint8Array): string {
  if (bytes.length >= 4 && bytes[0] === 0x89 && bytes[1] === 0x50 && bytes[2] === 0x4E && bytes[3] === 0x47) {
    return 'image/png';
  }
  if (bytes.length >= 3 && bytes[0] === 0xFF && bytes[1] === 0xD8 && bytes[2] === 0xFF) {
    return 'image/jpeg';
  }
  if (bytes.length >= 12 && bytes[0] === 0x52 && bytes[1] === 0x49 && bytes[2] === 0x46 && bytes[3] === 0x46 &&
    bytes[8] === 0x57 && bytes[9] === 0x45 && bytes[10] === 0x42 && bytes[11] === 0x50) {
    return 'image/webp';
  }
  throw new Error('仅支持 PNG、JPEG 或 WebP 图片');
}

function cloneSession(session: SkillSessionState): SkillSessionState {
  return JSON.parse(JSON.stringify(session)) as SkillSessionState;
}

function touch(session: SkillSessionState): SkillSessionState {
  session.updatedAt = new Date().toLocaleString();
  return session;
}

function moveBack(session: SkillSessionState): void {
  if (session.activeCardId === 'input_dates_people_budget') {
    session.activeCardId = 'input_departure_destination';
  } else if (session.activeCardId === 'input_preferences_lodging_transport') {
    session.activeCardId = 'input_dates_people_budget';
  } else {
    session.activeCardId = 'input_departure_destination';
  }
  session.nextAction = '继续填写旅行参数';
}

function replaceToolResult(session: SkillSessionState, result: ToolResult): void {
  let replaced: boolean = false;
  for (let i = 0; i < session.toolResults.length; i++) {
    if (session.toolResults[i].toolName === result.toolName) {
      session.toolResults[i] = result;
      replaced = true;
    }
  }
  if (!replaced) {
    session.toolResults.push(result);
  }
}

function hasTool(session: SkillSessionState, toolName: string): boolean {
  for (let i = 0; i < session.toolResults.length; i++) {
    if (session.toolResults[i].toolName === toolName) {
      return true;
    }
  }
  return false;
}
