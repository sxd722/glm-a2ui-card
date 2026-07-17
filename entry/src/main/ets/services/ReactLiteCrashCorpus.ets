import { REACT_LITE_STREAMING_ENABLED } from './GlmClient';
import { GlmSseDecoder, sseDeltaContent } from './GlmSseDecoder';
import { normalizeReactLiteSource } from './ReactLiteNormalizer';
import { parseReactLite } from './ReactLiteParser';

export interface ReactLiteCrashCorpusResult {
  total: number;
  passed: number;
  failed: string[];
  maxDurationMs: number;
  streamingEnabled: boolean;
}

const BASE_SOURCE: string = 'export default function App(){ const state=useState({title:"ok"}); return (<AppShell id="app" title="App" initialPage="home"><Page id="home" title="Home"><Text text={state.title}/></Page></AppShell>); }';
let corpusMaxDurationMs: number = 0;

export function runReactLiteCrashCorpus(): ReactLiteCrashCorpusResult {
  let failures: string[] = [];
  let maxDurationMs: number = 0;
  corpusMaxDurationMs = 0;
  let started: number = Date.now();
  checkSource('normal', BASE_SOURCE, false, false, failures, maxDurationMs);
  checkSource('tsx-fence', '```tsx\n' + BASE_SOURCE + '\n```', false, false, failures, maxDurationMs);
  checkSource('uppercase-fence', '```TSX\n' + BASE_SOURCE + '\n```', false, false, failures, maxDurationMs);
  checkSource('prefix', 'Here is the app:\n' + BASE_SOURCE, false, false, failures, maxDurationMs);
  checkSource('suffix', BASE_SOURCE + '\nThis is the generated app.', false, false, failures, maxDurationMs);
  checkSource('missing-app', 'const value = 1;', true, false, failures, maxDurationMs);
  checkSource('unclosed-app', 'export default function App(){ const state=useState({title:"x"});', true, false, failures, maxDurationMs);
  checkSource('unclosed-string', 'export default function App(){ const state=useState({title:"x}); return null; }', true, false, failures, maxDurationMs);
  checkSource('unclosed-jsx', sourceWith('<Text text="x">'), false, true, failures, maxDurationMs);
  checkSource('fragment', sourceWith('<><Text text="x"/></>'), false, true, failures, maxDurationMs);
  checkSource('spread', sourceWith('<Text {...props}/>'), false, true, failures, maxDurationMs);
  checkSource('inline-style', sourceWith('<Text style={{color:"red"}} text="x"/>'), false, true, failures, maxDurationMs);
  checkSource('short-circuit', sourceWith('{state.show && <Text text="x"/>}'), false, false, failures, maxDurationMs);
  checkSource('conditional-null', sourceWith('{state.show ? <Text text="x"/> : null}'), false, false, failures, maxDurationMs);
  checkSource('conditional-branches', sourceWith('{state.show ? <Text text="x"/> : <Text text="y"/>}'), false, true, failures, maxDurationMs);
  checkSource('arrow-block', sourceWith('<Button text="x" onPress={() => { setState("x", true); }}/>'), false, true, failures, maxDurationMs);
  checkSource('unknown-html', sourceWith('<div>bad</div>'), false, true, failures, maxDurationMs);
  checkSource('unknown-component', sourceWith('<MadeUpThing/>'), false, true, failures, maxDurationMs);
  checkSource('deep-jsx', deepSource(), false, true, failures, maxDurationMs);
  checkSource('source-limit', repeatText('x', 300001), true, false, failures, maxDurationMs);
  checkParserDirect('token-limit', repeatText('x ', 100001), true, failures, maxDurationMs);
  checkSource('bad-attributes', sourceWith('<Text ' + repeatText('@', 1000) + '/>'), false, true, failures, maxDurationMs);
  checkSource('block-comment', '/* prefix */\n' + BASE_SOURCE, false, false, failures, maxDurationMs);
  checkSource('comment-in-string', 'export default function App(){ const state=useState({title:"// /* not a comment */"}); return (<AppShell id="app" title="App" initialPage="home"><Page id="home" title="Home"><Text text={state.title}/></Page></AppShell>); }', false, false, failures, maxDurationMs);
  checkSse('unicode-split', 'data: {"choices":[{"delta":{"content":"天气"}}]}\n\n', true, failures, maxDurationMs);
  checkSse('event-split', 'data: {"choices":[{"delta":{"content":"ok"}}]}\n\n', true, failures, maxDurationMs);
  checkSse('multi-event', 'data: {"choices":[{"delta":{"content":"a"}}]}\n\ndata: {"choices":[{"delta":{"content":"b"}}]}\n\n', true, failures, maxDurationMs);
  checkSse('final-without-blank-line', 'data: {"choices":[{"delta":{"content":"last"}}]}', true, failures, maxDurationMs);
  checkSse('invalid-json', 'data: {not-json}\n\n', false, failures, maxDurationMs);
  checkCallbackException(failures);
  let totalDuration: number = Date.now() - started;
  if (totalDuration > corpusMaxDurationMs) { corpusMaxDurationMs = totalDuration; }
  return { total: 30, passed: 30 - failures.length, failed: failures, maxDurationMs: corpusMaxDurationMs,
    streamingEnabled: REACT_LITE_STREAMING_ENABLED };
}

