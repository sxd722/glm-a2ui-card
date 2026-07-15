import { ArkUiAction, ArkUiSessionState, CompiledArkUiNode, LocalCondition, LocalImageAsset } from '../services/ArkUiTypes';

@Component
export struct ArkUiNodeRenderer {
  @Require @Prop node: CompiledArkUiNode;
  @Require @Prop session: ArkUiSessionState;
  onAction: (action: ArkUiAction) => void = (action: ArkUiAction): void => {};
  onValueChange: (key: string, value: string) => void = (key: string, value: string): void => {};

  build() {
    if (!this.isNodeVisible()) {
      Blank().width(0).height(0)
    } else if (this.node.type === 'Column' || this.node.type === 'List' || this.node.type === 'Scroll') {
      Column({ space: this.node.style.gap }) {
        this.RenderChildren()
      }
      .width('100%')
      .alignItems(this.horizontalAlign())
      .justifyContent(this.justifyAlign())
      .padding(this.paddingValue())
      .margin(this.marginValue())
      .backgroundColor(this.node.style.backgroundColor)
      .borderRadius(this.node.style.borderRadius)
      .border({ width: this.node.style.borderWidth, color: this.node.style.borderColor })
      .opacity(this.node.style.opacity)
      .shadow({ radius: this.node.style.shadowRadius, color: this.node.style.shadowColor,
        offsetX: 0, offsetY: this.node.style.shadowOffsetY })
      .backgroundBlurStyle(this.blurStyle())
    } else if (this.node.type === 'Row') {
      Row({ space: this.node.style.gap }) {
        this.RenderChildren()
      }
      .width('100%')
      .alignItems(this.verticalAlign())
      .justifyContent(this.justifyAlign())
      .padding(this.paddingValue())
      .margin(this.marginValue())
      .backgroundColor(this.node.style.backgroundColor)
      .borderRadius(this.node.style.borderRadius)
      .border({ width: this.node.style.borderWidth, color: this.node.style.borderColor })
      .opacity(this.node.style.opacity)
      .backgroundBlurStyle(this.blurStyle())
    } else if (this.node.type === 'Stack') {
      Stack({ alignContent: Alignment.BottomStart }) {
        this.RenderChildren()
      }
      .width('100%')
      .height(this.node.style.height > 0 ? this.node.style.height : 180)
      .padding(this.paddingValue())
      .margin(this.marginValue())
      .backgroundColor(this.node.style.backgroundColor)
      .borderRadius(this.node.style.borderRadius)
      .border({ width: this.node.style.borderWidth, color: this.node.style.borderColor })
      .opacity(this.node.style.opacity)
      .shadow({ radius: this.node.style.shadowRadius, color: this.node.style.shadowColor,
        offsetX: 0, offsetY: this.node.style.shadowOffsetY })
      .backgroundBlurStyle(this.blurStyle())
    } else if (this.node.type === 'Text' || this.node.type === 'Badge') {
      Text(this.displayText())
        .fontSize(this.node.style.fontSize)
        .fontWeight(this.fontWeight())
        .fontColor(this.node.style.foregroundColor)
        .textAlign(this.textAlign())
        .width(this.node.style.widthFull || this.node.type === 'Badge' ? '100%' : undefined)
        .padding(this.paddingValue())
        .margin(this.marginValue())
        .backgroundColor(this.node.style.backgroundColor)
        .borderRadius(this.node.style.borderRadius)
        .border({ width: this.node.style.borderWidth, color: this.node.style.borderColor })
        .opacity(this.node.style.opacity)
    } else if (this.node.type === 'Image') {
      if (this.imageSource().length > 0) {
        Image(this.imageSource())
          .width('100%')
          .height(this.node.style.height > 0 ? this.node.style.height : 160)
          .objectFit(this.node.style.objectFit === 'contain' ? ImageFit.Contain : ImageFit.Cover)
          .borderRadius(this.node.style.borderRadius)
          .opacity(this.node.style.opacity)
          .onClick(() => { this.invokeFirstAction(); })
      } else {
        Column({ space: 8 }) {
          Text(this.prop('placeholder').length > 0 ? this.prop('placeholder') : '选择本地图片')
            .fontSize(13).fontColor(this.node.style.foregroundColor)
        }
        .justifyContent(FlexAlign.Center)
        .width('100%')
        .height(this.node.style.height > 0 ? this.node.style.height : 120)
        .backgroundColor(this.node.style.backgroundColor)
        .borderRadius(this.node.style.borderRadius)
        .onClick(() => { this.invokeFirstAction(); })
      }
    } else if (this.node.type === 'Button') {
      Button(this.displayText())
        .height(this.node.style.height > 0 ? this.node.style.height : 46)
        .layoutWeight(this.node.style.layoutWeight > 0 ? this.node.style.layoutWeight : 1)
        .fontSize(this.node.style.fontSize)
        .fontWeight(this.fontWeight())
        .fontColor(this.node.style.foregroundColor)
        .backgroundColor(this.node.style.backgroundColor)
        .borderRadius(this.node.style.borderRadius)
        .padding(this.paddingValue())
        .enabled(this.isNodeEnabled())
        .onClick(() => { this.invokeFirstAction(); })
    } else if (this.node.type === 'TextInput') {
      TextInput({ text: this.boundValue(), placeholder: this.prop('placeholder') })
        .width('100%')
        .height(this.node.style.height > 0 ? this.node.style.height : 44)
        .fontSize(this.node.style.fontSize)
        .fontColor(this.node.style.foregroundColor)
        .padding(this.paddingValue())
        .backgroundColor(this.node.style.backgroundColor)
        .borderRadius(this.node.style.borderRadius)
        .border({ width: this.node.style.borderWidth, color: this.node.style.borderColor })
        .onChange((value: string) => { this.onValueChange(this.node.binding, value); })
    } else if (this.node.type === 'TextArea') {
      TextArea({ text: this.boundValue(), placeholder: this.prop('placeholder') })
        .width('100%')
        .height(this.node.style.height > 0 ? this.node.style.height : 120)
        .fontSize(this.node.style.fontSize)
        .fontColor(this.node.style.foregroundColor)
        .padding(this.paddingValue())
        .backgroundColor(this.node.style.backgroundColor)
        .borderRadius(this.node.style.borderRadius)
        .onChange((value: string) => { this.onValueChange(this.node.binding, value); })
    } else if (this.node.type === 'Toggle') {
      Row({ space: 10 }) {
        Text(this.prop('text')).fontSize(this.node.style.fontSize).fontColor(this.node.style.foregroundColor).layoutWeight(1)
        Toggle({ type: ToggleType.Switch, isOn: this.boundValue() === 'true' })
          .enabled(this.isNodeEnabled())
          .onChange((value: boolean) => { this.onValueChange(this.node.binding, value ? 'true' : 'false'); })
      }.width('100%').padding(this.paddingValue()).backgroundColor(this.node.style.backgroundColor).borderRadius(this.node.style.borderRadius)
    } else if (this.node.type === 'ChoiceChips' || this.node.type === 'SegmentedControl') {
      Column({ space: 8 }) {
        if (this.prop('label').length > 0) {
          Text(this.prop('label')).fontSize(this.node.style.fontSize).fontColor(this.node.style.foregroundColor)
        }
        Row({ space: 8 }) {
          ForEach(this.choiceItems(), (item: string) => {
            Button(item)
              .height(36)
              .backgroundColor(this.isChoiceSelected(item) ? this.node.style.foregroundColor : this.node.style.backgroundColor)
              .fontColor(this.isChoiceSelected(item) ? this.node.style.backgroundColor : this.node.style.foregroundColor)
              .borderRadius(this.node.style.borderRadius)
              .enabled(this.isNodeEnabled())
              .onClick(() => { this.onValueChange(this.node.binding, item); })
          }, (item: string) => item)
        }
      }.width('100%').padding(this.paddingValue()).backgroundColor(this.node.style.backgroundColor).borderRadius(this.node.style.borderRadius)
    } else if (this.node.type === 'Progress') {
      Progress({ value: this.progressValue(), total: 100, type: ProgressType.Linear })
        .width('100%').height(this.node.style.height > 0 ? this.node.style.height : 8)
        .color(this.node.style.foregroundColor).backgroundColor(this.node.style.backgroundColor)
    } else if (this.node.type === 'Divider') {
      Divider().width('100%').color(this.node.style.borderColor).strokeWidth(this.node.style.borderWidth > 0 ? this.node.style.borderWidth : 1)
    } else if (this.node.type === 'Spacer') {
      Blank().height(this.node.style.height > 0 ? this.node.style.height : 12)
    } else {
      Column({ space: 6 }) {
        Text(this.displayText().length > 0 ? this.displayText() : 'Agent 动态区域')
          .fontSize(this.node.style.fontSize).fontColor(this.node.style.foregroundColor).width('100%')
        this.RenderChildren()
      }
      .width('100%').padding(this.paddingValue()).backgroundColor(this.node.style.backgroundColor)
      .borderRadius(this.node.style.borderRadius).border({ width: this.node.style.borderWidth, color: this.node.style.borderColor })
    }
  }

