import { http } from '@kit.NetworkKit';

const MAX_FILES: number = 10;
const MAX_FILE_CHARACTERS: number = 100 * 1024;
const MAX_TOTAL_CHARACTERS: number = 300000;
const MAX_DIRECTORY_DEPTH: number = 3;
const GITHUB_API_ORIGIN: string = 'https://api.github.com';
const RAW_GITHUB_ORIGIN: string = 'https://raw.githubusercontent.com';

export interface RepositorySkillLoadResult {
  ok: boolean;
  textContent: string;
  files: string[];
  diagnostics: string[];
  errorKind: 'SourceLoadError' | 'NetworkError' | 'HttpError' | '';
  httpStatus: number;
}

interface GitHubTreeEntry {
  path?: string;
  type?: string;
  size?: number;
}

interface GitHubRepositoryInfo {
  default_branch?: string;
}

interface GitHubTreeResponse {
  tree?: GitHubTreeEntry[];
  truncated?: boolean;
}

interface HttpTextResult {
  ok: boolean;
  body: string;
  status: number;
  errorKind: 'NetworkError' | 'HttpError' | '';
  errorMessage: string;
}

export async function loadPublicGithubSkill(repositoryUrl: string): Promise<RepositorySkillLoadResult> {
  let parsed: string[] = parseGithubRepository(repositoryUrl);
  if (parsed.length !== 2) {
    return failure('SourceLoadError', 0, ['只支持公开 github.com/<owner>/<repo> 仓库地址。']);
  }
  let owner: string = parsed[0];
  let repo: string = parsed[1];
  let infoResult: HttpTextResult = await getJson(GITHUB_API_ORIGIN + '/repos/' + owner + '/' + repo);
  if (!infoResult.ok) {
    return failure(infoResult.errorKind === '' ? 'SourceLoadError' : infoResult.errorKind, infoResult.status,
      [infoResult.errorMessage]);
  }
  let branch: string = 'main';
  try {
    let info: GitHubRepositoryInfo = JSON.parse(infoResult.body) as GitHubRepositoryInfo;
    if (typeof info.default_branch === 'string' && info.default_branch.length > 0) {
      branch = info.default_branch;
    }
  } catch (e) {
    return failure('SourceLoadError', infoResult.status, ['GitHub 仓库元数据不是有效 JSON。']);
  }

  let treeResult: HttpTextResult = await getJson(GITHUB_API_ORIGIN + '/repos/' + owner + '/' + repo +
    '/git/trees/' + encodePathPart(branch) + '?recursive=1');
  if (!treeResult.ok) {
    return failure(treeResult.errorKind === '' ? 'SourceLoadError' : treeResult.errorKind, treeResult.status,
      [treeResult.errorMessage]);
  }
  let entries: GitHubTreeEntry[] = [];
  let truncated: boolean = false;
  try {
    let tree: GitHubTreeResponse = JSON.parse(treeResult.body) as GitHubTreeResponse;
    entries = Array.isArray(tree.tree) ? tree.tree : [];
    truncated = tree.truncated === true;
  } catch (e) {
    return failure('SourceLoadError', treeResult.status, ['GitHub 文件树不是有效 JSON。']);
  }
  let candidates: GitHubTreeEntry[] = selectCandidates(entries);
  if (candidates.length === 0) {
    return failure('SourceLoadError', 200, ['仓库中未找到 SKILL.md、skill.md 或 README.md。']);
  }

  let diagnostics: string[] = [];
  if (truncated) { diagnostics.push('GitHub 文件树被截断，仅分析返回的有限文件。'); }
  let files: string[] = [];
  let sections: string[] = [];
  let totalCharacters: number = 0;
  for (let i: number = 0; i < candidates.length && files.length < MAX_FILES; i++) {
    let entry: GitHubTreeEntry = candidates[i];
    let path: string = entry.path === undefined ? '' : entry.path;
    if (path.length === 0 || isBinaryPath(path)) { continue; }
    if (entry.size !== undefined && entry.size > MAX_FILE_CHARACTERS) {
      diagnostics.push(path + ' 超过单文件 100 KB 上限，已跳过。');
      continue;
    }
    let rawUrl: string = RAW_GITHUB_ORIGIN + '/' + owner + '/' + repo + '/' + encodePath(branch) + '/' + encodePath(path);
    let fileResult: HttpTextResult = await getJson(rawUrl);
    if (!fileResult.ok) {
      diagnostics.push(path + ' 下载失败：' + fileResult.errorMessage);
      continue;
    }
    if (fileResult.body.length === 0 || fileResult.body.length > MAX_FILE_CHARACTERS) {
      diagnostics.push(path + ' 为空或超过单文件 100 KB 上限，已跳过。');
      continue;
    }
    if (totalCharacters + fileResult.body.length > MAX_TOTAL_CHARACTERS) {
      diagnostics.push('达到仓库 Skill 文本总字符上限，后续文件已跳过。');
      break;
    }
    totalCharacters += fileResult.body.length;
    files.push(path);
    sections.push('===== ' + path + ' =====\n' + fileResult.body);
  }
  if (sections.length === 0) {
    return failure('SourceLoadError', 200, diagnostics.concat(['候选 Skill 文件均未能读取，未调用 GLM。']));
  }
  return { ok: true, textContent: sections.join('\n\n'), files: files, diagnostics: diagnostics,
    errorKind: '', httpStatus: 200 };
}

