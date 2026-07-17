import { GlmLocalConfig, GlmCompletionMetrics } from './A2uiTypes';
import { LAST_GLM_COMPLETION_METRICS, requestReactLiteAppFromGlm, requestReactLiteRepairFromGlm } from './GlmClient';
import { AppBlueprint, ReactLiteFailureArtifact, ReactLiteForgeStage, SkillManifest } from './SkillAppTypes';
import { ReactLiteDiagnostic } from './ReactLiteTypes';
import { ReactLiteCompileResult, compileReactLite } from './ReactLiteCompiler';
import { UiIrSpec } from './UiIrTypes';
import { fingerprintReactLite, semanticRegression } from './ReactLiteSemantic';
import { MAX_REACT_LITE_SOURCE_CHARACTERS, ReactLiteNormalizeResult, normalizeReactLiteSource } from './ReactLiteNormalizer';

export interface ReactLiteForgeResult {
  ok: boolean;
  source: string;
  repairedSource: string;
  uiSpec: UiIrSpec | undefined;
  diagnostics: ReactLiteDiagnostic[];
  trace: string;
  metrics: GlmCompletionMetrics;
  failureArtifact?: ReactLiteFailureArtifact;
}

export async function forgeReactLite(manifest: SkillManifest, blueprint: AppBlueprint, localAssetIds: string[],
  config: GlmLocalConfig): Promise<ReactLiteForgeResult> {
  let stage: ReactLiteForgeStage = 'requesting';
  let rawSource: string = '';
  let normalizedSource: string = '';
  let firstDiagnostics: ReactLiteDiagnostic[] = [];
  try {
    rawSource = await requestReactLiteAppFromGlm(manifest, blueprint, localAssetIds, config);
    stage = 'raw-received';
    let normalized: ReactLiteNormalizeResult = normalizeReactLiteSource(rawSource);
    stage = 'normalizing';
    normalizedSource = normalized.source;
    if (!normalized.ok) {
      return failedResult(stage, rawSource, normalizedSource, normalized.diagnostics,
        'React Lite Normalize 失败。', 'ReactLiteNormalizeError');
    }
    stage = 'parsing';
    let firstNormalizedSource: string = normalizedSource;
    let first: ReactLiteCompileResult = compileReactLite(normalizedSource, {
      manifest: manifest, blueprint: blueprint, localAssetIds: localAssetIds
    });
    firstDiagnostics = first.diagnostics.concat(toDiagnosticList(first.uiDiagnostics));
    if (first.ok && first.value !== undefined) {
      return { ok: true, source: normalizedSource, repairedSource: '', uiSpec: first.value, diagnostics: first.diagnostics,
        trace: 'glm-5.2 React Lite 已编译为 ui-ir-1。', metrics: LAST_GLM_COMPLETION_METRICS };
    }

    stage = 'repairing';
    let repairedRaw: string = await requestReactLiteRepairFromGlm(manifest, blueprint, normalizedSource,
      [diagnosticText(first.diagnostics, first.uiDiagnostics)], localAssetIds, config);
    let repairedNormalized: ReactLiteNormalizeResult = normalizeReactLiteSource(repairedRaw);
    normalizedSource = repairedNormalized.source;
    if (!repairedNormalized.ok) {
      return failedResult(stage, rawSource, normalizedSource, firstDiagnostics.concat(repairedNormalized.diagnostics),
        'React Lite Repair Normalize 失败。', 'ReactLiteRepairNormalizeError', normalizedSource);
    }
    stage = 'parsing';
    let second: ReactLiteCompileResult = compileReactLite(normalizedSource, {
      manifest: manifest, blueprint: blueprint, localAssetIds: localAssetIds
    });
    let secondDiagnostics: ReactLiteDiagnostic[] = second.diagnostics.concat(toDiagnosticList(second.uiDiagnostics));
    if (second.ok && second.value !== undefined) {
      let regression = semanticRegression(fingerprintReactLite(firstNormalizedSource), fingerprintReactLite(normalizedSource));
      if (regression.length > 0) {
        return failedResult('quality-gate', rawSource, normalizedSource, firstDiagnostics.concat(regression),
          'Repair 被拒绝：检测到语义回归，未保存简化结果。', 'ReactLiteSemanticRegression');
      }
      return { ok: true, source: firstNormalizedSource, repairedSource: normalizedSource, uiSpec: second.value,
        diagnostics: second.diagnostics, trace: 'React Lite 首次解析失败，已由 glm-5.2 修复后编译为 ui-ir-1。',
        metrics: LAST_GLM_COMPLETION_METRICS };
    }
    return failedResult('quality-gate', rawSource, normalizedSource, firstDiagnostics.concat(secondDiagnostics),
      'React Lite 解析或编译失败。', 'ReactLiteCompileError', normalizedSource);
  } catch (error) {
    return failedResult(stage === 'requesting' ? 'failed' : stage, rawSource, normalizedSource, firstDiagnostics,
      safeErrorMessage(error), safeErrorName(error), normalizedSource, safeStackSummary(error));
  }
}