  @Builder
  RenderChildren() {
    ForEach(this.node.children, (child: CompiledArkUiNode) => {
      ArkUiNodeRenderer({ node: child, session: this.session, onAction: this.onAction, onValueChange: this.onValueChange })
    }, (child: CompiledArkUiNode) => child.id)
  }

  private displayText(): string {
    let bound: string = this.boundValue(); if (bound.length > 0) { return bound; }
    let text: string = this.prop('text'); return text.length > 0 ? text : this.prop('label');
  }

  private boundValue(): string {
    if (this.node.binding.length === 0) { return ''; }
    let value: string | undefined = this.session.data[this.node.binding]; return value === undefined ? '' : value;
  }

  private imageSource(): string {
    let assetId: string = this.prop('assetId');
    if (this.node.binding.indexOf('$asset.') === 0) { assetId = this.node.binding.substring(7); }
    for (let i: number = 0; i < this.session.assets.length; i++) {
      let asset: LocalImageAsset = this.session.assets[i]; if (asset.id === assetId) { return asset.dataUrl; }
    }
    return '';
  }

  private prop(key: string): string { let value: string | undefined = this.node.props[key]; return value === undefined ? '' : value; }
  private choiceItems(): string[] {
    let raw: string = this.prop('items'); if (raw.length === 0) { return []; }
    let parts: string[] = raw.split(','); let result: string[] = [];
    for (let i: number = 0; i < parts.length; i++) { if (parts[i].trim().length > 0) { result.push(parts[i].trim()); } }
    return result;
  }

