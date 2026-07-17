import { SemanticComponentCategory, SemanticDensity, SemanticTone, SemanticValueType } from '../foundation/SemanticEnums';
import { SemanticComponentDescriptor, semanticProperty } from './SemanticComponentDescriptor';

const MODEL_BASE: string = 'SemanticComponentBaseModel';
const ALL_TONES: SemanticTone[] = [SemanticTone.NEUTRAL, SemanticTone.PRIMARY, SemanticTone.INFO, SemanticTone.SUCCESS, SemanticTone.WARNING, SemanticTone.DANGER];
const ALL_DENSITIES: SemanticDensity[] = [SemanticDensity.COMPACT, SemanticDensity.COMFORTABLE, SemanticDensity.SPACIOUS];

function descriptor(type: string, arktsName: string, category: SemanticComponentCategory, modelName: string,
  events: string[] = [], slots: string[] = [], properties: string[] = []): SemanticComponentDescriptor {
  let item: SemanticComponentDescriptor = new SemanticComponentDescriptor();
  item.type = type;
  item.arktsName = arktsName;
  item.category = category;
  item.modelName = modelName;
  item.events = events;
  item.slots = slots;
  item.tones = ALL_TONES;
  item.densities = ALL_DENSITIES;
  for (let i: number = 0; i < properties.length; i++) {
    item.properties.push(semanticProperty(properties[i], SemanticValueType.STRING));
  }
  item.properties.push(semanticProperty('id', SemanticValueType.STRING, true, MODEL_BASE));
  item.properties.push(semanticProperty('model', SemanticValueType.MODEL, true, modelName));
  return item;
}

