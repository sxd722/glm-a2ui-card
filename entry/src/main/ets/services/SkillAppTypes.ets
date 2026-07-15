import { ArkUiSpec, LocalImageAsset } from './ArkUiTypes';

export type SkillSourceKind = 'image' | 'file' | 'repository' | 'text';
export type ForgeDraftStatus = 'import' | 'analyzed' | 'configured' | 'preview' | 'installed' | 'error';
export type RuntimeStatus = 'idle' | 'thinking' | 'toolRunning' | 'waitingUser' | 'complete' | 'error';
export type RuntimePatchOperation = 'setData' | 'updateStatus';
export type RuntimeUiPatchOperation = 'setVisibility' | 'setEnabled' | 'replaceItems' | 'appendItems' |
  'setSuggestedActions' | 'mountDynamicView' | 'dismissDynamicView';

export interface SkillSource {
  id: string;
  kind: SkillSourceKind;
  displayName: string;
  uri: string;
  textContent: string;
  localAssetIds: string[];
  importedAt: number;
}

export interface SkillInputField {
  id: string;
  label: string;
  kind: string;
  required: boolean;
  options: string[];
}

export interface ToolContract {
  name: string;
  description: string;
  adapterId: string;
  inputFields: string[];
  outputFields: string[];
  allowedOrigins: string[];
  credentialRef: string;
  confirmation: string;
  implemented: boolean;
}

export interface SkillManifest {
  schemaVersion: string;
  skillId: string;
  skillName: string;
  version: string;
  description: string;
  goals: string[];
  inputFields: SkillInputField[];
  outputFields: string[];
  workflow: string[];
  decisionPoints: string[];
  toolContracts: ToolContract[];
  permissions: string[];
  constraints: string[];
  examples: string[];
}

export interface DynamicSlotPolicy {
  id: string;
  pageId: string;
  allowedNodeKinds: string[];
  maxInstances: number;
}

export interface ComponentRecipe {
  id: string;
  description: string;
  rootNodeKind: string;
  fallbackNodeKind: string;
}

export interface AppPagePlan {
  id: string;
  title: string;
  purpose: string;
  primaryAction: string;
}

export interface AppBlueprint {
  schemaVersion: string;
  appId: string;
  skillId: string;
  title: string;
  summary: string;
  homePattern: string;
  palette: string[];
  runtimePrompt: string;
  dynamicSlots: DynamicSlotPolicy[];
  componentRecipes: ComponentRecipe[];
  pages: AppPagePlan[];
}

export interface AppBlueprintParseResult {
  ok: boolean;
  value: AppBlueprint | undefined;
  diagnostics: string[];
  repairedFields: string[];
}

export interface RunnerLaunchParams {
  appId: string;
  sessionId: string;
}

export interface RunnerSessionSnapshot {
  sessionId: string;
  appId: string;
  activePageId: string;
  routeStack: string[];
  data: Record<string, string>;
  assets: LocalImageAsset[];
  status: string;
  agentTrace: string;
  errorMessage: string;
  updatedAt: number;
}

export interface ForgeDraft {
  draftId: string;
  source: SkillSource;
  manifest: SkillManifest;
  blueprint: AppBlueprint;
  uiSpec: ArkUiSpec;
  status: ForgeDraftStatus;
  trace: string;
  errorMessage: string;
  updatedAt: number;
}

export interface InstalledSkillApp {
  appId: string;
  schemaVersion: string;
  skillVersion: string;
  generatedAt: number;
  manifest: SkillManifest;
  blueprint: AppBlueprint;
  uiSpec: ArkUiSpec;
  runtimePrompt: string;
  credentialRefs: string[];
}

export interface RuntimeSession {
  sessionId: string;
  appId: string;
  currentPageId: string;
  routeStack: string[];
  data: Record<string, string>;
  toolResults: RuntimeToolResult[];
  conversationSummary: string;
  suggestedActions: string[];
  status: RuntimeStatus;
  updatedAt: number;
}

export interface RuntimeToolCall {
  toolName: string;
  argsJson: string;
  callId: string;
}

export interface RuntimeToolResult {
  toolName: string;
  callId: string;
  success: boolean;
  summary: string;
  details: string[];
}

export interface RuntimeStatePatch {
  op: RuntimePatchOperation;
  key: string;
  value: string;
}

export interface RuntimeUiPatch {
  op: RuntimeUiPatchOperation;
  targetId: string;
  value: string;
  items: string[];
}

export interface RuntimeAgentTurnRequest {
  turnId: string;
  appId: string;
  skillId: string;
  currentPageId: string;
  actionId: string;
  actionPayload: string;
  state: Record<string, string>;
  availableTools: ToolContract[];
  dynamicSlotIds: string[];
  toolResults: RuntimeToolResult[];
}

export interface RuntimeAgentTurnResult {
  turnId: string;
  assistantText: string;
  toolCalls: RuntimeToolCall[];
  statePatches: RuntimeStatePatch[];
  uiPatches: RuntimeUiPatch[];
  navigationPageId: string;
  suggestedActions: string[];
  status: RuntimeStatus;
  errorMessage: string;
}