export function isPublicGithubRepositoryUrl(value: string): boolean {
  return parseGithubRepository(value).length === 2;
}

function parseGithubRepository(value: string): string[] {
  let input: string = value.trim();
  if (input.indexOf('https://github.com/') !== 0 || input.indexOf('?') >= 0 || input.indexOf('#') >= 0) {
    return [];
  }
  let path: string = input.substring('https://github.com/'.length);
  while (path.endsWith('/')) { path = path.substring(0, path.length - 1); }
  let parts: string[] = path.split('/');
  if (parts.length !== 2 || !validSegment(parts[0]) || !validSegment(parts[1]) || parts[1].endsWith('.git')) {
    return [];
  }
  return [parts[0], parts[1]];
}

function selectCandidates(entries: GitHubTreeEntry[]): GitHubTreeEntry[] {
  let candidates: GitHubTreeEntry[] = [];
  for (let i: number = 0; i < entries.length; i++) {
    let entry: GitHubTreeEntry = entries[i];
    if (entry.type !== 'blob' || entry.path === undefined || entry.path.length === 0) { continue; }
    let depth: number = entry.path.split('/').length - 1;
    if (depth > MAX_DIRECTORY_DEPTH || isBinaryPath(entry.path)) { continue; }
    let lower: string = entry.path.toLowerCase();
    let base: string = lower.substring(lower.lastIndexOf('/') + 1);
    if (base !== 'skill.md' && base !== 'readme.md') { continue; }
    candidates.push(entry);
  }
  candidates.sort((left: GitHubTreeEntry, right: GitHubTreeEntry): number => {
    return candidateRank(left.path === undefined ? '' : left.path) - candidateRank(right.path === undefined ? '' : right.path);
  });
  return candidates;
}

function candidateRank(path: string): number {
  let lower: string = path.toLowerCase();
  let depth: number = path.split('/').length - 1;
  let base: string = lower.substring(lower.lastIndexOf('/') + 1);
  if (depth === 0 && base === 'skill.md') { return 0; }
  if (depth === 0 && base === 'readme.md') { return 1; }
  if (base === 'skill.md') { return 2 + depth; }
  return 10 + depth;
}

function isBinaryPath(path: string): boolean {
  let lower: string = path.toLowerCase();
  let binaryExtensions: string[] = ['.png', '.jpg', '.jpeg', '.gif', '.webp', '.pdf', '.zip', '.gz', '.mp3', '.mp4', '.wasm'];
  for (let i: number = 0; i < binaryExtensions.length; i++) {
    if (lower.endsWith(binaryExtensions[i])) { return true; }
  }
  return false;
}

function validSegment(value: string): boolean {
  if (value.length === 0 || value.length > 100) { return false; }
  for (let i: number = 0; i < value.length; i++) {
    let code: number = value.charCodeAt(i);
    let allowed: boolean = (code >= 48 && code <= 57) || (code >= 65 && code <= 90) ||
      (code >= 97 && code <= 122) || value.charAt(i) === '-' || value.charAt(i) === '_' || value.charAt(i) === '.';
    if (!allowed) { return false; }
  }
  return true;
}

async function getJson(url: string): Promise<HttpTextResult> {
  let client: http.HttpRequest = http.createHttp();
  try {
    let options: http.HttpRequestOptions = {
      method: http.RequestMethod.GET,
      header: { 'Accept': 'application/vnd.github+json', 'User-Agent': 'glm-a2ui-card-mvp' },
      expectDataType: http.HttpDataType.STRING,
      connectTimeout: 10000,
      readTimeout: 30000
    };
    let response: http.HttpResponse = await client.request(url, options);
    let body: string = typeof response.result === 'string' ? response.result as string : '';
    if (response.responseCode < 200 || response.responseCode >= 300) {
      return { ok: false, body: body, status: response.responseCode, errorKind: 'HttpError',
        errorMessage: 'GitHub HTTP ' + response.responseCode.toString() };
    }
    return { ok: true, body: body, status: response.responseCode, errorKind: '', errorMessage: '' };
  } catch (error) {
    let message: string = error instanceof Error && typeof error.message === 'string' ? error.message : '网络请求失败';
    return { ok: false, body: '', status: 0, errorKind: 'NetworkError', errorMessage: message };
  } finally {
    client.destroy();
  }
}

function encodePath(value: string): string {
  let parts: string[] = value.split('/');
  let out: string[] = [];
  for (let i: number = 0; i < parts.length; i++) { out.push(encodePathPart(parts[i])); }
  return out.join('/');
}

function encodePathPart(value: string): string {
  return value.replace(/ /g, '%20').replace(/#/g, '%23').replace(/\?/g, '%3F');
}

function failure(kind: 'SourceLoadError' | 'NetworkError' | 'HttpError', status: number,
  diagnostics: string[]): RepositorySkillLoadResult {
  return { ok: false, textContent: '', files: [], diagnostics: diagnostics, errorKind: kind, httpStatus: status };
}
