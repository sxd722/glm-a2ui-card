import { AppBlueprint, SkillManifest } from './SkillAppTypes';
import { ReactLiteCompileContext, ReactLiteCompileResult, compileReactLite } from './ReactLiteCompiler';

// A deterministic fixture keeps HDC/manual demos usable when the network model is unavailable.
export const TRAVEL_REACT_LITE_SOURCE: string = [
  'export default function App() {',
  '  const state = useState({ departure: "上海", destination: "京都", selectedDay: "10.19", category: "全部", open: true, adding: false, draftTitle: "哲学之道散步", draftTime: "16:00", tripDate: "2026-10-18", agentSummary: "", agentStatus: "idle", agentError: "", budgetUsed: 12840, budgetTotal: 22000, budgetProgress: 58, coverTitle: "京都\n慢旅行", itinerary: [{ id: "activity-1", day: "10.19", category: "景点", time: "07:00", title: "清水寺晨间参拜", place: "东山区", note: "从二年坂进入，在清晨人潮前到达。", cost: "¥ 500", budget: 500, liked: false, done: false }, { id: "activity-2", day: "10.19", category: "体验", time: "10:30", title: "陶艺手作体验", place: "东山工房", note: "雨天也能完成的一日体验，作品寄送回家。", cost: "¥ 90 / 人", budget: 90, liked: false, done: false }, { id: "activity-3", day: "10.19", category: "餐饮", time: "13:00", title: "季节野菜午餐", place: "AWOMB 祇園八坂", note: "留出午后的慢节奏，建议提前预约。", cost: "¥ 3,200 / 人", budget: 3200, liked: false, done: false }], checklist: [{ id: "check-1", title: "预订 Hotel Kanra 京都", done: true }, { id: "check-2", title: "购买关西周游券", done: true }, { id: "check-3", title: "下载离线地图", done: false }, { id: "check-4", title: "准备轻便雨具", done: false }] });',
  '  const completedCount = useComputed(countWhere(state.checklist, "done", true));',
  '  const itineraryBudget = useComputed(sumBy(state.itinerary, "budget"));',
  '  const filteredItinerary = useComputed(filterEq(state.itinerary, "day", state.selectedDay));',
  '  const categoryItinerary = useComputed(filterEq(state.itinerary, "category", state.category));',
  // Keep this fixture within the parser's stable path-expression subset. The source
  // data is already ordered, while categoryItinerary still applies the selected tab.
  '  const orderedItinerary = useComputed(computed.categoryItinerary);',
  '  return (<AppShell id="travel-journal" title="漫游手记" subtitle="一份可以直接出发的旅行计划" initialPage="home">',
  '    <Page id="home" title="五日行程札记" scroll={false}>',
  '      <Column className="w-full h-full bg-surface">',
  '        <Scroll className="w-full flex-1">',
  '          <Column className="w-full gap-4 p-4 bg-surface">',
  '        <Row className="w-full items-center justify-between"><Column><Text text="漫游手记" className="text-lg font-bold text-ink" /><Text text="TRAVEL JOURNAL" className="text-xs text-muted" /></Column><Row className="gap-2"><Button text="分享行程" className="bg-card text-ink rounded-full" onPress={setState("agentSummary", "行程已准备好分享")} /><Button text="继续计划" className="bg-primary text-white rounded-full" onPress={invokeAgent("continuePlanning", { destination: state.destination }, "plan")} /></Row></Row>',
  '        <Stack className="w-full h-32 rounded-2xl bg-primary shadow-lg">',
  '          <Image assetId="travelHero" className="w-full h-32 object-cover rounded-2xl" />',
  '          <Column className="w-full gap-2 p-4">',
  '            <Row className="w-full justify-between"><Text text="JOURNAL 04 / 2026" className="text-xs text-white" /><Text text="5 DAYS · AUTUMN" className="text-xs text-white" /></Row>',
  '            <Text text="京都 · 慢旅行" className="text-2xl font-bold text-white" />',
  '            <Text text="10 月 18–22 日  ·  轻松节奏  ·  2 位旅伴" className="text-sm text-white" />',
  '          </Column>',
  '        </Stack>',
  '        <Row className="w-full gap-3 p-3 bg-card rounded-lg">',
  '          <Column className="flex-1"><Text text="OUTBOUND" className="text-xs text-muted" /><Text text="上海虹桥 09:05 → 大阪关西 12:10" className="text-xs text-ink" /></Column>',
  '          <Column className="flex-1"><Text text="STAY" className="text-xs text-muted" /><Text text="祇园町日町家 · 2 位旅客" className="text-xs text-ink" /></Column>',
  '          <Column className="flex-1"><Text text="BOOKING" className="text-xs text-muted" /><Text text="6 项预订 · 全部已确认" className="text-xs text-ink" /></Column>',
  '        </Row>',
  '        <Row className="w-full items-center justify-between"><Column><Text text="YOUR ITINERARY" className="text-xs text-muted" /><Text text="五日行程札记" className="text-2xl font-bold text-ink" /></Column><Text text="不赶航点，用双脚丈量小巷" className="text-xs text-muted" /></Row>',
  '        <SegmentedControl bind="selectedDay" items={["10.18", "10.19", "10.20", "10.21", "10.22"]} className="w-full bg-card rounded-lg" />',
  '        <Row className="w-full gap-4">',
  '          <Column className="flex-1 gap-3">',
  '            <Row className="w-full items-center justify-between"><Column><Text text="DAY 02" className="text-xs text-muted" /><Text text="寺院与小径" className="text-xl font-bold text-ink" /><Text text="悠然探索东山，穿过安静的晨间小路" className="text-xs text-muted" /></Column><Tabs bind="category" items={["全部", "景点", "餐饮"]} /></Row>',
  '            <ForEach items={computed.orderedItinerary} item="stop" keyBy="id"><InfoCard className="w-full gap-2 p-4 bg-card rounded-xl shadow-sm"><Row className="w-full gap-3"><Text text={stop.time} className="text-sm font-bold text-ink" /><Column className="flex-1 gap-2"><Text text={stop.title} className="text-lg font-bold text-ink" /><Text text={stop.place} className="text-xs text-muted" /><Text text={stop.note} className="text-xs text-muted" /><Text text={stop.cost} className="text-xs text-ink" /></Column><Checkbox checked={stop.done} label="完成" onChange={toggleWhere("itinerary", "id", stop.id, "done")} /></Row><Row className="gap-2"><Button text="喜欢" className="bg-secondary text-white rounded-full" onPress={toggleWhere("itinerary", "id", stop.id, "liked")} /><Button text="删除" className="bg-card text-ink rounded-full" onPress={removeWhere("itinerary", "id", stop.id)} /><Button text="快速改名" className="bg-card text-ink rounded-full" onPress={updateWhere("itinerary", "id", stop.id, { title: state.draftTitle })} /></Row></InfoCard></ForEach>',
  '            <Button text="＋  在 10.19 添加新计划" className="w-full bg-card text-ink rounded-full" onPress={setState("adding", true)} />',
  '          </Column>',
  '          <Column className="w-full gap-3">',
  '            <Card className="w-full gap-3 p-4 bg-primary rounded-2xl shadow-md"><Text text="TODAY’S ROUTE" className="text-xs text-white" /><Text text="今日路线" className="text-xl font-bold text-white" /><Image assetId="travelHero" className="w-full h-32 object-cover rounded-xl" /><Text text="① 清水寺   ② 手作体验   ③ AWOMB 祇園八坂" className="text-xs text-white" /></Card>',
  '            <Card className="w-full gap-3 p-4 bg-card rounded-xl shadow-sm"><Text text="TRAVEL BUDGET" className="text-xs text-muted" /><Text text="今日预算" className="text-lg font-bold text-ink" /><Progress value={state.budgetProgress} className="w-full" /><Row className="w-full justify-between"><Text text={formatCurrency(computed.itineraryBudget)} className="text-xs text-ink" /><Text text="总额 ¥ 22,000" className="text-xs text-muted" /></Row><Text text={formatDate(state.tripDate, "YYYY年MM月DD日")} className="text-xs text-muted" /></Card>',
  '            <Card className="w-full gap-3 p-4 bg-card rounded-xl shadow-sm"><Row className="w-full justify-between"><Column><Text text="BEFORE YOU GO" className="text-xs text-muted" /><Text text="出发前清单" className="text-lg font-bold text-ink" /></Column><Text text={formatNumber(computed.completedCount)} className="text-xs text-muted" /></Row><ForEach items={state.checklist} item="item" keyBy="id"><Row className="w-full gap-2"><Text text={item.done} className="text-xs text-muted" /><Text text={item.title} className="text-sm text-ink" /><Button text="勾选" className="bg-secondary text-white rounded-full" onPress={toggleWhere("checklist", "id", item.id, "done")} /></Row></ForEach></Card>',
  '          </Column>',
  '        </Row>',
  '          </Column>',
  '        </Scroll>',
  '        <If when={state.adding}><Sheet className="w-full p-4 bg-card rounded-2xl shadow-lg" onDismiss={setState("adding", false)}><Text text="新增今日计划" className="text-xl font-bold text-ink" /><TextInput bind="draftTitle" placeholder="活动名称" className="w-full p-3 bg-card rounded-lg border border-border" /><TextInput bind="draftTime" placeholder="时间，例如 16:00" className="w-full p-3 bg-card rounded-lg border border-border" /><Button text="保存计划" className="w-full bg-primary text-white rounded-xl" onPress={sequence(appendWithId("itinerary", "activity", { day: state.selectedDay, category: "景点", time: state.draftTime, title: state.draftTitle, place: "京都小巷", note: "由你临时加入的旅行计划。", cost: "待估算", budget: 0, liked: false, done: false }), setState("adding", false))} /><Button text="取消" className="w-full bg-card text-ink rounded-xl" onPress={setState("adding", false)} /></Sheet></If>',
  '        <ActionBar className="w-full p-3 bg-primary rounded-xl"><Button text="＋ 新增计划" className="bg-primary text-white rounded-xl" onPress={setState("adding", true)} /><Button text="生成方案" className="bg-primary text-white rounded-xl" onPress={invokeAgent({ intent: "generateTripPlan", args: { destination: state.destination, selectedDay: state.selectedDay }, bind: { summary: "agentSummary" }, status: "agentStatus", onSuccess: replace("plan"), onError: setState("agentError", "生成失败，请重试") })} /></ActionBar>',
      '      </Column>',
  '    </Page>',
  '    <Page id="plan" title="完整旅行方案" scroll>',
  '      <Column className="w-full gap-4 p-4 bg-surface"><Hero><Text text="你的京都手记" className="text-2xl font-bold text-white" /><Text text={state.agentSummary} className="text-sm text-white" /></Hero><Section><Text text="Agent 已整理好下一版方案" className="text-lg font-bold text-ink" /><Text text="可以继续调整预算、节奏和想去的店，简单收藏与勾选都在本地完成。" className="text-sm text-muted" /></Section><Button text="查看预算与清单" className="w-full bg-primary text-white rounded-xl" onPress={navigate("budget")} /><Button text="返回手记首页" className="w-full bg-card text-ink rounded-xl" onPress={back()} /></Column>',
  '    </Page>',
  '    <Page id="budget" title="预算与清单" scroll>',
  '      <Column className="w-full gap-4 p-4 bg-surface"><Text text="旅程准备" className="text-2xl font-bold text-ink" /><MetricGrid><Text text="住宿 ¥ 6,800" className="text-sm font-bold text-ink" /><Text text="交通 ¥ 2,540" className="text-sm font-bold text-ink" /><Text text="体验 ¥ 3,500" className="text-sm font-bold text-ink" /></MetricGrid><Button text="选择旅行封面" className="w-full bg-secondary text-white rounded-xl" onPress={pickLocalImage("travelHero")} /><Button text="重新开始" className="w-full bg-card text-ink rounded-xl" onPress={resetApp()} /></Column>',
  '    </Page>',
  '  </AppShell>);',
  '}'
].join('\n');

