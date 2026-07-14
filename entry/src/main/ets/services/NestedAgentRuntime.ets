import { NestedAction, NestedNode, NestedSessionState } from './NestedAppTypes';
import { reduceNestedAction } from './NestedAppService';
import {
  RuntimeAgentTurnRequest,
  RuntimeAgentTurnResult,
  RuntimeSession,
  RuntimeStatePatch,
  RuntimeToolCall,
  RuntimeToolResult,
  RuntimeUiPatch,
  SkillManifest,
  ToolContract
} from './SkillAppTypes';
import { runTravelTool } from './SkillWorkbench';
import { ToolResult, TravelInputs } from './SkillTypes';

const STATE_PATCHES: string[] = ['setData', 'updateStatus'];
const UI_PATCHES: string[] = ['setVisibility', 'setEnabled', 'replaceItems', 'appendItems',
  'setSuggestedActions', 'mountDynamicView', 'dismissDynamicView'];
const STATUSES: string[] = ['idle', 'thinking', 'toolRunning', 'waitingUser', 'complete', 'error'];

export function createRuntimeSession(appId: string): RuntimeSession {
  return {
    sessionId: 'runtime-' + Date.now().toString(),
    appId: appId,
    currentPageId: '',
    routeStack: [],
    data: {},
    toolResults: [],
    conversationSummary: '',
    suggestedActions: [],
    status: 'idle',
    updatedAt: Date.now()
  };
}

export function buildRuntimeAgentTurnRequest(session: NestedSessionState, current: NestedAction,
  manifest: SkillManifest): RuntimeAgentTurnRequest {
  return {
    turnId: 'turn-' + Date.now().toString(),
    appId: session.app.appId,
    skillId: manifest.skillId,
    currentPageId: session.activePageId,
    actionId: current.id,
    actionPayload: current.payload,
    state: cloneStringRecord(session.data),
    availableTools: implementedTools(manifest.toolContracts),
    dynamicSlotIds: collectDynamicSlotIds(session),
    toolResults: []
  };
}

export function normalizeRuntimeAgentTurnResult(raw: string): RuntimeAgentTurnResult {
  try {
    let parsed: RuntimeAgentTurnResult = JSON.parse(cleanJson(raw)) as RuntimeAgentTurnResult;
    if (isValidTurnResult(parsed)) {
      return sanitizeTurnResult(parsed);
    }
  } catch (e) {
  }
  return errorTurn('GLM 返回的 RuntimeAgentTurnResult 不合法。');
}

export function applyRuntimeAgentTurn(session: NestedSessionState, result: RuntimeAgentTurnResult,
  manifest: SkillManifest): NestedSessionState {
  let next: NestedSessionState = cloneNestedSession(session);
  next.errorMessage = '';
  applyStatePatches(next, result.statePatches);
  let toolResults: RuntimeToolResult[] = executeToolCalls(next, result.toolCalls, manifest);
  if (toolResults.length > 0) {
    next.data['toolResults'] = summarizeToolResults(toolResults);
  }
  applyUiPatches(next, result.uiPatches);
  if (result.assistantText.length > 0) {
    next.data['agentSummary'] = result.assistantText;
  }
  if (result.suggestedActions.length > 0) {
    next.data['suggestedActions'] = result.suggestedActions.join('、');
  }
  if (result.navigationPageId.length > 0) {
    let action: NestedAction = {
      id: 'agent-navigation',
      label: 'Agent navigation',
      kind: 'navigate',
      targetPageId: result.navigationPageId,
      payload: '',
      handling: 'local'
    };
    next = reduceNestedAction(next, action);
  }
  next.status = result.status;
  next.agentTrace = result.assistantText.length > 0 ? result.assistantText : 'Agent Turn 已完成。';
  if (result.status === 'error') {
    next.errorMessage = result.errorMessage.length > 0 ? result.errorMessage : 'Agent Turn 执行失败。';
  }
  return next;
}

export function runtimeToolResultsForNextTurn(session: NestedSessionState): RuntimeToolResult[] {
  // TODO(MVP-next): Persist structured ToolResult values and make the second GLM call in the same turn.
  let value: string = session.data['toolResults'];
  if (value === undefined || value.length === 0) {
    return [];
  }
  return [{ toolName: 'mvp.summary', callId: 'mvp-summary', success: true, summary: value, details: [] }];
}

function executeToolCalls(session: NestedSessionState, calls: RuntimeToolCall[], manifest: SkillManifest): RuntimeToolResult[] {
  let results: RuntimeToolResult[] = [];
  for (let i = 0; i < calls.length; i++) {
    let current: RuntimeToolCall = calls[i];
    let contract: ToolContract | undefined = findTool(manifest.toolContracts, current.toolName);
    if (contract === undefined || !contract.implemented) {
      results.push({
        toolName: current.toolName,
        callId: current.callId,
        success: false,
        summary: '已拒绝未知或未实现的工具',
        details: ['工具必须由平台注册并标记为 implemented。']
      });
    } else if (current.toolName.indexOf('travel.') === 0) {
      let local: ToolResult = runTravelTool(current.toolName, travelInputs(session.data));
      results.push({
        toolName: local.toolName,
        callId: current.callId,
        success: true,
        summary: local.summary,
        details: local.details
      });
    } else {
      // TODO(MVP-next): Route weather.* through SeniverseWeatherAdapter with CredentialVault injection.
      results.push({
        toolName: current.toolName,
        callId: current.callId,
        success: false,
        summary: '工具适配器尚未接入',
        details: ['当前 MVP 骨架只执行本地 travel.* 工具。']
      });
    }
  }
  return results;
}

