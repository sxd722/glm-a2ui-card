import { ArkUiTheme, ResolvedArkUiStyle } from '../services/ArkUiTypes';
import { resolveTailwindStyle } from '../services/ArkUiCompiler';
import { UiAction, UiEvaluationScope, UiIrNode, UiIrSessionState, UiValue } from '../services/UiIrTypes';
import { assetDataUrl, evaluateUiExpression } from '../services/UiIrRuntime';
import { uiValueToBoolean, uiValueToDisplayString } from '../services/UiValue';

@Component
export struct UiIrRenderer {
  @Prop node: UiIrNode;
  @Prop session: UiIrSessionState;
  @Prop scope: UiEvaluationScope = { aliases: {}, event: {} };
  onAction: (action: UiAction) => void = (_action: UiAction): void => {};
  onValueChange: (path: string, value: string) => void = (_path: string, _value: string): void => {};

  build() {
    if (this.node.kind === 'if') {
      if (uiValueToBoolean(evaluateUiExpression(this.node.condition, this.session, this.scope))) { this.RenderChildren(); }
      else { Blank().width(0).height(0); }
    } else if (this.node.kind === 'forEach') {
      this.RenderRepeat();
    } else {
      this.RenderElement();
    }
  }

  @Builder
  RenderElement() {
    if (this.node.component === 'Column' || this.node.component === 'SafeArea' || this.node.component === 'Card') {
      Column({ space: this.style().gap }) { this.RenderChildren(); }
        .width(this.style().widthFull ? '100%' : undefined).padding({ top: this.style().paddingTop, right: this.style().paddingRight, bottom: this.style().paddingBottom, left: this.style().paddingLeft })
        .backgroundColor(this.style().backgroundColor).borderRadius(this.style().borderRadius).shadow({ radius: this.style().shadowRadius, color: this.style().shadowColor, offsetX: 0, offsetY: this.style().shadowOffsetY })
        .alignItems(this.horizontalAlign(this.style())).justifyContent(this.flexAlign(this.style())).layoutWeight(this.style().layoutWeight);
    } else if (this.node.component === 'Row') {
      Row({ space: this.style().gap }) { this.RenderChildren(); }
        .width(this.style().widthFull ? '100%' : undefined).padding({ top: this.style().paddingTop, right: this.style().paddingRight, bottom: this.style().paddingBottom, left: this.style().paddingLeft })
        .backgroundColor(this.style().backgroundColor).borderRadius(this.style().borderRadius).alignItems(this.verticalAlign(this.style())).justifyContent(this.flexAlign(this.style())).layoutWeight(this.style().layoutWeight);
    } else if (this.node.component === 'Stack') {
      Stack({ alignContent: Alignment.BottomStart }) { this.RenderChildren(); }
        .width(this.style().widthFull ? '100%' : undefined).height(this.style().height > 0 ? this.style().height : 180).borderRadius(this.style().borderRadius)
        .backgroundColor(this.style().backgroundColor).shadow({ radius: this.style().shadowRadius, color: this.style().shadowColor, offsetX: 0, offsetY: this.style().shadowOffsetY });
    } else if (this.node.component === 'Scroll') {
      Scroll() { Column({ space: this.style().gap }) { this.RenderChildren(); } }
        .width('100%').height('100%').scrollBar(BarState.Auto);
    } else if (this.node.component === 'List') {
      List({ space: this.style().gap }) {
        ForEach(this.node.children, (child: UiIrNode) => { ListItem() { UiIrRenderer({ node: child, session: this.session, scope: this.scope, onAction: this.onAction, onValueChange: this.onValueChange }); } }, (child: UiIrNode) => child.id)
      }.width('100%').height('auto').scrollBar(BarState.Auto);
    } else if (this.node.component === 'Grid') {
      Grid() {
        ForEach(this.node.children, (child: UiIrNode) => { GridItem() { UiIrRenderer({ node: child, session: this.session, scope: this.scope, onAction: this.onAction, onValueChange: this.onValueChange }); } }, (child: UiIrNode) => child.id)
      }.columnsTemplate(this.gridColumns()).rowsGap(this.style().gap).columnsGap(this.style().gap).width('100%');
    } else if (this.node.component === 'Text' || this.node.component === 'Badge' || this.node.component === 'Icon') {
      Text(this.propText('text')).fontSize(this.style().fontSize).fontWeight(this.fontWeight(this.style())).fontColor(this.style().foregroundColor)
        .textAlign(this.textAlign(this.style())).opacity(this.style().opacity).padding({ top: this.style().paddingTop, right: this.style().paddingRight, bottom: this.style().paddingBottom, left: this.style().paddingLeft });
    } else if (this.node.component === 'Image') {
      if (assetDataUrl(this.session, this.propText('assetId')).length > 0) { Image(assetDataUrl(this.session, this.propText('assetId'))).width(this.style().widthFull ? '100%' : undefined).height(this.style().height > 0 ? this.style().height : 140).objectFit(this.objectFit(this.style())).borderRadius(this.style().borderRadius); }
      else { Blank().width(this.style().widthFull ? '100%' : undefined).height(this.style().height > 0 ? this.style().height : 80).backgroundColor(this.style().backgroundColor).borderRadius(this.style().borderRadius); }
    } else if (this.node.component === 'Button' || this.node.component === 'IconButton') {
      Button(this.propText('text')).width(this.style().widthFull ? '100%' : undefined).height(this.style().height > 0 ? this.style().height : 44)
        .backgroundColor(this.style().backgroundColor).fontColor(this.style().foregroundColor).borderRadius(this.style().borderRadius).onClick(() => { this.invokeFirstAction(); });
    } else if (this.node.component === 'TextInput' || this.node.component === 'TextArea') {
      if (this.node.component === 'TextInput') {
        TextInput({ text: this.boundText(), placeholder: this.propText('placeholder') }).width('100%').height(46).padding(12)
          .fontColor(this.style().foregroundColor).backgroundColor(this.style().backgroundColor).borderRadius(this.style().borderRadius)
          .onChange((value: string) => { this.onValueChange(this.node.binding, value); });
      } else {
        TextArea({ text: this.boundText(), placeholder: this.propText('placeholder') }).width('100%').height(110).padding(12)
          .fontColor(this.style().foregroundColor).backgroundColor(this.style().backgroundColor).borderRadius(this.style().borderRadius)
          .onChange((value: string) => { this.onValueChange(this.node.binding, value); });
      }
    } else if (this.node.component === 'Toggle' || this.node.component === 'Checkbox') {
      Row({ space: 10 }) {
        if (this.node.component === 'Toggle') { Toggle({ type: ToggleType.Switch, isOn: this.boundBoolean() }).onChange((value: boolean) => { this.onValueChange(this.node.binding, value ? 'true' : 'false'); }); }
        else { Checkbox({ name: this.node.id, group: 'ui-ir' }).select(this.boundBoolean()).onChange((value: boolean) => { this.onValueChange(this.node.binding, value ? 'true' : 'false'); }); }
        Text(this.propText('label')).fontSize(this.style().fontSize).fontColor(this.style().foregroundColor);
      }.width('100%').alignItems(VerticalAlign.Center);
    } else if (this.node.component === 'ChoiceChips' || this.node.component === 'SegmentedControl') {
      Row({ space: 8 }) { ForEach(this.choiceItems(), (item: string) => { Button(item).height(36).padding({ left: 12, right: 12 }).backgroundColor(item === this.boundText() ? this.style().foregroundColor : this.style().backgroundColor).fontColor(item === this.boundText() ? this.style().backgroundColor : this.style().foregroundColor).borderRadius(this.style().borderRadius).onClick(() => { this.onValueChange(this.node.binding, item); }); }, (item: string) => item); }.width('100%');
    } else if (this.node.component === 'Progress') {
      Progress({ value: Number(this.propText('value')) }).width('100%').color(this.style().foregroundColor).backgroundColor(this.style().backgroundColor);
    } else if (this.node.component === 'Divider') {
      Divider().strokeWidth(1).color(this.style().borderColor).width('100%');
    } else {
      Blank().height(this.style().height > 0 ? this.style().height : 8);
    }
  }

