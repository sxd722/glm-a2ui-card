import { http } from '@kit.NetworkKit';
import { GlmChatPayload, GlmChatResponse, GlmCompletionMetrics, GlmContentPart, GlmLocalConfig, GlmMessage } from './A2uiTypes';
import { AgentTurnRequest } from './SkillTypes';
import { AppBlueprint, AppPagePlan, RuntimeAgentTurnRequest, SkillManifest, SkillSource } from './SkillAppTypes';
import { GLM_API_KEY } from '../config/GlmLocalSecrets';
import { buildReactLitePrompt, buildReactLiteRepairPrompt, REACT_LITE_SYSTEM_PROMPT } from './ReactLitePrompt';
import { GlmSseDecoder, GlmSseEvent, sseDeltaContent, sseFinishReason } from './GlmSseDecoder';
import { emptyGlmMetrics, parseGlmCompletionResult } from './ReactLiteGenerationMetrics';

export const GLM_CODING_ENDPOINT: string = 'https://open.bigmodel.cn/api/coding/paas/v4';
export const GLM_GENERAL_ENDPOINT: string = 'https://open.bigmodel.cn/api/paas/v4';
const CHAT_COMPLETIONS_PATH: string = '/chat/completions';
export const GLM_DEFAULT_MODEL: string = 'glm-5.2';
export const GLM_ALTERNATE_MODEL: string = 'glm-5-turbo';
export const GLM_BLUEPRINT_FALLBACK_MODEL: string = 'glm-4.7-flash';
export const GLM_VISION_MODEL: string = 'glm-4.6v-flash';
export const GLM_VISION_FALLBACK_MODEL: string = 'glm-4v-flash';
export const GLM_LOCAL_API_KEY: string = GLM_API_KEY;
export const GLM_REQUEST_TIMEOUT_MS: number = 600000;
export const GLM_VISION_REQUEST_TIMEOUT_MS: number = 120000;
export let LAST_GLM_COMPLETION_METRICS: GlmCompletionMetrics = emptyGlmMetrics(GLM_DEFAULT_MODEL, false, false);

export interface ReactLiteGenerationPolicy {
  model: string;
  thinkingDisabled: boolean;
  doSample: boolean;
  maxTokens: number;
  streaming: boolean;
}

export function reactLiteMaxTokens(blueprint: AppBlueprint): number {
  let value: number = 1800 + blueprint.pages.length * 850 + blueprint.dynamicSlots.length * 160 + blueprint.componentRecipes.length * 80;
  return Math.max(3072, Math.min(8192, value));
}

const SYSTEM_PROMPT: string =
  'You generate A2UI v0.9 JSONL only. Return one createSurface message and one updateDataModel message. ' +
  'The updateDataModel value must include title, subtitle, body, and items string array. No markdown.';

const SKILL_IMAGE_SYSTEM_PROMPT: string =
  'You extract an Agent Skill card image into strict JSON only. No markdown. ' +
  'Return fields: skillName, skillId, goal, scenarios, inputFields, flow, outputs, rules, actions, examplePrompt. ' +
  'inputFields items must be {id,label,placeholder,required}. Use stable camelCase field ids. ' +
  'Do not assume a travel domain or any fixed skillId. Derive a stable uppercase skillId from the actual image.';

const AGENT_TURN_SYSTEM_PROMPT: string =
  'You are a card-state agent orchestrator. Return strict JSON only with fields: assistantText, toolCalls, cardPatchesJson, activeCardId, status. ' +
  'Only request tools from availableTools. toolCalls items must be {toolName,argsJson,callId}.';

const SKILL_MANIFEST_SYSTEM_PROMPT: string =
  'Analyze a user-provided Skill source and return strict SkillManifest JSON only. No markdown or code. ' +
  'Return schemaVersion,skillId,skillName,version,description,goals,inputFields,outputFields,workflow,decisionPoints,toolContracts,permissions,constraints,examples. ' +
  'inputFields items contain id,label,kind,required,options. toolContracts items contain name,description,adapterId,inputFields,outputFields,allowedOrigins,credentialRef,confirmation,implemented. ' +
  'Never include a secret. Mark tools implemented=false unless the source maps to an explicitly registered local adapter.';

