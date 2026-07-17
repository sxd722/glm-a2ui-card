import { SemanticUiEvent, booleanPayload, createSemanticEvent, numberPayload, textPayload, itemBooleanPayload } from '../../foundation/SemanticEvents';
import { SemanticTheme, createSemanticTheme } from '../../foundation/SemanticTheme';
import { SemanticThemeMode } from '../../foundation/SemanticEnums';
import { SemanticActionModel, SemanticFieldModel, SemanticOptionModel, SemanticImageModel } from '../../foundation/SemanticModels';
import { SemanticButton, SemanticFieldFrame, SemanticImage } from '../../internal/SemanticAtoms';

function textValue(value: string | number | boolean | undefined): string { return value === undefined ? '' : value.toString(); }
function numberValue(value: string): number { let parsed: number = Number(value); return Number.isFinite(parsed) ? parsed : 0; }

@ComponentV2
export struct FieldGroup {
  @Param title: string = '';
  @Param body: string = '';
  @Param theme: SemanticTheme = createSemanticTheme(SemanticThemeMode.LIGHT);
  build() { Column({ space: this.theme.spacing.sm }) { if (this.title.length > 0) { Text(this.title).fontSize(this.theme.typography.title).fontWeight(FontWeight.Bold); } if (this.body.length > 0) { Text(this.body).fontColor(this.theme.colors.textSecondary); } }.width('100%').padding(this.theme.spacing.md).backgroundColor(this.theme.colors.surfaceMuted).borderRadius(this.theme.radius.lg); }
}

@ComponentV2
export struct TextField {
  @Param model: SemanticFieldModel<string> = new SemanticFieldModel<string>();
  @Param theme: SemanticTheme = createSemanticTheme(SemanticThemeMode.LIGHT);
  @Event onEvent: (event: SemanticUiEvent) => void = () => {};
  build() { Column({ space: this.theme.spacing.xs }) { SemanticFieldFrame({ theme: this.theme, label: this.model.label, helper: this.model.helper, error: this.model.error, required: this.model.required }); TextInput({ text: textValue(this.model.value), placeholder: this.model.helper }).enabled(this.model.enabled).onChange((value: string) => this.onEvent(createSemanticEvent(this.model.id, 'change', textPayload(value)))).width('100%').height(46); }.width('100%'); }
}

@ComponentV2
export struct TextAreaField {
  @Param model: SemanticFieldModel<string> = new SemanticFieldModel<string>();
  @Param theme: SemanticTheme = createSemanticTheme(SemanticThemeMode.LIGHT);
  @Event onEvent: (event: SemanticUiEvent) => void = () => {};
  build() { Column({ space: this.theme.spacing.xs }) { SemanticFieldFrame({ theme: this.theme, label: this.model.label, helper: this.model.helper, error: this.model.error, required: this.model.required }); TextArea({ text: textValue(this.model.value), placeholder: this.model.helper }).enabled(this.model.enabled).onChange((value: string) => this.onEvent(createSemanticEvent(this.model.id, 'change', textPayload(value)))).width('100%').height(110); }.width('100%'); }
}

@ComponentV2
export struct NumberField {
  @Param model: SemanticFieldModel<number> = new SemanticFieldModel<number>();
  @Param theme: SemanticTheme = createSemanticTheme(SemanticThemeMode.LIGHT);
  @Event onEvent: (event: SemanticUiEvent) => void = () => {};
  build() { Column({ space: this.theme.spacing.xs }) { SemanticFieldFrame({ theme: this.theme, label: this.model.label, helper: this.model.helper, error: this.model.error, required: this.model.required }); Row({ space: this.theme.spacing.xs }) { TextInput({ text: textValue(this.model.value), placeholder: '0' }).type(InputType.Number).enabled(this.model.enabled).onChange((value: string) => this.onEvent(createSemanticEvent(this.model.id, 'change', numberPayload(numberValue(value))))).layoutWeight(1); Button('-').enabled(this.model.enabled).onClick(() => this.onEvent(createSemanticEvent(this.model.id, 'decrement'))); Button('+').enabled(this.model.enabled).onClick(() => this.onEvent(createSemanticEvent(this.model.id, 'increment'))); }.width('100%'); }.width('100%'); }
}