  private isNodeVisible(): boolean {
    return this.conditionPass(this.node.visibleWhen);
  }

  private isNodeEnabled(): boolean {
    return this.conditionPass(this.node.enabledWhen);
  }

  private isChoiceSelected(item: string): boolean {
    if (this.node.selectedWhen !== undefined && this.node.selectedWhen.path.length > 0) {
      return this.conditionPass(this.node.selectedWhen) && this.boundValue() === item;
    }
    return this.boundValue() === item;
  }

  private conditionPass(condition: LocalCondition | undefined): boolean {
    if (condition === undefined || condition.path.length === 0) { return true; }
    let actual: string = this.session.data[condition.path] === undefined ? '' : this.session.data[condition.path];
    let expected: string = condition.value;
    if (condition.op === 'exists') { return actual.length > 0; }
    if (condition.op === 'eq') { return actual === expected; }
    if (condition.op === 'neq') { return actual !== expected; }
    if (condition.op === 'truthy') { return actual === 'true' || actual === '1' || actual.length > 0; }
    if (condition.op === 'contains') { return actual.indexOf(expected) >= 0; }
    if (condition.op === 'gt') { return Number(actual) > Number(expected); }
    if (condition.op === 'gte') { return Number(actual) >= Number(expected); }
    if (condition.op === 'lt') { return Number(actual) < Number(expected); }
    if (condition.op === 'lte') { return Number(actual) <= Number(expected); }
    return true;
  }

  private invokeFirstAction(): void {
    if (this.node.actions.length > 0 && this.isNodeEnabled()) { this.onAction(this.node.actions[0]); }
  }
  private progressValue(): number { let value: number = Number.parseInt(this.boundValue()); return Number.isNaN(value) ? 0 : value; }
  private fontWeight(): FontWeight { if (this.node.style.fontWeight === 'bold') { return FontWeight.Bold; } if (this.node.style.fontWeight === 'semibold') { return FontWeight.Medium; } if (this.node.style.fontWeight === 'medium') { return FontWeight.Medium; } return FontWeight.Normal; }
  private textAlign(): TextAlign { if (this.node.style.textAlign === 'center') { return TextAlign.Center; } if (this.node.style.textAlign === 'end') { return TextAlign.End; } return TextAlign.Start; }
  private paddingValue(): Padding { return { top: this.node.style.paddingTop, right: this.node.style.paddingRight, bottom: this.node.style.paddingBottom, left: this.node.style.paddingLeft }; }
  private marginValue(): Margin { return { top: this.node.style.marginTop, right: this.node.style.marginRight, bottom: this.node.style.marginBottom, left: this.node.style.marginLeft }; }
  private horizontalAlign(): HorizontalAlign {
    if (this.node.style.align === 'center') { return HorizontalAlign.Center; }
    if (this.node.style.align === 'end') { return HorizontalAlign.End; }
    return HorizontalAlign.Start;
  }
  private verticalAlign(): VerticalAlign {
    if (this.node.style.align === 'center') { return VerticalAlign.Center; }
    if (this.node.style.align === 'end') { return VerticalAlign.Bottom; }
    return VerticalAlign.Top;
  }
  private justifyAlign(): FlexAlign {
    if (this.node.style.justify === 'center') { return FlexAlign.Center; }
    if (this.node.style.justify === 'between') { return FlexAlign.SpaceBetween; }
    if (this.node.style.justify === 'end') { return FlexAlign.End; }
    return FlexAlign.Start;
  }
  private blurStyle(): BlurStyle {
    if (this.node.style.blurStyle === 'thin') { return BlurStyle.Thin; }
    if (this.node.style.blurStyle === 'regular') { return BlurStyle.Regular; }
    return BlurStyle.NONE;
  }
}