function failedResult(stage: ReactLiteForgeStage, rawSource: string, normalizedSource: string,
  diagnostics: ReactLiteDiagnostic[], message: string, errorName: string, artifactSource: string = normalizedSource,
  stackSummary: string = ''): ReactLiteForgeResult {
  let boundedRaw: string = rawSource.substring(0, MAX_REACT_LITE_SOURCE_CHARACTERS);
  let boundedNormalized: string = artifactSource.substring(0, MAX_REACT_LITE_SOURCE_CHARACTERS);
  let artifact: ReactLiteFailureArtifact = {
    stage: stage, rawSource: boundedRaw, normalizedSource: boundedNormalized,
    sourceLength: rawSource.length, sourceHash: sourceHash(rawSource), diagnostics: diagnostics,
    errorName: errorName, errorMessage: message, stackSummary: stackSummary, createdAt: Date.now()
  };
  return { ok: false, source: normalizedSource, repairedSource: '', uiSpec: undefined, diagnostics: diagnostics,
    trace: message, metrics: LAST_GLM_COMPLETION_METRICS, failureArtifact: artifact };
}

function toDiagnosticList(messages: string[]): ReactLiteDiagnostic[] {
  let result: ReactLiteDiagnostic[] = [];
  for (let i: number = 0; i < messages.length; i++) {
    result.push({ code: 'RL_UI_VALIDATION', severity: 'error', message: messages[i], line: 1, column: 1, length: 1, suggestion: '' });
  }
  return result;
}

function diagnosticText(parseDiagnostics: ReactLiteDiagnostic[], uiDiagnostics: string[]): string {
  let output: string[] = [];
  for (let i: number = 0; i < parseDiagnostics.length; i++) { output.push(parseDiagnostics[i].code + ':' + parseDiagnostics[i].message); }
  for (let j: number = 0; j < uiDiagnostics.length; j++) { output.push('UI:' + uiDiagnostics[j]); }
  return output.length === 0 ? 'unknown React Lite validation error' : output.join(' | ');
}

function safeErrorMessage(error: Object): string {
  if (error instanceof Error && error.message.length > 0) { return error.message.substring(0, 4000); }
  return 'React Lite 生成发生受控异常。';
}

function safeErrorName(error: Object): string {
  return error instanceof Error && error.name.length > 0 ? error.name : 'ReactLiteForgeError';
}

function safeStackSummary(error: Object): string {
  if (error instanceof Error && typeof error.stack === 'string') {
    return error.stack.substring(0, 4000);
  }
  return '';
}

function sourceHash(value: string): string {
  let hash: number = 2166136261;
  let bounded: string = value.substring(0, MAX_REACT_LITE_SOURCE_CHARACTERS);
  for (let i: number = 0; i < bounded.length; i++) {
    hash = (hash ^ bounded.charCodeAt(i)) >>> 0;
    hash = Math.imul(hash, 16777619) >>> 0;
  }
  return hash.toString(16).padStart(8, '0');
}