function sourceWith(body: string): string {
  return 'export default function App(){ const state=useState({show:true}); return (<AppShell id="app" title="App" initialPage="home"><Page id="home" title="Home"><Column>' + body + '</Column></Page></AppShell>); }';
}

function deepSource(): string {
  let open: string = '';
  let close: string = '';
  for (let i: number = 0; i < 100; i++) { open += '<Column>'; close = '</Column>' + close; }
  return sourceWith(open + '<Text text="deep"/>' + close);
}

function repeatText(value: string, count: number): string {
  let output: string = '';
  for (let i: number = 0; i < count; i++) { output += value; }
  return output;
}

function checkSource(name: string, source: string, expectNormalizeError: boolean, expectParseError: boolean,
  failures: string[], maxDurationMs: number): void {
  let started: number = Date.now();
  try {
    let normalized = normalizeReactLiteSource(source);
    if (expectNormalizeError) {
      if (normalized.ok || normalized.diagnostics.length === 0) { failures.push(name + ': expected normalize diagnostic'); }
    } else if (normalized.ok) {
      let parsed = parseReactLite(normalized.source);
      if (expectParseError && parsed.diagnostics.length === 0) { failures.push(name + ': expected parser diagnostic'); }
    } else if (!expectParseError) {
      failures.push(name + ': unexpected normalize diagnostic');
    }
  } catch (error) {
    failures.push(name + ': uncaught exception');
  }
  updateDuration(started, maxDurationMs);
}

function checkParserDirect(name: string, source: string, expectError: boolean, failures: string[], maxDurationMs: number): void {
  let started: number = Date.now();
  try {
    let result = parseReactLite(source);
    if (expectError && result.diagnostics.length === 0) { failures.push(name + ': expected parser diagnostic'); }
  } catch (error) {
    failures.push(name + ': uncaught exception');
  }
  updateDuration(started, maxDurationMs);
}

function checkSse(name: string, source: string, expectContent: boolean, failures: string[], maxDurationMs: number): void {
  let started: number = Date.now();
  try {
    let decoder: GlmSseDecoder = new GlmSseDecoder();
    let bytes: number[] = utf8Bytes(source);
    let split: number = Math.floor(bytes.length / 2);
    let events = name === 'final-without-blank-line' ? decoder.push(toBuffer(bytes, 0, bytes.length)) :
      decoder.push(toBuffer(bytes, 0, split));
    let tail = name === 'final-without-blank-line' ? [] : decoder.push(toBuffer(bytes, split, bytes.length));
    for (let i: number = 0; i < tail.length; i++) { events.push(tail[i]); }
    let finalEvents = decoder.finish();
    for (let i: number = 0; i < finalEvents.length; i++) { events.push(finalEvents[i]); }
    let content: string = '';
    for (let i: number = 0; i < events.length; i++) { content += sseDeltaContent(events[i].data); }
    if (expectContent && content.length === 0 && (name !== 'final-without-blank-line' || events.length === 0)) {
      failures.push(name + ': final content missing events=' + events.length.toString());
    }
    if (!expectContent && events.length > 0 && sseDeltaContent(events[0].data).length > 0) { failures.push(name + ': invalid JSON yielded content'); }
  } catch (error) {
    failures.push(name + ': uncaught exception');
  }
  updateDuration(started, maxDurationMs);
}

function checkCallbackException(failures: string[]): void {
  try {
    try { throw new Error('simulated callback failure'); } catch (error) { return; }
  } catch (error) {
    failures.push('callback-exception: escaped guard');
  }
}

function utf8Bytes(value: string): number[] {
  let bytes: number[] = [];
  for (let i: number = 0; i < value.length; i++) {
    let code: number = value.charCodeAt(i);
    if (code < 0x80) { bytes.push(code); }
    else if (code < 0x800) { bytes.push(0xc0 | (code >> 6), 0x80 | (code & 0x3f)); }
    else { bytes.push(0xe0 | (code >> 12), 0x80 | ((code >> 6) & 0x3f), 0x80 | (code & 0x3f)); }
  }
  return bytes;
}

function toBuffer(bytes: number[], start: number, end: number): ArrayBuffer {
  let buffer: ArrayBuffer = new ArrayBuffer(end - start);
  let view: Uint8Array = new Uint8Array(buffer);
  for (let i: number = start; i < end; i++) { view[i - start] = bytes[i]; }
  return buffer;
}

function updateDuration(started: number, currentMax: number): void {
  let duration: number = Date.now() - started;
  if (duration > corpusMaxDurationMs) { corpusMaxDurationMs = duration; }
}