@ComponentV2
export struct SearchField {
  @Param model: SemanticFieldModel<string> = new SemanticFieldModel<string>();
  @Param theme: SemanticTheme = createSemanticTheme(SemanticThemeMode.LIGHT);
  @Event onEvent: (event: SemanticUiEvent) => void = () => {};
  build() { Row({ space: this.theme.spacing.xs }) { TextInput({ text: textValue(this.model.value), placeholder: this.model.helper || '搜索' }).onChange((value: string) => this.onEvent(createSemanticEvent(this.model.id, 'change', textPayload(value)))).onSubmit(() => this.onEvent(createSemanticEvent(this.model.id, 'submit'))).layoutWeight(1); Button('清除').onClick(() => this.onEvent(createSemanticEvent(this.model.id, 'clear'))); }.width('100%'); }
}

@ComponentV2
export struct SelectField {
  @Param model: SemanticFieldModel<string> = new SemanticFieldModel<string>();
  @Param theme: SemanticTheme = createSemanticTheme(SemanticThemeMode.LIGHT);
  @Event onEvent: (event: SemanticUiEvent) => void = () => {};
  build() { Column({ space: this.theme.spacing.xs }) { SemanticFieldFrame({ theme: this.theme, label: this.model.label, helper: this.model.helper, error: this.model.error, required: this.model.required }); ForEach(this.model.options, (item: SemanticOptionModel) => { Button(item.label).width('100%').backgroundColor(item.id === textValue(this.model.value) ? this.theme.colors.primary : this.theme.colors.surfaceMuted).fontColor(item.id === textValue(this.model.value) ? this.theme.colors.onPrimary : this.theme.colors.textPrimary).onClick(() => this.onEvent(createSemanticEvent(this.model.id, 'select', textPayload(item.id)))); }, (item: SemanticOptionModel) => item.id); }.width('100%'); }
  private selectedIndex(): number { for (let i: number = 0; i < this.model.options.length; i++) { if (this.model.options[i].id === textValue(this.model.value)) { return i; } } return 0; }
}

@ComponentV2
export struct MultiSelectField {
  @Param model: SemanticFieldModel<string[]> = new SemanticFieldModel<string[]>();
  @Param theme: SemanticTheme = createSemanticTheme(SemanticThemeMode.LIGHT);
  @Event onEvent: (event: SemanticUiEvent) => void = () => {};
  build() { Column({ space: this.theme.spacing.xs }) { SemanticFieldFrame({ theme: this.theme, label: this.model.label, helper: this.model.helper, error: this.model.error, required: this.model.required }); ForEach(this.model.options, (item: SemanticOptionModel) => { Row() { Checkbox().select(this.model.values.indexOf(item.id) >= 0).onChange((value: boolean) => this.onEvent(createSemanticEvent(this.model.id, 'toggle', itemBooleanPayload(item.id, value)))); Text(item.label).layoutWeight(1); }.width('100%').padding(this.theme.spacing.xs); }, (item: SemanticOptionModel) => item.id); }.width('100%'); }
}

@ComponentV2
export struct ChoiceChipsField {
  @Param model: SemanticFieldModel<string> = new SemanticFieldModel<string>();
  @Param theme: SemanticTheme = createSemanticTheme(SemanticThemeMode.LIGHT);
  @Event onEvent: (event: SemanticUiEvent) => void = () => {};
  build() { Column({ space: this.theme.spacing.xs }) { SemanticFieldFrame({ theme: this.theme, label: this.model.label, helper: this.model.helper, error: this.model.error, required: this.model.required }); Scroll() { Row({ space: this.theme.spacing.xs }) { ForEach(this.model.options, (item: SemanticOptionModel) => { Button(item.label).backgroundColor(item.id === textValue(this.model.value) ? this.theme.colors.primary : this.theme.colors.surfaceMuted).fontColor(item.id === textValue(this.model.value) ? this.theme.colors.onPrimary : this.theme.colors.textPrimary).onClick(() => this.onEvent(createSemanticEvent(this.model.id, 'select', textPayload(item.id)))); }, (item: SemanticOptionModel) => item.id); }.padding({ right: this.theme.spacing.sm }); }.scrollable(ScrollDirection.Horizontal).scrollBar(BarState.Off).width('100%'); }.width('100%'); }
}

@ComponentV2
export struct CheckboxField {
  @Param model: SemanticFieldModel<boolean> = new SemanticFieldModel<boolean>();
  @Param theme: SemanticTheme = createSemanticTheme(SemanticThemeMode.LIGHT);
  @Event onEvent: (event: SemanticUiEvent) => void = () => {};
  build() { Row({ space: this.theme.spacing.sm }) { Checkbox().select(this.model.value === true).enabled(this.model.enabled).onChange((value: boolean) => this.onEvent(createSemanticEvent(this.model.id, 'change', booleanPayload(value)))); Text(this.model.label).layoutWeight(1); }.width('100%'); }
}