const VISUAL_SKILL_MANIFEST_SYSTEM_PROMPT: string = SKILL_MANIFEST_SYSTEM_PROMPT +
  ' The Skill source is an image. Read all visible headings, labels, fields, workflow steps, rules, examples, and agent actions. ' +
  'Infer only what is supported by the image. Preserve the image language. Use stable camelCase input ids and namespaced tool names. ' +
  'Return every required field even when its value is an empty array.';

const APP_BLUEPRINT_TYPESCRIPT_SCHEMA: string =
  'The exact TypeScript interfaces are: ' +
  'interface AppPagePlan { id: string; title: string; purpose: string; primaryAction: string; } ' +
  'interface DynamicSlotPolicy { id: string; pageId: string; allowedNodeKinds: string[]; maxInstances: number; } ' +
  'interface ComponentRecipe { id: string; description: string; rootNodeKind: string; fallbackNodeKind: string; } ' +
  'interface AppBlueprint { schemaVersion: string; appId: string; skillId: string; title: string; summary: string; ' +
  'homePattern: string; palette: string[]; runtimePrompt: string; dynamicSlots: DynamicSlotPolicy[]; ' +
  'componentRecipes: ComponentRecipe[]; pages: AppPagePlan[]; } ';

const APP_BLUEPRINT_SYSTEM_PROMPT: string =
  'Act as a product designer. Return exactly one JSON object matching the following TypeScript interfaces. ' +
  'Do not return markdown, prose, URLs, nestedApp, payload objects, UI node trees, or code. ' +
  APP_BLUEPRINT_TYPESCRIPT_SCHEMA +
  'Every declared property is required. pages must contain 2 to 5 product-level plans. ' +
  'Use stable kebab-case ids, preserve the supplied Skill domain, and keep page purposes concise and domain-specific. ' +
  'Prefer tap choices and suggested actions over keyboard input. Use only local asset ids supplied in the request.';

const ARK_UI_PAGE_SYSTEM_PROMPT: string =
  'Design one native HarmonyOS page and return strict ArkUiPage JSON only. No markdown, JSX, ArkTS, URLs, comments, or arbitrary values. ' +
  'Return id,title,scroll,root. Every node requires id,type,className,props,binding,actions,children. ' +
  'Allowed types: Column,Row,Stack,Scroll,Grid,List,Text,Image,Button,TextInput,TextArea,Toggle,ChoiceChips,SegmentedControl,Progress,Divider,Spacer,Badge,DynamicSlot. ' +
  'Allowed actions: navigate,back,localMutate,invokeTool,invokeAgent,pickLocalImage,reset. Every action requires id,label,kind,targetPageId,payload,handling,effects,guards; localMutate uses effects, invokeTool uses tool. ' +
  'kind is authoritative: localMutate, invokeTool, navigate, back, pickLocalImage, and reset must use handling local; only invokeAgent may use handling agent. ' +
  'For checkbox, tab, choice, counter, filter, visibility, and simple form transitions use localMutate and never invokeAgent. ' +
  'Use invokeTool for a registered deterministic tool with bound args. Use invokeAgent only for reasoning, generation, ambiguity, or unstructured interpretation. ' +
  'localMutate effects use {op,path,value,valueFrom}; allowed ops are set,toggle,increment,append,remove,merge,clear. ' +
  'guards use {path,op,value}; allowed guard ops are exists,eq,neq,truthy,contains,gt,gte,lt,lte. ' +
  'className uses only this Tailwind subset: flex flex-col flex-row flex-1 w-full h-8 h-10 h-12 h-16 h-20 h-24 h-32 ' +
  'p-0 p-1 p-2 p-3 p-4 p-5 p-6 p-8 px-2 px-3 px-4 px-5 py-2 py-3 py-4 pt-2 pr-2 pb-2 pl-2 m-2 mx-2 my-2 mt-2 mr-2 mb-2 ml-2 gap-1 gap-2 gap-3 gap-4 gap-5 gap-6 ' +
  'text-xs text-sm text-base text-lg text-xl text-2xl text-3xl font-medium font-semibold font-bold text-center text-right ' +
  'bg-surface bg-card bg-primary bg-secondary bg-accent bg-white bg-black text-ink text-muted text-white border border-border ' +
  'rounded rounded-md rounded-lg rounded-xl rounded-2xl rounded-3xl rounded-full shadow-sm shadow-md shadow-lg ' +
  'opacity-50 opacity-70 opacity-80 opacity-90 items-center items-end justify-center justify-between justify-end object-contain ' +
  'backdrop-blur-sm backdrop-blur-md bg-gradient-to-r bg-gradient-to-b bg-gradient-to-br from-primary from-secondary to-accent to-secondary. ' +
  'Use props text,placeholder,assetId only. Bind runtime values through binding. Only use supplied page ids, manifest field ids, and local asset ids. ' +
  'Build a polished Morandi translucent interface with strong hierarchy, compact typography, coherent spacing, and at least one clear action.';

