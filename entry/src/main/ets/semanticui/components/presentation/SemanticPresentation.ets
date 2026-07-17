import { SemanticUiEvent, actionPayload, createSemanticEvent, itemPayload } from '../../foundation/SemanticEvents';
import { SemanticComponentBaseModel, SemanticKeyValueItem, SemanticListModel, SemanticMetricItem, SemanticTextModel } from '../../foundation/SemanticModels';
import { SemanticActionStyle, SemanticThemeMode, SemanticTone, SemanticViewStatus } from '../../foundation/SemanticEnums';
import { SemanticTheme, createSemanticTheme } from '../../foundation/SemanticTheme';
import { componentPadding, foregroundColor, surfaceBackground } from '../../foundation/SemanticStyles';

function emitAction(sourceId: string, onEvent: (event: SemanticUiEvent) => void, actionId: string): void {
  onEvent(createSemanticEvent(sourceId, 'action', actionPayload(actionId)));
}

@ComponentV2
export struct Hero {
  @Param @Require model: SemanticTextModel;
  @Param theme: SemanticTheme = createSemanticTheme(SemanticThemeMode.LIGHT);
  @BuilderParam media: () => void;
  @BuilderParam content: () => void;
  @Event onEvent: (event: SemanticUiEvent) => void = () => {};
  build() {
    Stack({ alignContent: Alignment.BottomStart }) {
      this.media();
      Column({ space: this.theme.spacing.sm }) { Text(this.model.title).fontSize(this.theme.typography.display).fontWeight(FontWeight.Bold).fontColor(this.theme.colors.onPrimary); this.content(); }
        .width('100%').padding(this.theme.spacing.lg).backgroundColor('#1F252699');
    }.width('100%').height(240).borderRadius(this.theme.radius.xl).clip(true)
      .onClick(() => { if (this.model.enabled) { emitAction(this.model.id, this.onEvent, 'press'); } });
  }
}

@ComponentV2
export struct SemanticSection {
  @Param @Require model: SemanticTextModel;
  @Param theme: SemanticTheme = createSemanticTheme(SemanticThemeMode.LIGHT);
  @BuilderParam header: () => void;
  @BuilderParam body: () => void;
  build() {
    Column({ space: this.theme.spacing.sm }) { this.header(); this.body(); }.width('100%').padding({ top: this.theme.spacing.sm, bottom: this.theme.spacing.sm });
  }
}

@ComponentV2
export struct SectionHeader {
  @Param @Require model: SemanticTextModel;
  @Param theme: SemanticTheme = createSemanticTheme(SemanticThemeMode.LIGHT);
  @Event onEvent: (event: SemanticUiEvent) => void = () => {};
  build() {
    Row() { Column({ space: 2 }) { Text(this.model.title).fontSize(this.theme.typography.title).fontWeight(FontWeight.Bold).fontColor(this.theme.colors.textPrimary); if (this.model.subtitle.length > 0) { Text(this.model.subtitle).fontSize(this.theme.typography.caption).fontColor(this.theme.colors.textSecondary); } }.layoutWeight(1); if (this.model.actions.length > 0) { Button(this.model.actions[0].label).fontSize(this.theme.typography.caption).backgroundColor(Color.Transparent).fontColor(this.theme.colors.primary).onClick(() => { emitAction(this.model.id, this.onEvent, this.model.actions[0].id); }); } }.width('100%');
  }
}

@ComponentV2
export struct SummaryCard {
  @Param @Require model: SemanticTextModel;
  @Param theme: SemanticTheme = createSemanticTheme(SemanticThemeMode.LIGHT);
  @Event onEvent: (event: SemanticUiEvent) => void = () => {};
  build() { this.CardContent(); }
  @Builder CardContent() { Column({ space: this.theme.spacing.sm }) { Text(this.model.title).fontSize(this.theme.typography.title).fontWeight(FontWeight.Bold).fontColor(this.theme.colors.textPrimary); Text(this.model.body.length > 0 ? this.model.body : this.model.value).fontSize(this.theme.typography.body).fontColor(this.theme.colors.textSecondary); }.width('100%').padding(this.theme.spacing.md).backgroundColor(this.theme.colors.surfaceElevated).borderRadius(this.theme.radius.lg).border({ width: 1, color: this.theme.colors.border }).onClick(() => { if (this.model.enabled) { emitAction(this.model.id, this.onEvent, 'open'); } }); }
}

