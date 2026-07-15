import { AppBlueprint, SkillManifest } from './SkillAppTypes';
import { ReactLiteCompileContext, ReactLiteCompileResult, compileReactLite } from './ReactLiteCompiler';

// A deterministic fixture keeps HDC/manual demos usable when the network model is unavailable.
export const TRAVEL_REACT_LITE_SOURCE: string = [
  'export default function App() {',
  '  const state = useState({ departure: "上海", destination: "成都", category: "全部", open: true, agentSummary: "", activities: [{ id: "1", title: "宽窄巷子", category: "景点", saved: false }, { id: "2", title: "建设路美食", category: "餐饮", saved: false }] });',
  '  const visibleActivities = useComputed(filterEq(state.activities, "category", state.category));',
  '  return (<AppShell id="travel-app" title="旅行规划助手" subtitle="轻松安排一段值得出发的旅程" initialPage="home">',
  '    <Page id="home" title="旅行首页" scroll>',
  '      <Column className="w-full gap-4 p-4 bg-surface">',
  '        <Hero><Text text="成都，慢慢走" className="text-2xl font-bold text-white" /><Text text="3 天 2 晚 · 美食与轻松游" className="text-base text-white" /></Hero>',
  '        <Section><Text text="从哪里出发？" className="text-lg font-bold text-ink" /><TextInput bind="destination" placeholder="输入目的地" /></Section>',
  '        <Tabs bind="category" items={["全部", "景点", "餐饮"]} />',
  '        <If when={state.open}><StatusBanner text="行程节奏已设为轻松" /></If>',
  '        <ForEach items={visibleActivities} item="activity" keyBy="id"><InfoCard><Text text={activity.title} /><Button text="收藏" onPress={toggleWhere("activities", "id", activity.id, "saved")} /></InfoCard></ForEach>',
  '        <Button text="生成旅行方案" onPress={invokeAgent("generateTripPlan", { destination: state.destination, category: state.category }, "plan")} />',
  '      </Column>',
  '    </Page>',
  '    <Page id="plan" title="旅行方案" scroll>',
  '      <Column className="w-full gap-4 p-4 bg-surface"><StatusBanner text={state.agentSummary} /><Text text="每日行程" className="text-xl font-bold text-ink" /><Button text="查看预算" onPress={navigate("budget")} /><Button text="返回首页" onPress={back()} /></Column>',
  '    </Page>',
  '    <Page id="budget" title="预算与清单" scroll>',
  '      <Column className="w-full gap-4 p-4 bg-surface"><MetricGrid><Text text="预算 5000 元" className="text-lg font-bold text-ink" /></MetricGrid><Button text="添加本地图片" onPress={pickLocalImage("gallery")} /><Button text="重新开始" onPress={resetApp()} /></Column>',
  '    </Page>',
  '  </AppShell>);',
  '}'
].join('\n');

export function compileTravelReactLite(manifest: SkillManifest, blueprint: AppBlueprint): ReactLiteCompileResult {
  let context: ReactLiteCompileContext = { manifest: manifest, blueprint: blueprint, localAssetIds: ['gallery'] };
  return compileReactLite(TRAVEL_REACT_LITE_SOURCE, context);
}
