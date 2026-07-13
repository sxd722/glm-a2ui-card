export type SkillSessionStatus = 'idle' | 'collecting' | 'running' | 'complete' | 'error';

export interface SkillFieldSpec {
  id: string;
  label: string;
  placeholder: string;
  required: boolean;
}

export interface SkillSpec {
  skillName: string;
  skillId: string;
  goal: string;
  scenarios: string[];
  inputFields: SkillFieldSpec[];
  flow: string[];
  outputs: string[];
  rules: string[];
  actions: string[];
  examplePrompt: string;
}

export interface SkillCardAction {
  id: string;
  label: string;
}

export interface SkillCard {
  id: string;
  kind: string;
  title: string;
  subtitle: string;
  body: string;
  fields: string[];
  actions: SkillCardAction[];
  status: string;
}

export interface TravelInputs {
  departure: string;
  destination: string;
  startDate: string;
  endDate: string;
  adults: string;
  children: string;
  budget: string;
  preferences: string;
  lodging: string;
  transport: string;
}

export interface ToolResult {
  toolName: string;
  summary: string;
  details: string[];
}

export interface SkillSessionState {
  sessionId: string;
  skillSpec: SkillSpec;
  cards: SkillCard[];
  activeCardId: string;
  inputs: TravelInputs;
  toolResults: ToolResult[];
  finalPlan: string;
  progress: number;
  status: SkillSessionStatus;
  nextAction: string;
  updatedAt: string;
  errorMessage: string;
}

export interface AgentToolCall {
  toolName: string;
  argsJson: string;
  callId: string;
}

export interface AgentTurnRequest {
  actionId: string;
  session: SkillSessionState;
  availableTools: string[];
}

export interface AgentTurnResult {
  assistantText: string;
  toolCalls: AgentToolCall[];
  cardPatchesJson: string;
  activeCardId: string;
  status: SkillSessionStatus;
}
