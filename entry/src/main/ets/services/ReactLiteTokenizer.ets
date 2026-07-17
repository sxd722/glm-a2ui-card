import { ReactLiteDiagnostic, ReactLiteToken, ReactLiteTokenKind } from './ReactLiteTypes';

export const MAX_REACT_LITE_SOURCE_CHARACTERS: number = 300000;
export const MAX_REACT_LITE_TOKENS: number = 100000;

export interface ReactLiteTokenResult {
  tokens: ReactLiteToken[];
  diagnostics: ReactLiteDiagnostic[];
}

export function tokenizeReactLite(source: string): ReactLiteTokenResult {
  if (source.length > MAX_REACT_LITE_SOURCE_CHARACTERS) {
    return { tokens: [{ kind: 'eof', value: '', offset: 0, line: 1, column: 1 }], diagnostics: [
      scannerDiag('RL_SOURCE_SIZE_LIMIT', 'React Lite 源码超过长度限制。', 1, 1, '缩短模型输出。')
    ] };
  }
  let result: ReactLiteTokenResult = new ReactLiteScanner(stripFence(source)).scan();
  if (result.tokens.length > MAX_REACT_LITE_TOKENS) {
    result.tokens = [{ kind: 'eof', value: '', offset: source.length, line: 1, column: 1 }];
    result.diagnostics.push(scannerDiag('RL_TOKEN_LIMIT', 'React Lite Token 数量超过限制。', 1, 1, '缩短模型输出。'));
  }
  return result;
}

class ReactLiteScanner {
  private input: string;
  private index: number = 0;
  private line: number = 1;
  private column: number = 1;
  private inJsxText: boolean = false;
  private jsxDepth: number = 0;
  private jsxExpressionDepth: number = 0;
  private currentTagClosing: boolean = false;
  private tokens: ReactLiteToken[] = [];
  private diagnostics: ReactLiteDiagnostic[] = [];

  constructor(input: string) { this.input = input; }

  scan(): ReactLiteTokenResult {
    while (this.index < this.input.length) {
      if (this.tokens.length >= MAX_REACT_LITE_TOKENS) {
        this.diagnostics.push(scannerDiag('RL_TOKEN_LIMIT', 'React Lite Token 数量超过限制。', this.line, this.column, '缩短模型输出。'));
        break;
      }
      let ch: string = this.input.charAt(this.index);
      if (this.inJsxText && ch !== '<' && ch !== '{') {
        this.scanJsxText();
        continue;
      }
      if (isWhitespace(ch)) { this.advance(ch); continue; }
      if (ch === '/' && this.input.charAt(this.index + 1) === '/') { this.scanLineComment(); continue; }
      if (ch === '/' && this.input.charAt(this.index + 1) === '*') { this.scanBlockComment(); continue; }
      if (ch === '<') {
        this.tokens.push(this.single('punctuation', '<'));
        this.currentTagClosing = this.input.charAt(this.index + 1) === '/';
        this.advance(ch);
        this.inJsxText = false;
        continue;
      }
      if (ch === '>') {
        let selfClosing: boolean = this.previousNonWhitespace() === '/';
        this.tokens.push(this.single('punctuation', '>'));
        this.advance(ch);
        if (this.currentTagClosing) {
          if (this.jsxDepth > 0) { this.jsxDepth--;
          }
        } else if (!selfClosing) {
          this.jsxDepth++;
        }
        this.currentTagClosing = false;
        this.inJsxText = this.jsxDepth > 0;
        continue;
      }
      if (ch === '{') {
        this.tokens.push(this.single('punctuation', '{')); this.advance(ch);
        if (this.inJsxText) { this.jsxExpressionDepth = 1; this.inJsxText = false; }
        else if (this.jsxExpressionDepth > 0) { this.jsxExpressionDepth++; }
        continue;
      }
      if (ch === '}') {
        this.tokens.push(this.single('punctuation', '}')); this.advance(ch);
        if (this.jsxExpressionDepth > 0) { this.jsxExpressionDepth--; this.inJsxText = this.jsxExpressionDepth === 0 && this.jsxDepth > 0; }
        continue;
      }
      if (this.scanOperator(ch)) { continue; }
      if (this.scanPunctuation(ch)) { continue; }
      if (ch === '"' || ch === "'") { this.scanString(ch); continue; }
      if (isDigit(ch)) { this.scanNumber(); continue; }
      if (isIdentifierStart(ch)) { this.scanIdentifier(); continue; }
      this.diagnostics.push(scannerDiag('RL1001', '无法识别字符：' + ch, this.line, this.column, '删除不支持的语法。'));
      this.advance(ch);
    }
    this.tokens.push({ kind: 'eof', value: '', offset: this.input.length, line: this.line, column: this.column });
    return { tokens: this.tokens, diagnostics: this.diagnostics };
  }

  private scanJsxText(): void {
    let start: number = this.index; let startLine: number = this.line; let startColumn: number = this.column;
    while (this.index < this.input.length && this.input.charAt(this.index) !== '<' && this.input.charAt(this.index) !== '{') { this.advance(this.input.charAt(this.index)); }
    let value: string = this.input.substring(start, this.index);
    if (value.trim().length > 0) { this.tokens.push(this.makeToken('jsxText', value, start, startLine, startColumn)); }
  }

