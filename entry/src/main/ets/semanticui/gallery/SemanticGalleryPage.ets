import { SemanticUiEvent, createSemanticEvent, itemPayload, textPayload } from '../foundation/SemanticEvents';
import { SemanticThemeMode, SemanticComponentCategory, SemanticViewStatus } from '../foundation/SemanticEnums';
import { SemanticTheme, createSemanticTheme } from '../foundation/SemanticTheme';
import { SemanticTextModel, SemanticListModel, SemanticOptionModel, SemanticOverlayModel, SemanticTaskItem, SemanticMetricItem } from '../foundation/SemanticModels';
import { SemanticComponentCatalog } from '../contracts/SemanticComponentCatalog';
import { SemanticComponentDescriptor } from '../contracts/SemanticComponentDescriptor';
import { AppShell } from '../components/pages/SemanticPages';
import { TopAppBar, BottomNavigation, TabNavigation, BottomActionBar } from '../components/navigation/SemanticNavigation';
import { Hero, SectionHeader, MetricGrid, SummaryCard, EmptyState, LoadingState } from '../components/presentation/SemanticPresentation';
import { TaskList, ItineraryList } from '../components/collection/SemanticCollections';
import { TextField, FormActions } from '../components/form/SemanticForms';
import { AgentSuggestion, ApprovalCard } from '../components/agent/SemanticAgentComponents';
import { TrendChart, MapPreview } from '../components/media/SemanticMedia';
import { Snackbar, BottomSheet } from '../components/feedback/SemanticFeedback';
import { GalleryState, todoListModel, travelListModel, todoField, sceneActions, travelMetrics, agentModel, chartModel } from './SemanticGalleryState';

@ComponentV2
export struct SemanticGalleryPage {
  @Local state: GalleryState = new GalleryState();
  private galleryTheme: SemanticTheme = createSemanticTheme(SemanticThemeMode.LIGHT);
  private shellModel: SemanticTextModel = new SemanticTextModel();

  aboutToAppear(): void { this.state = new GalleryState(); this.shellModel.id = 'shell'; this.shellModel.title = 'Semantic UI Kit'; this.shellModel.subtitle = 'Native component gallery'; }
  build() {
    Column() {
      TopAppBar({ model: this.shellModel, theme: this.galleryTheme, onEvent: (event: SemanticUiEvent) => this.handleEvent(event) });
      this.Body(this.galleryTheme);
      BottomNavigation({ model: this.bottomModel(), theme: this.galleryTheme, onEvent: (event: SemanticUiEvent) => this.handleEvent(event) });
      if (this.state.todoSheetVisible) { BottomSheet({ model: this.sheetModel(), theme: this.galleryTheme, onEvent: (event: SemanticUiEvent) => this.handleEvent(event) }); }
    }.width('100%').height('100%');
  }

  @Builder private Root(theme: SemanticTheme, shell: SemanticTextModel) {
    Column() {
      this.GalleryTop(shell, theme);
      this.Body(theme);
      this.GalleryBottom(theme);
    }.width('100%').height('100%');
  }

  @Builder private GalleryTop(shell: SemanticTextModel, theme: SemanticTheme) { TopAppBar({ model: shell, theme: theme, onEvent: (event: SemanticUiEvent) => this.handleEvent(event) }); }
  @Builder private GalleryBottom(theme: SemanticTheme) { BottomNavigation({ model: this.bottomModel(), theme: theme, onEvent: (event: SemanticUiEvent) => this.handleEvent(event) }); if (this.state.todoSheetVisible) { BottomSheet({ model: this.sheetModel(), theme: theme, onEvent: (event: SemanticUiEvent) => this.handleEvent(event) }); } }

  @Builder
  private Body(theme: SemanticTheme) {
    Scroll() { Column({ space: theme.spacing.md }) { this.CatalogIndex(theme); this.Scene(theme); this.EventInspector(theme); }.width('100%').padding({ left: theme.spacing.md, right: theme.spacing.md, bottom: 96 }); }.scrollBar(BarState.Off).width('100%').layoutWeight(1);
  }

