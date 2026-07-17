import { util } from '@kit.ArkTS';

export interface GlmSseEvent {
  data: string;
  done: boolean;
}

export class GlmSseDecoder {
  static readonly MAX_PENDING_CHARACTERS: number = 300000;
  private decoder: util.TextDecoder = util.TextDecoder.create('utf-8', { fatal: false, ignoreBOM: true });
  private pending: string = '';

  push(chunk: ArrayBuffer): GlmSseEvent[] {
    let bytes: Uint8Array = new Uint8Array(chunk);
    this.pending += this.decoder.decodeWithStream(bytes, { stream: true });
    if (this.pending.length > GlmSseDecoder.MAX_PENDING_CHARACTERS) {
      throw new Error('GLM_STREAM_FRAME_LIMIT');
    }
    return this.drain(false);
  }

  finish(): GlmSseEvent[] {
    this.pending += this.decoder.decodeWithStream(new Uint8Array(0), { stream: false });
    // Some providers close immediately after the final data line. Parse the
    // retained partial block directly instead of requiring a blank line.
    let finalBlock: string = this.pending;
    this.pending = '';
    let events: GlmSseEvent[] = [];
    if (finalBlock.length > 0) {
      let event: GlmSseEvent | undefined = parseSseBlock(finalBlock);
      if (event !== undefined) { events.push(event); }
    }
    return events;
  }

  private drain(flush: boolean): GlmSseEvent[] {
    let events: GlmSseEvent[] = [];
    let normalized: string = this.pending.replace(/\r\n/g, '\n').replace(/\r/g, '\n');
    let blocks: string[] = normalized.split('\n\n');
    let trailing: string = '';
    if (!flush) {
      trailing = blocks.pop() as string;
    }
    this.pending = trailing;
    for (let i: number = 0; i < blocks.length; i++) {
      let event: GlmSseEvent | undefined = parseSseBlock(blocks[i]);
      if (event !== undefined) { events.push(event); }
    }
    if (flush) {
      // split() keeps the final non-empty block in `blocks` when the stream
      // ends without the SSE-mandated blank line. It must still be emitted.
      this.pending = '';
    }
    return events;
  }
}

function parseSseBlock(block: string): GlmSseEvent | undefined {
  let lines: string[] = block.split('\n');
  let dataLines: string[] = [];
  for (let i: number = 0; i < lines.length; i++) {
    let line: string = lines[i];
    if (line.indexOf('data:') === 0) { dataLines.push(line.substring(5).trimStart()); }
  }
  if (dataLines.length === 0) { return undefined; }
  let data: string = dataLines.join('\n');
  return { data: data, done: data === '[DONE]' };
}

export function sseDeltaContent(data: string): string {
  try {
    let parsed: Record<string, Object> = JSON.parse(data) as Record<string, Object>;
    let choices: Object[] = Array.isArray(parsed['choices']) ? parsed['choices'] as Object[] : [];
    if (choices.length === 0) { return ''; }
    let choice: Record<string, Object> = choices[0] as Record<string, Object>;
    let delta: Record<string, Object> | undefined = objectValue(choice['delta']);
    if (delta === undefined) { return ''; }
    return typeof delta['content'] === 'string' ? delta['content'] as string : '';
  } catch (e) {
    return '';
  }
}

export function sseFinishReason(data: string): string {
  try {
    let parsed: Record<string, Object> = JSON.parse(data) as Record<string, Object>;
    let choices: Object[] = Array.isArray(parsed['choices']) ? parsed['choices'] as Object[] : [];
    if (choices.length === 0) { return ''; }
    return stringValue((choices[0] as Record<string, Object>)['finish_reason']);
  } catch (e) {
    return '';
  }
}

function objectValue(value: Object): Record<string, Object> | undefined {
  return value !== undefined && value !== null && typeof value === 'object' && !Array.isArray(value) ? value as Record<string, Object> : undefined;
}

function stringValue(value: Object): string {
  return typeof value === 'string' ? value as string : '';
}
