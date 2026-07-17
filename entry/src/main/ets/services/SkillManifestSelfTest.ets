import { localManifestForSource, normalizeSkillManifestResult, createSkillSource } from './SkillAppMvp';
import { isPublicGithubRepositoryUrl } from './RepositorySkillLoader';
import { SkillManifest } from './SkillAppTypes';

export interface SkillManifestSelfTestResult {
  passed: number;
  total: number;
  failures: string[];
}

export function runSkillManifestSelfTest(): SkillManifestSelfTestResult {
  let failures: string[] = [];
  let total: number = 0;
  let passed: number = 0;
  let fallback: SkillManifest = localManifestForSource(createSkillSource('text', 'travel', []));
  let check = (name: string, condition: boolean): void => {
    total++;
    if (condition) { passed++; } else { failures.push(name); }
  };
  let valid: string = '{"schemaVersion":"skill-app-mvp-2","skillId":"TODO_LIST_V1","skillName":"Todo 助手",' +
    '"version":"1","description":"capture tasks","goals":["capture"],"inputFields":[{"id":"title",' +
    '"label":"标题","kind":"text","required":true,"options":[]}],"outputFields":["tasks"],"workflow":' +
    '["capture"],"decisionPoints":[],"toolContracts":[{"name":"todo.unknown","description":"unknown",' +
    '"adapterId":"remote","inputFields":[],"outputFields":[],"allowedOrigins":[],"credentialRef":"",' +
    '"confirmation":"none","implemented":true}],"permissions":[],"constraints":[],"examples":[]}';
  let result = normalizeSkillManifestResult(valid, fallback);
  check('valid JSON parses', result.ok && result.value !== undefined);
  check('valid JSON keeps dynamic skillId', result.value !== undefined && result.value.skillId === 'TODO_LIST_V1');
  check('valid JSON does not use travel fallback', result.value !== undefined && result.value.skillId !== fallback.skillId);
  check('unknown tool is not implemented', result.value !== undefined && result.value.toolContracts.length === 1 &&
    !result.value.toolContracts[0].implemented);

  let fenced = normalizeSkillManifestResult('说明\n```json\n' + valid + '\n```\n结束', fallback);
  check('fenced JSON parses', fenced.ok);
  let prefixed = normalizeSkillManifestResult('模型说明：\n' + valid + '\n谢谢。', fallback);
  check('prefix and suffix parse', prefixed.ok);
  let bracesInString = normalizeSkillManifestResult(valid.replace('capture tasks', 'text with { braces }'), fallback);
  check('braces in string parse', bracesInString.ok);
  let noJson = normalizeSkillManifestResult('没有结构化结果', fallback);
  check('no JSON has extraction diagnostic', !noJson.ok && noJson.diagnostics.join(' ').indexOf('JsonExtractionError') >= 0);
  let truncated = normalizeSkillManifestResult('{"skillId":"TODO_LIST_V1"', fallback);
  check('truncated JSON is rejected', !truncated.ok);
  let missingId = normalizeSkillManifestResult(valid.replace('"skillId":"TODO_LIST_V1",', ''), fallback);
  check('missing skillId is rejected', !missingId.ok && missingId.diagnostics.join(' ').indexOf('skillId') >= 0);
  let emptyName = normalizeSkillManifestResult(valid.replace('"skillName":"Todo 助手"', '"skillName":""'), fallback);
  check('empty skillName is rejected', !emptyName.ok && emptyName.diagnostics.join(' ').indexOf('skillName') >= 0);
  let invalidItems = valid.replace('"inputFields":[{', '"inputFields":[null,"bad",{')
    .replace('"toolContracts":[{', '"toolContracts":[null,7,{');
  let invalidItemResult = normalizeSkillManifestResult(invalidItems, fallback);
  check('null and primitive array items do not crash', invalidItemResult.ok && invalidItemResult.value !== undefined &&
    invalidItemResult.value.inputFields.length === 1 && invalidItemResult.value.toolContracts.length === 1);
  let missingArrays = normalizeSkillManifestResult(valid.replace('"inputFields":[{"id":"title","label":"标题",\n      "kind":"text","required":true,"options":[]}],', '')
    .replace('"toolContracts":[{', '"toolContracts":null,'), fallback);
  check('missing or invalid optional arrays are diagnosed', missingArrays.ok && missingArrays.diagnostics.length > 0);
  check('valid GitHub URL accepted', isPublicGithubRepositoryUrl('https://github.com/seniverse/skills'));
  check('non-GitHub URL rejected', !isPublicGithubRepositoryUrl('https://example.com/seniverse/skills'));
  check('GitHub URL with path traversal rejected', !isPublicGithubRepositoryUrl('https://github.com/seniverse/skills/tree/main'));
  return { passed: passed, total: total, failures: failures };
}
