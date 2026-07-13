import { http } from '@kit.NetworkKit';
import { GlmChatPayload, GlmChatResponse, GlmContentPart, GlmLocalConfig, GlmMessage } from './A2uiTypes';
import { AgentTurnRequest } from './SkillTypes';
import { AppBlueprint, RuntimeAgentTurnRequest, SkillManifest, SkillSource } from './SkillAppTypes';

export const GLM_CODING_ENDPOINT: string = 'https://open.bigmodel.cn/api/coding/paas/v4';
const CHAT_COMPLETIONS_PATH: string = '/chat/completions';
export const GLM_DEFAULT_MODEL: string = 'glm-5.2';
export const GLM_ALTERNATE_MODEL: string = 'glm-5-turbo';
// TODO(MVP-next): Replace manual entry with a HUKS-backed CredentialVault reference.
export const GLM_LOCAL_API_KEY: string = '';

const SYSTEM_PROMPT: string =
  'You generate A2UI v0.9 JSONL only. Return one createSurface message and one updateDataModel message. ' +
  'The updateDataModel value must include title, subtitle, body, and items string array. No markdown.';

const SKILL_IMAGE_SYSTEM_PROMPT: string =
  'You extract an Agent Skill card image into strict JSON only. No markdown. ' +
  'Return fields: skillName, skillId, goal, scenarios, inputFields, flow, outputs, rules, actions, examplePrompt. ' +
  'inputFields items must be {id,label,placeholder,required}. Use stable camelCase ids.';

const AGENT_TURN_SYSTEM_PROMPT: string =
  'You are a card-state agent orchestrator. Return strict JSON only with fields: assistantText, toolCalls, cardPatchesJson, activeCardId, status. ' +
  'Only request tools from availableTools. toolCalls items must be {toolName,argsJson,callId}.';

const NESTED_APP_SYSTEM_PROMPT: string =
  'You generate a strict NestedAppSpec JSON only. No markdown, no URLs, no colors, no code. ' +
  'Use only node kinds heroMedia, glassPanel, sectionHeader, formField, choiceChips, timeline, metric, mediaGallery, actionBar, statusBanner, resultList. ' +
  'Use only action kinds navigate, back, invokeAgent, pickLocalImage, reset. ' +
  'Return fields appId,title,subtitle,initialPageId,pages. Each page contains id,title,subtitle,nodes. ' +
  'Each node contains id,kind,title,text,binding,assetId,items,actions,tone. ' +
  'Each action contains id,label,kind,targetPageId,payload. Design a multi-page app and only reference local asset ids supplied by the user.';

const SKILL_MANIFEST_SYSTEM_PROMPT: string =
  'Analyze a user-provided Skill source and return strict SkillManifest JSON only. No markdown or code. ' +
  'Return schemaVersion,skillId,skillName,version,description,goals,inputFields,outputFields,workflow,decisionPoints,toolContracts,permissions,constraints,examples. ' +
  'inputFields items contain id,label,kind,required,options. toolContracts items contain name,description,adapterId,inputFields,outputFields,allowedOrigins,credentialRef,confirmation,implemented. ' +
  'Never include a secret. Mark tools implemented=false unless the source maps to an explicitly registered local adapter.';

const APP_BLUEPRINT_SYSTEM_PROMPT: string =
  'Act as a product designer. Return strict AppBlueprint JSON only. No markdown, URLs, colors outside palette, or code. ' +
  'Return schemaVersion,appId,skillId,title,summary,homePattern,palette,runtimePrompt,dynamicSlots,componentRecipes,nestedApp. ' +
  'nestedApp is a multi-page NestedAppSpec. Allowed node kinds: heroMedia,glassPanel,sectionHeader,formField,choiceChips,timeline,metric,mediaGallery,actionBar,statusBanner,resultList,dataChart,compareTable,entityPicker,conversationPanel,credentialForm,dynamicSlot. ' +
  'Allowed actions: navigate,back,invokeAgent,pickLocalImage,reset. Each action may set handling to local,agent,localThenAgent. ' +
  'Prefer tap choices and suggested actions over keyboard input. Only reference supplied local asset ids.';

