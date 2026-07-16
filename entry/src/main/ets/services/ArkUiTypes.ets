export type ArkUiNodeType = 'Column' | 'Row' | 'Stack' | 'Scroll' | 'Grid' | 'List' |
  'Text' | 'Image' | 'Button' | 'TextInput' | 'TextArea' | 'Toggle' | 'Progress' |
  'ChoiceChips' | 'SegmentedControl' | 'Divider' | 'Spacer' | 'Badge' | 'DynamicSlot';

export type ArkUiActionKind = 'navigate' | 'back' | 'localMutate' | 'invokeTool' | 'invokeAgent' | 'pickLocalImage' | 'reset';
export type ArkUiActionHandling = 'local' | 'agent' | 'localThenAgent';

export type LocalMutationOp = 'set' | 'toggle' | 'increment' | 'append' | 'remove' | 'merge' | 'clear';

export interface LocalMutation {
  op: LocalMutationOp;
  path: string;
  value: string;
  valueFrom: string;
}

export interface LocalCondition {
  path: string;
  op: 'exists' | 'eq' | 'neq' | 'truthy' | 'contains' | 'gt' | 'gte' | 'lt' | 'lte';
  value: string;
}

export interface ArkUiToolAction {
  name: string;
  args: Record<string, string>;
  resultBindings: Record<string, string>;
}

export interface ArkUiAction {
  id: string;
  label: string;
  kind: ArkUiActionKind;
  targetPageId: string;
  payload: string;
  handling: ArkUiActionHandling;
  effects?: LocalMutation[];
  guards?: LocalCondition[];
  tool?: ArkUiToolAction;
}

export interface ArkUiRepeatBinding {
  source: string;
  itemAlias: string;
  keyPath?: string;
}

export interface ArkUiNode {
  id: string;
  type: ArkUiNodeType;
  className: string;
  props: Record<string, string>;
  binding: string;
  repeat?: ArkUiRepeatBinding;
  visibleWhen?: LocalCondition;
  enabledWhen?: LocalCondition;
  selectedWhen?: LocalCondition;
  actions: ArkUiAction[];
  children: ArkUiNode[];
}

export interface ArkUiPage {
  id: string;
  title: string;
  scroll: boolean;
  root: ArkUiNode;
}

export interface ArkUiPageParseResult {
  ok: boolean;
  value: ArkUiPage | undefined;
  diagnostics: string[];
  repairedFields: string[];
}

export interface ArkUiTheme {
  colors: Record<string, string>;
}

export interface ArkUiSpec {
  schemaVersion: string;
  appId: string;
  title: string;
  subtitle: string;
  initialPageId: string;
  theme: ArkUiTheme;
  pages: ArkUiPage[];
}

export interface ResolvedArkUiStyle {
  paddingTop: number;
  paddingRight: number;
  paddingBottom: number;
  paddingLeft: number;
  marginTop: number;
  marginRight: number;
  marginBottom: number;
  marginLeft: number;
  gap: number;
  backgroundColor: string;
  foregroundColor: string;
  borderColor: string;
  borderWidth: number;
  borderRadius: number;
  fontSize: number;
  fontWeight: string;
  textAlign: string;
  opacity: number;
  shadowRadius: number;
  shadowColor: string;
  shadowOffsetY: number;
  widthFull: boolean;
  heightFull: boolean;
  height: number;
  layoutWeight: number;
  align: string;
  justify: string;
  objectFit: string;
  blurStyle: string;
  gradientFrom: string;
  gradientTo: string;
  gradientAngle: number;
}

export interface CompiledArkUiNode {
  id: string;
  type: ArkUiNodeType;
  props: Record<string, string>;
  binding: string;
  repeat?: ArkUiRepeatBinding;
  actions: ArkUiAction[];
  children: CompiledArkUiNode[];
  visibleWhen?: LocalCondition;
  enabledWhen?: LocalCondition;
  selectedWhen?: LocalCondition;
  style: ResolvedArkUiStyle;
  // Deprecated renderer fields stay internal for one migration release; they are never accepted in ArkUiSpec JSON.
  kind: string;
  title: string;
  text: string;
  assetId: string;
  items: string[];
  tone: string;
}

export interface CompiledArkUiPage {
  id: string;
  title: string;
  scroll: boolean;
  root: CompiledArkUiNode;
}

export interface CompiledArkUiSpec {
  schemaVersion: string;
  appId: string;
  title: string;
  subtitle: string;
  initialPageId: string;
  theme: ArkUiTheme;
  pages: CompiledArkUiPage[];
}

export interface LocalImageAsset {
  id: string;
  name: string;
  dataUrl: string;
}

export interface ArkUiSessionState {
  app: CompiledArkUiSpec;
  activePageId: string;
  routeStack: string[];
  data: Record<string, string>;
  assets: LocalImageAsset[];
  status: string;
  agentTrace: string;
  errorMessage: string;
}
