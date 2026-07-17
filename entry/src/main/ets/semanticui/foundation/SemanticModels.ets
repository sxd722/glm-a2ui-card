import { SemanticActionStyle, SemanticAgentStatus, SemanticDensity, SemanticSize, SemanticTone, SemanticViewStatus } from './SemanticEnums';

export class SemanticComponentBaseModel {
  id: string = '';
  variant: string = 'standard';
  tone: SemanticTone = SemanticTone.NEUTRAL;
  density: SemanticDensity = SemanticDensity.COMFORTABLE;
  size: SemanticSize = SemanticSize.MEDIUM;
  status: SemanticViewStatus = SemanticViewStatus.READY;
  enabled: boolean = true;
  accessibilityLabel: string = '';
  progress: number = 0;
}

export class SemanticActionModel {
  id: string = '';
  label: string = '';
  style: SemanticActionStyle = SemanticActionStyle.PRIMARY;
  enabled: boolean = true;
  icon: string = '';
}

export class SemanticOptionModel {
  id: string = '';
  label: string = '';
  selected: boolean = false;
  enabled: boolean = true;
}

export class SemanticImageModel {
  id: string = '';
  assetId: string = '';
  source: string = '';
  alt: string = '';
  caption: string = '';
}

export class SemanticBadgeModel {
  id: string = '';
  label: string = '';
  tone: SemanticTone = SemanticTone.NEUTRAL;
}

export class SemanticKeyValueItem {
  id: string = '';
  key: string = '';
  value: string = '';
  tone: SemanticTone = SemanticTone.NEUTRAL;
}

export class SemanticMetricItem {
  id: string = '';
  label: string = '';
  value: string = '';
  detail: string = '';
  tone: SemanticTone = SemanticTone.NEUTRAL;
}

export class SemanticEntityItem {
  id: string = '';
  title: string = '';
  subtitle: string = '';
  description: string = '';
  image: SemanticImageModel = new SemanticImageModel();
  badge: SemanticBadgeModel = new SemanticBadgeModel();
  enabled: boolean = true;
}

export class SemanticTaskItem {
  id: string = '';
  title: string = '';
  subtitle: string = '';
  done: boolean = false;
  disabled: boolean = false;
  badge: SemanticBadgeModel = new SemanticBadgeModel();
}

export class SemanticTimelineItem {
  id: string = '';
  time: string = '';
  title: string = '';
  detail: string = '';
  completed: boolean = false;
}

export class SemanticMessageItem {
  id: string = '';
  sender: string = '';
  text: string = '';
  timestamp: string = '';
  outgoing: boolean = false;
  status: SemanticAgentStatus = SemanticAgentStatus.COMPLETE;
}

export class SemanticMediaItem {
  id: string = '';
  title: string = '';
  image: SemanticImageModel = new SemanticImageModel();
  duration: string = '';
  playing: boolean = false;
}

export class SemanticScheduleItem {
  id: string = '';
  time: string = '';
  title: string = '';
  location: string = '';
  status: SemanticViewStatus = SemanticViewStatus.READY;
}

export class SemanticItineraryItem {
  id: string = '';
  day: string = '';
  time: string = '';
  title: string = '';
  location: string = '';
  detail: string = '';
}

export class SemanticChartSeries {
  id: string = '';
  label: string = '';
  values: number[] = [];
  colorKey: string = 'primary';
}

export class SemanticSourceItem {
  id: string = '';
  title: string = '';
  uri: string = '';
  detail: string = '';
}

export class SemanticTextModel extends SemanticComponentBaseModel {
  title: string = '';
  subtitle: string = '';
  body: string = '';
  value: string = '';
  icon: string = '';
  actions: SemanticActionModel[] = [];
}

export class SemanticListModel<T> extends SemanticComponentBaseModel {
  title: string = '';
  emptyTitle: string = '暂无内容';
  emptyBody: string = '这里还没有可展示的数据。';
  items: T[] = [];
  selectedId: string = '';
  actions: SemanticActionModel[] = [];
}

export class SemanticFieldModel<T> extends SemanticComponentBaseModel {
  label: string = '';
  helper: string = '';
  error: string = '';
  required: boolean = false;
  value: T | undefined = undefined;
  values: string[] = [];
  options: SemanticOptionModel[] = [];
}

export class SemanticOverlayModel extends SemanticComponentBaseModel {
  title: string = '';
  body: string = '';
  actions: SemanticActionModel[] = [];
  progress: number = 0;
  cancellable: boolean = false;
}

export class SemanticChartModel extends SemanticComponentBaseModel {
  title: string = '';
  summary: string = '';
  series: SemanticChartSeries[] = [];
  maxValue: number = 0;
}

export class SemanticAgentModel extends SemanticComponentBaseModel {
  title: string = '';
  body: string = '';
  agentStatus: SemanticAgentStatus = SemanticAgentStatus.IDLE;
  actions: SemanticActionModel[] = [];
  sources: SemanticSourceItem[] = [];
  riskLevel: string = '';
}

export class SemanticOverlayPresentation {
  kind: string = 'none';
  snackbar: SemanticOverlayModel = new SemanticOverlayModel();
  confirmation: SemanticOverlayModel = new SemanticOverlayModel();
  sheet: SemanticOverlayModel = new SemanticOverlayModel();
  loading: SemanticOverlayModel = new SemanticOverlayModel();
}

export function finiteNumber(value: number, fallback: number = 0): number {
  return Number.isFinite(value) ? value : fallback;
}

export function hasUniqueIds(items: SemanticTaskItem[]): boolean {
  let seen: string[] = [];
  for (let i: number = 0; i < items.length; i++) {
    if (items[i].id.length === 0 || seen.indexOf(items[i].id) >= 0) { return false; }
    seen.push(items[i].id);
  }
  return true;
}
