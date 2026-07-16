import { GlmLocalConfig } from './A2uiTypes';
import { requestReactLiteAppFromGlm, requestReactLiteRepairFromGlm } from './GlmClient';
import { AppBlueprint, SkillManifest } from './SkillAppTypes';
import { ReactLiteDiagnostic } from './ReactLiteTypes';
import { ReactLiteCompileResult, compileReactLite } from './ReactLiteCompiler';
import { UiIrSpec } from './UiIrTypes';
import { fingerprintReactLite, semanticRegression } from './ReactLiteSemantic';

export interface ReactLiteForgeResult {
  ok: boolean;
  source: string;
  repairedSource: string;
  uiSpec: UiIrSpec | undefined;
  diagnostics: ReactLiteDiagnostic[];
  trace: string;
}

export async function forgeReactLite(manifest: SkillManifest, blueprint: AppBlueprint, localAssetIds: string[],
  config: GlmLocalConfig): Promise<ReactLiteForgeResult> {
  let source: string = await requestReactLiteAppFromGlm(manifest, blueprint, localAssetIds, config);
  let first: ReactLiteCompileResult = compileReactLite(source, { manifest: manifest, blueprint: blueprint, localAssetIds: localAssetIds });
  if (first.ok && first.value !== undefined) {
    return { ok: true, source: source, repairedSource: '', uiSpec: first.value, diagnostics: first.diagnostics, trace: 'glm-5.2 React Lite 已编译为 ui-ir-1。' };
  }
  let diagnosticsText: string = diagnosticText(first.diagnostics, first.uiDiagnostics);
  let beforeFingerprint = fingerprintReactLite(source);
  let repaired: string = await requestReactLiteRepairFromGlm(manifest, blueprint, source, [diagnosticsText], localAssetIds, config);
  let second: ReactLiteCompileResult = compileReactLite(repaired, { manifest: manifest, blueprint: blueprint, localAssetIds: localAssetIds });
  if (second.ok && second.value !== undefined) {
    let regression = semanticRegression(beforeFingerprint, fingerprintReactLite(repaired));
    if (regression.length > 0) {
      return { ok: false, source: source, repairedSource: repaired, uiSpec: undefined, diagnostics: first.diagnostics.concat(regression),
        trace: 'Repair 被拒绝：检测到语义回归，未保存简化结果。' };
    }
    return { ok: true, source: source, repairedSource: repaired, uiSpec: second.value, diagnostics: second.diagnostics,
      trace: 'React Lite 首次解析失败，已由 glm-5.2 修复后编译为 ui-ir-1。' };
  }
  return { ok: false, source: source, repairedSource: repaired, uiSpec: undefined,
    diagnostics: first.diagnostics.concat(second.diagnostics), trace: 'React Lite 解析失败：' + diagnosticText(second.diagnostics, second.uiDiagnostics) };
}

function diagnosticText(parseDiagnostics: ReactLiteDiagnostic[], uiDiagnostics: string[]): string {
  let output: string[] = [];
  for (let i: number = 0; i < parseDiagnostics.length; i++) { output.push(parseDiagnostics[i].code + ':' + parseDiagnostics[i].message); }
  for (let j: number = 0; j < uiDiagnostics.length; j++) { output.push('UI:' + uiDiagnostics[j]); }
  return output.length === 0 ? 'unknown React Lite validation error' : output.join(' | ');
}