function applyStatePatches(session: NestedSessionState, patches: RuntimeStatePatch[]): void {
  for (let i = 0; i < patches.length; i++) {
    let patch: RuntimeStatePatch = patches[i];
    if (patch.op === 'setData' && patch.key.length > 0) {
      session.data[patch.key] = patch.value;
    } else if (patch.op === 'updateStatus') {
      session.status = patch.value;
    }
  }
}

function applyUiPatches(session: NestedSessionState, patches: RuntimeUiPatch[]): void {
  for (let i = 0; i < patches.length; i++) {
    let patch: RuntimeUiPatch = patches[i];
    if (patch.op === 'setSuggestedActions') {
      session.data['suggestedActions'] = patch.items.join('、');
    } else if (patch.op === 'mountDynamicView') {
      // TODO(MVP-next): Mount a validated temporary page through DynamicViewHost.
      session.data['dynamicSlot'] = patch.value;
    } else if (patch.op === 'dismissDynamicView') {
      session.data['dynamicSlot'] = '';
    }
  }
}

function sanitizeTurnResult(result: RuntimeAgentTurnResult): RuntimeAgentTurnResult {
  let statePatches: RuntimeStatePatch[] = [];
  for (let i = 0; i < result.statePatches.length; i++) {
    if (STATE_PATCHES.indexOf(result.statePatches[i].op) >= 0) {
      statePatches.push(result.statePatches[i]);
    }
  }
  let uiPatches: RuntimeUiPatch[] = [];
  for (let i = 0; i < result.uiPatches.length; i++) {
    if (UI_PATCHES.indexOf(result.uiPatches[i].op) >= 0) {
      uiPatches.push(result.uiPatches[i]);
    }
  }
  return {
    turnId: result.turnId,
    assistantText: result.assistantText,
    toolCalls: result.toolCalls,
    statePatches: statePatches,
    uiPatches: uiPatches,
    navigationPageId: result.navigationPageId,
    suggestedActions: result.suggestedActions.slice(0, 4),
    status: result.status,
    errorMessage: result.errorMessage
  };
}

function isValidTurnResult(result: RuntimeAgentTurnResult): boolean {
  return result !== undefined && result !== null && typeof result.turnId === 'string' &&
    typeof result.assistantText === 'string' && Array.isArray(result.toolCalls) &&
    Array.isArray(result.statePatches) && Array.isArray(result.uiPatches) &&
    typeof result.navigationPageId === 'string' && Array.isArray(result.suggestedActions) &&
    typeof result.status === 'string' && STATUSES.indexOf(result.status) >= 0 &&
    typeof result.errorMessage === 'string';
}

function errorTurn(message: string): RuntimeAgentTurnResult {
  return {
    turnId: 'invalid-turn',
    assistantText: '',
    toolCalls: [],
    statePatches: [],
    uiPatches: [],
    navigationPageId: '',
    suggestedActions: ['重试', '返回'],
    status: 'error',
    errorMessage: message
  };
}

function collectDynamicSlotIds(session: NestedSessionState): string[] {
  let ids: string[] = [];
  for (let i = 0; i < session.app.pages.length; i++) {
    collectDynamicSlots(session.app.pages[i].root, ids);
  }
  return ids;
}

function collectDynamicSlots(node: NestedNode, ids: string[]): void {
  if (node.type === 'DynamicSlot') { ids.push(node.id); }
  for (let i: number = 0; i < node.children.length; i++) { collectDynamicSlots(node.children[i], ids); }
}

function implementedTools(tools: ToolContract[]): ToolContract[] {
  let result: ToolContract[] = [];
  for (let i = 0; i < tools.length; i++) {
    if (tools[i].implemented) {
      result.push(tools[i]);
    }
  }
  return result;
}

function findTool(tools: ToolContract[], name: string): ToolContract | undefined {
  for (let i = 0; i < tools.length; i++) {
    if (tools[i].name === name) {
      return tools[i];
    }
  }
  return undefined;
}

function travelInputs(data: Record<string, string>): TravelInputs {
  return {
    departure: value(data, 'departure'),
    destination: value(data, 'destination'),
    startDate: value(data, 'startDate').length > 0 ? value(data, 'startDate') : value(data, 'dates'),
    endDate: value(data, 'endDate').length > 0 ? value(data, 'endDate') : value(data, 'dates'),
    adults: value(data, 'adults').length > 0 ? value(data, 'adults') : '2',
    children: value(data, 'children').length > 0 ? value(data, 'children') : '0',
    budget: value(data, 'budget'),
    preferences: value(data, 'preferences'),
    lodging: value(data, 'lodging'),
    transport: value(data, 'transport')
  };
}

function value(data: Record<string, string>, key: string): string {
  let result: string | undefined = data[key];
  return result === undefined ? '' : result;
}

function summarizeToolResults(results: RuntimeToolResult[]): string {
  let summaries: string[] = [];
  for (let i = 0; i < results.length; i++) {
    summaries.push(results[i].summary + (results[i].details.length > 0 ? '：' + results[i].details.join('；') : ''));
  }
  return summaries.join('\n');
}

function cleanJson(raw: string): string {
  return raw.replace('```json', '').replace('```', '').trim();
}

function cloneNestedSession(session: NestedSessionState): NestedSessionState {
  return JSON.parse(JSON.stringify(session)) as NestedSessionState;
}

function cloneStringRecord(data: Record<string, string>): Record<string, string> {
  return JSON.parse(JSON.stringify(data)) as Record<string, string>;
}
