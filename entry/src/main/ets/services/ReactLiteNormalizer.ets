import { ReactLiteDiagnostic } from './ReactLiteTypes';

export const MAX_REACT_LITE_SOURCE_CHARACTERS: number = 300000;

export interface ReactLiteNormalizeResult {
  ok: boolean;
  source: string;
  diagnostics: ReactLiteDiagnostic[];
  extractedFromFence: boolean;
  removedPrefixCharacters: number;
  removedSuffixCharacters: number;
}

export function normalizeReactLiteSource(raw: string): ReactLiteNormalizeResult {
  let diagnostics: ReactLiteDiagnostic[] = [];
  if (raw.length > MAX_REACT_LITE_SOURCE_CHARACTERS) {
    diagnostics.push(normalizeDiagnostic('RL_NORMALIZE_SOURCE_LIMIT', 'React Lite 源码超过长度限制。', raw.length));
    return emptyResult(diagnostics);
  }
  let normalized: string = raw.replace(/\r\n/g, '\n').replace(/\r/g, '\n');
  let marker: string = 'export default function App';
  let markerIndex: number = normalized.indexOf(marker);
  if (markerIndex < 0) {
    diagnostics.push(normalizeDiagnostic('RL_NORMALIZE_APP_NOT_FOUND', '未找到 export default function App。', 0));
    return emptyResult(diagnostics);
  }

  let extractedFromFence: boolean = false;
  let start: number = markerIndex;
  let fenceStart: number = normalized.lastIndexOf('```', markerIndex);
  if (fenceStart >= 0) {
    let headerEnd: number = normalized.indexOf('\n', fenceStart);
    let fenceEnd: number = normalized.indexOf('```', markerIndex + marker.length);
    if (headerEnd >= 0 && fenceEnd > markerIndex && isSupportedFence(normalized.substring(fenceStart + 3, headerEnd).trim())) {
      start = headerEnd + 1;
      extractedFromFence = true;
    }
  }

  let end: number = findAppEnd(normalized, markerIndex);
  if (end < 0) {
    diagnostics.push(normalizeDiagnostic('RL_NORMALIZE_APP_UNCLOSED', 'App 函数未闭合。', markerIndex));
    return { ok: false, source: normalized.substring(start), diagnostics: diagnostics,
      extractedFromFence: extractedFromFence, removedPrefixCharacters: start, removedSuffixCharacters: 0 };
  }
  let source: string = normalized.substring(start, end + 1).trim();
  let removedPrefixCharacters: number = start;
  let removedSuffixCharacters: number = Math.max(0, normalized.length - end - 1);
  return { ok: diagnostics.length === 0, source: source, diagnostics: diagnostics,
    extractedFromFence: extractedFromFence, removedPrefixCharacters: removedPrefixCharacters,
    removedSuffixCharacters: removedSuffixCharacters };
}

function findAppEnd(source: string, markerIndex: number): number {
  let state: 'normal' | 'singleQuote' | 'doubleQuote' | 'template' | 'lineComment' | 'blockComment' = 'normal';
  let escaped: boolean = false;
  let bodyStarted: boolean = false;
  let depth: number = 0;
  for (let i: number = markerIndex; i < source.length; i++) {
    let current: string = source.charAt(i);
    let next: string = i + 1 < source.length ? source.charAt(i + 1) : '';
    if (state === 'lineComment') { if (current === '\n') { state = 'normal'; } continue; }
    if (state === 'blockComment') { if (current === '*' && next === '/') { state = 'normal'; i++; } continue; }
    if (state === 'singleQuote' || state === 'doubleQuote' || state === 'template') {
      if (escaped) { escaped = false; continue; }
      if (current === '\\') { escaped = true; continue; }
      if ((state === 'singleQuote' && current === "'") || (state === 'doubleQuote' && current === '"') ||
        (state === 'template' && current === '`')) { state = 'normal'; }
      continue;
    }
    if (current === '/' && next === '/') { state = 'lineComment'; i++; continue; }
    if (current === '/' && next === '*') { state = 'blockComment'; i++; continue; }
    if (current === "'") { state = 'singleQuote'; continue; }
    if (current === '"') { state = 'doubleQuote'; continue; }
    if (current === '`') { state = 'template'; continue; }
    if (current === '{') { depth++; bodyStarted = true; continue; }
    if (current === '}' && bodyStarted) {
      depth--;
      if (depth === 0) { return i; }
    }
  }
  return -1;
}

function isSupportedFence(language: string): boolean {
  let value: string = language.toLowerCase();
  return value === '' || value === 'tsx' || value === 'jsx' || value === 'typescript' ||
    value === 'javascript' || value === 'react';
}

function normalizeDiagnostic(code: string, message: string, offset: number): ReactLiteDiagnostic {
  return { code: code, severity: 'error', message: message, line: 1, column: Math.max(1, offset + 1), length: 1,
    suggestion: '返回完整的 React Lite App 源码。' };
}

function emptyResult(diagnostics: ReactLiteDiagnostic[]): ReactLiteNormalizeResult {
  return { ok: false, source: '', diagnostics: diagnostics, extractedFromFence: false,
    removedPrefixCharacters: 0, removedSuffixCharacters: 0 };
}