  @Builder
  private CatalogIndex(theme: SemanticTheme) {
    Column({ space: theme.spacing.sm }) { Text('组件目录').fontSize(theme.typography.display).fontWeight(FontWeight.Bold); Text('72 个模型可见组件，统一使用 typed model + SemanticUiEvent。').fontColor(theme.colors.textSecondary); SearchFieldStub({ value: this.state.query, theme: theme, onEvent: (event: SemanticUiEvent) => { this.state.query = event.payload.textValue; } }); Scroll() { Row({ space: theme.spacing.xs }) { ForEach(this.categoryOptions(), (item: SemanticOptionModel) => { Button(item.label).backgroundColor(this.state.category === item.id ? theme.colors.primary : theme.colors.surfaceMuted).fontColor(this.state.category === item.id ? theme.colors.onPrimary : theme.colors.textPrimary).onClick(() => { this.state.category = item.id; }); }, (item: SemanticOptionModel) => item.id); }.padding({ right: theme.spacing.md }); }.scrollable(ScrollDirection.Horizontal).scrollBar(BarState.Off).width('100%'); List({ space: theme.spacing.xs }) { ForEach(this.visibleCatalog(), (item: SemanticComponentDescriptor) => { ListItem() { Row() { Text(item.type).fontWeight(FontWeight.Medium).layoutWeight(1); Text(item.category).fontSize(theme.typography.caption).fontColor(theme.colors.textSecondary); }.width('100%').padding(theme.spacing.sm).backgroundColor(this.state.selectedComponent === item.type ? theme.colors.primarySoft : theme.colors.surface).borderRadius(theme.radius.md).onClick(() => { this.state.selectedComponent = item.type; }); } }, (item: SemanticComponentDescriptor) => item.type); }.height(190).width('100%'); }.width('100%');
  }

  @Builder
  private Scene(theme: SemanticTheme) {
    Column({ space: theme.spacing.sm }) { Text('场景验证').fontSize(theme.typography.title).fontWeight(FontWeight.Bold); TabNavigation({ model: this.sceneTabModel(), theme: theme, onEvent: (event: SemanticUiEvent) => { this.state.selectedScene = event.payload.itemId; } }); if (this.state.selectedScene === 'todo') { this.TodoScene(theme); } else if (this.state.selectedScene === 'travel') { this.TravelScene(theme); } else if (this.state.selectedScene === 'search') { this.SearchScene(theme); } else { this.AgentScene(theme); } }.width('100%');
  }

  @Builder private TodoScene(theme: SemanticTheme) { Column({ space: theme.spacing.sm }) { SectionHeader({ model: this.sectionText('Todo', '本地 toggle、Sheet 和受控输入'), theme: theme }); TaskList({ model: todoListModel(this.state), theme: theme, onEvent: (event: SemanticUiEvent) => this.handleEvent(event) }); FormActions({ actions: sceneActions(), theme: theme, onEvent: (event: SemanticUiEvent) => this.handleEvent(event) }); if (this.state.todoSheetVisible) { Text('新增表单').fontWeight(FontWeight.Bold); TextField({ model: todoField(this.state), theme: theme, onEvent: (event: SemanticUiEvent) => { this.state.todoInput = event.payload.textValue; } }); } }.width('100%'); }
  @Builder private TravelScene(theme: SemanticTheme) { Column({ space: theme.spacing.sm }) { Hero({ model: this.heroText(), theme: theme, media: () => { Column().width('100%').height(220).backgroundColor(theme.colors.primary); }, content: () => { Text('五日行程札记').fontColor(theme.colors.onPrimary); } }); SummaryCard({ model: this.sectionText('京都慢旅行', '5 天行程，预算 ¥22,000'), theme: theme }); MetricGrid({ model: this.metricModel(), theme: theme }); ItineraryList({ model: travelListModel(this.state), theme: theme, onEvent: (event: SemanticUiEvent) => this.handleEvent(event) }); MapPreview({ model: this.sectionText('今日路线', '清水寺 → 祇园 → 哲学之道'), theme: theme, onEvent: (event: SemanticUiEvent) => this.handleEvent(event) }); TrendChart({ model: chartModel(), theme: theme }); }.width('100%'); }
  @Builder private SearchScene(theme: SemanticTheme) { Column({ space: theme.spacing.sm }) { SectionHeader({ model: this.sectionText('Search', '列表、空态、加载态和媒体组件'), theme: theme }); EmptyState({ model: this.emptyText(), theme: theme }); LoadingState({ model: this.loadingText(), theme: theme }); }.width('100%'); }
  @Builder private AgentScene(theme: SemanticTheme) { Column({ space: theme.spacing.sm }) { AgentSuggestion({ model: agentModel(), theme: theme, onEvent: (event: SemanticUiEvent) => this.handleEvent(event) }); ApprovalCard({ model: agentModel(), theme: theme, onEvent: (event: SemanticUiEvent) => this.handleEvent(event) }); }.width('100%'); }

