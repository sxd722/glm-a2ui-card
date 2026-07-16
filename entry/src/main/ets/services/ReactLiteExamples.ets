import { AppBlueprint, SkillManifest } from './SkillAppTypes';
import { ReactLiteCompileContext, ReactLiteCompileResult, compileReactLite } from './ReactLiteCompiler';

// A deterministic fixture keeps HDC/manual demos usable when the network model is unavailable.
export const TRAVEL_REACT_LITE_SOURCE: string = [
  'export default function App() {',
  '  const state = useState({ departure: "上海", destination: "京都", selectedDay: "10.19", category: "全部", adding: false, draftTitle: "", draftTime: "16:00", tripDate: "2026-10-18", agentSummary: "行程就绪，随时可生成路线方案。", agentStatus: "idle", agentError: "", budgetUsed: 12840, budgetTotal: 22000, budgetProgress: 58, itinerary: [{ id: "act-1", day: "10.19", category: "景点", time: "07:00", title: "清水寺晨间参拜", place: "东山区", note: "清晨人潮前到达。", cost: "¥ 500", budget: 500, liked: false, done: false }, { id: "act-2", day: "10.19", category: "体验", time: "10:30", title: "陶艺手作体验", place: "东山工房", note: "雨天也能完成的一日体验，作品寄送回家。", cost: "¥ 90 / 人", budget: 90, liked: false, done: false }, { id: "act-3", day: "10.19", category: "餐饮", time: "13:00", title: "季节野菜午餐", place: "AWOMB 祇園八坂", note: "留出午后的慢节奏，建议提前预约。", cost: "¥ 3,200 / 人", budget: 3200, liked: false, done: false }], checklist: [{ id: "chk-1", title: "预订 Hotel Kanra 京都", done: true }, { id: "chk-2", title: "购买关西周游券", done: true }, { id: "chk-3", title: "下载离线地图", done: false }, { id: "chk-4", title: "准备轻便雨具", done: false }] });',
  '  const completedCount = useComputed(countWhere(state.checklist, "done", true));',
  '  const currentItinerary = useComputed(filterEq(state.itinerary, "day", state.selectedDay));',
  '  return (<AppShell id="travel-journal" title="漫游手记" subtitle="可以直接出发的计划" initialPage="home">',
  '    <Page id="home" title="五日行程札记" scroll>',
  '      <Column className="w-full gap-4 p-4 bg-surface">',
  '        <Row className="w-full items-center justify-between">',
  '          <Column><Text text="漫游手记" className="text-xl font-bold text-ink" /><Text text="TRAVEL JOURNAL" className="text-xs text-muted" /></Column>',
  '          <Button text="分享" className="bg-card text-ink rounded-full px-4" onPress={setState("agentSummary", "行程已准备好分享")} />',
  '        </Row>',
  '        <Stack className="w-full h-32 rounded-2xl bg-primary shadow-lg">',
  '          <Image assetId="travelHero" className="w-full h-32 object-cover rounded-2xl" />',
  '          <Column className="w-full h-full justify-between p-4 bg-black/20 rounded-2xl">',
  '            <Row className="w-full justify-between"><Text text="JOURNAL" className="text-xs font-bold text-white" /><Text text="5 DAYS" className="text-xs font-bold text-white" /></Row>',
  '            <Column className="w-full gap-1"><Text text="京都慢旅行" className="text-3xl font-bold text-white" /><Text text="10.18–10.22 · 轻松节奏" className="text-sm text-white" /></Column>',
  '          </Column>',
  '        </Stack>',
  '        <Row className="w-full gap-3 p-3 bg-card rounded-xl shadow-sm">',
  '          <Column className="flex-1 gap-1"><Text text="航班" className="text-xs text-muted" /><Text text="09:05 浦东" className="text-sm font-bold text-ink" /></Column>',
  '          <Column className="flex-1 gap-1"><Text text="住宿" className="text-xs text-muted" /><Text text="祇园町家" className="text-sm font-bold text-ink" /></Column>',
  '          <Column className="flex-1 gap-1"><Text text="预订" className="text-xs text-muted" /><Text text="已确认" className="text-sm font-bold text-ink" /></Column>',
  '        </Row>',
  '        <Row className="w-full gap-2"><Button text="10.18" className="flex-1 bg-card text-ink rounded-lg" onPress={setState("selectedDay", "10.18")} /><Button text="10.19" className="flex-1 bg-primary text-white rounded-lg" onPress={setState("selectedDay", "10.19")} /><Button text="10.20" className="flex-1 bg-card text-ink rounded-lg" onPress={setState("selectedDay", "10.20")} /><Button text="10.21" className="flex-1 bg-card text-ink rounded-lg" onPress={setState("selectedDay", "10.21")} /><Button text="10.22" className="flex-1 bg-card text-ink rounded-lg" onPress={setState("selectedDay", "10.22")} /></Row>',
  '        <If when={length(computed.currentItinerary) === 0}><Card className="w-full p-6 items-center justify-center bg-card rounded-2xl shadow-sm"><Text text="这一天还没有安排行程" className="text-sm text-muted" /></Card></If>',
  '        <ForEach items={computed.currentItinerary} item="stop" keyBy="id">',
  '          <Card className="w-full gap-3 p-4 bg-card rounded-2xl shadow-sm">',
  '            <Row className="w-full gap-4">',
  '              <Text text={stop.time} className="text-base font-bold text-primary" />',
  '              <Column className="flex-1 gap-1"><Text text={stop.title} className="text-lg font-bold text-ink" /><Row className="gap-1 items-center"><Text text="⌖" className="text-xs text-muted" /><Text text={stop.place} className="text-xs text-muted" /></Row><Text text={stop.note} className="text-sm text-muted mt-1" /></Column>',
  '            </Row>',
  '            <Divider />',
  '            <Row className="w-full gap-2 justify-end"><Button text="完成" className="bg-secondary text-white rounded-lg px-4" onPress={toggleWhere("itinerary", "id", stop.id, "done")} /><Button text="喜欢" className="bg-surface text-muted rounded-lg px-4" onPress={toggleWhere("itinerary", "id", stop.id, "liked")} /><Button text="删除" className="bg-surface text-muted rounded-lg px-4" onPress={removeWhere("itinerary", "id", stop.id)} /></Row>',
  '          </Card>',
  '        </ForEach>',
  '        <If when={state.adding}>',
  '          <Card className="w-full gap-3 p-5 bg-card rounded-2xl shadow-lg border border-border">',
  '            <Text text="新增今日计划" className="text-lg font-bold text-ink" /><TextInput bind="draftTitle" placeholder="活动名称，如：哲学之道散步" /><TextInput bind="draftTime" placeholder="时间，如：16:00" />',
  '            <Row className="w-full gap-3 mt-2"><Button text="取消" className="flex-1 bg-surface text-ink rounded-xl border border-border" onPress={setState("adding", false)} /><Button text="保存" className="flex-1 bg-primary text-white rounded-xl" onPress={sequence(appendWithId("itinerary", "activity", { day: state.selectedDay, category: "景点", time: state.draftTime, title: state.draftTitle, place: "京都", note: "临时加入", cost: "-", budget: 0, liked: false, done: false }), setState("adding", false), setState("draftTitle", ""), setState("draftTime", ""))} /></Row>',
  '          </Card>',
  '        </If>',
  '        <If when={!state.adding}><Button text="＋ 新增行程" className="w-full bg-card text-ink rounded-2xl shadow-sm py-4" onPress={setState("adding", true)} /></If>',
  '        <Spacer />',
  '        <Row className="w-full gap-3"><Button text="清单与封面" className="flex-1 bg-card text-ink rounded-xl shadow-sm" onPress={navigate("budget")} /><Button text="生成方案" className="flex-1 bg-primary text-white rounded-xl shadow-sm" onPress={invokeAgent("generateTripPlan", { destination: state.destination, selectedDay: state.selectedDay }, "plan")} /></Row>',
  '      </Column>',
  '    </Page>',
  '    <Page id="plan" title="旅行方案" scroll><Column className="w-full gap-4 p-4 bg-surface"><Card className="w-full gap-2 p-5 bg-card rounded-2xl shadow-sm"><Text text="Agent 回复" className="text-lg font-bold text-ink" /><Text text={state.agentSummary} className="text-sm text-ink" /></Card><Button text="返回首页" className="w-full bg-primary text-white rounded-xl shadow-sm" onPress={back()} /></Column></Page>',
  '    <Page id="budget" title="准备与清单" scroll>',
  '      <Column className="w-full gap-4 p-4 bg-surface"><Text text="出发前准备" className="text-2xl font-bold text-ink" />',
  '        <MetricGrid><Card className="p-4 gap-2 bg-card rounded-xl shadow-sm"><Text text="住宿" className="text-xs text-muted" /><Text text="¥ 6,800" className="text-sm font-bold text-ink" /></Card><Card className="p-4 gap-2 bg-card rounded-xl shadow-sm"><Text text="交通" className="text-xs text-muted" /><Text text="¥ 2,540" className="text-sm font-bold text-ink" /></Card><Card className="p-4 gap-2 bg-card rounded-xl shadow-sm"><Text text="体验" className="text-xs text-muted" /><Text text="¥ 3,500" className="text-sm font-bold text-ink" /></Card></MetricGrid>',
  '        <Card className="w-full gap-3 p-4 bg-card rounded-xl shadow-sm"><Row className="w-full justify-between"><Text text="出发前清单" className="text-lg font-bold text-ink" /><Text text={computed.completedCount + " / 4"} className="text-sm font-bold text-primary" /></Row><ForEach items={state.checklist} item="item" keyBy="id"><Row className="w-full items-center justify-between p-2"><Text text={item.title} className="text-base text-ink" /><Button text="勾选" className="bg-secondary text-white rounded-lg px-3" onPress={toggleWhere("checklist", "id", item.id, "done")} /></Row></ForEach></Card>',
  '        <Button text="设置旅行封面" className="w-full bg-secondary text-white rounded-xl shadow-sm" onPress={pickLocalImage("travelHero")} /><Button text="重新开始" className="w-full bg-card text-ink rounded-xl shadow-sm border border-border" onPress={resetApp()} /><Button text="返回" className="w-full bg-surface text-ink rounded-xl" onPress={back()} />',
  '      </Column>',
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
