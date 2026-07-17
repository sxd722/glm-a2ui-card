import { SemanticUiEvent, createSemanticEvent } from '../../foundation/SemanticEvents';
import { SemanticTheme, createSemanticTheme } from '../../foundation/SemanticTheme';
import { SemanticThemeMode } from '../../foundation/SemanticEnums';
import { SemanticChartModel, SemanticImageModel, SemanticTextModel } from '../../foundation/SemanticModels';
import { SemanticChartCanvas, SemanticImage, SemanticSurface } from '../../internal/SemanticAtoms';

@ComponentV2
export struct ImageHero {
  @Param model: SemanticImageModel = new SemanticImageModel();
  @Param theme: SemanticTheme = createSemanticTheme(SemanticThemeMode.LIGHT);
  @Event onEvent: (event: SemanticUiEvent) => void = () => {};
  build() { Stack({ alignContent: Alignment.BottomStart }) { SemanticImage({ theme: this.theme, source: this.model.source, alt: this.model.alt }).height(220); Column({ space: 3 }) { Text(this.model.caption || this.model.alt).fontSize(this.theme.typography.title).fontWeight(FontWeight.Bold).fontColor(Color.White); }.width('100%').padding(this.theme.spacing.lg).backgroundColor('#99000000'); }.width('100%').height(220).borderRadius(this.theme.radius.xl); }
}

@ComponentV2
export struct MediaPreview {
  @Param model: SemanticImageModel = new SemanticImageModel();
  @Param theme: SemanticTheme = createSemanticTheme(SemanticThemeMode.LIGHT);
  @Event onEvent: (event: SemanticUiEvent) => void = () => {};
  build() { Column({ space: this.theme.spacing.sm }) { SemanticImage({ theme: this.theme, source: this.model.source, alt: this.model.alt }); if (this.model.caption.length > 0) { Text(this.model.caption).fontSize(this.theme.typography.caption).fontColor(this.theme.colors.textSecondary); } }.width('100%'); }
}

@ComponentV2
export struct MapPreview {
  @Param model: SemanticTextModel = new SemanticTextModel();
  @Param theme: SemanticTheme = createSemanticTheme(SemanticThemeMode.LIGHT);
  @Event onEvent: (event: SemanticUiEvent) => void = () => {};
  build() { Stack() { Column().width('100%').height(180).backgroundColor(this.theme.colors.surfaceMuted).borderRadius(this.theme.radius.lg); Column({ space: 4 }) { Text('路线预览').fontWeight(FontWeight.Bold); Text(this.model.body || this.model.title).fontSize(this.theme.typography.caption).fontColor(this.theme.colors.textSecondary); Button('选择地点').onClick(() => this.onEvent(createSemanticEvent(this.model.id, 'select'))); }.justifyContent(FlexAlign.Center).width('100%').height(180); }.width('100%'); }
}

@ComponentV2
export struct ProgressSummary {
  @Param model: SemanticTextModel = new SemanticTextModel();
  @Param theme: SemanticTheme = createSemanticTheme(SemanticThemeMode.LIGHT);
  @Event onEvent: (event: SemanticUiEvent) => void = () => {};
  build() { Column({ space: this.theme.spacing.xs }) { Row() { Text(this.model.title).layoutWeight(1); Text(this.model.value).fontWeight(FontWeight.Bold); }.width('100%'); Progress({ value: Math.max(0, Math.min(100, this.model.progress)), total: 100, type: ProgressType.Linear }).color(this.theme.colors.primary).width('100%'); Text(this.model.body).fontSize(this.theme.typography.caption).fontColor(this.theme.colors.textSecondary); }.width('100%'); }
}

@ComponentV2
export struct TrendChart {
  @Param model: SemanticChartModel = new SemanticChartModel();
  @Param theme: SemanticTheme = createSemanticTheme(SemanticThemeMode.LIGHT);
  @Event onEvent: (event: SemanticUiEvent) => void = () => {};
  build() { Column({ space: this.theme.spacing.sm }) { Text(this.model.title).fontWeight(FontWeight.Bold); if (this.model.series.length > 0) { SemanticChartCanvas({ theme: this.theme, values: this.model.series[0].values, chartHeight: 130 }); } Text(this.model.summary).fontSize(this.theme.typography.caption).fontColor(this.theme.colors.textSecondary); }.width('100%'); }
}

@ComponentV2
export struct BarChart {
  @Param model: SemanticChartModel = new SemanticChartModel();
  @Param theme: SemanticTheme = createSemanticTheme(SemanticThemeMode.LIGHT);
  @Event onEvent: (event: SemanticUiEvent) => void = () => {};
  build() { TrendChart({ model: this.model, theme: this.theme, onEvent: this.onEvent }); }
}
