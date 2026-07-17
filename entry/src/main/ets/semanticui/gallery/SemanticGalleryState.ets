import { SemanticUiEvent } from '../foundation/SemanticEvents';
import { SemanticActionStyle, SemanticAgentStatus, SemanticDensity, SemanticSize, SemanticTone, SemanticViewStatus } from '../foundation/SemanticEnums';
import { SemanticActionModel, SemanticAgentModel, SemanticChartModel, SemanticChartSeries, SemanticFieldModel, SemanticImageModel, SemanticItineraryItem, SemanticListModel, SemanticMetricItem, SemanticOptionModel, SemanticOverlayModel, SemanticTaskItem, SemanticTextModel, SemanticTimelineItem } from '../foundation/SemanticModels';

export class GalleryState {
  themeMode: string = 'light';
  scale: number = 1;
  category: string = 'all';
  selectedComponent: string = 'hero';
  selectedScene: string = 'todo';
  query: string = '';
  events: SemanticUiEvent[] = [];
  todoTasks: SemanticTaskItem[] = createTodoTasks();
  travelItems: SemanticItineraryItem[] = createTravelItems();
  todoInput: string = '';
  todoSheetVisible: boolean = false;

  addEvent(event: SemanticUiEvent): void { this.events = [event].concat(this.events).slice(0, 20); }
}

export function createTodoTasks(): SemanticTaskItem[] {
  return [task('task-1', '整理本周会议纪要', true), task('task-2', '回复产品评审邮件', false), task('task-3', '准备周五演示', false), task('task-4', '更新项目看板', false), task('task-5', '预约下周访谈', false)];
}
function task(id: string, title: string, done: boolean): SemanticTaskItem { let item: SemanticTaskItem = new SemanticTaskItem(); item.id = id; item.title = title; item.done = done; item.subtitle = done ? '已完成' : '今天'; return item; }

export function createTravelItems(): SemanticItineraryItem[] {
  let first: SemanticItineraryItem = new SemanticItineraryItem(); first.id = 'trip-1'; first.day = 'DAY 01'; first.time = '09:00'; first.title = '清水寺晨间参拜'; first.location = '东山区'; first.detail = '从车站步行前往';
  let second: SemanticItineraryItem = new SemanticItineraryItem(); second.id = 'trip-2'; second.day = 'DAY 01'; second.time = '11:30'; second.title = '陶艺手作体验'; second.location = '清水坂'; second.detail = '预约 90 分钟体验';
  let third: SemanticItineraryItem = new SemanticItineraryItem(); third.id = 'trip-3'; third.day = 'DAY 01'; third.time = '13:00'; third.title = '季节野菜午餐'; third.location = '祇园'; third.detail = '轻松散步与午餐';
  return [first, second, third];
}

export function todoListModel(state: GalleryState): SemanticListModel<SemanticTaskItem> { let model: SemanticListModel<SemanticTaskItem> = new SemanticListModel<SemanticTaskItem>(); model.id = 'todo-list'; model.title = '今日待办'; model.items = state.todoTasks; model.selectedId = ''; return model; }
export function travelListModel(state: GalleryState): SemanticListModel<SemanticItineraryItem> { let model: SemanticListModel<SemanticItineraryItem> = new SemanticListModel<SemanticItineraryItem>(); model.id = 'travel-list'; model.title = '五日行程札记'; model.items = state.travelItems; return model; }
export function todoField(state: GalleryState): SemanticFieldModel<string> { let model: SemanticFieldModel<string> = new SemanticFieldModel<string>(); model.id = 'todo-input'; model.label = '快速记录'; model.helper = '输入一件要完成的事情'; model.value = state.todoInput; return model; }
export function sceneActions(): SemanticActionModel[] { let add: SemanticActionModel = new SemanticActionModel(); add.id = 'add'; add.label = '新增计划'; add.style = SemanticActionStyle.PRIMARY; let reset: SemanticActionModel = new SemanticActionModel(); reset.id = 'reset'; reset.label = '重置'; reset.style = SemanticActionStyle.SECONDARY; return [add, reset]; }
export function travelMetrics(): SemanticMetricItem[] { let a: SemanticMetricItem = new SemanticMetricItem(); a.id = 'budget'; a.label = '预算'; a.value = '¥12,840'; a.detail = '总预算 ¥22,000'; a.tone = SemanticTone.PRIMARY; let b: SemanticMetricItem = new SemanticMetricItem(); b.id = 'days'; b.label = '行程'; b.value = '5 天'; b.detail = '京都慢旅行'; b.tone = SemanticTone.SUCCESS; return [a, b]; }
export function agentModel(): SemanticAgentModel { let model: SemanticAgentModel = new SemanticAgentModel(); model.id = 'agent-review'; model.title = '旅行建议已准备'; model.body = '已根据时间、预算和偏好生成一版轻松行程，请审核后保存。'; model.agentStatus = SemanticAgentStatus.COMPLETE; model.riskLevel = '低'; model.actions = sceneActions(); return model; }
export function chartModel(): SemanticChartModel { let model: SemanticChartModel = new SemanticChartModel(); model.id = 'budget-chart'; model.title = '预算趋势'; model.summary = '交通、住宿、体验三类支出'; let series: SemanticChartSeries = new SemanticChartSeries(); series.id = 'budget-series'; series.label = '预算'; series.values = [38, 62, 48, 84, 70, 96]; model.series = [series]; return model; }
