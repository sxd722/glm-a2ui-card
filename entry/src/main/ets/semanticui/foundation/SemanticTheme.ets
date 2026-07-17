import { SemanticDensity, SemanticSize, SemanticThemeMode, SemanticTone } from './SemanticEnums';
import { SemanticColorTokens, SemanticElevationTokens, SemanticRadiusTokens, SemanticSpacingTokens, SemanticTypographyTokens } from './SemanticTokens';

export class SemanticTheme {
  mode: SemanticThemeMode = SemanticThemeMode.LIGHT;
  scale: number = 1;
  colors: SemanticColorTokens = new SemanticColorTokens();
  spacing: SemanticSpacingTokens = new SemanticSpacingTokens();
  radius: SemanticRadiusTokens = new SemanticRadiusTokens();
  elevation: SemanticElevationTokens = new SemanticElevationTokens();
  typography: SemanticTypographyTokens = new SemanticTypographyTokens();
}

export function createSemanticTheme(mode: SemanticThemeMode, scale: number = 1): SemanticTheme {
  let theme: SemanticTheme = new SemanticTheme();
  theme.mode = mode;
  theme.scale = scale;
  theme.typography.display = 32 * scale;
  theme.typography.headline = 24 * scale;
  theme.typography.title = 18 * scale;
  theme.typography.body = 15 * scale;
  theme.typography.label = 13 * scale;
  theme.typography.caption = 11 * scale;
  if (mode === SemanticThemeMode.DARK) {
    theme.colors.surface = '#202321';
    theme.colors.surfaceElevated = '#2A2E2B';
    theme.colors.surfaceMuted = '#343936';
    theme.colors.textPrimary = '#F5F3EC';
    theme.colors.textSecondary = '#C5C2B9';
    theme.colors.textDisabled = '#777B75';
    theme.colors.border = '#4B534D';
    theme.colors.divider = '#3C433F';
    theme.colors.scrim = '#00000099';
    theme.colors.primarySoft = '#31433F';
    theme.colors.warningSoft = '#4A3D2E';
    theme.colors.dangerSoft = '#4A302D';
  }
  return theme;
}

export function toneColor(theme: SemanticTheme, tone: SemanticTone): string {
  switch (tone) {
    case SemanticTone.PRIMARY: return theme.colors.primary;
    case SemanticTone.INFO: return theme.colors.info;
    case SemanticTone.SUCCESS: return theme.colors.success;
    case SemanticTone.WARNING: return theme.colors.warning;
    case SemanticTone.DANGER: return theme.colors.danger;
    default: return theme.colors.textSecondary;
  }
}

export function densityGap(theme: SemanticTheme, density: SemanticDensity): number {
  if (density === SemanticDensity.COMPACT) { return theme.spacing.sm; }
  if (density === SemanticDensity.SPACIOUS) { return theme.spacing.lg; }
  return theme.spacing.md;
}

export function sizeFont(theme: SemanticTheme, size: SemanticSize): number {
  if (size === SemanticSize.SMALL) { return theme.typography.label; }
  if (size === SemanticSize.LARGE) { return theme.typography.headline; }
  return theme.typography.body;
}