const RUNTIME_AGENT_SYSTEM_PROMPT: string =
  'Run one Nested App agent turn. Return one JSON object only. For a UI IR request, the canonical input is a mode=ui-ir action with this shape: ' +
  '{"mode":"ui-ir","action":{"intent":"generateTripPlan","args":{"destination":"京都","selectedDay":"10.19"},"expectedOutputs":["summary"],"outputKinds":{"summary":"string"}}}. ' +
  'Return the compact response shape {"assistantText":"...","state":{"summary":"..."},"status":"complete","errorMessage":""}. ' +
  'state must be an ordinary JSON object, never a tagged UiValue object, and may contain only expectedOutputs. Do not return kind,stringValue,numberValue,booleanValue,arrayValue,objectValue. ' +
  'Do not modify UI IR or navigate unless the supplied Action explicitly handles navigation. Only call availableTools. Use toolCalls only for reasoning-required orchestration; simple UI state is handled locally by the Action DSL. ' +
  'Legacy statePatches and uiPatches are accepted only for the legacy runtime path. Return at most 4 suggestedActions. Never request or expose credentials.';

export async function requestA2uiDslFromGlm(prompt: string, config: GlmLocalConfig): Promise<string> {
  let messages: GlmMessage[] = [
    { role: 'system', content: SYSTEM_PROMPT },
    { role: 'user', content: prompt }
  ];
  return requestChatContent(messages, config, 0.2);
}

export async function requestSkillSpecFromGlmImage(imageDataUrl: string, config: GlmLocalConfig): Promise<string> {
  let parts: GlmContentPart[] = [
    {
      type: 'text',
      text: 'Extract the actual Skill shown in this image as domain-independent SkillSpec JSON. Preserve visible labels and do not substitute a demo Skill.'
    },
    {
      type: 'image_url',
      image_url: {
        url: imageDataUrl
      }
    }
  ];
  let messages: GlmMessage[] = [
    { role: 'system', content: SKILL_IMAGE_SYSTEM_PROMPT },
    { role: 'user', content: parts }
  ];
  return requestChatContent(messages, config, 0.1);
}

export async function requestAgentTurnFromGlm(turn: AgentTurnRequest, config: GlmLocalConfig): Promise<string> {
  let prompt: string = JSON.stringify(turn);
  let messages: GlmMessage[] = [
    { role: 'system', content: AGENT_TURN_SYSTEM_PROMPT },
    { role: 'user', content: prompt }
  ];
  return requestChatContent(messages, config, 0.2);
}

export async function requestSkillManifestFromGlm(source: SkillSource, config: GlmLocalConfig): Promise<string> {
  let sourcePayload: string = JSON.stringify({
    kind: source.kind,
    displayName: source.displayName,
    uri: source.uri,
    textContent: source.textContent,
    localAssetIds: source.localAssetIds
  });
  let messages: GlmMessage[] = [
    { role: 'system', content: SKILL_MANIFEST_SYSTEM_PROMPT },
    { role: 'user', content: sourcePayload }
  ];
  return requestChatContent(messages, config, 0.15);
}

