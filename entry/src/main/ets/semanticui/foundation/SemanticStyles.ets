import { SemanticDensity, SemanticTone } from './SemanticEnums';
import { SemanticTheme, toneColor } from './SemanticTheme';

export function surfaceBackground(theme: SemanticTheme, tone: SemanticTone): string {
  if (tone === SemanticTone.PRIMARY) { return theme.colors.primary; }
  if (tone === SemanticTone.DANGER) { return '#F2E2DF'; }
  if (tone === SemanticTone.WARNING) { return '#F2E8D9'; }
  if (tone === SemanticTone.INFO) { return '#E3EBEF'; }
  if (tone === SemanticTone.SUCCESS) { return '#E2ECE5'; }
  return theme.colors.surfaceElevated;
}

export function foregroundColor(theme: SemanticTheme, tone: SemanticTone): string {
  return tone === SemanticTone.PRIMARY ? theme.colors.onPrimary : toneColor(theme, tone);
}

export function componentPadding(theme: SemanticTheme, density: SemanticDensity): number {
  if (density === SemanticDensity.COMPACT) { return theme.spacing.sm; }
  if (density === SemanticDensity.SPACIOUS) { return theme.spacing.lg; }
  return theme.spacing.md;
}