  @Builder private EventInspector(theme: SemanticTheme) { Column({ space: theme.spacing.xs }) { Text('事件日志').fontSize(theme.typography.title).fontWeight(FontWeight.Bold); if (this.state.events.length === 0) { Text('点击组件操作查看 SemanticUiEvent').fontColor(theme.colors.textSecondary); } else { ForEach(this.state.events, (event: SemanticUiEvent, index: number) => { Text(event.sourceId + ' / ' + event.name).fontSize(theme.typography.caption).fontColor(theme.colors.textSecondary); }, (event: SemanticUiEvent, index: number) => event.sourceId + event.name + index.toString()); } }.width('100%'); }

  private bottomModel(): SemanticListModel<SemanticOptionModel> { let model: SemanticListModel<SemanticOptionModel> = new SemanticListModel<SemanticOptionModel>(); model.id = 'bottom-nav'; model.items = this.sceneTabs(); return model; }
  private sceneTabs(): SemanticOptionModel[] { return [this.option('todo', 'Todo'), this.option('travel', 'Travel'), this.option('search', 'Search'), this.option('agent', 'Agent')]; }
  private categoryOptions(): SemanticOptionModel[] { return [this.option('all', '全部'), this.option('page', '页面'), this.option('navigation', '导航'), this.option('presentation', '展示'), this.option('collection', '集合'), this.option('form', '表单'), this.option('feedback', '反馈'), this.option('media', '媒体'), this.option('agent', 'Agent')]; }
  private option(id: string, label: string): SemanticOptionModel { let option: SemanticOptionModel = new SemanticOptionModel(); option.id = id; option.label = label; return option; }
  private visibleCatalog(): SemanticComponentDescriptor[] { let result: SemanticComponentDescriptor[] = SemanticComponentCatalog.list().filter((item: SemanticComponentDescriptor) => this.state.category === 'all' || item.category === this.state.category); if (this.state.query.length > 0) { result = result.filter((item: SemanticComponentDescriptor) => item.type.toLowerCase().indexOf(this.state.query.toLowerCase()) >= 0); } return result; }
  private sectionText(title: string, body: string): SemanticTextModel { let model: SemanticTextModel = new SemanticTextModel(); model.id = title.toLowerCase(); model.title = title; model.body = body; return model; }
  private heroText(): SemanticTextModel { let model: SemanticTextModel = new SemanticTextModel(); model.id = 'travel-hero'; model.title = '京都慢旅行'; model.body = '五日行程札记'; return model; }
  private metricModel(): SemanticListModel<SemanticMetricItem> { let model: SemanticListModel<SemanticMetricItem> = new SemanticListModel<SemanticMetricItem>(); model.id = 'travel-metrics'; model.items = travelMetrics(); return model; }
  private emptyText(): SemanticTextModel { return this.sectionText('没有搜索结果', '尝试调整关键词或筛选条件。'); }
  private loadingText(): SemanticTextModel { let model = this.sectionText('加载示例', '组件提供 loading 状态'); model.status = SemanticViewStatus.LOADING; return model; }
  private sheetModel(): SemanticOverlayModel { let model: SemanticOverlayModel = new SemanticOverlayModel(); model.id = 'todo-sheet'; model.title = '新增计划'; model.body = '输入内容后点击保存，Runtime 负责分配稳定 ID。'; model.status = SemanticViewStatus.READY; return model; }
  private sceneTabModel(): SemanticListModel<SemanticOptionModel> { let model: SemanticListModel<SemanticOptionModel> = new SemanticListModel<SemanticOptionModel>(); model.id = 'scene-tabs'; model.items = this.sceneTabs(); return model; }
  private handleEvent(event: SemanticUiEvent): void { this.state.addEvent(event); if (event.name === 'toggle' && event.payload.actionId.length > 0) { this.state.todoTasks = this.state.todoTasks.map((item) => { if (item.id === event.payload.actionId) { let next = new SemanticTaskItem(); next.id = item.id; next.title = item.title; next.subtitle = event.payload.booleanValue ? '已完成' : '今天'; next.done = event.payload.booleanValue; next.badge = item.badge; return next; } return item; }); } if (event.payload.actionId === 'add' || event.sourceId === 'add') { this.state.todoSheetVisible = true; } if (event.name === 'dismiss' || event.payload.actionId === 'reset') { this.state.todoSheetVisible = false; } }
}

@ComponentV2
struct SearchFieldStub {
  @Param value: string = '';
  @Param theme: SemanticTheme = createSemanticTheme(SemanticThemeMode.LIGHT);
  @Event onEvent: (event: SemanticUiEvent) => void = () => {};
  build() { TextInput({ text: this.value, placeholder: '搜索组件' }).onChange((value: string) => this.onEvent(createSemanticEvent('catalog-search', 'change', textPayload(value)))).width('100%').height(42); }
}
