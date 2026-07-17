export interface CardPreviewModel {
  title: string;
  subtitle: string;
  body: string;
  itemsText: string;
  updatedAt: string;
}

export interface FormCardData {
  title: string;
  subtitle: string;
  body: string;
  itemsText: string;
  updatedAt: string;
}

export interface GlmLocalConfig {
  baseUrl: string;
  apiKey: string;
  model: string;
}

export interface GlmMessage {
  role: string;
  content: string | GlmContentPart[];
}

export interface GlmContentPartImageUrl {
  url: string;
}

export interface GlmContentPart {
  type: string;
  text?: string;
  image_url?: GlmContentPartImageUrl;
}

export interface GlmChatPayload {
  model: string;
  messages: GlmMessage[];
  stream: boolean;
  temperature?: number;
  do_sample?: boolean;
  max_tokens?: number;
  thinking?: GlmThinkingConfig;
  request_id?: string;
}

export interface GlmThinkingConfig {
  type: 'enabled' | 'disabled';
}

export interface GlmPromptTokenDetails {
  cached_tokens: number;
}

export interface GlmUsage {
  prompt_tokens: number;
  completion_tokens: number;
  total_tokens: number;
  prompt_tokens_details?: GlmPromptTokenDetails;
}

export interface GlmCompletionMetrics {
  model: string;
  requestId: string;
  promptTokens: number;
  cachedTokens: number;
  cacheRatio: number;
  completionTokens: number;
  totalTokens: number;
  ttftMs: number;
  totalMs: number;
  sourceCharacters: number;
  sourceLines: number;
  finishReason: string;
  streamed: boolean;
  streamFallback: boolean;
  truncatedRetry: boolean;
  repairCount: number;
}

export interface GlmChoice {
  message: GlmMessage;
}

export interface GlmChatResponse {
  choices: GlmChoice[];
}
