import { SemanticUiEvent, actionPayload, createSemanticEvent } from '../foundation/SemanticEvents';
import { SemanticDensity, SemanticThemeMode, SemanticTone } from '../foundation/SemanticEnums';
import { SemanticTheme, createSemanticTheme, toneColor } from '../foundation/SemanticTheme';
import { componentPadding, foregroundColor, surfaceBackground } from '../foundation/SemanticStyles';

@ComponentV2
export struct SemanticSurface {
  @Param theme: SemanticTheme = createSemanticTheme(SemanticThemeMode.LIGHT);
  @Param tone: SemanticTone = SemanticTone.NEUTRAL;
  @Param title: string = '';
  @Param body: string = '';

  build() {
    Column({ space: this.theme.spacing.sm }) {
      if (this.title.length > 0) { Text(this.title).fontSize(this.theme.typography.title).fontWeight(FontWeight.Bold).fontColor(this.theme.colors.textPrimary); }
      if (this.body.length > 0) { Text(this.body).fontSize(this.theme.typography.body).fontColor(this.theme.colors.textSecondary); }
    }
    .width('100%')
    .padding(this.theme.spacing.md)
    .backgroundColor(surfaceBackground(this.theme, this.tone))
    .borderRadius(this.theme.radius.lg)
    .border({ width: 1, color: this.theme.colors.border });
  }
}

@ComponentV2
export struct SemanticText {
  @Param theme: SemanticTheme = createSemanticTheme(SemanticThemeMode.LIGHT);
  @Param text: string = '';
  @Param textSize: number = 15;
  @Param color: string = '';

  build() {
    Text(this.text).fontSize(this.textSize).fontColor(this.color.length > 0 ? this.color : this.theme.colors.textPrimary);
  }
}

@ComponentV2
export struct SemanticIcon {
  @Param theme: SemanticTheme = createSemanticTheme(SemanticThemeMode.LIGHT);
  @Param glyph: string = '';
  @Param iconSize: number = 18;

  build() {
    Text(this.glyph).fontSize(this.iconSize).fontColor(this.theme.colors.primary).width(this.iconSize + 8).textAlign(TextAlign.Center);
  }
}

@ComponentV2
export struct SemanticButton {
  @Param theme: SemanticTheme = createSemanticTheme(SemanticThemeMode.LIGHT);
  @Param label: string = '';
  @Param isEnabled: boolean = true;
  @Event onEvent: (event: SemanticUiEvent) => void = () => {};

  build() {
    Button(this.label)
      .enabled(this.isEnabled)
      .fontColor(this.theme.colors.onPrimary)
      .backgroundColor(this.theme.colors.primary)
      .borderRadius(this.theme.radius.pill)
      .onClick(() => {
        if (this.isEnabled) { this.onEvent(createSemanticEvent('', 'action', actionPayload(this.label))); }
      });
  }
}

@ComponentV2
export struct SemanticBadge {
  @Param theme: SemanticTheme = createSemanticTheme(SemanticThemeMode.LIGHT);
  @Param label: string = '';
  @Param tone: SemanticTone = SemanticTone.NEUTRAL;

  build() {
    Text(this.label).fontSize(this.theme.typography.caption).fontColor(foregroundColor(this.theme, this.tone))
      .padding({ left: this.theme.spacing.sm, right: this.theme.spacing.sm, top: 3, bottom: 3 })
      .backgroundColor(surfaceBackground(this.theme, this.tone)).borderRadius(this.theme.radius.pill);
  }
}

@ComponentV2
export struct SemanticDivider {
  @Param theme: SemanticTheme = createSemanticTheme(SemanticThemeMode.LIGHT);

  build() {
    Divider().strokeWidth(1).color(this.theme.colors.divider).width('100%');
  }
}

@ComponentV2
export struct SemanticListRow {
  @Param theme: SemanticTheme = createSemanticTheme(SemanticThemeMode.LIGHT);
  @Param title: string = '';
  @Param subtitle: string = '';
  @Param isEnabled: boolean = true;
  @Event onEvent: (event: SemanticUiEvent) => void = () => {};

  build() {
    Row({ space: this.theme.spacing.sm }) {
      Column({ space: 3 }) {
        Text(this.title).fontSize(this.theme.typography.body).fontColor(this.theme.colors.textPrimary);
        if (this.subtitle.length > 0) { Text(this.subtitle).fontSize(this.theme.typography.caption).fontColor(this.theme.colors.textSecondary); }
      }.layoutWeight(1)
      Text('›').fontSize(20).fontColor(this.theme.colors.textSecondary);
    }
    .width('100%')
    .padding(componentPadding(this.theme, SemanticDensity.COMFORTABLE))
    .enabled(this.isEnabled)
    .onClick(() => { if (this.isEnabled) { this.onEvent(createSemanticEvent('', 'select')); } });
  }
}