  @Builder
  RenderChildren() { ForEach(this.node.children, (child: UiIrNode) => { UiIrRenderer({ node: child, session: this.session, scope: this.scope, onAction: this.onAction, onValueChange: this.onValueChange }); }, (child: UiIrNode) => child.id); }

  @Builder
  RenderRepeat() {
    if (this.repeatItems().length > 0) { ForEach(this.repeatItems(), (item: UiValue, index: number) => { this.RenderRepeatedItem(item, index); }, (_item: UiValue, index: number) => index.toString()); }
  }

  @Builder
  RenderRepeatedItem(item: UiValue, index: number) {
    Column() { ForEach(this.node.children, (child: UiIrNode) => { UiIrRenderer({ node: child, session: this.session, scope: this.repeatScope(item), onAction: this.onAction, onValueChange: this.onValueChange }); }, (child: UiIrNode) => child.id + '-' + index.toString()); }
  }

  private style(): ResolvedArkUiStyle { let theme: ArkUiTheme = { colors: this.session.app.theme.tokens }; return resolveTailwindStyle(this.node.className, theme); }
  private propText(name: string): string { return uiValueToDisplayString(evaluateUiExpression(this.node.props[name], this.session, this.scope)); }
  private boundText(): string { return uiValueToDisplayString(evaluateUiExpression({ kind: 'path', root: 'state', segments: this.node.binding.split('.'), operator: '', items: [], properties: [], callee: '', args: [] }, this.session, this.scope)); }
  private boundBoolean(): boolean { return uiValueToBoolean(evaluateUiExpression({ kind: 'path', root: 'state', segments: this.node.binding.split('.'), operator: '', items: [], properties: [], callee: '', args: [] }, this.session, this.scope)); }
  private choiceItems(): string[] { let value: UiValue = evaluateUiExpression(this.node.props['items'], this.session, this.scope); let result: string[] = []; if (value.kind === 'array') { for (let i: number = 0; i < value.arrayValue.length; i++) { result.push(uiValueToDisplayString(value.arrayValue[i])); } } return result; }
  private repeatItems(): UiValue[] { let value: UiValue = evaluateUiExpression(this.node.source, this.session, this.scope); return value.kind === 'array' ? value.arrayValue.slice(0, 200) : []; }
  private repeatScope(item: UiValue): UiEvaluationScope { let aliases: Record<string, UiValue> = {}; aliases[this.node.itemAlias] = item; return { aliases: aliases, event: {} }; }
  private invokeFirstAction(): void { let action = this.node.actions['press']; if (action !== undefined) { this.onAction(action); } }
  private horizontalAlign(style: ResolvedArkUiStyle): HorizontalAlign { return style.align === 'center' ? HorizontalAlign.Center : style.align === 'end' ? HorizontalAlign.End : HorizontalAlign.Start; }
  private verticalAlign(style: ResolvedArkUiStyle): VerticalAlign { return style.align === 'center' ? VerticalAlign.Center : style.align === 'end' ? VerticalAlign.Bottom : VerticalAlign.Center; }
  private flexAlign(style: ResolvedArkUiStyle): FlexAlign { return style.justify === 'center' ? FlexAlign.Center : style.justify === 'between' ? FlexAlign.SpaceBetween : style.justify === 'end' ? FlexAlign.End : FlexAlign.Start; }
  private textAlign(style: ResolvedArkUiStyle): TextAlign { return style.textAlign === 'center' ? TextAlign.Center : style.textAlign === 'end' ? TextAlign.End : TextAlign.Start; }
  private fontWeight(style: ResolvedArkUiStyle): FontWeight { return style.fontWeight === 'bold' ? FontWeight.Bold : style.fontWeight === 'semibold' ? FontWeight.Medium : FontWeight.Regular; }
  private objectFit(style: ResolvedArkUiStyle): ImageFit { return style.objectFit === 'contain' ? ImageFit.Contain : ImageFit.Cover;
  }
  private gridColumns(): string { return '1fr 1fr'; }
}
