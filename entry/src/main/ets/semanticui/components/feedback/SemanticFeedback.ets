import { SemanticUiEvent, createSemanticEvent } from '../../foundation/SemanticEvents';
import { SemanticTheme, createSemanticTheme } from '../../foundation/SemanticTheme';
import { SemanticThemeMode, SemanticOverlayKind, SemanticTone, SemanticViewStatus } from '../../foundation/SemanticEnums';
import { SemanticActionModel, SemanticOverlayModel } from '../../foundation/SemanticModels';
import { SemanticButton, SemanticOverlayHost, SemanticSurface } from '../../internal/SemanticAtoms';

@ComponentV2
export struct StatusBanner {
  @Param model: SemanticOverlayModel = new SemanticOverlayModel();
  @Param theme: SemanticTheme = createSemanticTheme(SemanticThemeMode.LIGHT);
  @Event onEvent: (event: SemanticUiEvent) => void = () => {};
  build() { Row({ space: this.theme.spacing.sm }) { Text(this.model.title).fontWeight(FontWeight.Bold); Text(this.model.body).fontColor(this.theme.colors.textSecondary).layoutWeight(1); if (this.model.cancellable) { Button('关闭').onClick(() => this.onEvent(createSemanticEvent(this.model.id, 'dismiss'))); } }.width('100%').padding(this.theme.spacing.md).backgroundColor(this.bannerColor()).borderRadius(this.theme.radius.md); }
  private bannerColor(): string { if (this.model.tone === SemanticTone.DANGER) { return this.theme.colors.dangerSoft; } if (this.model.tone === SemanticTone.WARNING) { return this.theme.colors.warningSoft; } return this.theme.colors.primarySoft; }
}

@ComponentV2
export struct Snackbar {
  @Param model: SemanticOverlayModel = new SemanticOverlayModel();
  @Param theme: SemanticTheme = createSemanticTheme(SemanticThemeMode.LIGHT);
  @Event onEvent: (event: SemanticUiEvent) => void = () => {};
  build() { if (this.model.status !== SemanticViewStatus.DISABLED) { Row({ space: this.theme.spacing.sm }) { Text(this.model.body || this.model.title).layoutWeight(1).fontColor(this.theme.colors.onPrimary); Button('关闭').fontColor(this.theme.colors.onPrimary).backgroundColor(Color.Transparent).onClick(() => this.onEvent(createSemanticEvent(this.model.id, 'dismiss'))); }.width('92%').padding(this.theme.spacing.md).backgroundColor(this.theme.colors.textPrimary).borderRadius(this.theme.radius.md); } }
}

@ComponentV2
export struct ConfirmationDialog {
  @Param model: SemanticOverlayModel = new SemanticOverlayModel();
  @Param theme: SemanticTheme = createSemanticTheme(SemanticThemeMode.LIGHT);
  @Event onEvent: (event: SemanticUiEvent) => void = () => {};
  build() { Column({ space: this.theme.spacing.sm }) { Text(this.model.title).fontSize(this.theme.typography.title).fontWeight(FontWeight.Bold); Text(this.model.body).fontColor(this.theme.colors.textSecondary); Row({ space: this.theme.spacing.sm }) { ForEach(this.model.actions, (item: SemanticActionModel) => { SemanticButton({ theme: this.theme, label: item.label, isEnabled: item.enabled, onEvent: () => this.onEvent(createSemanticEvent(item.id, 'press')) }); }, (item: SemanticActionModel) => item.id); }.width('100%'); }.width('100%').padding(this.theme.spacing.lg).backgroundColor(this.theme.colors.surfaceElevated).borderRadius(this.theme.radius.xl); }
}

@ComponentV2
export struct BottomSheet {
  @Param model: SemanticOverlayModel = new SemanticOverlayModel();
  @Param theme: SemanticTheme = createSemanticTheme(SemanticThemeMode.LIGHT);
  @Event onEvent: (event: SemanticUiEvent) => void = () => {};
  build() { SemanticOverlayHost({ theme: this.theme, visible: this.model.status !== SemanticViewStatus.DISABLED, title: this.model.title, body: this.model.body, onEvent: this.onEvent }); }
}

@ComponentV2
export struct ActionSheet {
  @Param model: SemanticOverlayModel = new SemanticOverlayModel();
  @Param theme: SemanticTheme = createSemanticTheme(SemanticThemeMode.LIGHT);
  @Event onEvent: (event: SemanticUiEvent) => void = () => {};
  build() { Column({ space: this.theme.spacing.xs }) { Text(this.model.title).fontSize(this.theme.typography.title).fontWeight(FontWeight.Bold); ForEach(this.model.actions, (item: SemanticActionModel) => { Button(item.label).width('100%').enabled(item.enabled).onClick(() => this.onEvent(createSemanticEvent(item.id, 'press'))); }, (item: SemanticActionModel) => item.id); }.width('100%').padding(this.theme.spacing.lg).backgroundColor(this.theme.colors.surfaceElevated).borderRadius({ topLeft: this.theme.radius.xl, topRight: this.theme.radius.xl }); }
}

@ComponentV2
export struct LoadingOverlay {
  @Param model: SemanticOverlayModel = new SemanticOverlayModel();
  @Param theme: SemanticTheme = createSemanticTheme(SemanticThemeMode.LIGHT);
  @Event onEvent: (event: SemanticUiEvent) => void = () => {};
  build() { if (this.model.status === SemanticViewStatus.LOADING) { Stack() { Column().backgroundColor(this.theme.colors.scrim).width('100%').height('100%'); Column({ space: this.theme.spacing.sm }) { LoadingProgress().width(44).height(44); Text(this.model.title || '处理中…').fontColor(this.theme.colors.onPrimary); if (this.model.cancellable) { Button('取消').onClick(() => this.onEvent(createSemanticEvent(this.model.id, 'cancel'))); } }.justifyContent(FlexAlign.Center).width('100%').height('100%'); }.width('100%').height('100%'); } }
}