@ComponentV2
export struct SemanticFieldFrame {
  @Param theme: SemanticTheme = createSemanticTheme(SemanticThemeMode.LIGHT);
  @Param label: string = '';
  @Param helper: string = '';
  @Param error: string = '';
  @Param required: boolean = false;

  build() {
    Column({ space: this.theme.spacing.xs }) {
      Text(this.label + (this.required ? ' *' : '')).fontSize(this.theme.typography.label).fontColor(this.theme.colors.textSecondary);
      if (this.error.length > 0) { Text(this.error).fontSize(this.theme.typography.caption).fontColor(this.theme.colors.danger); }
      else if (this.helper.length > 0) { Text(this.helper).fontSize(this.theme.typography.caption).fontColor(this.theme.colors.textSecondary); }
    }.width('100%');
  }
}

@ComponentV2
export struct SemanticOverlayHost {
  @Param theme: SemanticTheme = createSemanticTheme(SemanticThemeMode.LIGHT);
  @Param visible: boolean = false;
  @Param title: string = '';
  @Param body: string = '';
  @Event onEvent: (event: SemanticUiEvent) => void = () => {};

  build() {
    if (this.visible) {
      Stack({ alignContent: Alignment.Bottom }) {
        Column().backgroundColor(this.theme.colors.scrim).width('100%').height('100%');
        Column({ space: this.theme.spacing.sm }) {
          Text(this.title).fontSize(this.theme.typography.title).fontWeight(FontWeight.Bold).fontColor(this.theme.colors.textPrimary);
          Text(this.body).fontSize(this.theme.typography.body).fontColor(this.theme.colors.textSecondary);
          Button('关闭').onClick(() => { this.onEvent(createSemanticEvent('', 'dismiss')); });
        }.width('100%').padding(this.theme.spacing.lg).backgroundColor(this.theme.colors.surfaceElevated).borderRadius({ topLeft: this.theme.radius.xl, topRight: this.theme.radius.xl });
      }.width('100%').height('100%');
    }
  }
}

@ComponentV2
export struct SemanticChartCanvas {
  @Param theme: SemanticTheme = createSemanticTheme(SemanticThemeMode.LIGHT);
  @Param values: number[] = [];
  @Param chartHeight: number = 160;

  build() {
    Column() {
      Row({ space: 4 }) {
        ForEach(this.safeValues(), (value: number) => {
          Column().layoutWeight(1).height(Math.max(4, Math.min(this.chartHeight, value))).backgroundColor(this.theme.colors.primary).borderRadius(this.theme.radius.sm);
        }, (value: number, index: number) => 'bar-' + index.toString() + '-' + value.toString());
      }.alignItems(VerticalAlign.Bottom).width('100%').height(this.chartHeight);
      Text('图表数据可视化摘要').fontSize(this.theme.typography.caption).fontColor(this.theme.colors.textSecondary);
    }.width('100%');
  }

  private safeValues(): number[] {
    let result: number[] = [];
    for (let i: number = 0; i < this.values.length; i++) {
      let value: number = Number.isFinite(this.values[i]) ? this.values[i] : 0;
      result.push(Math.max(0, value));
    }
    return result;
  }
}

@ComponentV2
export struct SemanticImage {
  @Param theme: SemanticTheme = createSemanticTheme(SemanticThemeMode.LIGHT);
  @Param source: string = '';
  @Param alt: string = '';

  build() {
    if (this.isLocalSource()) { Image(this.source).width('100%').height(160).objectFit(ImageFit.Cover).borderRadius(this.theme.radius.lg); }
    else { Column() { Text(this.alt.length > 0 ? this.alt : '本地图片').fontColor(this.theme.colors.textSecondary); }.width('100%').height(160).justifyContent(FlexAlign.Center).backgroundColor(this.theme.colors.surfaceMuted).borderRadius(this.theme.radius.lg); }
  }

  private isLocalSource(): boolean {
    if (typeof this.source !== 'string') { return true; }
    return !this.source.startsWith('http://') && !this.source.startsWith('https://') && this.source.length > 0;
  }
}

@ComponentV2
export struct SemanticSkeleton {
  @Param theme: SemanticTheme = createSemanticTheme(SemanticThemeMode.LIGHT);
  @Param blockHeight: number = 20;

  build() {
    Column().width('100%').height(Math.max(4, this.blockHeight)).backgroundColor(this.theme.colors.surfaceMuted).borderRadius(this.theme.radius.sm);
  }
}
