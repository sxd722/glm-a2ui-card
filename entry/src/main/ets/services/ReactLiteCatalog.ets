export type ReactLiteCatalogLowering = 'native' | 'recipe' | 'core';
export type ReactLitePropRole = 'runtimeProp' | 'binding' | 'event' | 'compilerOnly';

export interface ReactLitePropDescriptor {
  name: string;
  role: ReactLitePropRole;
  required: boolean;
  type: string;
}

export interface ReactLiteComponentDescriptor {
  name: string;
  props: ReactLitePropDescriptor[];
  events: string[];
  supportsBinding: boolean;
  requiresItemTemplate: boolean;
  lowering: ReactLiteCatalogLowering;
}

export const REACT_LITE_COMPONENT_CATALOG: ReactLiteComponentDescriptor[] = [
  descriptor('AppShell', ['id', 'title', 'subtitle', 'initialPage'], [], false, false, 'core'),
  descriptor('Page', ['id', 'title', 'subtitle', 'scroll', 'layoutPreset'], [], false, false, 'core'),
  descriptor('SafeArea', [], [], false, false, 'core'), descriptor('Scroll', [], [], false, false, 'core'),
  descriptor('Column', [], [], false, false, 'core'), descriptor('Row', [], [], false, false, 'core'),
  descriptor('Stack', [], [], false, false, 'core'), descriptor('Grid', [], [], false, false, 'core'),
  descriptor('List', ['items', 'item', 'keyBy'], [], false, true, 'core'),
  descriptor('Card', [], [], false, false, 'recipe'), descriptor('Text', ['text'], [], false, false, 'core'),
  descriptor('Image', ['assetId'], [], false, false, 'core'), descriptor('Icon', ['name'], [], false, false, 'core'),
  descriptor('Badge', [], [], false, false, 'recipe'), descriptor('Progress', ['value'], [], false, false, 'core'),
  descriptor('Divider', [], [], false, false, 'core'), descriptor('Spacer', [], [], false, false, 'core'),
  descriptor('Button', ['text'], ['onPress', 'onLongPress'], false, false, 'core'),
  descriptor('IconButton', [], ['onPress'], false, false, 'core'),
  descriptor('TextInput', ['placeholder', 'value'], ['onChange', 'onSubmit'], true, false, 'core'),
  descriptor('TextArea', ['placeholder', 'value'], ['onChange', 'onSubmit'], true, false, 'core'),
  descriptor('Toggle', ['value', 'label'], ['onChange', 'onSelect'], true, false, 'core'),
  descriptor('Checkbox', ['checked', 'label'], ['onChange', 'onSelect'], true, false, 'core'),
  descriptor('ChoiceChips', ['items'], ['onChange', 'onSelect'], true, false, 'core'),
  descriptor('SegmentedControl', ['items'], ['onChange', 'onSelect'], true, false, 'core'),
  descriptor('Hero', [], [], false, false, 'recipe'), descriptor('Section', [], [], false, false, 'recipe'),
  descriptor('InfoCard', [], [], false, false, 'recipe'), descriptor('FormGroup', [], [], false, false, 'recipe'),
  descriptor('MetricGrid', [], [], false, false, 'recipe'), descriptor('Timeline', [], [], false, true, 'recipe'),
  descriptor('ResultList', ['items', 'item', 'keyBy'], [], false, true, 'recipe'),
  descriptor('MediaGallery', [], [], false, true, 'recipe'), descriptor('StatusBanner', [], [], false, false, 'recipe'),
  descriptor('Tabs', ['items'], ['onChange', 'onSelect'], true, false, 'recipe'),
  descriptor('ActionBar', [], [], false, false, 'recipe'), descriptor('EmptyState', [], [], false, false, 'recipe'),
  descriptor('Sheet', [], ['onDismiss'], false, false, 'recipe'), descriptor('If', ['when'], [], false, false, 'core'),
  descriptor('ForEach', ['items', 'item', 'keyBy'], [], false, true, 'core')
];