export async function requestSkillManifestFromGlmImage(imageDataUrl: string, localAssetIds: string[],
  config: GlmLocalConfig): Promise<string> {
  let parts: GlmContentPart[] = [
    {
      type: 'image_url',
      image_url: {
        url: imageDataUrl
      }
    },
    {
      type: 'text',
      text: 'Analyze this Skill image and return SkillManifest JSON. Local asset ids: ' + JSON.stringify(localAssetIds)
    }
  ];
  let messages: GlmMessage[] = [
    { role: 'system', content: VISUAL_SKILL_MANIFEST_SYSTEM_PROMPT },
    { role: 'user', content: parts }
  ];
  return requestChatContent(messages, config, 0.1, GLM_VISION_REQUEST_TIMEOUT_MS);
}

export async function requestAppBlueprintFromGlm(manifest: SkillManifest, localAssetIds: string[],
  config: GlmLocalConfig): Promise<string> {
  let manifestPayload: AppBlueprintRequest = {
    manifest: manifest,
    localAssetIds: localAssetIds
  };
  let messages: GlmMessage[] = [
    { role: 'system', content: APP_BLUEPRINT_SYSTEM_PROMPT },
    { role: 'user', content: JSON.stringify(manifestPayload) }
  ];
  return requestChatContent(messages, config, 0.4, GLM_REQUEST_TIMEOUT_MS);
}

export async function requestArkUiPageFromGlm(manifest: SkillManifest, blueprint: AppBlueprint,
  pagePlan: AppPagePlan, localAssetIds: string[], config: GlmLocalConfig): Promise<string> {
  let request: ArkUiPageRequest = { manifest: manifest, blueprint: blueprint, pagePlan: pagePlan,
    localAssetIds: localAssetIds, allowedPageIds: pageIds(blueprint) };
  let messages: GlmMessage[] = [
    { role: 'system', content: ARK_UI_PAGE_SYSTEM_PROMPT },
    { role: 'user', content: JSON.stringify(request) }
  ];
  return requestChatContent(messages, config, 0.35, GLM_REQUEST_TIMEOUT_MS);
}

export async function requestReactLiteAppFromGlm(manifest: SkillManifest, blueprint: AppBlueprint,
  localAssetIds: string[], config: GlmLocalConfig): Promise<string> {
  let messages: GlmMessage[] = [
    { role: 'system', content: REACT_LITE_SYSTEM_PROMPT },
    { role: 'user', content: buildReactLitePrompt(manifest, blueprint, localAssetIds) }
  ];
  let policy: ReactLiteGenerationPolicy = { model: 'glm-5.2', thinkingDisabled: true, doSample: false,
    maxTokens: reactLiteMaxTokens(blueprint), streaming: true };
  let generationConfig: GlmLocalConfig = { baseUrl: config.baseUrl, apiKey: config.apiKey, model: policy.model };
  let source: string = await requestChatContent(messages, generationConfig, 0.2,
    GLM_REQUEST_TIMEOUT_MS, policy);
  if (LAST_GLM_COMPLETION_METRICS.finishReason === 'length') {
    let retryPolicy: ReactLiteGenerationPolicy = { model: policy.model, thinkingDisabled: true, doSample: false,
      maxTokens: Math.min(12288, Math.ceil(policy.maxTokens * 1.5)), streaming: true };
    source = await requestChatContent(messages, generationConfig, 0.2, GLM_REQUEST_TIMEOUT_MS, retryPolicy);
    LAST_GLM_COMPLETION_METRICS.truncatedRetry = true;
  }
  return source;
}

export async function requestReactLiteRepairFromGlm(manifest: SkillManifest, blueprint: AppBlueprint, source: string,
  diagnostics: string[], localAssetIds: string[], config: GlmLocalConfig): Promise<string> {
  let prompt: string = buildReactLiteRepairPrompt(source, diagnostics.join('\n')) +
    '\nManifest=' + JSON.stringify(manifest) + '\nBlueprint=' + JSON.stringify(blueprint) + '\nAssets=' + JSON.stringify(localAssetIds);
  let messages: GlmMessage[] = [
    { role: 'system', content: REACT_LITE_SYSTEM_PROMPT },
    { role: 'user', content: prompt }
  ];
  let policy: ReactLiteGenerationPolicy = { model: config.model, thinkingDisabled: true, doSample: false,
    maxTokens: Math.min(12288, 8192), streaming: false };
  return requestChatContent(messages, config, 0.15, GLM_REQUEST_TIMEOUT_MS, policy);
}