@ComponentV2
export struct InfoCard {
  @Param @Require model: SemanticTextModel;
  @Param theme: SemanticTheme = createSemanticTheme(SemanticThemeMode.LIGHT);
  @Event onEvent: (event: SemanticUiEvent) => void = () => {};
  build() { Column({ space: this.theme.spacing.xs }) { Text(this.model.title).fontSize(this.theme.typography.title).fontWeight(FontWeight.Bold).fontColor(this.theme.colors.textPrimary); Text(this.model.body).fontSize(this.theme.typography.body).fontColor(this.theme.colors.textSecondary); }.width('100%').padding(componentPadding(this.theme, this.model.density)).backgroundColor(surfaceBackground(this.theme, this.model.tone)).borderRadius(this.theme.radius.md).onClick(() => { if (this.model.enabled) { emitAction(this.model.id, this.onEvent, 'open'); } }); }
}

@ComponentV2
export struct MetricCard {
  @Param @Require model: SemanticMetricItem;
  @Param theme: SemanticTheme = createSemanticTheme(SemanticThemeMode.LIGHT);
  @Event onEvent: (event: SemanticUiEvent) => void = () => {};
  build() { Column({ space: this.theme.spacing.xs }) { Text(this.model.label).fontSize(this.theme.typography.caption).fontColor(this.theme.colors.textSecondary); Text(this.model.value).fontSize(this.theme.typography.headline).fontWeight(FontWeight.Bold).fontColor(foregroundColor(this.theme, this.model.tone)); if (this.model.detail.length > 0) { Text(this.model.detail).fontSize(this.theme.typography.caption).fontColor(this.theme.colors.textSecondary); } }.padding(this.theme.spacing.md).layoutWeight(1).backgroundColor(this.theme.colors.surfaceElevated).borderRadius(this.theme.radius.md).onClick(() => { this.onEvent(createSemanticEvent(this.model.id, 'action', actionPayload('open'))); }); }
}

@ComponentV2
export struct MetricGrid {
  @Param @Require model: SemanticListModel<SemanticMetricItem>;
  @Param theme: SemanticTheme = createSemanticTheme(SemanticThemeMode.LIGHT);
  @Event onEvent: (event: SemanticUiEvent) => void = () => {};
  build() { GridRow({ columns: 2, gutter: this.theme.spacing.sm }) { ForEach(this.model.items, (item: SemanticMetricItem, index: number) => { GridCol() { MetricCard({ model: item, theme: this.theme, onEvent: (event: SemanticUiEvent) => { this.onEvent(createSemanticEvent(this.model.id, 'select', itemPayload(item.id, index))); } }); } }, (item: SemanticMetricItem) => item.id); }.width('100%'); }
}

@ComponentV2
export struct KeyValueList {
  @Param @Require model: SemanticListModel<SemanticKeyValueItem>;
  @Param theme: SemanticTheme = createSemanticTheme(SemanticThemeMode.LIGHT);
  build() { Column({ space: this.theme.spacing.xs }) { ForEach(this.model.items, (item: SemanticKeyValueItem) => { Row() { Text(item.key).fontSize(this.theme.typography.body).fontColor(this.theme.colors.textSecondary).layoutWeight(1); Text(item.value).fontSize(this.theme.typography.body).fontColor(this.theme.colors.textPrimary); }.width('100%').padding({ top: this.theme.spacing.sm, bottom: this.theme.spacing.sm }).border({ width: { bottom: 1 }, color: { bottom: this.theme.colors.divider } }); }, (item: SemanticKeyValueItem) => item.id); }.width('100%'); }
}

