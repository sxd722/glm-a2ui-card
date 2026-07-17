import { common } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { router } from '@kit.ArkUI';
import { ArkUiNodeRenderer } from '../components/ArkUiRenderer';
import { UiIrRenderer } from '../components/UiIrRenderer';
import {
  ArkUiAction,
  ArkUiSessionState
} from '../services/ArkUiTypes';
import {
  activeNestedPage,
  addNestedAsset,
  createNestedSession,
  createRunnerSessionSnapshot,
  defaultTravelNestedApp,
  reduceNestedAction,
  restoreRunnerSession,
  updateNestedField
} from '../services/NestedAppService';
import {
  GLM_CODING_ENDPOINT,
  GLM_DEFAULT_MODEL,
  GLM_LOCAL_API_KEY,
  requestNestedRuntimeTurnFromGlm
} from '../services/GlmClient';
import {
  applyRuntimeAgentTurn,
  buildRuntimeAgentTurnRequest,
  normalizeRuntimeAgentTurnResult,
  normalizeUiIrAgentTurnResult
} from '../services/NestedAgentRuntime';
import { UiAction, UiEvaluationScope, UiIrNode, UiIrSessionState, UiIrSpec, UiValue, UiValueKind } from '../services/UiIrTypes';
import { addUiIrAsset, activeUiIrPage, createUiIrSession, evaluateUiExpression, reduceUiAction, updateUiBinding } from '../services/UiIrRuntime';
import { stringValue as uiStringValue, uiValueFromObject, uiValueToDisplayString, uiValueToPlainObject } from '../services/UiValue';
import {
  readInstalledNestedAppById,
  readRunnerSession,
  readUiIrRunnerSession,
  saveRunnerSession,
  saveUiIrRunnerSession
} from '../services/SkillAppStore';
import { InstalledSkillApp, RuntimeAgentTurnRequest, RuntimeAgentTurnResult, SkillManifest, UiIrAgentActionPayload, UiIrRunnerSessionSnapshot } from '../services/SkillAppTypes';
import { pickFileSystemImageAsDataUrl, runTravelTool } from '../services/SkillWorkbench';
import { TravelInputs } from '../services/SkillTypes';
import { runTravelReactLiteAcceptance } from '../services/UiIrSelfTest';
import { HDC_DEBUG_EVENT, HdcDebugCommand, HdcDebugSnapshot, recordHdcDebugResult,
  runningHdcDebugResult, takeNextHdcDebugCommand } from '../services/HdcDebugBridge';

@Entry
@Component
struct AppRunner {
  @State nestedSession: ArkUiSessionState = createNestedSession(defaultTravelNestedApp());
  @State uiIrSession: UiIrSessionState = emptyUiIrSession();
  @State uiIrEnabled: boolean = false;
  @State nestedDslText: string = '';
  @State statusText: string = '正在载入 Nested App...';
  @State showDeveloperDrawer: boolean = false;
  @State appTitle: string = 'Nested App';
  @State appSubtitle: string = '';
  private appId: string = '';
  private sessionId: string = '';
  private manifest: SkillManifest | undefined = undefined;
  private installedApp: InstalledSkillApp | undefined = undefined;
  private context: common.UIAbilityContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
  private pageStack: NavPathStack = new NavPathStack();
  private hdcDebugRunning: boolean = false;
  private hdcDebugListener: () => void = (): void => { this.drainHdcDebugCommands(); };

  aboutToAppear(): void {
    this.context.eventHub.on(HDC_DEBUG_EVENT, this.hdcDebugListener);
    this.loadRunnerState();
    this.drainHdcDebugCommands();
  }

  aboutToDisappear(): void {
    this.context.eventHub.off(HDC_DEBUG_EVENT, this.hdcDebugListener);
    this.persistRunnerState();
  }

