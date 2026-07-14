# MVP 骨架延期模块与 TODO

本文记录 Skill-to-Nested-App MVP 骨架中有明确边界、但本轮不实现的单元模块。它们不得被临时代码绕过，也不得把密钥、任意网络或模型生成代码直接接入 Renderer。

## 已完成骨架

- 通用 `SkillSource`、`SkillManifest`、`AppBlueprint`、`ForgeDraft`、`InstalledNestedApp` 和 Runtime Agent Turn 类型。
- 旅行与天气本地 Manifest/Blueprint 回退。
- Forge 的导入、分析、设置和预览四阶段 UI。
- GLM Skill 分析、Blueprint 设计和 Runtime Turn 请求入口。
- `invokeAgent` 到 Runtime Agent Bridge 的接线。
- 本地 `travel.*` 工具白名单和基础 State/UI Patch Guard。
- 非敏感 Forge/App/Session Preferences 存储接口。
- 六种通用组件类型及安全的骨架渲染降级。

## TODO 1：CredentialVault

**职责**：使用 HUKS 生成或加载设备密钥，加密保存 GLM、Seniverse 和其他工具凭据。

**接口**：

```typescript
saveCredential(alias: string, secret: string): Promise<string>
readCredential(credentialRef: string): Promise<string>
deleteCredential(credentialRef: string): Promise<void>
```

**约束**：Prompt、Blueprint、ArkUiSpec、Preferences 和日志只保存 `credentialRef`。读取明文仅允许发生在对应 Tool Adapter 发请求前。

**验收**：重启 App 后凭据仍可用；导出 Preferences、Agent 请求和 hilog 均不包含明文。

## TODO 2：RepositoryImporter

**职责**：读取 GitHub/GitCode 公开仓库的 README、`SKILL.md` 及其直接引用文本。

**接口**：

```typescript
importRepository(url: string): Promise<SkillSource>
```

**约束**：只允许配置过的 HTTPS 主机；重定向重新校验；限制文件数、单文件大小和总字符数；不执行脚本、不解析依赖、不读取私有凭据。

**当前行为**：仓库 URL 进入本地识别和 GLM Source 摘要，不抓取远端正文。

## TODO 3：SeniverseWeatherAdapter

**职责**：由 App 直接请求心知天气，并把响应转换为稳定的 `RuntimeToolResult`。

**接口**：

```typescript
executeWeatherTool(call: RuntimeToolCall, credentialRef: string): Promise<RuntimeToolResult>
```

**工具**：`weather.searchLocation`、`weather.getNow`、`weather.getDailyForecast`、`weather.getHourlyForecast`、`weather.getLifeIndices`、`weather.getAlerts`。

**约束**：固定允许域名和请求模板；GLM 不提供完整 URL；认证、限流、超时和服务错误统一映射；不伪造实时数据。

**当前行为**：天气 ToolContract 标记 `implemented=false`，Runtime Agent 不会获得这些工具。

## TODO 4：两阶段 Tool Loop

**职责**：GLM 首次返回 `toolCalls` 后执行工具，再把同一 `turnId` 和 `ToolResult[]` 回传模型，获得最终解释与 UI Patch。

**接口**：

```typescript
runAgentTurn(request: RuntimeAgentTurnRequest): Promise<RuntimeAgentTurnResult>
```

**约束**：限制调用轮数；拒绝无进展的重复调用；支持取消；只发送脱敏结果。

**当前行为**：骨架执行本地旅行工具并把摘要写入 Session，本轮不进行第二次 GLM 请求。

## TODO 5：DynamicViewHost

**职责**：在 Blueprint 声明的 `dynamicSlot` 中挂载通过校验的临时面板或详情页。

**接口**：

```typescript
mount(slotId: string, spec: NestedPageSpec, lifetime: string): boolean
dismiss(slotId: string): void
```

**约束**：仅使用注册组件；限制实例数、嵌套深度和文本/列表大小；必须包含来源页和返回路径。

**当前行为**：`mountDynamicView` 只更新骨架状态，不现场创建页面。

## TODO 6：AssetSearchGateway

**职责**：根据 GLM 提供的语义查询词执行受控图片搜索、下载和来源记录。

**约束**：只允许 HTTPS；校验类型、尺寸和大小；记录来源；失败时使用本地资源或无图布局。Runtime 不接受模型直接注入的 URL。

## 已接入：MVP 视觉模型路由

**职责**：区分 `visionModel`、`designModel` 和 `runtimeModel` 配置。图片导入先检查视觉能力，再生成通用 `SkillManifest`。

**当前行为**：Forge 图片源优先使用 `GLM-4.6V-Flash` 和通用端点 `https://open.bigmodel.cn/api/paas/v4` 生成真实 `SkillManifest`；遇到明确的 HTTP 429 容量限制时，降级到免费 `GLM-4V-Flash`。随后使用 `glm-5.2` 和 Coding 端点生成 `AppBlueprint`。图片解析或 Blueprint 校验失败时停留在当前阶段并显示错误，不再静默使用旅行模板冒充模型结果。

**仍需后续实现**：将三个模型角色改为用户可配置项，并在请求前查询模型能力；当前 MVP 使用固定的视觉与设计模型组合。

## TODO 8：组件原生实现

`dataChart`、`compareTable`、`entityPicker`、`conversationPanel`、`credentialForm` 和 `dynamicSlot` 已进入 DSL allowlist。骨架阶段复用列表、选择器和玻璃面板 Renderer。

后续分别实现原生 ArkUI 组件，并保持相同 DSL 类型，不要求重新生成 Blueprint。

## TODO 9：持久化迁移与恢复

为 `ForgeDraft`、`InstalledNestedApp` 和 `RuntimeSession` 增加 schema 校验、last-known-good 快照、版本不兼容提示和启动恢复接线。

