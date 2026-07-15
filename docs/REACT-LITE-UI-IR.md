# React Lite -> Native UI IR MVP

本轮将默认的生成路径从“逐页 ArkUiSpec”升级为受限 React Lite DSL。模型只负责输出类似 React/Tailwind 的页面描述，设备端不执行代码，而是经过 tokenizer、parser、validator 和 compiler 转成 `ui-ir-1`，再由 ArkUI 原生组件渲染。

## 数据流

```text
SkillManifest + AppBlueprint
  -> GLM-5.2 React Lite source
  -> tokenizer / parser
  -> repair request（一次）
  -> UI IR validator
  -> ui-ir-1
  -> UiIrRenderer -> Column / Row / Stack / List / Grid / Text / Image / Button / Input
```

模型只需要组合 `AppShell`、`Page`、`Hero`、`Section`、`InfoCard`、`FormGroup`、`MetricGrid`、`Timeline`、`ResultList`、`Tabs` 等语义组件；缺省 `className` 时，编译器自动补齐 Morandi glass 主题、间距、圆角、阴影和层次，降低模型对细节的要求。

## 交互边界

- `bind`、choice、toggle、列表过滤和导航使用本地 `ui-ir` Action，不请求 GLM。
- `invokeTool` 进入白名单工具；`invokeAgent` 才进入 Runtime Agent Turn。
- 本地图片通过 `pickLocalImage` 选择，Asset id 由 App 管理，模型不能注入 URL。
- Runtime 页面优先加载 `InstalledSkillApp.uiIrSpec`；旧 `ArkUiSpec` 保留兼容路径。

## 最小示例

```tsx
export default function App() {
  const state = useState({ title: "天气", location: "上海", open: true });
  return (<AppShell id="weather" title="天气助手" initialPage="home">
    <Page id="home" title="当前天气" scroll>
      <Column>
        <Hero><Text text={state.title} /></Hero>
        <TextInput bind="location" placeholder="选择地点" />
        <If when={state.open}><StatusBanner text="适合出门" /></If>
        <Button text="获取建议" onPress={invokeAgent("explainWeather", { location: state.location }, "home")} />
      </Column>
    </Page>
  </AppShell>);
}
```

## HDC 快速调试

```text
debugAction=loadReactLiteDemo
debugAction=compileReactLiteSource, debugPayload=<React Lite source>
debugAction=runReactLiteSelfTest
```

这些入口只用于本机调试，不改变生产数据流。完整的 CredentialVault、仓库导入、真实天气适配器、第二轮 Tool Loop 和组件级测试继续记录在 `MVP-SKELETON-DEFERRED.md`。
