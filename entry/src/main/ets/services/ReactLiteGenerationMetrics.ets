import { GlmCompletionMetrics, GlmUsage } from './A2uiTypes';

export interface GlmCompletionResult {
  content: string;
  metrics: GlmCompletionMetrics;
}

export function parseGlmCompletionResult(raw: string, model: string, startedAt: number,
  streamed: boolean = false, streamFallback: boolean = false): GlmCompletionResult {
  let parsed: Record<string, Object> = {};
  try { parsed = JSON.parse(raw) as Record<string, Object>; } catch (e) { parsed = {}; }
  let choices: Object[] = Array.isArray(parsed['choices']) ? parsed['choices'] as Object[] : [];
  let content: string = '';
  let finishReason: string = '';
  if (choices.length > 0) {
    let choice: Record<string, Object> = choices[0] as Record<string, Object>;
    finishReason = stringValue(choice['finish_reason']);
    let message = objectValue(choice['message']);
    if (message !== undefined) { content = stringValue(message['content']); }
    if (content.length === 0) { let delta = objectValue(choice['delta']); if (delta !== undefined) { content = stringValue(delta['content']); } }
  }
  let usage: GlmUsage = readUsage(parsed['usage']);
  let now: number = Date.now();
  let totalMs: number = Math.max(0, now - startedAt);
  let promptTokens: number = usage.prompt_tokens;
  let cachedTokens: number = usage.prompt_tokens_details === undefined ? 0 : usage.prompt_tokens_details.cached_tokens;
  let cacheRatio: number = promptTokens <= 0 ? 0 : cachedTokens / promptTokens;
  let metrics: GlmCompletionMetrics = { model: model, requestId: readRequestId(parsed), promptTokens: promptTokens,
    cachedTokens: cachedTokens, cacheRatio: cacheRatio, completionTokens: usage.completion_tokens, totalTokens: usage.total_tokens,
    ttftMs: streamed && content.length > 0 ? totalMs : 0, totalMs: totalMs, sourceCharacters: content.length,
    sourceLines: lineCount(content), finishReason: finishReason, streamed: streamed, streamFallback: streamFallback,
    truncatedRetry: false, repairCount: 0 };
  return { content: content, metrics: metrics };
}

export function withReactLiteSourceMetrics(result: GlmCompletionResult): GlmCompletionResult {
  result.metrics.sourceCharacters = result.content.length;
  result.metrics.sourceLines = lineCount(result.content);
  return result;
}

export function emptyGlmMetrics(model: string, streamed: boolean, streamFallback: boolean): GlmCompletionMetrics {
  return { model: model, requestId: '', promptTokens: 0, cachedTokens: 0, cacheRatio: 0, completionTokens: 0, totalTokens: 0,
    ttftMs: 0, totalMs: 0, sourceCharacters: 0, sourceLines: 0, finishReason: '', streamed: streamed,
    streamFallback: streamFallback, truncatedRetry: false, repairCount: 0 };
}

function readUsage(value: Object): GlmUsage {
  let record: Record<string, Object> | undefined = objectValue(value);
  let details: Record<string, Object> | undefined = record === undefined ? undefined : objectValue(record['prompt_tokens_details']);
  let prompt: Object = record === undefined || record['prompt_tokens'] === undefined ? 0 : record['prompt_tokens'];
  let completion: Object = record === undefined || record['completion_tokens'] === undefined ? 0 : record['completion_tokens'];
  let total: Object = record === undefined || record['total_tokens'] === undefined ? 0 : record['total_tokens'];
  let cached: Object = details === undefined || details['cached_tokens'] === undefined ? 0 : details['cached_tokens'];
  return { prompt_tokens: numberValue(prompt), completion_tokens: numberValue(completion), total_tokens: numberValue(total),
    prompt_tokens_details: details === undefined ? undefined : { cached_tokens: numberValue(cached) } };
}

function readRequestId(value: Record<string, Object>): string {
  return stringValue(value['id']).length > 0 ? stringValue(value['id']) : stringValue(value['request_id']);
}

function objectValue(value: Object): Record<string, Object> | undefined {
  return value !== undefined && value !== null && typeof value === 'object' && !Array.isArray(value) ? value as Record<string, Object> : undefined;
}

function stringValue(value: Object): string {
  if (value === undefined || value === null) { return ''; }
  return typeof value === 'string' ? value as string : String(value);
}

function numberValue(value: Object): number {
  if (value === undefined || value === null) { return 0; }
  return typeof value === 'number' ? value as number : Number(value);
}

function lineCount(value: string): number { return value.length === 0 ? 0 : value.split('\n').length; }