const CATALOG_ITEMS: SemanticComponentDescriptor[] = [
  descriptor('app-shell', 'AppShell', SemanticComponentCategory.PAGE, 'SemanticPageModel', ['back', 'action'], ['top', 'body', 'bottom', 'overlay']),
  descriptor('list-page', 'ListPage', SemanticComponentCategory.PAGE, 'SemanticPageModel', [], ['header', 'list', 'empty']),
  descriptor('detail-page', 'DetailPage', SemanticComponentCategory.PAGE, 'SemanticPageModel', [], ['header', 'body', 'actions']),
  descriptor('form-page', 'FormPage', SemanticComponentCategory.PAGE, 'SemanticPageModel', [], ['header', 'fields', 'actions']),
  descriptor('dashboard-page', 'DashboardPage', SemanticComponentCategory.PAGE, 'SemanticPageModel', [], ['header', 'body']),
  descriptor('search-page', 'SearchPage', SemanticComponentCategory.PAGE, 'SemanticPageModel', [], ['search', 'filters', 'results']),
  descriptor('wizard-page', 'WizardPage', SemanticComponentCategory.PAGE, 'SemanticPageModel', ['selectStep'], ['header', 'step', 'actions']),
  descriptor('agent-page', 'AgentPage', SemanticComponentCategory.PAGE, 'SemanticPageModel', ['action'], ['header', 'messages', 'composer']),

  descriptor('top-app-bar', 'TopAppBar', SemanticComponentCategory.NAVIGATION, 'SemanticTextModel', ['back', 'action']),
  descriptor('page-header', 'PageHeader', SemanticComponentCategory.NAVIGATION, 'SemanticTextModel', ['action']),
  descriptor('bottom-navigation', 'BottomNavigation', SemanticComponentCategory.NAVIGATION, 'SemanticListModel<SemanticOptionModel>', ['select']),
  descriptor('tab-navigation', 'TabNavigation', SemanticComponentCategory.NAVIGATION, 'SemanticListModel<SemanticOptionModel>', ['select']),
  descriptor('segmented-navigation', 'SegmentedNavigation', SemanticComponentCategory.NAVIGATION, 'SemanticListModel<SemanticOptionModel>', ['change']),
  descriptor('stepper-navigation', 'StepperNavigation', SemanticComponentCategory.NAVIGATION, 'SemanticListModel<SemanticOptionModel>', ['selectStep']),
  descriptor('filter-bar', 'FilterBar', SemanticComponentCategory.NAVIGATION, 'SemanticListModel<SemanticOptionModel>', ['change', 'clear', 'openAdvanced']),
  descriptor('bottom-action-bar', 'BottomActionBar', SemanticComponentCategory.NAVIGATION, 'SemanticTextModel', ['action']),

  descriptor('hero', 'Hero', SemanticComponentCategory.PRESENTATION, 'SemanticTextModel', ['action'], ['media', 'content']),
  descriptor('section', 'SemanticSection', SemanticComponentCategory.PRESENTATION, 'SemanticTextModel', [], ['header', 'body']),
  descriptor('section-header', 'SectionHeader', SemanticComponentCategory.PRESENTATION, 'SemanticTextModel', ['action']),
  descriptor('summary-card', 'SummaryCard', SemanticComponentCategory.PRESENTATION, 'SemanticTextModel', ['action']),
  descriptor('info-card', 'InfoCard', SemanticComponentCategory.PRESENTATION, 'SemanticTextModel', ['action']),
  descriptor('metric-card', 'MetricCard', SemanticComponentCategory.PRESENTATION, 'SemanticMetricItem', ['action']),
  descriptor('metric-grid', 'MetricGrid', SemanticComponentCategory.PRESENTATION, 'SemanticListModel<SemanticMetricItem>', ['select']),
  descriptor('key-value-list', 'KeyValueList', SemanticComponentCategory.PRESENTATION, 'SemanticListModel<SemanticKeyValueItem>'),
  descriptor('callout', 'Callout', SemanticComponentCategory.PRESENTATION, 'SemanticTextModel', ['action']),
  descriptor('empty-state', 'EmptyState', SemanticComponentCategory.PRESENTATION, 'SemanticTextModel', ['action']),
  descriptor('error-state', 'ErrorState', SemanticComponentCategory.PRESENTATION, 'SemanticTextModel', ['retry']),
  descriptor('loading-state', 'LoadingState', SemanticComponentCategory.PRESENTATION, 'SemanticTextModel', ['action']),

  descriptor('entity-list', 'EntityList', SemanticComponentCategory.COLLECTION, 'SemanticListModel<SemanticEntityItem>', ['select', 'action', 'reachEnd']),
  descriptor('result-list', 'ResultList', SemanticComponentCategory.COLLECTION, 'SemanticListModel<SemanticEntityItem>', ['select', 'action', 'reachEnd']),
  descriptor('task-list', 'TaskList', SemanticComponentCategory.COLLECTION, 'SemanticListModel<SemanticTaskItem>', ['toggle', 'select', 'action']),
  descriptor('checklist', 'Checklist', SemanticComponentCategory.COLLECTION, 'SemanticListModel<SemanticTaskItem>', ['toggle', 'select']),
  descriptor('timeline', 'Timeline', SemanticComponentCategory.COLLECTION, 'SemanticListModel<SemanticTimelineItem>', ['select', 'action']),
  descriptor('activity-feed', 'ActivityFeed', SemanticComponentCategory.COLLECTION, 'SemanticListModel<SemanticEntityItem>', ['select']),
  descriptor('message-list', 'MessageList', SemanticComponentCategory.COLLECTION, 'SemanticListModel<SemanticMessageItem>', ['select', 'retry', 'action']),
  descriptor('media-list', 'MediaList', SemanticComponentCategory.COLLECTION, 'SemanticListModel<SemanticMediaItem>', ['select', 'play', 'action']),
  descriptor('gallery-grid', 'GalleryGrid', SemanticComponentCategory.COLLECTION, 'SemanticListModel<SemanticMediaItem>', ['select', 'reachEnd']),
  descriptor('schedule-list', 'ScheduleList', SemanticComponentCategory.COLLECTION, 'SemanticListModel<SemanticScheduleItem>', ['select', 'action']),
  descriptor('itinerary-list', 'ItineraryList', SemanticComponentCategory.COLLECTION, 'SemanticListModel<SemanticItineraryItem>', ['select', 'action']),
  descriptor('comparison-table', 'ComparisonTable', SemanticComponentCategory.COLLECTION, 'SemanticListModel<SemanticKeyValueItem>', ['selectCell', 'selectColumn']),

  descriptor('field-group', 'FieldGroup', SemanticComponentCategory.FORM, 'SemanticTextModel', [], ['fields']),
  descriptor('text-field', 'TextField', SemanticComponentCategory.FORM, 'SemanticFieldModel<string>', ['change', 'submit', 'focus', 'blur']),
  descriptor('text-area-field', 'TextAreaField', SemanticComponentCategory.FORM, 'SemanticFieldModel<string>', ['change', 'focus', 'blur']),
  descriptor('number-field', 'NumberField', SemanticComponentCategory.FORM, 'SemanticFieldModel<number>', ['change', 'increment', 'decrement']),
  descriptor('search-field', 'SearchField', SemanticComponentCategory.FORM, 'SemanticFieldModel<string>', ['change', 'submit', 'selectSuggestion', 'clear']),
  descriptor('select-field', 'SelectField', SemanticComponentCategory.FORM, 'SemanticFieldModel<string>', ['change', 'open']),
  descriptor('multi-select-field', 'MultiSelectField', SemanticComponentCategory.FORM, 'SemanticFieldModel<string[]>', ['change']),
  descriptor('choice-chips-field', 'ChoiceChipsField', SemanticComponentCategory.FORM, 'SemanticFieldModel<string>', ['change']),
  descriptor('checkbox-field', 'CheckboxField', SemanticComponentCategory.FORM, 'SemanticFieldModel<boolean>', ['change']),
  descriptor('switch-field', 'SwitchField', SemanticComponentCategory.FORM, 'SemanticFieldModel<boolean>', ['change']),
  descriptor('date-field', 'DateField', SemanticComponentCategory.FORM, 'SemanticFieldModel<string>', ['change', 'open']),
  descriptor('time-field', 'TimeField', SemanticComponentCategory.FORM, 'SemanticFieldModel<string>', ['change', 'open']),
  descriptor('date-range-field', 'DateRangeField', SemanticComponentCategory.FORM, 'SemanticFieldModel<string[]>', ['change', 'open']),
  descriptor('slider-field', 'SliderField', SemanticComponentCategory.FORM, 'SemanticFieldModel<number>', ['change', 'changeEnd']),
  descriptor('image-picker-field', 'ImagePickerField', SemanticComponentCategory.FORM, 'SemanticFieldModel<SemanticImageModel[]>', ['pick', 'remove', 'reorder']),
  descriptor('form-actions', 'FormActions', SemanticComponentCategory.FORM, 'SemanticTextModel', ['action']),

  descriptor('status-banner', 'StatusBanner', SemanticComponentCategory.FEEDBACK, 'SemanticTextModel', ['action']),
  descriptor('snackbar', 'SemanticSnackbar', SemanticComponentCategory.FEEDBACK, 'SemanticOverlayModel', ['action', 'dismiss']),
  descriptor('confirmation-dialog', 'ConfirmationDialog', SemanticComponentCategory.FEEDBACK, 'SemanticOverlayModel', ['confirm', 'cancel', 'dismiss']),
  descriptor('bottom-sheet', 'BottomSheet', SemanticComponentCategory.FEEDBACK, 'SemanticOverlayModel', ['dismiss', 'action']),
  descriptor('action-sheet', 'ActionSheet', SemanticComponentCategory.FEEDBACK, 'SemanticOverlayModel', ['action', 'cancel', 'dismiss']),
  descriptor('loading-overlay', 'LoadingOverlay', SemanticComponentCategory.FEEDBACK, 'SemanticOverlayModel', ['cancel']),

  descriptor('image-hero', 'ImageHero', SemanticComponentCategory.MEDIA, 'SemanticTextModel', ['press', 'action'], ['media', 'content']),
  descriptor('media-preview', 'MediaPreview', SemanticComponentCategory.MEDIA, 'SemanticMediaItem', ['open', 'play', 'pause', 'action']),
  descriptor('map-preview', 'MapPreview', SemanticComponentCategory.MEDIA, 'SemanticListModel<SemanticEntityItem>', ['openMap', 'selectMarker', 'action']),
  descriptor('progress-summary', 'ProgressSummary', SemanticComponentCategory.MEDIA, 'SemanticMetricItem', ['selectSegment']),
  descriptor('trend-chart', 'TrendChart', SemanticComponentCategory.MEDIA, 'SemanticChartModel', ['selectPoint']),
  descriptor('bar-chart', 'BarChart', SemanticComponentCategory.MEDIA, 'SemanticChartModel', ['selectBar']),

  descriptor('agent-suggestion', 'AgentSuggestion', SemanticComponentCategory.AGENT, 'SemanticAgentModel', ['generate', 'accept', 'reject', 'retry']),
  descriptor('agent-result', 'AgentResult', SemanticComponentCategory.AGENT, 'SemanticAgentModel', ['action', 'openSource', 'retry']),
  descriptor('approval-card', 'ApprovalCard', SemanticComponentCategory.AGENT, 'SemanticAgentModel', ['approve', 'reject', 'edit']),
  descriptor('tool-result-card', 'ToolResultCard', SemanticComponentCategory.AGENT, 'SemanticAgentModel', ['action', 'retry', 'openDetails'])
];

