import { SemanticUiEvent, booleanPayload, createSemanticEvent, itemPayload, itemBooleanPayload } from '../../foundation/SemanticEvents';
import { SemanticTheme, createSemanticTheme } from '../../foundation/SemanticTheme';
import { SemanticThemeMode, SemanticTone, SemanticViewStatus } from '../../foundation/SemanticEnums';
import { SemanticEntityItem, SemanticKeyValueItem, SemanticListModel, SemanticMediaItem, SemanticMessageItem, SemanticScheduleItem, SemanticTaskItem, SemanticTimelineItem, SemanticItineraryItem } from '../../foundation/SemanticModels';
import { SemanticBadge, SemanticListRow, SemanticSurface } from '../../internal/SemanticAtoms';

@ComponentV2
export struct EntityList {
  @Param @Require model: SemanticListModel<SemanticEntityItem>;
  @Param theme: SemanticTheme = createSemanticTheme(SemanticThemeMode.LIGHT);
  @Event onEvent: (event: SemanticUiEvent) => void = () => {};
  build() { List() { ForEach(this.model.items, (item: SemanticEntityItem, index: number) => { ListItem() { Row({ space: this.theme.spacing.sm }) { Column({ space: 3 }) { Text(item.title).fontWeight(FontWeight.Medium); Text(item.subtitle).fontSize(this.theme.typography.caption).fontColor(this.theme.colors.textSecondary); }.layoutWeight(1); Text('›').fontSize(20); }.width('100%').padding(this.theme.spacing.md).onClick(() => this.onEvent(createSemanticEvent(this.model.id, 'select', itemPayload(item.id, index)))); } }, (item: SemanticEntityItem) => item.id); }.width('100%').layoutWeight(1); }
}

@ComponentV2
export struct ResultList {
  @Param @Require model: SemanticListModel<SemanticEntityItem>;
  @Param theme: SemanticTheme = createSemanticTheme(SemanticThemeMode.LIGHT);
  @Event onEvent: (event: SemanticUiEvent) => void = () => {};
  build() { if (this.model.status === SemanticViewStatus.LOADING) { LoadingProgress().width(32).height(32); } else if (this.model.items.length === 0) { SemanticSurface({ theme: this.theme, title: this.model.emptyTitle, body: this.model.emptyBody, tone: SemanticTone.NEUTRAL }); } else { EntityList({ model: this.model, theme: this.theme, onEvent: this.onEvent }); } }
}

@ComponentV2
export struct TaskList {
  @Param @Require model: SemanticListModel<SemanticTaskItem>;
  @Param theme: SemanticTheme = createSemanticTheme(SemanticThemeMode.LIGHT);
  @Event onEvent: (event: SemanticUiEvent) => void = () => {};
  build() { List() { ForEach(this.model.items, (item: SemanticTaskItem, index: number) => { ListItem() { Row({ space: this.theme.spacing.sm }) { Checkbox().select(item.done).enabled(!item.disabled).onChange((value: boolean) => this.onEvent(createSemanticEvent(this.model.id, 'toggle', itemBooleanPayload(item.id, value)))); Column({ space: 3 }) { Text(item.title).decoration({ type: item.done ? TextDecorationType.LineThrough : TextDecorationType.None }); Text(item.subtitle).fontSize(this.theme.typography.caption).fontColor(this.theme.colors.textSecondary); }.layoutWeight(1); if (item.badge.label.length > 0) { SemanticBadge({ theme: this.theme, label: item.badge.label, tone: item.badge.tone }); } }.width('100%').padding(this.theme.spacing.sm).onClick(() => this.onEvent(createSemanticEvent(this.model.id, 'select', itemPayload(item.id, index)))); } }, (item: SemanticTaskItem) => item.id); }.width('100%').layoutWeight(1); }
}

@ComponentV2
export struct Checklist {
  @Param @Require model: SemanticListModel<SemanticTaskItem>;
  @Param theme: SemanticTheme = createSemanticTheme(SemanticThemeMode.LIGHT);
  @Event onEvent: (event: SemanticUiEvent) => void = () => {};
  build() { TaskList({ model: this.model, theme: this.theme, onEvent: this.onEvent }); }
}

@ComponentV2
export struct Timeline {
  @Param @Require model: SemanticListModel<SemanticTimelineItem>;
  @Param theme: SemanticTheme = createSemanticTheme(SemanticThemeMode.LIGHT);
  @Event onEvent: (event: SemanticUiEvent) => void = () => {};
  build() { List() { ForEach(this.model.items, (item: SemanticTimelineItem, index: number) => { ListItem() { Row({ space: this.theme.spacing.sm }) { Text(item.completed ? '●' : '○').fontColor(this.theme.colors.primary); Column({ space: 3 }) { Text(item.time).fontSize(this.theme.typography.caption).fontColor(this.theme.colors.textSecondary); Text(item.title).fontWeight(FontWeight.Medium); Text(item.detail).fontSize(this.theme.typography.caption).fontColor(this.theme.colors.textSecondary); }.layoutWeight(1); }.width('100%').onClick(() => this.onEvent(createSemanticEvent(this.model.id, 'select', itemPayload(item.id, index)))); } }, (item: SemanticTimelineItem) => item.id); }.width('100%').layoutWeight(1); }
}