export async function requestNestedRuntimeTurnFromGlm(turn: RuntimeAgentTurnRequest,
  config: GlmLocalConfig): Promise<string> {
  let messages: GlmMessage[] = [
    { role: 'system', content: RUNTIME_AGENT_SYSTEM_PROMPT },
    { role: 'user', content: JSON.stringify(turn) }
  ];
  return requestChatContent(messages, config, 0.2);
}

interface AppBlueprintRequest {
  manifest: SkillManifest;
  localAssetIds: string[];
}

interface ArkUiPageRequest {
  manifest: SkillManifest;
  blueprint: AppBlueprint;
  pagePlan: AppPagePlan;
  localAssetIds: string[];
  allowedPageIds: string[];
}

function pageIds(blueprint: AppBlueprint): string[] {
  let ids: string[] = [];
  for (let i: number = 0; i < blueprint.pages.length; i++) { ids.push(blueprint.pages[i].id); }
  return ids;
}

async function requestChatContent(messages: GlmMessage[], config: GlmLocalConfig, temperature: number,
  readTimeout: number = GLM_REQUEST_TIMEOUT_MS, policy?: ReactLiteGenerationPolicy): Promise<string> {
  if (policy !== undefined && policy.streaming) {
    try {
      return await requestStreamingChatContent(messages, config, policy, readTimeout);
    } catch (error) {
      let streamError: Error = error as Error;
      if (!isStreamCapabilityError(streamError)) { throw streamError; }
      let fallback: ReactLiteGenerationPolicy = { model: policy.model, thinkingDisabled: policy.thinkingDisabled,
        doSample: policy.doSample, maxTokens: policy.maxTokens, streaming: false };
      let result: string = await requestChatContent(messages, config, temperature, readTimeout, fallback);
      LAST_GLM_COMPLETION_METRICS.streamFallback = true;
      LAST_GLM_COMPLETION_METRICS.streamed = false;
      return result;
    }
  }
  let client: http.HttpRequest = http.createHttp();
  let startedAt: number = Date.now();
  let payload: GlmChatPayload = {
    model: config.model,
    messages: messages,
    stream: policy === undefined ? false : policy.streaming
  };
  if (policy === undefined || policy.doSample) { payload.temperature = temperature; }
  if (policy !== undefined) {
    payload.do_sample = policy.doSample;
    payload.max_tokens = policy.maxTokens;
    payload.thinking = { type: policy.thinkingDisabled ? 'disabled' : 'enabled' };
  }

  try {
    let requestUrl: string = resolveChatCompletionsUrl(config.baseUrl);
    let extraData: string = JSON.stringify(payload);
    let maxAttempts: number = config.model === GLM_VISION_MODEL ? 4 : 2;
    let timeoutMs: number = readTimeout > GLM_REQUEST_TIMEOUT_MS ? GLM_REQUEST_TIMEOUT_MS : readTimeout;
    let deadline: number = Date.now() + timeoutMs;
    for (let attempt: number = 1; attempt <= maxAttempts; attempt++) {
      let remainingMs: number = deadline - Date.now();
      if (remainingMs <= 0) {
        throw new Error(timeoutMessage(timeoutMs));
      }
      let response: http.HttpResponse;
      try {
        response = await client.request(requestUrl, {
          method: http.RequestMethod.POST,
          header: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer ' + config.apiKey
          },
          extraData: extraData,
          expectDataType: http.HttpDataType.STRING,
          connectTimeout: 15000,
          readTimeout: remainingMs
        });
      } catch (error) {
        let err: Error = error as Error;
        let message: string = typeof err.message === 'string' ? err.message.toLowerCase() : '';
        if (Date.now() >= deadline || message.indexOf('timeout') >= 0) {
          throw new Error(timeoutMessage(timeoutMs));
        }
        throw new Error('GLM 请求失败：' + err.message);
      }

      let body: string = response.result as string;
      if (response.responseCode >= 200 && response.responseCode < 300) {
        if (policy !== undefined) {
          let parsedResult = parseGlmCompletionResult(body, config.model, startedAt, false, false);
          LAST_GLM_COMPLETION_METRICS = parsedResult.metrics;
        }
        return extractContent(body);
      }
      if (!isRetryableResponse(response.responseCode) || attempt === maxAttempts) {
        throw new Error('GLM HTTP ' + response.responseCode.toString() + ': ' + body);
      }
      let retryDelay: number = 1500 * attempt * attempt;
      if (Date.now() + retryDelay >= deadline) {
        throw new Error(timeoutMessage(timeoutMs));
      }
      await waitForRetry(retryDelay);
    }
    throw new Error('GLM 请求未完成');
  } finally {
    client.destroy();
  }
}