@ComponentV2
export struct SwitchField {
  @Param model: SemanticFieldModel<boolean> = new SemanticFieldModel<boolean>();
  @Param theme: SemanticTheme = createSemanticTheme(SemanticThemeMode.LIGHT);
  @Event onEvent: (event: SemanticUiEvent) => void = () => {};
  build() { Row() { Text(this.model.label).layoutWeight(1); Toggle({ type: ToggleType.Switch, isOn: this.model.value === true }).enabled(this.model.enabled).onChange((value: boolean) => this.onEvent(createSemanticEvent(this.model.id, 'change', booleanPayload(value)))); }.width('100%'); }
}

@ComponentV2
export struct DateField {
  @Param model: SemanticFieldModel<string> = new SemanticFieldModel<string>();
  @Param theme: SemanticTheme = createSemanticTheme(SemanticThemeMode.LIGHT);
  @Event onEvent: (event: SemanticUiEvent) => void = () => {};
  build() { Button(textValue(this.model.value) || this.model.helper || '选择日期').enabled(this.model.enabled).width('100%').onClick(() => this.onEvent(createSemanticEvent(this.model.id, 'open'))); }
}

@ComponentV2
export struct TimeField {
  @Param model: SemanticFieldModel<string> = new SemanticFieldModel<string>();
  @Param theme: SemanticTheme = createSemanticTheme(SemanticThemeMode.LIGHT);
  @Event onEvent: (event: SemanticUiEvent) => void = () => {};
  build() { Button(textValue(this.model.value) || this.model.helper || '选择时间').enabled(this.model.enabled).width('100%').onClick(() => this.onEvent(createSemanticEvent(this.model.id, 'open'))); }
}

@ComponentV2
export struct DateRangeField {
  @Param model: SemanticFieldModel<string[]> = new SemanticFieldModel<string[]>();
  @Param theme: SemanticTheme = createSemanticTheme(SemanticThemeMode.LIGHT);
  @Event onEvent: (event: SemanticUiEvent) => void = () => {};
  build() { Row({ space: this.theme.spacing.sm }) { Button(this.model.values.length > 0 ? this.model.values[0] : '开始日期').layoutWeight(1).onClick(() => this.onEvent(createSemanticEvent(this.model.id, 'start'))); Text('至'); Button(this.model.values.length > 1 ? this.model.values[1] : '结束日期').layoutWeight(1).onClick(() => this.onEvent(createSemanticEvent(this.model.id, 'end'))); }.width('100%'); }
}

@ComponentV2
export struct SliderField {
  @Param model: SemanticFieldModel<number> = new SemanticFieldModel<number>();
  @Param theme: SemanticTheme = createSemanticTheme(SemanticThemeMode.LIGHT);
  @Event onEvent: (event: SemanticUiEvent) => void = () => {};
  build() { Column({ space: this.theme.spacing.xs }) { Row() { Text(this.model.label).layoutWeight(1); Text(textValue(this.model.value)); }.width('100%'); Slider({ value: this.model.value || 0, min: 0, max: 100, step: 1 }).enabled(this.model.enabled).onChange((value: number) => this.onEvent(createSemanticEvent(this.model.id, 'change', numberPayload(value)))).width('100%'); }.width('100%'); }
}

@ComponentV2
export struct ImagePickerField {
  @Param model: SemanticFieldModel<SemanticImageModel[]> = new SemanticFieldModel<SemanticImageModel[]>();
  @Param theme: SemanticTheme = createSemanticTheme(SemanticThemeMode.LIGHT);
  @Event onEvent: (event: SemanticUiEvent) => void = () => {};
  build() { Column({ space: this.theme.spacing.sm }) { Row({ space: this.theme.spacing.sm }) { ForEach(this.model.value || [], (item: SemanticImageModel) => { SemanticImage({ theme: this.theme, source: item.source, alt: item.alt }).width(100).height(88); }, (item: SemanticImageModel) => item.id); Button('添加图片').onClick(() => this.onEvent(createSemanticEvent(this.model.id, 'pick'))); }.width('100%'); }.width('100%'); }
}

@ComponentV2
export struct FormActions {
  @Param actions: SemanticActionModel[] = [];
  @Param theme: SemanticTheme = createSemanticTheme(SemanticThemeMode.LIGHT);
  @Event onEvent: (event: SemanticUiEvent) => void = () => {};
  build() { Row({ space: this.theme.spacing.sm }) { ForEach(this.actions, (item: SemanticActionModel) => { SemanticButton({ theme: this.theme, label: item.label, isEnabled: item.enabled, onEvent: () => this.onEvent(createSemanticEvent(item.id, 'press')) }); }, (item: SemanticActionModel) => item.id); }.width('100%'); }
}