export function compileTravelReactLite(manifest: SkillManifest, blueprint: AppBlueprint): ReactLiteCompileResult {
  let context: ReactLiteCompileContext = { manifest: manifest, blueprint: blueprint, localAssetIds: ['gallery', 'travelHero'] };
  return compileReactLite(TRAVEL_REACT_LITE_SOURCE, context);
}

export const TODO_REACT_LITE_SOURCE: string = [
  'export default function App() {',
  '  const state = useState({ draftTitle: "", draftPriority: "normal", draftDue: "", suggestionNote: "", agentStatus: "idle", adding: false, tasks: [{ id: "task-1", title: "整理收件箱", priority: "high", done: false }, { id: "task-2", title: "回复客户邮件", priority: "normal", done: false }, { id: "task-3", title: "准备周会材料", priority: "normal", done: true }, { id: "task-4", title: "提交报销单", priority: "low", done: false }, { id: "task-5", title: "规划下周任务", priority: "low", done: false }] });',
  '  const completed = useComputed(countWhere(state.tasks, "done", true));',
  '  return (<AppShell id="todo-app" title="今日待办" subtitle="一个受限 React Lite Todo Nested App" initialPage="today-list">',
  '    <Page id="today-list" title="今日待办" scroll={false}>',
  '      <Column className="w-full h-full bg-surface">',
  '        <Scroll className="w-full flex-1"><Column className="w-full gap-4 p-4 bg-surface">',
  '        <Row className="w-full items-center justify-between"><Column><Text text="今日待办" className="text-2xl font-bold text-ink" /><Text text={formatNumber(computed.completed)} className="text-xs text-muted" /></Column><Button text="新增" className="bg-primary text-white rounded-xl" onPress={setState("adding", true)} /></Row>',
  '        <ForEach items={state.tasks} item="task" keyBy="id"><Card className="w-full gap-2 p-4 bg-card rounded-xl"><Row className="w-full items-center justify-between"><Column><Text text={task.title} className="text-lg font-bold text-ink" /><Text text={task.priority} className="text-xs text-muted" /></Column><Checkbox checked={task.done} label="完成" onChange={toggleWhere("tasks", "id", task.id, "done")} /></Row><Button text="切换完成" className="bg-secondary text-white rounded-full" onPress={toggleWhere("tasks", "id", task.id, "done")} /><Button text="编辑标题" className="bg-card text-ink rounded-full" onPress={updateWhere("tasks", "id", task.id, { title: state.draftTitle })} /></Card></ForEach>',
  '        <If when={length(state.tasks) === 0}><EmptyState><Text text="暂无任务" className="text-lg font-bold text-ink" /></EmptyState></If>',
  '        </Column></Scroll>',
  '        <If when={state.adding}><Sheet className="w-full p-4 bg-card rounded-2xl shadow-lg" onDismiss={setState("adding", false)}><Text text="新增任务" className="text-xl font-bold text-ink" /><TextInput bind="draftTitle" placeholder="任务名称" onChange={(value) => setState("draftTitle", value)} /><Button text="生成建议" className="w-full bg-primary text-white rounded-xl" onPress={invokeAgent({ intent: "suggestTaskDetails", args: { title: state.draftTitle }, bind: { priority: "draftPriority", due: "draftDue", note: "suggestionNote" }, status: "agentStatus" })} /><Button text="保存任务" className="w-full bg-primary text-white rounded-xl" onPress={sequence(appendWithId("tasks", "task", { title: state.draftTitle, priority: state.draftPriority, due: state.draftDue, note: state.suggestionNote, done: false }), setState("adding", false))} /><Button text="取消" className="w-full bg-card text-ink rounded-xl" onPress={setState("adding", false)} /></Sheet></If>',
  '        <ActionBar className="w-full p-3 bg-primary rounded-xl"><Button text="快速新增" className="bg-primary text-white rounded-xl" onPress={setState("adding", true)} /><Button text="回到今日" className="bg-primary text-white rounded-xl" onPress={popTo("today-list")} /></ActionBar>',
  '      </Column>',
  '    </Page>',
  '  </AppShell>);',
  '}'
].join('\n');

export function compileTodoReactLite(manifest: SkillManifest, blueprint: AppBlueprint): ReactLiteCompileResult {
  return compileReactLite(TODO_REACT_LITE_SOURCE, { manifest: manifest, blueprint: blueprint, localAssetIds: [] });
}

export const REACT_LITE_MAP_SMOKE_SOURCE: string = [
  'export default function App() {',
  '  const state = useState({ tasks: [{ id: "map-1", title: "Map item" }] });',
  '  return (<AppShell id="map-smoke" title="Map" initialPage="home"><Page id="home" title="Map"><Column>{state.tasks.map(task => (<Card key={task.id}><Text text={task.title} /></Card>))}</Column></Page></AppShell>);',
  '}'
].join('\n');

export function compileReactLiteMapSmoke(manifest: SkillManifest, blueprint: AppBlueprint): ReactLiteCompileResult {
  return compileReactLite(REACT_LITE_MAP_SMOKE_SOURCE, { manifest: manifest, blueprint: blueprint, localAssetIds: [] });
}
