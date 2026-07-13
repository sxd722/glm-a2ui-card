export type NestedNodeKind = 'heroMedia' | 'glassPanel' | 'sectionHeader' | 'formField' | 'choiceChips' |
  'timeline' | 'metric' | 'mediaGallery' | 'actionBar' | 'statusBanner' | 'resultList' | 'dataChart' |
  'compareTable' | 'entityPicker' | 'conversationPanel' | 'credentialForm' | 'dynamicSlot';

export type NestedActionKind = 'navigate' | 'back' | 'invokeAgent' | 'pickLocalImage' | 'reset';
export type NestedActionHandling = 'local' | 'agent' | 'localThenAgent';

export interface NestedAction {
  id: string;
  label: string;
  kind: NestedActionKind;
  targetPageId: string;
  payload: string;
  handling?: NestedActionHandling;
}

export interface NestedNode {
  id: string;
  kind: NestedNodeKind;
  title: string;
  text: string;
  binding: string;
  assetId: string;
  items: string[];
  actions: NestedAction[];
  tone: string;
}

export interface NestedPageSpec {
  id: string;
  title: string;
  subtitle: string;
  nodes: NestedNode[];
}

export interface NestedAppSpec {
  appId: string;
  title: string;
  subtitle: string;
  initialPageId: string;
  pages: NestedPageSpec[];
}

export interface LocalImageAsset {
  id: string;
  name: string;
  dataUrl: string;
}

export interface NestedSessionState {
  app: NestedAppSpec;
  activePageId: string;
  routeStack: string[];
  data: Record<string, string>;
  assets: LocalImageAsset[];
  status: string;
  agentTrace: string;
  errorMessage: string;
}
