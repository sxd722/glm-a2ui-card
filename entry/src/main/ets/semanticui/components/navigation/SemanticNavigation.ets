import { SemanticUiEvent, actionPayload, createSemanticEvent, itemPayload } from '../../foundation/SemanticEvents';
import { SemanticActionModel, SemanticComponentBaseModel, SemanticListModel, SemanticOptionModel, SemanticTextModel } from '../../foundation/SemanticModels';
import { SemanticActionStyle, SemanticThemeMode } from '../../foundation/SemanticEnums';
import { SemanticTheme, createSemanticTheme } from '../../foundation/SemanticTheme';
import { componentPadding } from '../../foundation/SemanticStyles';

@ComponentV2
export struct TopAppBar {
  @Param @Require model: SemanticTextModel;
  @Param theme: SemanticTheme = createSemanticTheme(SemanticThemeMode.LIGHT);
  @Event onEvent: (event: SemanticUiEvent) => void = () => {};
  build() {
    Row({ space: this.theme.spacing.sm }) {
      Button('‹').width(40).height(40).backgroundColor(Color.Transparent).fontColor(this.theme.colors.textPrimary)
        .onClick(() => { this.onEvent(createSemanticEvent(this.model.id, 'back')); });
      Column({ space: 2 }) {
        Text(this.model.title).fontSize(this.theme.typography.title).fontWeight(FontWeight.Bold).fontColor(this.theme.colors.textPrimary);
        if (this.model.subtitle.length > 0) { Text(this.model.subtitle).fontSize(this.theme.typography.caption).fontColor(this.theme.colors.textSecondary); }
      }.layoutWeight(1);
      Button('⋯').width(40).height(40).backgroundColor(Color.Transparent).fontColor(this.theme.colors.textPrimary)
        .onClick(() => { this.onEvent(createSemanticEvent(this.model.id, 'action', actionPayload('more'))); });
    }.width('100%').padding({ top: this.theme.spacing.sm, bottom: this.theme.spacing.sm });
  }
}

@ComponentV2
export struct PageHeader {
  @Param @Require model: SemanticTextModel;
  @Param theme: SemanticTheme = createSemanticTheme(SemanticThemeMode.LIGHT);
  @Event onEvent: (event: SemanticUiEvent) => void = () => {};
  build() {
    Column({ space: this.theme.spacing.xs }) {
      Text(this.model.title).fontSize(this.theme.typography.headline).fontWeight(FontWeight.Bold).fontColor(this.theme.colors.textPrimary);
      if (this.model.subtitle.length > 0) { Text(this.model.subtitle).fontSize(this.theme.typography.body).fontColor(this.theme.colors.textSecondary); }
      if (this.model.body.length > 0) { Text(this.model.body).fontSize(this.theme.typography.caption).fontColor(this.theme.colors.textSecondary); }
    }.width('100%').alignItems(HorizontalAlign.Start);
  }
}

@ComponentV2
export struct BottomNavigation {
  @Param @Require model: SemanticListModel<SemanticOptionModel>;
  @Param theme: SemanticTheme = createSemanticTheme(SemanticThemeMode.LIGHT);
  @Event onEvent: (event: SemanticUiEvent) => void = () => {};
  build() {
    Row({ space: this.theme.spacing.xs }) {
      ForEach(this.model.items, (item: SemanticOptionModel, index: number) => {
        Text(item.label).layoutWeight(1).textAlign(TextAlign.Center).fontSize(this.theme.typography.caption)
          .fontColor(item.selected ? this.theme.colors.primary : this.theme.colors.textSecondary)
          .padding(this.theme.spacing.sm).onClick(() => { if (this.model.enabled && item.enabled) { this.emit('select', item, index); } });
      }, (item: SemanticOptionModel) => item.id);
    }.width('100%').backgroundColor(this.theme.colors.surfaceElevated).border({ width: 1, color: this.theme.colors.divider });
  }
  private emit(name: string, item: SemanticOptionModel, index: number): void { this.onEvent(createSemanticEvent(this.model.id, name, itemPayload(item.id, index))); }
}

@ComponentV2
export struct TabNavigation {
  @Param @Require model: SemanticListModel<SemanticOptionModel>;
  @Param theme: SemanticTheme = createSemanticTheme(SemanticThemeMode.LIGHT);
  @Event onEvent: (event: SemanticUiEvent) => void = () => {};
  build() {
    Scroll() {
      Row({ space: this.theme.spacing.sm }) {
        ForEach(this.model.items, (item: SemanticOptionModel, index: number) => {
          Text(item.label).fontSize(this.theme.typography.label).fontColor(item.selected ? this.theme.colors.primary : this.theme.colors.textSecondary)
            .padding({ left: this.theme.spacing.md, right: this.theme.spacing.md, top: this.theme.spacing.sm, bottom: this.theme.spacing.sm })
            .backgroundColor(item.selected ? this.theme.colors.surfaceMuted : Color.Transparent).borderRadius(this.theme.radius.pill)
            .onClick(() => { if (this.model.enabled && item.enabled) { this.onEvent(createSemanticEvent(this.model.id, 'select', itemPayload(item.id, index))); } });
        }, (item: SemanticOptionModel) => item.id);
      }
    }.scrollable(ScrollDirection.Horizontal).scrollBar(BarState.Off).width('100%');
  }
}