async function requestStreamingChatContent(messages: GlmMessage[], config: GlmLocalConfig,
  policy: ReactLiteGenerationPolicy, readTimeout: number): Promise<string> {
  let client: http.HttpRequest = http.createHttp();
  let decoder: GlmSseDecoder = new GlmSseDecoder();
  let content: string = '';
  let finishReason: string = '';
  let startedAt: number = Date.now();
  let firstTokenAt: number = 0;
  let promptTokens: number = 0;
  let completionTokens: number = 0;
  let totalTokens: number = 0;
  let cachedTokens: number = 0;
  let requestId: string = '';
  let resolveEnd: (() => void) | undefined = undefined;
  let streamFinished: Promise<void> = new Promise<void>((resolve: () => void) => { resolveEnd = resolve; });
  let consumeStreamEvents = (events: GlmSseEvent[]): void => {
    for (let i: number = 0; i < events.length; i++) {
      if (events[i].done) { continue; }
      let delta: string = sseDeltaContent(events[i].data);
      if (delta.length > 0) {
        if (firstTokenAt === 0) { firstTokenAt = Date.now(); }
        content += delta;
      }
      let finish: string = sseFinishReason(events[i].data);
      if (finish.length > 0) { finishReason = finish; }
      readStreamMetrics(events[i].data, (id: string, prompt: number, completion: number, total: number, cached: number): void => {
        if (id.length > 0) { requestId = id; }
        if (prompt > 0) { promptTokens = prompt; }
        if (completion > 0) { completionTokens = completion; }
        if (total > 0) { totalTokens = total; }
        if (cached > 0) { cachedTokens = cached; }
      });
    }
  };
  let dataHandler = (chunk: ArrayBuffer): void => {
    let events: GlmSseEvent[] = decoder.push(chunk);
    consumeStreamEvents(events);
  };
  let endHandler = (): void => {
    consumeStreamEvents(decoder.finish());
    if (resolveEnd !== undefined) { resolveEnd(); }
  };
  try {
    client.on('dataReceive', dataHandler);
    client.on('dataEnd', endHandler);
    let payload: GlmChatPayload = buildPayload(messages, config, policy);
    let responseCode: number = await client.requestInStream(resolveChatCompletionsUrl(config.baseUrl), {
      method: http.RequestMethod.POST,
      header: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ' + config.apiKey,
        'Accept': 'text/event-stream'
      },
      extraData: JSON.stringify(payload),
      connectTimeout: 15000,
      readTimeout: readTimeout
    });
    if (responseCode < 200 || responseCode >= 300) {
      throw new Error('GLM_STREAM_HTTP_' + responseCode.toString());
    }
    await streamFinished;
    if (content.length === 0) { throw new Error('GLM_STREAM_UNSUPPORTED_EMPTY'); }
    let totalMs: number = Date.now() - startedAt;
    let metrics: GlmCompletionMetrics = emptyGlmMetrics(policy.model, true, false);
    metrics.totalMs = totalMs;
    metrics.ttftMs = firstTokenAt === 0 ? 0 : firstTokenAt - startedAt;
    metrics.requestId = requestId;
    metrics.promptTokens = promptTokens;
    metrics.completionTokens = completionTokens;
    metrics.totalTokens = totalTokens;
    metrics.cachedTokens = cachedTokens;
    metrics.cacheRatio = promptTokens <= 0 ? 0 : cachedTokens / promptTokens;
    metrics.sourceCharacters = content.length;
    metrics.sourceLines = content.split('\n').length;
    metrics.finishReason = finishReason;
    LAST_GLM_COMPLETION_METRICS = metrics;
    return normalizeDslContent(content);
  } catch (error) {
    let streamError: Error = error as Error;
    if (streamError.message !== undefined && streamError.message.indexOf('GLM_STREAM_HTTP_') === 0) {
      throw streamError;
    }
    throw new Error('GLM_STREAM_UNSUPPORTED: ' + streamError.message);
  } finally {
    client.off('dataReceive', dataHandler);
    client.off('dataEnd', endHandler);
    client.destroy();
  }
}