@ComponentV2
export struct Callout {
  @Param @Require model: SemanticTextModel;
  @Param theme: SemanticTheme = createSemanticTheme(SemanticThemeMode.LIGHT);
  @Event onEvent: (event: SemanticUiEvent) => void = () => {};
  build() { Row({ space: this.theme.spacing.sm }) { Text('i').fontSize(this.theme.typography.title).fontWeight(FontWeight.Bold).fontColor(foregroundColor(this.theme, this.model.tone)); Column({ space: 3 }) { Text(this.model.title).fontSize(this.theme.typography.label).fontWeight(FontWeight.Bold).fontColor(this.theme.colors.textPrimary); Text(this.model.body).fontSize(this.theme.typography.body).fontColor(this.theme.colors.textSecondary); }.layoutWeight(1); }.width('100%').padding(this.theme.spacing.md).backgroundColor(surfaceBackground(this.theme, this.model.tone)).borderRadius(this.theme.radius.md).onClick(() => { if (this.model.enabled) { emitAction(this.model.id, this.onEvent, 'open'); } }); }
}

@ComponentV2
export struct EmptyState {
  @Param @Require model: SemanticTextModel;
  @Param theme: SemanticTheme = createSemanticTheme(SemanticThemeMode.LIGHT);
  @Event onEvent: (event: SemanticUiEvent) => void = () => {};
  build() { Column({ space: this.theme.spacing.sm }) { Text('○').fontSize(34).fontColor(this.theme.colors.primary); Text(this.model.title.length > 0 ? this.model.title : '暂无内容').fontSize(this.theme.typography.title).fontWeight(FontWeight.Bold).fontColor(this.theme.colors.textPrimary); Text(this.model.body).fontSize(this.theme.typography.body).fontColor(this.theme.colors.textSecondary); if (this.model.actions.length > 0) { Button(this.model.actions[0].label).backgroundColor(this.theme.colors.primary).fontColor(this.theme.colors.onPrimary).onClick(() => { emitAction(this.model.id, this.onEvent, this.model.actions[0].id); }); } }.width('100%').padding(this.theme.spacing.xl).alignItems(HorizontalAlign.Center); }
}

@ComponentV2
export struct ErrorState {
  @Param @Require model: SemanticTextModel;
  @Param theme: SemanticTheme = createSemanticTheme(SemanticThemeMode.LIGHT);
  @Event onEvent: (event: SemanticUiEvent) => void = () => {};
  build() { Column({ space: this.theme.spacing.sm }) { Text('!').fontSize(30).fontColor(this.theme.colors.danger); Text(this.model.title.length > 0 ? this.model.title : '加载失败').fontSize(this.theme.typography.title).fontWeight(FontWeight.Bold).fontColor(this.theme.colors.textPrimary); Text(this.model.body).fontSize(this.theme.typography.body).fontColor(this.theme.colors.textSecondary); Button('重试').backgroundColor(this.theme.colors.danger).fontColor(this.theme.colors.onPrimary).onClick(() => { if (this.model.enabled) { this.onEvent(createSemanticEvent(this.model.id, 'retry')); } }); }.width('100%').padding(this.theme.spacing.xl).alignItems(HorizontalAlign.Center); }
}

@ComponentV2
export struct LoadingState {
  @Param @Require model: SemanticTextModel;
  @Param theme: SemanticTheme = createSemanticTheme(SemanticThemeMode.LIGHT);
  build() { Column({ space: this.theme.spacing.sm }) { LoadingProgress().color(this.theme.colors.primary); Text(this.model.title.length > 0 ? this.model.title : '正在加载').fontSize(this.theme.typography.body).fontColor(this.theme.colors.textSecondary); if (this.model.progress > 0) { Progress({ value: this.model.progress, total: 100, type: ProgressType.Linear }).width('100%').color(this.theme.colors.primary); } }.width('100%').padding(this.theme.spacing.xl).alignItems(HorizontalAlign.Center); }
}