export function reactLiteComponentNames(): string[] {
  return REACT_LITE_COMPONENT_CATALOG.map((item: ReactLiteComponentDescriptor) => item.name);
}

export function reactLiteComponent(name: string): ReactLiteComponentDescriptor | undefined {
  for (let i: number = 0; i < REACT_LITE_COMPONENT_CATALOG.length; i++) {
    if (REACT_LITE_COMPONENT_CATALOG[i].name === name) { return REACT_LITE_COMPONENT_CATALOG[i]; }
  }
  return undefined;
}

export function reactLiteAllowedProps(name: string): string[] {
  let result: string[] = ['id', 'className', 'key'];
  let component = reactLiteComponent(name);
  if (component !== undefined) {
    if (component.supportsBinding) { result.push('bind'); }
    for (let i: number = 0; i < component.props.length; i++) { if (result.indexOf(component.props[i].name) < 0) { result.push(component.props[i].name); } }
  }
  if (name === 'ChoiceChips' || name === 'SegmentedControl' || name === 'Tabs') { result.push('options'); }
  return result;
}

export function reactLiteAllowedEvents(name: string): string[] {
  let component = reactLiteComponent(name); return component === undefined ? [] : component.events;
}

export function reactLiteComponentSignatures(): string[] {
  let result: string[] = [];
  for (let i: number = 0; i < REACT_LITE_COMPONENT_CATALOG.length; i++) {
    let item = REACT_LITE_COMPONENT_CATALOG[i];
    let props: string[] = item.props.map((prop: ReactLitePropDescriptor) => prop.name);
    if (item.supportsBinding) { props.push('bind'); }
    let events: string = item.events.length === 0 ? '' : ' events=' + item.events.join('|');
    result.push(item.name + '(' + props.join(',') + ')' + events);
  }
  return result;
}

export function reactLiteEventNames(): string[] {
  let result: string[] = [];
  for (let i: number = 0; i < REACT_LITE_COMPONENT_CATALOG.length; i++) {
    let events: string[] = REACT_LITE_COMPONENT_CATALOG[i].events;
    for (let j: number = 0; j < events.length; j++) { if (result.indexOf(events[j]) < 0) { result.push(events[j]); } }
  }
  return result;
}

function descriptor(name: string, props: string[], events: string[], binding: boolean, template: boolean,
  lowering: ReactLiteCatalogLowering): ReactLiteComponentDescriptor {
  let descriptors: ReactLitePropDescriptor[] = [];
  for (let i: number = 0; i < props.length; i++) {
    let propName: string = props[i];
    descriptors.push({ name: propName, role: propRole(propName), required: requiredProp(name, propName), type: propType(propName) });
  }
  return { name: name, props: descriptors, events: events, supportsBinding: binding, requiresItemTemplate: template, lowering: lowering };
}

function propRole(name: string): ReactLitePropRole {
  return name === 'bind' ? 'binding' : name.indexOf('on') === 0 ? 'event' : 'runtimeProp';
}

function requiredProp(component: string, prop: string): boolean {
  if (component === 'AppShell') { return ['id', 'title', 'initialPage'].indexOf(prop) >= 0; }
  if (component === 'Page') { return ['id', 'title'].indexOf(prop) >= 0; }
  if (component === 'Text' || component === 'Button') { return prop === 'text'; }
  if (component === 'ForEach' || component === 'List' || component === 'ResultList') { return ['items', 'item', 'keyBy'].indexOf(prop) >= 0; }
  return false;
}

function propType(prop: string): string {
  if (prop === 'id' || prop === 'title' || prop === 'subtitle' || prop === 'initialPage' || prop === 'text' || prop === 'placeholder' || prop === 'assetId') { return 'string'; }
  if (prop === 'scroll' || prop === 'checked') { return 'boolean'; }
  if (prop === 'value') { return 'expression'; }
  if (prop === 'items' || prop === 'options') { return 'array-expression'; }
  if (prop === 'item' || prop === 'keyBy') { return 'identifier'; }
  return 'UiValue';
}