function buildPayload(messages: GlmMessage[], config: GlmLocalConfig, policy: ReactLiteGenerationPolicy): GlmChatPayload {
  let payload: GlmChatPayload = { model: policy.model, messages: messages, stream: true };
  payload.do_sample = policy.doSample;
  payload.max_tokens = policy.maxTokens;
  payload.thinking = { type: policy.thinkingDisabled ? 'disabled' : 'enabled' };
  return payload;
}

function readStreamMetrics(raw: string, onRead: (requestId: string, promptTokens: number, completionTokens: number,
  totalTokens: number, cachedTokens: number) => void): void {
  try {
    let parsed: Record<string, Object> = JSON.parse(raw) as Record<string, Object>;
    let usage = parsed['usage'] as Record<string, Object>;
    if (usage === undefined || typeof usage !== 'object') { return; }
    let details = usage['prompt_tokens_details'] as Record<string, Object>;
    let id: string = parsed['id'] === undefined ? '' : String(parsed['id']);
    let prompt: number = usage['prompt_tokens'] === undefined ? 0 : Number(usage['prompt_tokens']);
    let completion: number = usage['completion_tokens'] === undefined ? 0 : Number(usage['completion_tokens']);
    let total: number = usage['total_tokens'] === undefined ? 0 : Number(usage['total_tokens']);
    let cached: number = details === undefined || details['cached_tokens'] === undefined ? 0 : Number(details['cached_tokens']);
    onRead(id, prompt, completion, total, cached);
  } catch (e) {
  }
}

function isStreamCapabilityError(error: Error): boolean {
  return error.message !== undefined && error.message.indexOf('GLM_STREAM_UNSUPPORTED') === 0;
}

function timeoutMessage(timeoutMs: number): string {
  return 'GLM 请求 ' + Math.floor(timeoutMs / 1000).toString() + ' 秒未返回，工作流已终止。';
}

function isRetryableResponse(responseCode: number): boolean {
  return responseCode === 408 || responseCode === 429 || responseCode >= 500;
}

async function waitForRetry(delayMs: number): Promise<void> {
  await new Promise<void>((resolve: () => void) => {
    setTimeout(resolve, delayMs);
  });
}

function resolveChatCompletionsUrl(baseUrl: string): string {
  let trimmed: string = baseUrl.trim();
  if (trimmed.endsWith(CHAT_COMPLETIONS_PATH)) {
    return trimmed;
  }
  if (trimmed.endsWith('/')) {
    return trimmed.substring(0, trimmed.length - 1) + CHAT_COMPLETIONS_PATH;
  }
  return trimmed + CHAT_COMPLETIONS_PATH;
}

function extractContent(body: string): string {
  try {
    let parsed: GlmChatResponse = JSON.parse(body) as GlmChatResponse;
    if (parsed.choices.length > 0) {
      let content: string | GlmContentPart[] = parsed.choices[0].message.content;
      if (typeof content === 'string') {
        return normalizeDslContent(content);
      }
      return JSON.stringify(content);
    }
  } catch (e) {
    return body;
  }
  return body;
}

function normalizeDslContent(content: string): string {
  return content
    .replace('```jsonl', '')
    .replace('```json', '')
    .replace('```', '')
    .trim();
}
