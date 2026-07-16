export type UiValueKind = 'null' | 'string' | 'number' | 'boolean' | 'array' | 'object';

export interface UiValue {
  kind: UiValueKind;
  stringValue: string;
  numberValue: number;
  booleanValue: boolean;
  arrayValue: UiValue[];
  objectValue: Record<string, UiValue>;
}

export type UiExpressionKind = 'literal' | 'path' | 'unary' | 'binary' | 'conditional' |
  'array' | 'object' | 'intrinsicCall' | 'lambda' | 'jsx' | 'map';

export interface UiExpressionProperty {
  key: string;
  value: UiExpression;
}

export interface UiExpression {
  kind: UiExpressionKind;
  literalValue?: UiValue;
  root: string;
  segments: string[];
  operator: string;
  left?: UiExpression;
  right?: UiExpression;
  test?: UiExpression;
  consequent?: UiExpression;
  alternate?: UiExpression;
  items: UiExpression[];
  properties: UiExpressionProperty[];
  callee: string;
  args: UiExpression[];
}

export type UiComponentType = 'SafeArea' | 'Scroll' | 'Column' | 'Row' | 'Stack' | 'Grid' | 'List' |
  'Card' | 'Text' | 'Image' | 'Icon' | 'Badge' | 'Progress' | 'Divider' | 'Spacer' |
  'Button' | 'IconButton' | 'TextInput' | 'TextArea' | 'Toggle' | 'Checkbox' |
  'ChoiceChips' | 'SegmentedControl' | 'Hero' | 'Section' | 'InfoCard' | 'FormGroup' |
  'MetricGrid' | 'Timeline' | 'ResultList' | 'MediaGallery' | 'StatusBanner' | 'Tabs' |
  'ActionBar' | 'EmptyState' | 'Sheet';

export type UiActionKind = 'state.set' | 'state.toggle' | 'state.increment' | 'list.append' |
  'list.appendWithId' | 'list.updateWhere' | 'list.removeWhere' | 'list.toggleWhere' | 'navigation.push' |
  'navigation.back' | 'navigation.popTo' | 'navigation.replace' | 'app.reset' | 'asset.pickLocalImage' | 'tool.invoke' |
  'agent.invoke' | 'action.sequence' | 'action.transaction';

export interface UiAction {
  id: string;
  kind: UiActionKind;
  targetPageId: string;
  path: string;
  keyField: string;
  keyValue?: UiExpression;
  targetField: string;
  idPrefix: string;
  amount?: UiExpression;
  value?: UiExpression;
  toolName: string;
  toolArgs: UiExpression;
  resultBindings: Record<string, string>;
  intent: string;
  statusPath?: string;
  successSteps?: UiAction[];
  errorSteps?: UiAction[];
  assetSlotId: string;
  steps: UiAction[];
}

export type UiIrNodeKind = 'element' | 'if' | 'forEach';

export interface UiIrNode {
  kind: UiIrNodeKind;
  id: string;
  component: UiComponentType;
  props: Record<string, UiExpression>;
  binding: string;
  className: string;
  actions: Record<string, UiAction>;
  children: UiIrNode[];
  condition?: UiExpression;
  source?: UiExpression;
  itemAlias: string;
  keyPath: string;
}

export interface UiIrPage {
  id: string;
  title: string;
  scroll: boolean;
  layoutPreset: string;
  root: UiIrNode;
  overlays?: UiIrNode[];
}

export interface UiIrTheme {
  name: string;
  tokens: Record<string, string>;
}

export interface UiComputedDefinition {
  name: string;
  expression: UiExpression;
}

export interface UiIrSpec {
  schemaVersion: string;
  appId: string;
  title: string;
  subtitle: string;
  initialPageId: string;
  theme: UiIrTheme;
  initialState: Record<string, UiValue>;
  computed: UiComputedDefinition[];
  pages: UiIrPage[];
}

export interface UiEvaluationScope {
  aliases: Record<string, UiValue>;
  event: Record<string, UiValue>;
}

export interface UiIrSessionState {
  app: UiIrSpec;
  activePageId: string;
  routeStack: string[];
  state: Record<string, UiValue>;
  assets: LocalImageAssetRef[];
  status: string;
  agentTrace: string;
  errorMessage: string;
  stateRevision: number;
  computedCacheRevision: number;
  computedCache: Record<string, UiValue>;
}

export interface LocalImageAssetRef {
  id: string;
  name: string;
  dataUrl: string;
}

export interface UiIrDiagnostic {
  code: string;
  severity: 'error' | 'warning';
  message: string;
  nodeId: string;
  path: string;
}

export interface UiIrValidationResult {
  ok: boolean;
  diagnostics: UiIrDiagnostic[];
}

export interface UiIrCompileResult {
  ok: boolean;
  value: UiIrSpec | undefined;
  diagnostics: UiIrDiagnostic[];
}
