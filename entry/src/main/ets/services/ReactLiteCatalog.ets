export type ReactLiteCatalogLowering = 'native' | 'recipe' | 'core';

export interface ReactLiteComponentDescriptor {
  name: string;
  props: string[];
  events: string[];
  supportsBinding: boolean;
  requiresItemTemplate: boolean;
  lowering: ReactLiteCatalogLowering;
}

export const REACT_LITE_COMPONENT_CATALOG: ReactLiteComponentDescriptor[] = [
  descriptor('AppShell', [], [], false, false, 'core'),
  descriptor('Page', ['id', 'title', 'scroll'], [], false, false, 'core'),
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
  descriptor('TextInput', ['placeholder'], ['onChange', 'onSubmit'], true, false, 'core'),
  descriptor('TextArea', ['placeholder'], ['onChange', 'onSubmit'], true, false, 'core'),
  descriptor('Toggle', [], ['onChange', 'onSelect'], true, false, 'core'),
  descriptor('Checkbox', [], ['onChange', 'onSelect'], true, false, 'core'),
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

function descriptor(name: string, props: string[], events: string[], binding: boolean, template: boolean,
  lowering: ReactLiteCatalogLowering): ReactLiteComponentDescriptor {
  return { name: name, props: props, events: events, supportsBinding: binding, requiresItemTemplate: template, lowering: lowering };
}