const RUNTIME_AGENT_SYSTEM_PROMPT: string =
  'Run one Nested App agent turn. Return strict RuntimeAgentTurnResult JSON only with turnId,assistantText,toolCalls,statePatches,uiPatches,navigationPageId,suggestedActions,status,errorMessage. ' +
  'Only call availableTools. statePatches allow setData or updateStatus. uiPatches allow setVisibility,setEnabled,replaceItems,appendItems,setSuggestedActions,mountDynamicView,dismissDynamicView. ' +
  'Use only supplied dynamicSlotIds. Return 2 to 4 suggestedActions. Never request or expose credentials.';

export async function requestA2uiDslFromGlm(prompt: string, config: GlmLocalConfig): Promise<string> {
  let client: http.HttpRequest = http.createHttp();
  let messages: GlmMessage[] = [
    { role: 'system', content: SYSTEM_PROMPT },
    { role: 'user', content: prompt }
  ];

  let payload: GlmChatPayload = {
    model: config.model,
    messages: messages,
    temperature: 0.2,
    stream: false
  };

  try {
    let requestUrl: string = resolveChatCompletionsUrl(config.baseUrl);
    let response: http.HttpResponse = await client.request(requestUrl, {
      method: http.RequestMethod.POST,
      header: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ' + config.apiKey
      },
      extraData: JSON.stringify(payload),
      expectDataType: http.HttpDataType.STRING,
      connectTimeout: 15000,
      readTimeout: 30000
    });

    let body: string = response.result as string;
    if (response.responseCode < 200 || response.responseCode >= 300) {
      throw new Error('GLM HTTP ' + response.responseCode.toString() + ': ' + body);
    }
    return extractContent(body);
  } finally {
    client.destroy();
  }
}

export async function requestSkillSpecFromGlmImage(imageDataUrl: string, config: GlmLocalConfig): Promise<string> {
  let parts: GlmContentPart[] = [
    {
      type: 'text',
      text: 'Extract this image as TRAVEL_PLANNER_V1 SkillSpec JSON. Preserve Chinese labels from the image.'
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

export async function requestNestedAppSpecFromGlm(skillName: string, skillGoal: string, localAssetIds: string[],
  config: GlmLocalConfig): Promise<string> {
  let prompt: string = JSON.stringify({ skillName: skillName, skillGoal: skillGoal, localAssetIds: localAssetIds });
  let messages: GlmMessage[] = [
    { role: 'system', content: NESTED_APP_SYSTEM_PROMPT },
    { role: 'user', content: prompt }
  ];
  return requestChatContent(messages, config, 0.45);
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
  return requestChatContent(messages, config, 0.4);
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

async function requestChatContent(messages: GlmMessage[], config: GlmLocalConfig, temperature: number): Promise<string> {
  let client: http.HttpRequest = http.createHttp();
  let payload: GlmChatPayload = {
    model: config.model,
    messages: messages,
    temperature: temperature,
    stream: false
  };

  try {
    let requestUrl: string = resolveChatCompletionsUrl(config.baseUrl);
    let response: http.HttpResponse = await client.request(requestUrl, {
      method: http.RequestMethod.POST,
      header: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ' + config.apiKey
      },
      extraData: JSON.stringify(payload),
      expectDataType: http.HttpDataType.STRING,
      connectTimeout: 15000,
      readTimeout: 45000
    });

    let body: string = response.result as string;
    if (response.responseCode < 200 || response.responseCode >= 300) {
      throw new Error('GLM HTTP ' + response.responseCode.toString() + ': ' + body);
    }
    return extractContent(body);
  } finally {
    client.destroy();
  }
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