export class SemanticComponentCatalog {
  static readonly catalogVersion: number = 1;
  static readonly catalogHash: string = hashCatalog(CATALOG_ITEMS);

  static list(): SemanticComponentDescriptor[] { return CATALOG_ITEMS.slice(); }

  static findByType(type: string): SemanticComponentDescriptor | undefined {
    for (let i: number = 0; i < CATALOG_ITEMS.length; i++) {
      if (CATALOG_ITEMS[i].type === type) { return CATALOG_ITEMS[i]; }
    }
    return undefined;
  }

  static listByCategory(category: SemanticComponentCategory): SemanticComponentDescriptor[] {
    let result: SemanticComponentDescriptor[] = [];
    for (let i: number = 0; i < CATALOG_ITEMS.length; i++) {
      if (CATALOG_ITEMS[i].category === category) { result.push(CATALOG_ITEMS[i]); }
    }
    return result;
  }
}

function hashCatalog(items: SemanticComponentDescriptor[]): string {
  let text: string = 'semantic-catalog-v1';
  for (let i: number = 0; i < items.length; i++) {
    let item: SemanticComponentDescriptor = items[i];
    text += '|' + item.type + ':' + item.arktsName + ':' + item.category + ':' + item.modelName + ':' + item.events.join(',') + ':' + item.slots.join(',');
  }
  let hash: number = 2166136261;
  for (let i: number = 0; i < text.length; i++) {
    hash = (hash ^ text.charCodeAt(i)) * 16777619;
    hash = hash % 4294967291;
  }
  let value: string = Math.floor(hash).toString(16).toUpperCase();
  while (value.length < 8) { value = '0' + value; }
  return value;
}

export const SEMANTIC_COMPONENT_COUNT: number = CATALOG_ITEMS.length;