@ComponentV2
export struct ActivityFeed {
  @Param @Require model: SemanticListModel<SemanticTimelineItem>;
  @Param theme: SemanticTheme = createSemanticTheme(SemanticThemeMode.LIGHT);
  @Event onEvent: (event: SemanticUiEvent) => void = () => {};
  build() { Timeline({ model: this.model, theme: this.theme, onEvent: this.onEvent }); }
}

@ComponentV2
export struct MessageList {
  @Param @Require model: SemanticListModel<SemanticMessageItem>;
  @Param theme: SemanticTheme = createSemanticTheme(SemanticThemeMode.LIGHT);
  @Event onEvent: (event: SemanticUiEvent) => void = () => {};
  build() { List() { ForEach(this.model.items, (item: SemanticMessageItem, index: number) => { ListItem() { Row() { Text(item.text).padding(this.theme.spacing.sm).backgroundColor(item.outgoing ? this.theme.colors.primarySoft : this.theme.colors.surfaceMuted).borderRadius(this.theme.radius.md); }.justifyContent(item.outgoing ? FlexAlign.End : FlexAlign.Start).width('100%').onClick(() => this.onEvent(createSemanticEvent(this.model.id, 'select', itemPayload(item.id, index)))); } }, (item: SemanticMessageItem) => item.id); }.width('100%').layoutWeight(1); }
}

@ComponentV2
export struct MediaList {
  @Param @Require model: SemanticListModel<SemanticMediaItem>;
  @Param theme: SemanticTheme = createSemanticTheme(SemanticThemeMode.LIGHT);
  @Event onEvent: (event: SemanticUiEvent) => void = () => {};
  build() { List() { ForEach(this.model.items, (item: SemanticMediaItem, index: number) => { ListItem() { Row({ space: this.theme.spacing.sm }) { Column().width(88).height(56).backgroundColor(this.theme.colors.surfaceMuted); Text(item.title).layoutWeight(1); Button(item.playing ? '暂停' : '播放').onClick(() => this.onEvent(createSemanticEvent(this.model.id, 'play', itemPayload(item.id, index)))); }.width('100%'); } }, (item: SemanticMediaItem) => item.id); }.width('100%').layoutWeight(1); }
}

@ComponentV2
export struct GalleryGrid {
  @Param @Require model: SemanticListModel<SemanticMediaItem>;
  @Param theme: SemanticTheme = createSemanticTheme(SemanticThemeMode.LIGHT);
  @Event onEvent: (event: SemanticUiEvent) => void = () => {};
  build() { GridRow({ columns: 2 }) { ForEach(this.model.items, (item: SemanticMediaItem, index: number) => { GridCol() { Column() { Column().height(90).backgroundColor(this.theme.colors.surfaceMuted); Text(item.title).fontSize(this.theme.typography.caption); }.width('100%').onClick(() => this.onEvent(createSemanticEvent(this.model.id, 'select', itemPayload(item.id, index)))); } }, (item: SemanticMediaItem) => item.id); }.width('100%'); }
}

@ComponentV2
export struct ScheduleList {
  @Param @Require model: SemanticListModel<SemanticScheduleItem>;
  @Param theme: SemanticTheme = createSemanticTheme(SemanticThemeMode.LIGHT);
  @Event onEvent: (event: SemanticUiEvent) => void = () => {};
  build() { List() { ForEach(this.model.items, (item: SemanticScheduleItem, index: number) => { ListItem() { SemanticListRow({ theme: this.theme, title: item.time + '  ' + item.title, subtitle: item.location, onEvent: () => this.onEvent(createSemanticEvent(this.model.id, 'select', itemPayload(item.id, index))) }); } }, (item: SemanticScheduleItem) => item.id); }.width('100%').layoutWeight(1); }
}

@ComponentV2
export struct ItineraryList {
  @Param @Require model: SemanticListModel<SemanticItineraryItem>;
  @Param theme: SemanticTheme = createSemanticTheme(SemanticThemeMode.LIGHT);
  @Event onEvent: (event: SemanticUiEvent) => void = () => {};
  build() { List() { ForEach(this.model.items, (item: SemanticItineraryItem, index: number) => { ListItem() { Column({ space: 3 }) { Text(item.day + '  ' + item.time).fontSize(this.theme.typography.caption).fontColor(this.theme.colors.primary); Text(item.title).fontWeight(FontWeight.Medium); Text(item.location + '  ' + item.detail).fontSize(this.theme.typography.caption).fontColor(this.theme.colors.textSecondary); }.width('100%').padding(this.theme.spacing.sm).onClick(() => this.onEvent(createSemanticEvent(this.model.id, 'select', itemPayload(item.id, index)))); } }, (item: SemanticItineraryItem) => item.id); }.width('100%').layoutWeight(1); }
}

@ComponentV2
export struct ComparisonTable {
  @Param @Require model: SemanticListModel<SemanticKeyValueItem>;
  @Param theme: SemanticTheme = createSemanticTheme(SemanticThemeMode.LIGHT);
  @Event onEvent: (event: SemanticUiEvent) => void = () => {};
  build() { Column() { ForEach(this.model.items, (item: SemanticKeyValueItem) => { Row() { Text(item.key).layoutWeight(1).fontColor(this.theme.colors.textSecondary); Text(item.value).layoutWeight(1); }.width('100%').padding(this.theme.spacing.sm); }, (item: SemanticKeyValueItem) => item.id); }.width('100%'); }
}