  private scanLineComment(): void {
    let start: number = this.index; let startLine: number = this.line; let startColumn: number = this.column;
    while (this.index < this.input.length && this.input.charAt(this.index) !== '\n') { this.advance(this.input.charAt(this.index)); }
    this.tokens.push(this.makeToken('comment', this.input.substring(start, this.index), start, startLine, startColumn));
    this.diagnostics.push(scannerDiag('RL1002', '不允许注释', startLine, startColumn, '删除注释后重新生成。'));
  }

  private scanBlockComment(): void {
    let start: number = this.index; let startLine: number = this.line; let startColumn: number = this.column;
    this.advance('/'); this.advance('*');
    while (this.index < this.input.length && !(this.input.charAt(this.index) === '*' && this.input.charAt(this.index + 1) === '/')) { this.advance(this.input.charAt(this.index)); }
    if (this.index < this.input.length) { this.advance('*'); this.advance('/'); }
    this.tokens.push(this.makeToken('comment', this.input.substring(start, this.index), start, startLine, startColumn));
    this.diagnostics.push(scannerDiag('RL1002', '不允许注释', startLine, startColumn, '删除注释后重新生成。'));
  }

  private scanPunctuation(ch: string): boolean {
    if ('()[],=:.;'.indexOf(ch) < 0) { return false; }
    this.tokens.push(this.single('punctuation', ch)); this.advance(ch); return true;
  }

  private scanOperator(ch: string): boolean {
    let three: string = this.input.substring(this.index, this.index + 3);
    if (three === '===' || three === '!==') { this.tokens.push(this.single('operator', three)); this.advance(ch); this.advance(this.input.charAt(this.index)); this.advance(this.input.charAt(this.index)); return true; }
    let two: string = this.input.substring(this.index, this.index + 2);
    if (['&&', '||', '??', '>=', '<=', '=>', '!=', '=='].indexOf(two) >= 0) { this.tokens.push(this.single('operator', two)); this.advance(ch); this.advance(this.input.charAt(this.index)); return true; }
    if ('!?+-*/%<>'.indexOf(ch) >= 0) { this.tokens.push(this.single('operator', ch)); this.advance(ch); return true; }
    return false;
  }

  private scanString(quote: string): void {
    let start: number = this.index; let startLine: number = this.line; let startColumn: number = this.column;
    this.advance(quote); let value: string = '';
    while (this.index < this.input.length && this.input.charAt(this.index) !== quote) {
      let current: string = this.input.charAt(this.index);
      if (current === '\\' && this.index + 1 < this.input.length) { this.advance(current); value += decodeEscape(this.input.charAt(this.index)); this.advance(this.input.charAt(this.index)); }
      else { value += current; this.advance(current); }
    }
    if (this.index < this.input.length) { this.advance(this.input.charAt(this.index)); }
    else { this.diagnostics.push(scannerDiag('RL1001', '字符串未闭合', startLine, startColumn, '补齐引号。')); }
    this.tokens.push(this.makeToken('string', value, start, startLine, startColumn));
  }

  private scanNumber(): void {
    let start: number = this.index; let startLine: number = this.line; let startColumn: number = this.column;
    while (this.index < this.input.length && /[0-9.]/.test(this.input.charAt(this.index))) { this.advance(this.input.charAt(this.index)); }
    this.tokens.push(this.makeToken('number', this.input.substring(start, this.index), start, startLine, startColumn));
  }

  private scanIdentifier(): void {
    let start: number = this.index; let startLine: number = this.line; let startColumn: number = this.column;
    while (this.index < this.input.length && isIdentifierPart(this.input.charAt(this.index))) { this.advance(this.input.charAt(this.index)); }
    this.tokens.push(this.makeToken('identifier', this.input.substring(start, this.index), start, startLine, startColumn));
  }

  private advance(value: string): void { this.index++; if (value === '\n') { this.line++; this.column = 1; } else { this.column++; } }
  private previousNonWhitespace(): string {
    let cursor: number = this.index - 1;
    while (cursor >= 0 && /\s/.test(this.input.charAt(cursor))) { cursor--;
    }
    return cursor >= 0 ? this.input.charAt(cursor) : '';
  }
  private single(kind: ReactLiteTokenKind, value: string): ReactLiteToken { return this.makeToken(kind, value, this.index, this.line, this.column); }
  private makeToken(kind: ReactLiteTokenKind, value: string, offset: number, line: number, column: number): ReactLiteToken { return { kind: kind, value: value, offset: offset, line: line, column: column }; }
}

function stripFence(source: string): string { let trimmed: string = source.trim(); if (trimmed.indexOf('```') === 0) { let firstLineEnd: number = trimmed.indexOf('\n'); let start: number = firstLineEnd >= 0 ? firstLineEnd + 1 : 3; let end: number = trimmed.lastIndexOf('```'); return end > start ? trimmed.substring(start, end).trim() : trimmed.substring(start).trim(); } return source; }
function isWhitespace(value: string): boolean { return /\s/.test(value); }
function isDigit(value: string): boolean { return /[0-9]/.test(value); }
function isIdentifierStart(value: string): boolean { return /[A-Za-z_$]/.test(value) || value.charCodeAt(0) > 127; }
function isIdentifierPart(value: string): boolean { return /[A-Za-z0-9_$-]/.test(value) || value.charCodeAt(0) > 127; }
function decodeEscape(value: string): string { if (value === 'n') { return '\n'; } if (value === 't') { return '\t'; } if (value === 'r') { return '\r'; } return value; }
function scannerDiag(code: string, message: string, line: number, column: number, suggestion: string): ReactLiteDiagnostic { return { code: code, severity: 'error', message: message, line: line, column: column, length: 1, suggestion: suggestion }; }