  build() {
    // AppRunner is already a router destination. Rendering the surface directly
    // avoids an empty nested Navigation container on device while preserving
    // router-based entry and exit for the standalone Nested App experience.
    Column() {
      this.RuntimeSurface()
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  PageBuilder(name: string, param: Object) {
    NavDestination() {
      this.RuntimeSurface()
    }
    .hideTitleBar(true)
  }

  @Builder
  RuntimeSurface() {
    Column({ space: 14 }) {
        Row({ space: 10 }) {
          Column({ space: 3 }) {
            Text(this.appTitle)
              .fontSize(24)
              .fontWeight(FontWeight.Bold)
              .fontColor('#2E3A35')
            Text(this.appSubtitle)
              .fontSize(12)
              .fontColor('#5B675F')
          }
          .layoutWeight(1)
          Button('退出')
            .height(38)
            .backgroundColor('#9A7E78')
            .fontColor('#FFFFFF')
            .onClick(() => { router.back(); })
        }
        .width('100%')

        Text(this.statusText)
          .fontSize(12)
          .fontColor('#5B675F')
          .width('100%')

        if (this.uiIrEnabled) {
          Text('第 ' + this.uiIrSession.routeStack.length.toString() + ' 层 · ' + activeUiIrPage(this.uiIrSession).title)
            .fontSize(14).fontWeight(FontWeight.Medium).fontColor('#45534C').width('100%')
        } else {
          Text('第 ' + this.nestedSession.routeStack.length.toString() + ' 层 · ' + this.currentPageTitle())
            .fontSize(14).fontWeight(FontWeight.Medium).fontColor('#45534C').width('100%')
        }

        if (this.runtimeErrorText().length > 0) {
          Text(this.runtimeErrorText())
            .fontSize(13)
            .fontColor('#9A4D4D')
            .padding(12)
            .width('100%')
            .backgroundColor('#F3DFDA')
            .borderRadius(12)
        }

        if (this.uiIrEnabled) { this.RenderUiIrPage(); }
        else { this.RenderLegacyPage(); }

        Button(this.showDeveloperDrawer ? '关闭开发抽屉' : '开发抽屉')
          .width('100%')
          .height(38)
          .backgroundColor('#7A8A99')
          .fontColor('#FFFFFF')
          .onClick(() => { this.showDeveloperDrawer = !this.showDeveloperDrawer; })

        if (this.showDeveloperDrawer) {
          Text(this.uiIrEnabled ? 'React Lite / UI IR / Session' : 'ArkUiSpec / Session')
            .fontSize(13)
            .fontWeight(FontWeight.Medium)
            .width('100%')
          TextArea({ text: this.nestedDslText, placeholder: this.uiIrEnabled ? 'UI IR JSON' : 'ArkUiSpec JSON' })
            .height(180)
            .fontSize(10)
            .onChange((value: string) => { this.nestedDslText = value; })
          Text(this.nestedSession.agentTrace)
            .fontSize(11)
            .fontColor('#5B675F')
            .width('100%')
        }
    }
    .padding(18)
    .width('100%')
    .height('100%')
    .backgroundColor('#FFF1F2EE')
  }

  @Builder
  RenderUiIrPage() {
    Stack() {
      if (activeUiIrPage(this.uiIrSession).scroll) {
        Scroll() { this.RenderUiIrRoot(); }.width('100%').height('100%').scrollBar(BarState.Auto)
      } else { this.RenderUiIrRoot(); }
      this.RenderUiIrOverlays();
    }
    .width('100%')
    .layoutWeight(1)
  }

  @Builder
  RenderUiIrRoot() {
    UiIrRenderer({
      node: activeUiIrPage(this.uiIrSession).root, session: this.uiIrSession,
      onAction: (action: UiAction, scope?: UiEvaluationScope): void => { this.runUiIrAction(action, scope); },
      onValueChange: (key: string, value: UiValue): void => { this.uiIrSession = updateUiBinding(this.uiIrSession, key, value); this.persistRunnerState(); },
      onDiagnostic: (message: string): void => { this.statusText = message; }
    })
  }

  @Builder
  RenderUiIrOverlays() {
    ForEach(this.overlayNodes(), (overlay: UiIrNode) => {
      UiIrRenderer({ node: overlay, session: this.uiIrSession,
        onAction: (action: UiAction, scope?: UiEvaluationScope): void => { this.runUiIrAction(action, scope); },
        onValueChange: (key: string, value: UiValue): void => { this.uiIrSession = updateUiBinding(this.uiIrSession, key, value); this.persistRunnerState(); },
        onDiagnostic: (message: string): void => { this.statusText = message; } })
    }, (overlay: UiIrNode) => overlay.id);
  }

  private overlayNodes(): UiIrNode[] {
    let overlays = activeUiIrPage(this.uiIrSession).overlays;
    return overlays === undefined ? [] : overlays;
  }

  private runtimeErrorText(): string { return this.uiIrEnabled ? this.uiIrSession.errorMessage : this.nestedSession.errorMessage; }

  @Builder
  RenderLegacyPage() {
    Column() {
      if (activeNestedPage(this.nestedSession).scroll) {
        Scroll() {
          ArkUiNodeRenderer({
            node: activeNestedPage(this.nestedSession).root,
            session: this.nestedSession,
            onAction: (current: ArkUiAction): void => { this.runNestedAction(current); },
            onValueChange: (key: string, value: string): void => {
              this.nestedSession = updateNestedField(this.nestedSession, key, value);
              this.persistRunnerState();
            }
          })
        }
        .width('100%')
        .layoutWeight(1)
        .scrollBar(BarState.Auto)
      } else {
        ArkUiNodeRenderer({
          node: activeNestedPage(this.nestedSession).root,
          session: this.nestedSession,
          onAction: (current: ArkUiAction): void => { this.runNestedAction(current); },
          onValueChange: (key: string, value: string): void => {
            this.nestedSession = updateNestedField(this.nestedSession, key, value);
            this.persistRunnerState();
          }
        })
      }
    }
    .width('100%')
    .layoutWeight(1)
  }

  private loadRunnerState(): void {
    let params: Record<string, Object> = this.getUIContext().getRouter().getParams() as Record<string, Object>;
    this.appId = stringValue(params, 'appId');
    this.sessionId = stringValue(params, 'sessionId');
    if (this.appId.length === 0 || this.sessionId.length === 0) {
      this.statusText = 'Nested App 路由参数缺失。';
      return;
    }
    let installed: InstalledSkillApp | undefined = readInstalledNestedAppById(this.context, this.appId);
    if (installed === undefined) {
      this.statusText = '未找到已安装的 Nested App。';
      return;
    }
    this.installedApp = installed;
    this.manifest = installed.manifest;
    if (installed.uiIrSpec !== undefined) {
      this.uiIrEnabled = true;
      this.appTitle = installed.uiIrSpec.title;
      this.appSubtitle = installed.uiIrSpec.subtitle;
      let uiSnapshot = readUiIrRunnerSession(this.context, this.sessionId);
      this.uiIrSession = uiSnapshot === undefined ? createUiIrSession(installed.uiIrSpec) : restoreUiIrSession(installed.uiIrSpec, uiSnapshot);
      this.nestedDslText = JSON.stringify(installed.uiIrSpec);
      this.statusText = 'React Lite Nested App 已载入；简单交互在本地完成。';
    } else {
      this.uiIrEnabled = false;
      this.appTitle = installed.uiSpec.title;
      this.appSubtitle = installed.uiSpec.subtitle;
      let snapshot = readRunnerSession(this.context, this.sessionId);
      this.nestedSession = snapshot === undefined ? createNestedSession(installed.uiSpec) :
        restoreRunnerSession(installed.uiSpec, snapshot);
      this.nestedDslText = JSON.stringify(installed.uiSpec);
      this.statusText = 'Legacy Nested App 已载入；本地动作不会调用 GLM。';
    }
  }

  private async persistRunnerState(): Promise<void> {
    if (this.appId.length === 0 || this.sessionId.length === 0) { return; }
    try {
      if (this.uiIrEnabled) {
        await saveUiIrRunnerSession(this.context, { sessionId: this.sessionId, appId: this.appId,
          activePageId: this.uiIrSession.activePageId, routeStack: this.uiIrSession.routeStack,
          state: this.uiIrSession.state, assets: this.uiIrSession.assets, status: this.uiIrSession.status,
          agentTrace: this.uiIrSession.agentTrace, errorMessage: this.uiIrSession.errorMessage, updatedAt: Date.now() });
      } else {
        await saveRunnerSession(this.context, createRunnerSessionSnapshot(this.nestedSession, this.appId, this.sessionId));
      }
    } catch (error) {
      this.statusText = '运行状态保存失败，但当前交互仍可继续。';
    }
  }

  private async runUiIrAction(action: UiAction, scope: UiEvaluationScope = { aliases: {}, event: {} }): Promise<void> {
    let reduced = reduceUiAction(this.uiIrSession, action, scope);
    this.uiIrSession = reduced.session;
    if (reduced.effect === undefined) {
      this.statusText = this.uiIrActionDiagnostic(action, scope);
      await this.persistRunnerState();
      return;
    }
    if (reduced.effect.kind === 'asset.pickLocalImage') {
      try {
        let imageDataUrl: string = await pickFileSystemImageAsDataUrl(this.context);
        this.uiIrSession = addUiIrAsset(this.uiIrSession, action.assetSlotId, '本地图片', imageDataUrl);
        this.statusText = '本地图片已载入。';
      } catch (error) {
        this.uiIrSession.errorMessage = '图片选择失败。';
      }
      await this.persistRunnerState();
      return;
    }
    if (reduced.effect.kind === 'tool.invoke') {
      if (action.toolName.indexOf('travel.') !== 0) {
        this.uiIrSession.errorMessage = '已拒绝未注册的本地工具：' + action.toolName;
      } else {
        let toolResult = runTravelTool(action.toolName, uiTravelInputs(this.uiIrSession.state));
        this.uiIrSession.agentTrace = toolResult.summary + (toolResult.details.length > 0 ? ' ' + toolResult.details.join('；') : '');
        let bindings: string[] = Object.keys(action.resultBindings);
        for (let i: number = 0; i < bindings.length; i++) {
          this.uiIrSession = updateUiBinding(this.uiIrSession, action.resultBindings[bindings[i]], uiValueFromObject(toolResult.summary));
        }
      }
      this.statusText = '本地工具已完成：' + action.toolName;
      await this.persistRunnerState();
      return;
    }
    if (this.manifest === undefined || GLM_LOCAL_API_KEY.length === 0) {
      this.uiIrSession.status = 'waitingUser';
      this.uiIrSession.agentTrace = '需要 GLM API Key 才能执行 Agent 动作。';
      await this.persistRunnerState();
      return;
    }
    try {
      this.uiIrSession.status = 'thinking';
      this.statusText = 'GLM 正在处理：' + action.intent;
      let expectedOutputs: string[] = Object.keys(action.resultBindings);
      let outputKinds: Record<string, UiValueKind> = {};
      for (let i: number = 0; i < expectedOutputs.length; i++) {
        let current = readUiStatePath(this.uiIrSession.state, action.resultBindings[expectedOutputs[i]]);
        if (current !== undefined) { outputKinds[expectedOutputs[i]] = current.kind; }
      }
      let plainArgs: Object = uiValueToPlainObject(reduced.effect.args);
      let uiIrAction: UiIrAgentActionPayload = { intent: action.intent, args: plainArgs,
        expectedOutputs: expectedOutputs, outputKinds: outputKinds };
      let request: RuntimeAgentTurnRequest = {
        mode: 'ui-ir', turnId: 'turn-' + Date.now().toString(), appId: this.appId, skillId: this.manifest.skillId,
        currentPageId: this.uiIrSession.activePageId, actionId: action.id, action: uiIrAction,
        availableTools: this.manifest.toolContracts.filter((tool) => tool.implemented)
      };
      let raw: string = await requestNestedRuntimeTurnFromGlm(request, { baseUrl: GLM_CODING_ENDPOINT, apiKey: GLM_LOCAL_API_KEY, model: GLM_DEFAULT_MODEL });
      let result: RuntimeAgentTurnResult = normalizeUiIrAgentTurnResult(raw, expectedOutputs, outputKinds);
      let bindingKeys: string[] = Object.keys(action.resultBindings);
      let rejectedPatch: boolean = false;
      let bindingFailed: boolean = false;
      for (let i: number = 0; i < result.statePatches.length; i++) {
        let target: string | undefined = action.resultBindings[result.statePatches[i].key];
        if (target !== undefined) { let rawValue: Object = result.statePatches[i].rawValue === undefined ? result.statePatches[i].value : result.statePatches[i].rawValue as Object; this.uiIrSession = updateUiBinding(this.uiIrSession, target, uiValueFromObject(rawValue)); if (this.uiIrSession.errorMessage.length > 0) { bindingFailed = true; } }
        else { rejectedPatch = true; }
      }
      if (rejectedPatch || bindingFailed || (bindingKeys.length === 0 && result.statePatches.length > 0)) {
        this.uiIrSession.status = 'error';
        this.uiIrSession.errorMessage = 'Agent 返回了未声明的字段，已拒绝写入。';
        if (action.statusPath !== undefined && action.statusPath.length > 0) { this.uiIrSession = updateUiBinding(this.uiIrSession, action.statusPath, uiStringValue('error')); }
        await this.runUiIrLocalSteps(action.errorSteps);
      } else {
        if (action.statusPath !== undefined && action.statusPath.length > 0) {
          this.uiIrSession = updateUiBinding(this.uiIrSession, action.statusPath, uiStringValue(result.status === 'complete' ? 'complete' : 'error'));
        }
        this.uiIrSession.status = result.status;
        this.uiIrSession.agentTrace = result.assistantText;
        this.uiIrSession.errorMessage = result.errorMessage;
        await this.runUiIrLocalSteps(result.status === 'complete' ? action.successSteps : action.errorSteps);
      }
      this.statusText = result.status === 'error' ? 'Agent Turn 失败，但已保留 UI。' : 'Agent Turn 已完成。';
    } catch (error) {
      this.uiIrSession.status = 'error';
      this.uiIrSession.errorMessage = 'GLM Runtime Turn 失败。';
      if (action.statusPath !== undefined && action.statusPath.length > 0) { this.uiIrSession = updateUiBinding(this.uiIrSession, action.statusPath, uiStringValue('error')); }
      await this.runUiIrLocalSteps(action.errorSteps);
      this.statusText = 'Agent 失败，但已保留当前 UI。';
    }
    await this.persistRunnerState();
  }

  private uiIrActionDiagnostic(action: UiAction, scope: UiEvaluationScope): string {
    let selectedDay: string = uiValueToDisplayString(readUiStatePath(this.uiIrSession.state, 'selectedDay'));
    let message: string = 'UiIR ' + action.kind + '；stateRevision=' + this.uiIrSession.stateRevision.toString() +
      '；selectedDay=' + selectedDay;
    if (action.kind === 'list.toggleWhere' || action.kind === 'list.removeWhere' || action.kind === 'list.updateWhere') {
      let list: UiValue | undefined = readUiStatePath(this.uiIrSession.state, action.path);
      let expected: UiValue = evaluateUiExpression(action.keyValue, this.uiIrSession, scope);
      if (list !== undefined && list.kind === 'array') {
        for (let i: number = 0; i < list.arrayValue.length; i++) {
          let item: UiValue = list.arrayValue[i];
          if (item.kind !== 'object') { continue; }
          let actual: UiValue | undefined = item.objectValue[action.keyField];
          if (actual !== undefined && JSON.stringify(actual) === JSON.stringify(expected)) {
            message += '；target=' + uiValueToDisplayString(actual) + ' done=' +
              uiValueToDisplayString(item.objectValue['done']) + ' liked=' + uiValueToDisplayString(item.objectValue['liked']);
            break;
          }
        }
      }
    }
    return message;
  }

  private async runUiIrLocalSteps(steps: UiAction[] | undefined): Promise<void> {
    if (steps === undefined) { return; }
    for (let i: number = 0; i < steps.length; i++) {
      let reduced = reduceUiAction(this.uiIrSession, steps[i]);
      this.uiIrSession = reduced.session;
      if (reduced.effect !== undefined) { this.uiIrSession.errorMessage = 'Agent success/error steps 只能包含本地 Action。'; }
    }
  }

  private async runNestedAction(current: ArkUiAction): Promise<void> {
    let previousPageId: string = this.nestedSession.activePageId;
    if (current.kind === 'pickLocalImage') {
      try {
        let imageDataUrl: string = await pickFileSystemImageAsDataUrl(this.context);
        this.nestedSession = addNestedAsset(this.nestedSession, '文件系统图片', imageDataUrl, current.payload);
      } catch (error) {
        this.nestedSession.errorMessage = '图片选择失败：' + (error as BusinessError).message;
      }
      await this.persistRunnerState();
      return;
    }
    if (current.kind === 'invokeAgent' && GLM_LOCAL_API_KEY.length > 0 && this.manifest !== undefined) {
      try {
        this.nestedSession.status = 'thinking';
        this.statusText = 'GLM 正在处理：' + current.label;
        let turn: RuntimeAgentTurnRequest = buildRuntimeAgentTurnRequest(this.nestedSession, current, this.manifest);
        let raw: string = await requestNestedRuntimeTurnFromGlm(turn, {
          baseUrl: GLM_CODING_ENDPOINT, apiKey: GLM_LOCAL_API_KEY, model: GLM_DEFAULT_MODEL
        });
        let result: RuntimeAgentTurnResult = normalizeRuntimeAgentTurnResult(raw);
        this.nestedSession = applyRuntimeAgentTurn(this.nestedSession, result, this.manifest);
        this.statusText = 'Agent Turn 已完成。';
      } catch (error) {
        this.nestedSession.status = 'error';
        this.nestedSession.errorMessage = 'GLM Runtime Turn 失败：' + (error as BusinessError).message;
        this.statusText = '已保留上一份 UI，可重试。';
      }
    } else {
      this.nestedSession = reduceNestedAction(this.nestedSession, current);
      this.statusText = '本地动作已完成。';
    }
    this.syncNavigation(previousPageId, current.kind);
    await this.persistRunnerState();
  }

  private syncNavigation(previousPageId: string, actionKind: string): void {
    if (actionKind === 'back') {
      this.pageStack.pop();
    } else if (previousPageId !== this.nestedSession.activePageId) {
      this.pageStack.pushPath({ name: this.nestedSession.activePageId }, false);
    }
  }

  private currentPageTitle(): string {
    return activeNestedPage(this.nestedSession).title;
  }

  private async drainHdcDebugCommands(): Promise<void> {
    if (this.hdcDebugRunning) { return; }
    this.hdcDebugRunning = true;
    let command: HdcDebugCommand | undefined = takeNextHdcDebugCommand('runner');
    while (command !== undefined) {
      await this.executeHdcDebugCommand(command);
      command = takeNextHdcDebugCommand('runner');
    }
    this.hdcDebugRunning = false;
  }

  private async executeHdcDebugCommand(command: HdcDebugCommand): Promise<void> {
    recordHdcDebugResult(runningHdcDebugResult(command, this.hdcDebugSnapshot()));
    try {
      if (command.action === 'setNestedFields') {
        let fields: Array<Record<string, Object>> = JSON.parse(command.payload) as Array<Record<string, Object>>;
        for (let i: number = 0; i < fields.length; i++) {
          let key: string = stringValue(fields[i], 'key');
          this.nestedSession = updateNestedField(this.nestedSession, key, stringValue(fields[i], 'value'));
        }
      } else if (command.action === 'runNestedAction') {
        await this.runNestedAction(JSON.parse(command.payload) as ArkUiAction);
      } else if (command.action === 'exportCurrentArtifacts') {
        this.showDeveloperDrawer = true;
      } else if (command.action === 'runTravelReactLiteAcceptance') {
        let result = runTravelReactLiteAcceptance();
        this.statusText = result.summary + '：' + result.details.join('；');
        this.uiIrSession.agentTrace = result.wire;
      } else {
        throw new Error('当前 Runner 不支持调试动作：' + command.action);
      }
      await this.persistRunnerState();
      recordHdcDebugResult({ requestId: command.requestId, action: command.action, status: 'succeeded',
        message: 'runner command completed', startedAt: 0, finishedAt: Date.now(), snapshot: this.hdcDebugSnapshot() });
    } catch (error) {
      recordHdcDebugResult({ requestId: command.requestId, action: command.action, status: 'failed',
        message: (error as BusinessError).message, startedAt: 0, finishedAt: Date.now(), snapshot: this.hdcDebugSnapshot() });
    }
  }

  private hdcDebugSnapshot(): HdcDebugSnapshot {
    return { workspaceMode: 'runner', nestedFlow: 'runtime', forgeStage: 'installed',
      skillId: this.manifest === undefined ? '' : this.manifest.skillId, activeSkillCardId: '', nestedAppId: this.appId,
      activePageId: this.nestedSession.activePageId, skillProgress: 0, statusText: this.statusText,
      errorMessage: this.nestedSession.errorMessage, manifestLength: 0, blueprintLength: 0,
      dslLength: this.nestedDslText.length, reactLiteFailureStage: '', reactLiteRawLength: 0,
      reactLiteNormalizedLength: 0, reactLiteSourceHash: '', reactLiteDiagnosticCodes: '' };
  }
}

function stringValue(values: Record<string, Object>, key: string): string {
  let value: Object | undefined = values[key];
  return value !== undefined && typeof value === 'string' ? value as string : '';
}

function readUiStatePath(state: Record<string, UiValue>, path: string): UiValue | undefined {
  if (path.length === 0) { return undefined; }
  let parts: string[] = path.split('.'); let current: UiValue | undefined = state[parts[0]];
  for (let i: number = 1; i < parts.length && current !== undefined; i++) {
    current = current.kind === 'object' ? current.objectValue[parts[i]] : undefined;
  }
  return current;
}

function emptyUiIrSession(): UiIrSessionState {
  let spec: UiIrSpec = { schemaVersion: 'ui-ir-1', appId: '', title: 'Nested App', subtitle: '', initialPageId: '',
    theme: { name: 'empty', tokens: {} }, initialState: {}, computed: [], pages: [{ id: '', title: '', scroll: true,
      layoutPreset: 'empty', root: { kind: 'element', id: 'empty', component: 'Column', props: {}, binding: '', className: '', actions: {}, children: [], itemAlias: '', keyPath: '' } }] };
  return createUiIrSession(spec);
}

function restoreUiIrSession(spec: UiIrSpec, snapshot: UiIrRunnerSessionSnapshot): UiIrSessionState {
  return { app: spec, activePageId: snapshot.activePageId, routeStack: snapshot.routeStack, state: snapshot.state,
    assets: snapshot.assets, status: snapshot.status, agentTrace: snapshot.agentTrace, errorMessage: snapshot.errorMessage, stateRevision: 0,
    computedCacheRevision: -1, computedCache: {} };
}

function uiTravelInputs(state: Record<string, UiValue>): TravelInputs {
  return { departure: uiValueToDisplayString(state['departure']), destination: uiValueToDisplayString(state['destination']),
    startDate: uiValueToDisplayString(state['startDate']), endDate: uiValueToDisplayString(state['endDate']), adults: uiValueToDisplayString(state['adults']),
    children: uiValueToDisplayString(state['children']), budget: uiValueToDisplayString(state['budget']), preferences: uiValueToDisplayString(state['preferences']),
    lodging: uiValueToDisplayString(state['lodging']), transport: uiValueToDisplayString(state['transport']) };
}