@ComponentV2
export struct SegmentedNavigation {
  @Param @Require model: SemanticListModel<SemanticOptionModel>;
  @Param theme: SemanticTheme = createSemanticTheme(SemanticThemeMode.LIGHT);
  @Event onEvent: (event: SemanticUiEvent) => void = () => {};
  build() {
    Row() {
      ForEach(this.model.items, (item: SemanticOptionModel, index: number) => {
        Button(item.label).layoutWeight(1).fontSize(this.theme.typography.caption).backgroundColor(item.selected ? this.theme.colors.primary : this.theme.colors.surfaceMuted)
          .fontColor(item.selected ? this.theme.colors.onPrimary : this.theme.colors.textSecondary).onClick(() => { if (this.model.enabled) { this.onEvent(createSemanticEvent(this.model.id, 'change', itemPayload(item.id, index))); } });
      }, (item: SemanticOptionModel) => item.id);
    }.width('100%').padding(3).backgroundColor(this.theme.colors.surfaceMuted).borderRadius(this.theme.radius.md);
  }
}

@ComponentV2
export struct StepperNavigation {
  @Param @Require model: SemanticListModel<SemanticOptionModel>;
  @Param theme: SemanticTheme = createSemanticTheme(SemanticThemeMode.LIGHT);
  @Event onEvent: (event: SemanticUiEvent) => void = () => {};
  build() {
    Row({ space: this.theme.spacing.xs }) {
      ForEach(this.model.items, (item: SemanticOptionModel, index: number) => {
        Row({ space: 3 }) { Text((index + 1).toString()).fontColor(item.selected ? this.theme.colors.onPrimary : this.theme.colors.textSecondary); Text(item.label).fontSize(this.theme.typography.caption); }
          .padding(this.theme.spacing.sm).backgroundColor(item.selected ? this.theme.colors.primary : this.theme.colors.surfaceMuted).borderRadius(this.theme.radius.pill)
          .onClick(() => { if (this.model.enabled) { this.onEvent(createSemanticEvent(this.model.id, 'selectStep', itemPayload(item.id, index))); } });
      }, (item: SemanticOptionModel) => item.id);
    }.width('100%');
  }
}

@ComponentV2
export struct FilterBar {
  @Param @Require model: SemanticListModel<SemanticOptionModel>;
  @Param theme: SemanticTheme = createSemanticTheme(SemanticThemeMode.LIGHT);
  @Event onEvent: (event: SemanticUiEvent) => void = () => {};
  build() {
    Row({ space: this.theme.spacing.sm }) {
      Scroll() {
        Row({ space: this.theme.spacing.sm }) {
          ForEach(this.model.items, (item: SemanticOptionModel, index: number) => {
            Text(item.label).fontSize(this.theme.typography.caption).fontColor(item.selected ? this.theme.colors.onPrimary : this.theme.colors.textSecondary)
              .padding({ left: this.theme.spacing.sm, right: this.theme.spacing.sm, top: 5, bottom: 5 }).backgroundColor(item.selected ? this.theme.colors.primary : this.theme.colors.surfaceMuted).borderRadius(this.theme.radius.pill)
              .onClick(() => { if (this.model.enabled) { this.onEvent(createSemanticEvent(this.model.id, 'change', itemPayload(item.id, index))); } });
          }, (item: SemanticOptionModel) => item.id);
        }
      }.layoutWeight(1).scrollable(ScrollDirection.Horizontal).scrollBar(BarState.Off);
      Button('清除').fontSize(this.theme.typography.caption).backgroundColor(Color.Transparent).fontColor(this.theme.colors.primary)
        .onClick(() => { if (this.model.enabled) { this.onEvent(createSemanticEvent(this.model.id, 'clear')); } });
    }.width('100%');
  }
}

@ComponentV2
export struct BottomActionBar {
  @Param @Require model: SemanticTextModel;
  @Param theme: SemanticTheme = createSemanticTheme(SemanticThemeMode.LIGHT);
  @Event onEvent: (event: SemanticUiEvent) => void = () => {};
  build() {
    Row({ space: this.theme.spacing.sm }) {
      ForEach(this.model.actions, (action: SemanticActionModel) => {
        Button(action.label).layoutWeight(1).enabled(this.model.enabled && action.enabled)
          .backgroundColor(action.style === SemanticActionStyle.PRIMARY ? this.theme.colors.primary : this.theme.colors.surfaceMuted)
          .fontColor(action.style === SemanticActionStyle.PRIMARY ? this.theme.colors.onPrimary : this.theme.colors.textPrimary)
          .onClick(() => { if (this.model.enabled && action.enabled) { this.onEvent(createSemanticEvent(this.model.id, 'action', actionPayload(action.id))); } });
      }, (action: SemanticActionModel) => action.id);
    }.width('100%').padding(componentPadding(this.theme, this.model.density)).backgroundColor(this.theme.colors.surfaceElevated)
      .shadow({ radius: this.theme.elevation.medium, color: '#00000018', offsetX: 0, offsetY: -2 });
  }
}