当前 `SkillAppStore.ets` 只提供非敏感 JSON Preferences 接口，损坏 JSON 返回 `undefined`。

## TODO 10：聚焦测试

本轮按 Demo 骨架要求不建立完整测试工程。后续至少覆盖：

- Manifest/Blueprint/RuntimeTurn 正常与非法 JSON。
- 未知工具、未实现工具和非法 Patch 拒绝。
- `local`、`agent`、`localThenAgent` 路由。
- Preferences 损坏数据恢复。
- 旅行图片与 Seniverse 仓库两条真机端到端流程。

## One Pager：天气 Skill 如何生成 Nested App

### 输入与目标

用户在 Forge 输入公开仓库 `https://github.com/seniverse/skills`。系统不运行仓库代码，只读取 `README.md`、`SKILL.md` 和直接引用的文本，最终生成一个可安装的天气 Nested App。默认交互以地点选择、快捷任务和卡片控件为主，减少键盘输入。

### 生成流程

```text
仓库 URL
  -> RepositoryImporter（TODO 2：受限读取）
  -> GLM Skill Analyzer
  -> SkillManifest
     - 能力：当前天气、逐小时/逐日预报、生活指数、预警
     - 输入：地点、日期范围、单位、用户意图
     - 工具：weather.searchLocation / getNow / getDailyForecast / ...
     - 凭据：Seniverse API Key，仅保存 credentialRef
  -> GLM UI Designer
  -> AppBlueprint
     - 首页：当前位置、当前天气、快捷任务
     - 详情：逐小时、逐日、生活指数、预警
     - Agent 页：适合散步吗、是否需要带伞、地点比较
     - 设置页：地点、单位、凭据状态
  -> Compiler + Schema Guard
  -> ArkUiSpec Tailwind JSON tree
  -> ArkUI A2UI Renderer
  -> InstalledNestedApp + RuntimeSession
```

GLM 负责理解 Skill 和设计声明式 UI；App 负责组件白名单、Schema 校验、凭据、网络请求、状态持久化和 ArkUI 渲染。模型不能生成或执行 ArkTS，也不能提供任意请求 URL。

### Forge 伪代码

```typescript
async function forgeWeatherApp(repoUrl: string): Promise<InstalledNestedApp> {
  const source = await repositoryImporter.importRepository(repoUrl); // TODO 2

  const manifest = validateSkillManifest(
    await glm.analyzeSkill({
      source,
      availableToolCatalog: platformToolCatalog
    })
  );

  const credentialRef = await credentialVault.saveCredential( // TODO 1
    'seniverse',
    await platformCredentialForm.requestSecret()
  );

  const blueprint = validateAppBlueprint(
    await glm.designNestedApp({
      manifest,
      componentCatalog,
      designRules: {
        preferControlsOverFreeText: true,
        allowDynamicSlots: true,
        neverGenerateCode: true
      }
    })
  );

  const spec = compiler.compile(blueprint, componentCatalog);
  return appStore.install({ manifest, blueprint, spec, credentialRef });
}
```

### 一次运行时交互

用户打开 App 后，App 读取已授权位置并调用 `weather.getNow`。当用户点击“适合散步吗”，该动作被 Blueprint 标记为 `agent`：

```typescript
async function onUiEvent(event: UIEvent, session: RuntimeSession) {
  if (event.handling === 'local') {
    return reducer.apply(event, session);
  }

  const firstTurn = await glm.runAgentTurn({
    event,
    session: snapshot(session),
    availableTools: registeredWeatherTools
  });

  const calls = toolGateway.validate(firstTurn.toolCalls);
  const results = await seniverseAdapter.execute( // TODO 3
    calls,
    session.credentialRef
  );

  const finalTurn = await glm.runAgentTurn({ // TODO 4
    event,
    session: snapshot(session),
    toolResults: redact(results)
  });

  patchGuard.assertAllowed(finalTurn.statePatch, finalTurn.uiPatch);
  renderer.apply(finalTurn); // 更新现有页面，必要时挂载 DynamicViewHost（TODO 5）
  appStore.saveSession(session); // 完整迁移与恢复见 TODO 9
}
```

典型结果是：GLM 根据逐小时天气返回“18:00 后更适合散步”，App 更新结论、依据和推荐时段，并提供“设置提醒”“查看逐小时预报”“换一个地点”等点选动作。天气事实只能来自 Seniverse ToolResult，GLM 只负责推理与界面更新。

## 本机 SDK 与设备验证

2026-07-13 已确认无需安装独立的 HarmonyOS JS 组件，也无需把 OpenHarmony JS 链接到 `hms/js`。当前 Hvigor 的 HarmonyOS Loader 会从 `default/openharmony/{ets,js,native,previewer,toolchains}` 读取五个基础组件。

此前 `00303168 SDK component missing` 的根因是 `DEVECO_SDK_HOME` 错误指向了 `C:\Program Files\Huawei\DevEco Studio\sdk\default`。SDK Scanner 不扫描根目录自身的 `sdk-pkg.json`，因此返回空组件集合。正确值是：

```powershell
$env:DEVECO_SDK_HOME='C:\Program Files\Huawei\DevEco Studio\sdk'
```

使用该值后，HarmonyOS default product 已成功完成 ArkTS 编译、HAP 打包和签名。签名 HAP 已更新安装到 Pura X，`EntryAbility` 启动成功，应用进程保持运行，受限 hilog 未发现应用启动崩溃。
# UI Schema Update

The MVP now uses `ArkUiSpec` with a Tailwind-like utility subset as the only generated UI contract. `AppBlueprint` is a lightweight page plan. See `docs/ARKUI-TAILWIND-DSL.md` for the implemented flow and current deferred items.
