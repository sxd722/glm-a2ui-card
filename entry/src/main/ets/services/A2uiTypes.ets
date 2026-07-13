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
  temperature: number;
  stream: boolean;
}

export interface GlmChoice {
  message: GlmMessage;
}

export interface GlmChatResponse {
  choices: GlmChoice[];
}
