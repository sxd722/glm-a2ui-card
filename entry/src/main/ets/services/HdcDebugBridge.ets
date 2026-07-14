import { Want } from '@kit.AbilityKit';
import { util } from '@kit.ArkTS';

export const HDC_DEBUG_EVENT: string = 'HdcDebugCommandAvailable';
const MAX_PAYLOAD_LENGTH: number = 64 * 1024;
const MAX_QUEUE_LENGTH: number = 16;
const MAX_RESULT_LENGTH: number = 10;

export type HdcDebugAction = 'setForgeSource' | 'runForgeAnalyze' | 'runForgePreview' |
  'installForgePreview' | 'runForgePipeline' | 'setSkillFields' | 'runSkillAction' |
  'setNestedFields' | 'runNestedAction' | 'loadForgeImageFromDevice' | 'loadForgeImageDataUrl' |
  'resetForgeImageTransfer' | 'appendForgeImageChunk' | 'finishForgeImageTransfer' |
  'loadTravelDemo' | 'resetWorkbench';

export interface HdcDebugCommand {
  requestId: string;
  action: HdcDebugAction;
  payload: string;
  enqueuedAt: number;
}

export interface HdcDebugSnapshot {
  workspaceMode: string;
  nestedFlow: string;
  forgeStage: string;
  skillId: string;
  activeSkillCardId: string;
  nestedAppId: string;
  activePageId: string;
  skillProgress: number;
  statusText: string;
  errorMessage: string;
  manifestLength: number;
  blueprintLength: number;
  dslLength: number;
}

export interface HdcDebugResult {
  requestId: string;
  action: HdcDebugAction;
  status: 'queued' | 'running' | 'succeeded' | 'failed';
  message: string;
  startedAt: number;
  finishedAt: number;
  snapshot: HdcDebugSnapshot;
}

export interface HdcDebugIngestResult {
  command: HdcDebugCommand | undefined;
  error: string;
  requestId: string;
}

const EMPTY_SNAPSHOT: HdcDebugSnapshot = {
  workspaceMode: '',
  nestedFlow: '',
  forgeStage: '',
  skillId: '',
  activeSkillCardId: '',
  nestedAppId: '',
  activePageId: '',
  skillProgress: 0,
  statusText: '',
  errorMessage: '',
  manifestLength: 0,
  blueprintLength: 0,
  dslLength: 0
};

let pendingCommands: HdcDebugCommand[] = [];
let results: HdcDebugResult[] = [];
let seenRequestIds: string[] = [];

export function ingestHdcDebugWant(want: Want): HdcDebugIngestResult {
  let requestId: string = readString(want.parameters, 'debugRequestId');
  if (requestId.length === 0) {
    requestId = 'hdc-' + Date.now().toString();
  }
  if (requestId.length > 80) {
    return { command: undefined, error: 'debugRequestId exceeds 80 characters', requestId: requestId };
  }
  let actionName: string = readString(want.parameters, 'debugAction');
  if (!isHdcDebugAction(actionName)) {
    return { command: undefined, error: 'unknown debugAction: ' + actionName, requestId: requestId };
  }
  let plainPayload: string = readString(want.parameters, 'debugPayload');
  let encodedPayload: string = readString(want.parameters, 'debugPayloadBase64');
  if (plainPayload.length > 0 && encodedPayload.length > 0) {
    return { command: undefined, error: 'debugPayload and debugPayloadBase64 are mutually exclusive', requestId: requestId };
  }
  let payload: string = plainPayload;
  if (encodedPayload.length > 0) {
    try {
      payload = decodeBase64(encodedPayload);
    } catch (error) {
      return { command: undefined, error: 'invalid debugPayloadBase64', requestId: requestId };
    }
  }
  if (payload.length > MAX_PAYLOAD_LENGTH) {
    return { command: undefined, error: 'debug payload exceeds 64 KB', requestId: requestId };
  }
  return {
    command: {
      requestId: requestId,
      action: actionName as HdcDebugAction,
      payload: payload,
      enqueuedAt: Date.now()
    },
    error: '',
    requestId: requestId
  };
}

export function enqueueHdcDebugCommand(command: HdcDebugCommand): boolean {
  if (seenRequestIds.indexOf(command.requestId) >= 0) {
    return false;
  }
  if (pendingCommands.length >= MAX_QUEUE_LENGTH) {
    return false;
  }
  seenRequestIds.push(command.requestId);
  pendingCommands.push(command);
  return true;
}

export function takeNextHdcDebugCommand(): HdcDebugCommand | undefined {
  if (pendingCommands.length === 0) {
    return undefined;
  }
  return pendingCommands.shift();
}

export function recordHdcDebugResult(result: HdcDebugResult): void {
  results.push(result);
  if (results.length > MAX_RESULT_LENGTH) {
    results.shift();
  }
}

export function latestHdcDebugResult(): HdcDebugResult | undefined {
  if (results.length === 0) {
    return undefined;
  }
  return results[results.length - 1];
}

export function hdcDebugDumpLines(): string[] {
  let lines: string[] = ['HDC_DEBUG_BRIDGE queue=' + pendingCommands.length.toString() +
    ' results=' + results.length.toString()];
  for (let i: number = 0; i < results.length; i++) {
    lines.push('HDC_DEBUG_RESULT ' + JSON.stringify(results[i]));
  }
  return lines;
}

export function queuedHdcDebugResult(command: HdcDebugCommand): HdcDebugResult {
  return {
    requestId: command.requestId,
    action: command.action,
    status: 'queued',
    message: 'command queued',
    startedAt: 0,
    finishedAt: 0,
    snapshot: EMPTY_SNAPSHOT
  };
}

export function runningHdcDebugResult(command: HdcDebugCommand, snapshot: HdcDebugSnapshot): HdcDebugResult {
  return {
    requestId: command.requestId,
    action: command.action,
    status: 'running',
    message: 'command running',
    startedAt: Date.now(),
    finishedAt: 0,
    snapshot: snapshot
  };
}

function readString(parameters: Record<string, Object> | undefined, key: string): string {
  if (parameters === undefined) {
    return '';
  }
  let value: Object | undefined = parameters[key];
  if (value === undefined || typeof value !== 'string') {
    return '';
  }
  return value as string;
}

function decodeBase64(value: string): string {
  let helper: util.Base64Helper = new util.Base64Helper();
  let bytes: Uint8Array = helper.decodeSync(value, util.Type.BASIC);
  let decoder: util.TextDecoder = util.TextDecoder.create('utf-8', { fatal: false, ignoreBOM: true });
  return decoder.decodeToString(bytes);
}

function isHdcDebugAction(value: string): boolean {
  return value === 'setForgeSource' || value === 'runForgeAnalyze' || value === 'runForgePreview' ||
    value === 'installForgePreview' || value === 'runForgePipeline' || value === 'setSkillFields' ||
    value === 'runSkillAction' || value === 'setNestedFields' || value === 'runNestedAction' ||
    value === 'loadForgeImageFromDevice' || value === 'loadForgeImageDataUrl' ||
    value === 'resetForgeImageTransfer' || value === 'appendForgeImageChunk' ||
    value === 'finishForgeImageTransfer' || value === 'loadTravelDemo' || value === 'resetWorkbench';
}
