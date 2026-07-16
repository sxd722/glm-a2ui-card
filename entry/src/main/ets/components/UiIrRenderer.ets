import { ArkUiTheme, ResolvedArkUiStyle } from '../services/ArkUiTypes';
import { resolveTailwindStyle } from '../services/ArkUiCompiler';
import { UiAction, UiEvaluationScope, UiExpression, UiIrNode, UiIrSessionState, UiValue } from '../services/UiIrTypes';
import { assetDataUrl, evaluateUiExpression } from '../services/UiIrRuntime';
import { booleanValue, numberValue, stringValue, uiValueToBoolean, uiValueToDisplayString } from '../services/UiValue';

@Component
export struct UiIrRenderer {
  @Prop node: UiIrNode;
  @Prop session: UiIrSessionState;
  @Prop scope: UiEvaluationScope = { aliases: {}, event: {} };
  onAction: (action: UiAction, scope?: UiEvaluationScope) => void = (_action: UiAction, _scope?: UiEvaluationScope): void => {};
  onValueChange: (path: string, value: UiValue) => void = (_path: string, _value: UiValue): void => {};
  onDiagnostic: (message: string) => void = (_message: string): void => {};
  private reportedDiagnostics: string[] = [];

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
    if (this.node.component === 'Column' || this.node.component === 'SafeArea' || this.node.component === 'Card' ||
      this.node.component === 'Section' || this.node.component === 'FormGroup' || this.node.component === 'InfoCard' ||
      this.node.component === 'StatusBanner' || this.node.component === 'EmptyState') {
      Column({ space: this.style().gap }) { this.RenderChildren(); }
        .width(this.style().widthFull ? '100%' : undefined).padding({ top: this.style().paddingTop, right: this.style().paddingRight, bottom: this.style().paddingBottom, left: this.style().paddingLeft })
        .backgroundColor(this.style().backgroundColor).borderRadius(this.style().borderRadius).shadow({ radius: this.style().shadowRadius, color: this.style().shadowColor, offsetX: 0, offsetY: this.style().shadowOffsetY })
        .alignItems(this.horizontalAlign(this.style())).justifyContent(this.flexAlign(this.style()))
        .height(this.style().heightFull ? '100%' : undefined).layoutWeight(this.style().layoutWeight);
    } else if (this.node.component === 'Row' || this.node.component === 'ActionBar') {
      Row({ space: this.style().gap }) { this.RenderChildren(); }
        .width(this.style().widthFull ? '100%' : undefined).padding({ top: this.style().paddingTop, right: this.style().paddingRight, bottom: this.style().paddingBottom, left: this.style().paddingLeft })
        .backgroundColor(this.style().backgroundColor).borderRadius(this.style().borderRadius).alignItems(this.verticalAlign(this.style())).justifyContent(this.flexAlign(this.style())).layoutWeight(this.style().layoutWeight);
    } else if (this.node.component === 'Stack' || this.node.component === 'Hero') {
      Stack({ alignContent: Alignment.BottomStart }) { this.RenderChildren(); }
        .width(this.style().widthFull ? '100%' : undefined).height(this.style().heightFull ? '100%' : this.style().height > 0 ? this.style().height : 180).borderRadius(this.style().borderRadius)
        .backgroundColor(this.style().backgroundColor).shadow({ radius: this.style().shadowRadius, color: this.style().shadowColor, offsetX: 0, offsetY: this.style().shadowOffsetY });
    } else if (this.node.component === 'Scroll') {
      Scroll() { Column({ space: this.style().gap }) { this.RenderChildren(); } }
        .width('100%').height('100%').layoutWeight(this.style().layoutWeight).scrollBar(BarState.Auto);
    } else if (this.node.component === 'List' || this.node.component === 'Timeline' || this.node.component === 'ResultList') {
      List({ space: this.style().gap }) {
        ForEach(this.node.children, (child: UiIrNode) => { ListItem() { UiIrRenderer({ node: child, session: this.session, scope: this.scope, onAction: this.onAction, onValueChange: this.onValueChange, onDiagnostic: this.onDiagnostic }); } }, (child: UiIrNode) => child.id)
      }.width('100%').height(this.style().height > 0 ? this.style().height : 240).layoutWeight(this.style().layoutWeight).scrollBar(BarState.Auto)
        .onReachEnd(() => { this.invokeAction('reachEnd'); });
    } else if (this.node.component === 'Grid' || this.node.component === 'MetricGrid' || this.node.component === 'MediaGallery') {
      Grid() {
        ForEach(this.node.children, (child: UiIrNode) => { GridItem() { UiIrRenderer({ node: child, session: this.session, scope: this.scope, onAction: this.onAction, onValueChange: this.onValueChange, onDiagnostic: this.onDiagnostic }); } }, (child: UiIrNode) => child.id)
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
          .onChange((value: string) => { let nextValue = stringValue(value); this.onValueChange(this.node.binding, nextValue); this.invokeAction('change', this.changeEvent(nextValue)); })
          .onSubmit(() => { this.invokeAction('submit'); });
      } else {
        TextArea({ text: this.boundText(), placeholder: this.propText('placeholder') }).width('100%').height(110).padding(12)
          .fontColor(this.style().foregroundColor).backgroundColor(this.style().backgroundColor).borderRadius(this.style().borderRadius)
          .onChange((value: string) => { let nextValue = stringValue(value); this.onValueChange(this.node.binding, nextValue); this.invokeAction('change', this.changeEvent(nextValue)); })
          .onSubmit(() => { this.invokeAction('submit'); });
      }
    } else if (this.node.component === 'Toggle' || this.node.component === 'Checkbox') {
      Row({ space: 10 }) {
        if (this.node.component === 'Toggle') { Toggle({ type: ToggleType.Switch, isOn: this.boundBoolean() }).onChange((value: boolean) => { let nextValue = booleanValue(value); this.updateBooleanBinding(nextValue); this.invokeAction('change', this.changeEvent(nextValue)); }); }
        else { Checkbox({ name: this.node.id, group: 'ui-ir' }).select(this.boundBoolean()).onChange((value: boolean) => { let nextValue = booleanValue(value); this.updateBooleanBinding(nextValue); this.invokeAction('change', this.changeEvent(nextValue)); }); }
        Text(this.propText('label')).fontSize(this.style().fontSize).fontColor(this.style().foregroundColor);
      }.width('100%').alignItems(VerticalAlign.Center);
    } else if (this.node.component === 'ChoiceChips' || this.node.component === 'SegmentedControl' || this.node.component === 'Tabs') {
      Scroll() { Row({ space: 8 }) { ForEach(this.choiceItems(), (item: string) => { Button(item).height(36).padding({ left: 12, right: 12 }).backgroundColor(item === this.boundText() ? this.style().foregroundColor : this.style().backgroundColor).fontColor(item === this.boundText() ? this.style().backgroundColor : this.style().foregroundColor).borderRadius(this.style().borderRadius).onClick(() => { let selected = this.choiceValue(item); this.onValueChange(this.node.binding, selected); this.invokeAction('change', this.changeEvent(selected)); }); }, (item: string) => item); }.width('max-content'); }
        .width('100%').height(48).scrollable(ScrollDirection.Horizontal).scrollBar(BarState.Off);
    } else if (this.node.component === 'Sheet') {
      Stack({ alignContent: Alignment.Bottom }) {
        Column() { Blank().width('100%').height('100%').backgroundColor('#66000000'); }
          .width('100%').height('100%').onClick(() => { this.invokeAction('dismiss'); });
        Column({ space: this.style().gap }) { this.RenderChildren(); }
          .width('100%').padding({ top: this.style().paddingTop, right: this.style().paddingRight, bottom: this.style().paddingBottom, left: this.style().paddingLeft })
          .backgroundColor(this.style().backgroundColor).borderRadius(this.style().borderRadius)
          .shadow({ radius: this.style().shadowRadius, color: this.style().shadowColor, offsetX: 0, offsetY: this.style().shadowOffsetY });
      }.width('100%').height('100%');
    } else if (this.node.component === 'Progress') {
      Progress({ value: Number(this.propText('value')) }).width('100%').color(this.style().foregroundColor).backgroundColor(this.style().backgroundColor);
    } else if (this.node.component === 'Divider') {
      Divider().strokeWidth(1).color(this.style().borderColor).width('100%');
    } else {
      Blank().height(this.style().height > 0 ? this.style().height : 8);
    }
  }

  @Builder
  RenderChildren() { ForEach(this.node.children, (child: UiIrNode) => { UiIrRenderer({ node: child, session: this.session, scope: this.scope, onAction: this.onAction, onValueChange: this.onValueChange, onDiagnostic: this.onDiagnostic }); }, (child: UiIrNode) => child.id); }

  @Builder
  RenderRepeat() {
    if (this.repeatItems().length > 0) { ForEach(this.repeatItems(), (item: UiValue, index: number) => { this.RenderRepeatedItem(item, index); }, (item: UiValue, index: number) => this.repeatKey(item, index)); }
  }

  @Builder
  RenderRepeatedItem(item: UiValue, index: number) {
    Column() { ForEach(this.node.children, (child: UiIrNode) => { UiIrRenderer({ node: child, session: this.session, scope: this.repeatScope(item), onAction: this.onAction, onValueChange: this.onValueChange, onDiagnostic: this.onDiagnostic }); }, (child: UiIrNode) => child.id + '-' + this.repeatKey(item, index)); }
  }

  private style(): ResolvedArkUiStyle { let theme: ArkUiTheme = { colors: this.session.app.theme.tokens }; return resolveTailwindStyle(this.node.className, theme); }
  private propText(name: string): string { return uiValueToDisplayString(evaluateUiExpression(this.node.props[name], this.session, this.scope)); }
  private boundText(): string { return uiValueToDisplayString(evaluateUiExpression(this.bindingExpression(), this.session, this.scope)); }
  private boundBoolean(): boolean {
    if (this.node.binding.length > 0) { return uiValueToBoolean(evaluateUiExpression(this.bindingExpression(), this.session, this.scope)); }
    let propName: string = this.node.component === 'Checkbox' ? 'checked' : 'value';
    return uiValueToBoolean(evaluateUiExpression(this.node.props[propName], this.session, this.scope));
  }
  private choiceItems(): string[] { let value: UiValue = evaluateUiExpression(this.node.props['items'], this.session, this.scope); let result: string[] = []; if (value.kind === 'array') { for (let i: number = 0; i < value.arrayValue.length; i++) { result.push(uiValueToDisplayString(value.arrayValue[i])); } } return result; }
  private choiceValue(display: string): UiValue {
    let current: UiValue = evaluateUiExpression(this.bindingExpression(), this.session, this.scope);
    if (current.kind === 'number') { let parsed: number = Number(display); return isNaN(parsed) ? stringValue(display) : numberValue(parsed); }
    if (current.kind === 'boolean') { return booleanValue(display === 'true'); }
    return stringValue(display);
  }
  private repeatItems(): UiValue[] { let value: UiValue = evaluateUiExpression(this.node.source, this.session, this.scope); return value.kind === 'array' ? value.arrayValue.slice(0, 200) : []; }
  private repeatKeys(items: UiValue[]): string[] {
    let result: string[] = []; let seen: string[] = [];
    for (let i: number = 0; i < items.length; i++) {
      let candidate: string = this.repeatKey(items[i], i);
      if (seen.indexOf(candidate) >= 0) { this.reportDiagnostic('重复 ForEach key：' + candidate); candidate = 'index-' + i.toString(); }
      seen.push(candidate); result.push(this.node.id + '-' + candidate);
    }
    return result;
  }
  private repeatKey(item: UiValue, index: number): string {
    let key: string = this.rawRepeatKey(item);
    if (key.length > 0) {
      let items: UiValue[] = this.repeatItems();
      for (let i: number = 0; i < index; i++) {
        if (this.rawRepeatKey(items[i]) === key) { this.reportDiagnostic('重复 ForEach key：' + key); return 'index-' + index.toString(); }
      }
      return key;
    }
    this.reportDiagnostic('ForEach 缺少有效 key：' + this.node.keyPath);
    return 'index-' + index.toString();
  }
  private rawRepeatKey(item: UiValue): string {
    let value: UiValue | undefined = this.readItemPath(item, this.node.keyPath);
    if (value !== undefined && (value.kind === 'string' || value.kind === 'number')) { return uiValueToDisplayString(value); }
    return '';
  }
  private readItemPath(item: UiValue, path: string): UiValue | undefined {
    if (item.kind !== 'object' || path.length === 0) { return undefined; }
    let parts: string[] = path.split('.'); let current: UiValue | undefined = item;
    for (let i: number = 0; i < parts.length && current !== undefined; i++) {
      current = current.kind === 'object' ? current.objectValue[parts[i]] : undefined;
    }
    return current;
  }
  private reportDiagnostic(message: string): void {
    if (this.reportedDiagnostics.indexOf(message) < 0) { this.reportedDiagnostics.push(message); this.onDiagnostic(message); }
  }
  private repeatScope(item: UiValue): UiEvaluationScope {
    let aliases: Record<string, UiValue> = {};
    let names: string[] = Object.keys(this.scope.aliases);
    for (let i: number = 0; i < names.length; i++) { aliases[names[i]] = this.scope.aliases[names[i]]; }
    aliases[this.node.itemAlias] = item;
    return { aliases: aliases, event: this.scope.event };
  }
  private invokeFirstAction(): void {
    let action = this.node.actions['press'];
    if (action === undefined) { action = this.node.actions['submit']; }
    if (action !== undefined) { this.onAction(action, this.scope); }
  }
  private invokeAction(name: string, event: Record<string, UiValue> = {}): void {
    let action = this.node.actions[name]; if (action !== undefined) { let nextScope: UiEvaluationScope = { aliases: this.scope.aliases, event: event }; this.onAction(action, nextScope); }
  }
  private changeEvent(value: UiValue): Record<string, UiValue> { let event: Record<string, UiValue> = {}; event['value'] = value; event['checked'] = value; return event; }
  private updateBooleanBinding(value: UiValue): void { if (this.node.binding.length > 0) { this.onValueChange(this.node.binding, value); } }
  private bindingExpression(): UiExpression {
    let parts: string[] = this.node.binding.split('.');
    return { kind: 'path', root: parts[0], segments: parts.slice(1), operator: '', items: [], properties: [], callee: '', args: [] };
  }
  private horizontalAlign(style: ResolvedArkUiStyle): HorizontalAlign { return style.align === 'center' ? HorizontalAlign.Center : style.align === 'end' ? HorizontalAlign.End : HorizontalAlign.Start; }
  private verticalAlign(style: ResolvedArkUiStyle): VerticalAlign { return style.align === 'center' ? VerticalAlign.Center : style.align === 'end' ? VerticalAlign.Bottom : VerticalAlign.Center; }
  private flexAlign(style: ResolvedArkUiStyle): FlexAlign { return style.justify === 'center' ? FlexAlign.Center : style.justify === 'between' ? FlexAlign.SpaceBetween : style.justify === 'end' ? FlexAlign.End : FlexAlign.Start; }
  private textAlign(style: ResolvedArkUiStyle): TextAlign { return style.textAlign === 'center' ? TextAlign.Center : style.textAlign === 'end' ? TextAlign.End : TextAlign.Start; }
  private fontWeight(style: ResolvedArkUiStyle): FontWeight { return style.fontWeight === 'bold' ? FontWeight.Bold : style.fontWeight === 'semibold' ? FontWeight.Medium : FontWeight.Regular; }
  private objectFit(style: ResolvedArkUiStyle): ImageFit { return style.objectFit === 'contain' ? ImageFit.Contain : ImageFit.Cover;
  }
  private gridColumns(): string { return '1fr 1fr'; }
}
