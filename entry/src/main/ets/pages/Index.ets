import { common } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { formProvider } from '@kit.FormKit';
import { CardPreviewModel, GlmLocalConfig } from '../services/A2uiTypes';
import { defaultCardPreview, isRenderableA2uiDsl, projectDslToCardPreview, SAMPLE_A2UI_JSONL } from '../services/A2uiMvp';
import { saveLatestCard } from '../services/CardStore';
import {
  activeCardTitle,
  advanceSkillSession,
  applyWhitelistedTravelTool,
  createSkillSession,
  defaultTravelSkillSpec,
  normalizeSkillSpec,
  pickFileSystemImageAsDataUrl,
  pickImageAsDataUrl,
  pickSkillMarkdownFile,
  readImageFileAsDataUrl,
  saveSkillSession,
  skillSessionToCardPreview,
  TRAVEL_TOOL_NAMES
} from '../services/SkillWorkbench';
import { AgentTurnResult, SkillCard, SkillCardAction, SkillFieldSpec, SkillSessionState, TravelInputs } from '../services/SkillTypes';
import { LocalImageAsset, NestedAction, NestedNode, NestedPageSpec, NestedSessionState } from '../services/NestedAppTypes';
import { ArkUiPage, ArkUiSpec } from '../services/ArkUiTypes';
import { ArkUiNodeRenderer } from '../components/ArkUiRenderer';
import {
  activeNestedPage,
  addNestedAsset,
  assetDataUrl,
  composeArkUiSpec,
  createNestedSession,
  defaultTravelNestedApp,
  normalizeNestedApp,
  normalizeArkUiPage,
  reduceNestedAction,
  updateNestedField
} from '../services/NestedAppService';
import {
  GLM_ALTERNATE_MODEL,
  GLM_BLUEPRINT_FALLBACK_MODEL,
  GLM_CODING_ENDPOINT,
  GLM_DEFAULT_MODEL,
  GLM_GENERAL_ENDPOINT,
  GLM_LOCAL_API_KEY,
  GLM_VISION_FALLBACK_MODEL,
  GLM_VISION_MODEL,
  requestA2uiDslFromGlm,
  requestAgentTurnFromGlm,
  requestAppBlueprintFromGlm,
  requestArkUiPageFromGlm,
  requestNestedRuntimeTurnFromGlm,
  requestSkillManifestFromGlm,
  requestSkillManifestFromGlmImage,
  requestSkillSpecFromGlmImage
} from '../services/GlmClient';
import {
  compileBlueprint,
  createForgeDraft,
  createSkillSource,
  installBlueprint,
  localArkUiSpecForManifest,
  localBlueprintForManifest,
  normalizeAppBlueprint,
  normalizeSkillManifest,
  updateDraftBlueprint,
  updateDraftUiSpec,
  updateDraftManifest
} from '../services/SkillAppMvp';
import { AppBlueprint, ForgeDraft, RuntimeAgentTurnRequest, RuntimeAgentTurnResult, SkillSource, ToolContract } from '../services/SkillAppTypes';
import { applyRuntimeAgentTurn, buildRuntimeAgentTurnRequest, normalizeRuntimeAgentTurnResult } from '../services/NestedAgentRuntime';
import { saveForgeDraft, saveInstalledNestedApp } from '../services/SkillAppStore';
import {
  HDC_DEBUG_EVENT,
  HdcDebugCommand,
  HdcDebugResult,
  HdcDebugSnapshot,
  recordHdcDebugArtifactExport,
  recordHdcDebugResult,
  runningHdcDebugResult,
  takeNextHdcDebugCommand
} from '../services/HdcDebugBridge';

@Entry
@Component
struct Index {
  @State prompt: string = '生成一个今天的个人效率桌面卡片';
  @State dslText: string = SAMPLE_A2UI_JSONL;
  @State statusText: string = 'P0: A2UI DSL -> app preview -> desktop Form entry';
  @State baseUrl: string = GLM_CODING_ENDPOINT;
  @State model: string = GLM_DEFAULT_MODEL;
  @State apiKey: string = GLM_LOCAL_API_KEY;
  @State preview: CardPreviewModel = defaultCardPreview();
  @State skillSession: SkillSessionState = createSkillSession(defaultTravelSkillSpec());
  @State skillRawJson: string = '';
  @State agentTrace: string = 'Skill Workbench: 图片 -> SkillSpec -> 卡片集合 -> Agent 工具';
  @State workspaceMode: string = 'nested';
  @State nestedFlow: string = 'landing';
  @State forgeStage: string = 'import';
  @State forgeSourceKind: string = 'repository';
  @State forgeRepositoryUrl: string = 'https://github.com/seniverse/skills';
  @State forgeSourceValue: string = '';
  @State forgeSkillFileName: string = '';
  @State forgeSkillName: string = '旅行规划助手';
  @State forgeSkillGoal: string = '生成一套可交互的旅行规划应用';
  @State seniverseApiKey: string = '';
  @State forgeDraft: ForgeDraft = createForgeDraft(createSkillSource('repository', 'https://github.com/seniverse/skills', []));
  @State forgeManifestJson: string = '';
  @State forgeVisionJson: string = '';
  @State forgeBlueprintJson: string = '';
  @State nestedSession: NestedSessionState = createNestedSession(defaultTravelNestedApp());
  @State nestedDslText: string = '';
  private context: common.UIAbilityContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
  private hdcDebugRunning: boolean = false;
  private hdcImageChunks: Record<string, string> = {};
  private hdcImageChunkTotal: number = 0;
  private hdcDebugListener: () => void = (): void => {
    this.drainHdcDebugCommands();
  };

  aboutToAppear(): void {
    this.preview = projectDslToCardPreview(this.dslText);
    this.context.eventHub.on(HDC_DEBUG_EVENT, this.hdcDebugListener);
    this.drainHdcDebugCommands();
  }

  aboutToDisappear(): void {
    this.context.eventHub.off(HDC_DEBUG_EVENT, this.hdcDebugListener);
  }

  build() {
    Scroll() {
      Column({ space: 16 }) {
        Text('GLM A2UI Card MVP')
          .fontSize(24)
          .fontWeight(FontWeight.Bold)
          .width('100%')

        Text(this.statusText)
          .fontSize(13)
          .fontColor('#4B5563')
          .width('100%')

        Row({ space: 8 }) {
          Button('Nested App')
            .layoutWeight(1)
            .backgroundColor(this.workspaceMode === 'nested' ? '#6D7E73' : '#D9D9D2')
            .fontColor('#FFFFFF')
            .onClick(() => {
              this.workspaceMode = 'nested';
            })
          Button('桌面卡片实验')
            .layoutWeight(1)
            .backgroundColor(this.workspaceMode === 'cards' ? '#9A7E78' : '#D9D9D2')
            .fontColor('#FFFFFF')
            .onClick(() => {
              this.workspaceMode = 'cards';
            })
        }
        .width('100%')

        if (this.workspaceMode === 'nested') {
          this.NestedAppWorkbench()
        } else {

        Column({ space: 10 }) {
          TextInput({ text: this.prompt, placeholder: '输入要生成的卡片 prompt' })
            .height(44)
            .onChange((value: string) => {
              this.prompt = value;
            })

          TextInput({ text: this.baseUrl, placeholder: 'GLM API endpoint' })
            .height(40)
            .onChange((value: string) => {
              this.baseUrl = value;
            })

          Row({ space: 8 }) {
            TextInput({ text: this.model, placeholder: 'model' })
              .layoutWeight(1)
              .height(40)
              .onChange((value: string) => {
                this.model = value;
              })

            Button(GLM_ALTERNATE_MODEL)
              .height(40)
              .onClick(() => {
                this.model = GLM_ALTERNATE_MODEL;
              })
          }
          .width('100%')

          Row({ space: 8 }) {
            TextInput({ text: this.apiKey, placeholder: 'API key, P0 手动输入' })
              .layoutWeight(1)
              .height(40)
              .type(InputType.Password)
              .onChange((value: string) => {
                this.apiKey = value;
              })

            Button(GLM_DEFAULT_MODEL)
              .height(40)
              .onClick(() => {
                this.model = GLM_DEFAULT_MODEL;
              })
          }
          .width('100%')

          Row({ space: 8 }) {
            Button('示例 DSL')
              .layoutWeight(1)
              .onClick(() => {
                this.dslText = SAMPLE_A2UI_JSONL;
                this.preview = projectDslToCardPreview(this.dslText);
                this.statusText = '已加载 A2UI JSONL 示例';
              })

            Button('本地预览')
              .layoutWeight(1)
              .onClick(() => {
                this.preview = projectDslToCardPreview(this.dslText);
                this.statusText = '已按 Form-safe 子集投影预览';
              })
          }
          .width('100%')

          Button('调用 GLM 生成 DSL')
            .width('100%')
            .onClick(async () => {
              await this.generateWithGlm();
            })
        }
        .width('100%')

        TextArea({ text: this.dslText, placeholder: 'A2UI v0.9 JSONL' })
          .height(160)
          .fontSize(12)
          .onChange((value: string) => {
            this.dslText = value;
          })

        this.CardPreview()

        Row({ space: 8 }) {
          Button('加到桌面')
            .layoutWeight(1)
            .onClick(async () => {
              await this.saveAndOpenFormManager();
            })

          Button('保存当前卡片')
            .layoutWeight(1)
            .onClick(async () => {
              await this.saveCurrentPreview();
            })
        }
        .width('100%')

        Divider()

        this.SkillWorkbenchPanel()
        }
      }
      .padding(20)
      .width('100%')
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#FFFFFF')
  }

  @Builder
  NestedAppWorkbench() {
    Column({ space: 14 }) {
      if (this.nestedFlow === 'landing') {
        this.NestedLanding()
      } else if (this.nestedFlow === 'forge') {
        this.NestedForge()
      } else {
        this.NestedRuntime()
      }
    }
    .width('100%')
  }

  @Builder
  NestedLanding() {
    Column({ space: 14 }) {
      Text('Nested Skill App')
        .fontSize(26)
        .fontWeight(FontWeight.Bold)
        .fontColor('#34433B')
        .width('100%')
      Text('提供一个 Skill，由 GLM 设计应用；确认预览后进入独立 Nested App。')
        .fontSize(14)
        .fontColor('#627168')
        .width('100%')
      Button('进入 Skill Forge')
        .id('nested-load-demo')
        .width('100%')
        .height(48)
        .backgroundColor('#6D7E73')
        .onClick(() => {
          this.nestedSession = createNestedSession(defaultTravelNestedApp());
          this.nestedDslText = JSON.stringify(this.nestedSession.app);
          this.forgeStage = 'import';
          this.nestedFlow = 'forge';
        })
      Button('直接运行旅行 Demo')
        .width('100%')
        .height(44)
        .backgroundColor('#9A7E78')
        .onClick(() => {
          this.forgeDraft = createForgeDraft(createSkillSource('text', '旅行规划助手 travel planner', []));
          this.nestedSession = createNestedSession(defaultTravelNestedApp());
          this.nestedDslText = JSON.stringify(this.nestedSession.app);
          this.nestedFlow = 'runtime';
        })
    }
    .padding(20)
    .width('100%')
    .backgroundColor('#E8E3DC')
    .borderRadius(18)
  }

  @Builder
  NestedForge() {
    Column({ space: 12 }) {
      Text('Skill App Forge')
        .fontSize(23)
        .fontWeight(FontWeight.Bold)
        .fontColor('#394840')
        .width('100%')
      Text(this.forgeStageLabel())
        .fontSize(13)
        .fontColor('#607067')
      if (this.forgeStage === 'import') {
        this.ForgeImportStage()
      } else if (this.forgeStage === 'analyze') {
        this.ForgeAnalyzeStage()
      } else if (this.forgeStage === 'setup') {
        this.ForgeSetupStage()
      } else {
        this.ForgePreviewStage()
      }
    }
    .padding(18)
    .width('100%')
    .backgroundColor('#E9E6DE')
    .borderRadius(18)
  }

  @Builder
  ForgeImportStage() {
    Column({ space: 12 }) {
      Text('1 · 提供 Skill').fontSize(18).fontWeight(FontWeight.Bold).fontColor('#394840').width('100%')
      Row({ space: 8 }) {
        Button('仓库链接').layoutWeight(1)
          .backgroundColor(this.forgeSourceKind === 'repository' ? '#6D7E73' : '#B7C1BA')
          .onClick(() => { this.selectForgeSourceKind('repository'); })
        Button('Skill.md').layoutWeight(1)
          .backgroundColor(this.forgeSourceKind === 'text' ? '#6D7E73' : '#B7C1BA')
          .onClick(() => { this.selectForgeSourceKind('text'); })
        Button('图片').layoutWeight(1)
          .backgroundColor(this.forgeSourceKind === 'image' ? '#6D7E73' : '#B7C1BA')
          .onClick(() => { this.selectForgeSourceKind('image'); })
      }.width('100%')
      if (this.forgeSourceKind === 'repository') {
        TextInput({ text: this.forgeRepositoryUrl, placeholder: 'https://github.com/.../skills' })
          .height(44).backgroundColor('#FFFFFFAA')
          .onChange((value: string) => { this.forgeRepositoryUrl = value; })
      } else if (this.forgeSourceKind === 'text') {
        Button(this.forgeSkillFileName.length > 0 ? '重新选择 skill.md' : '从文件系统选择 skill.md')
          .width('100%')
          .backgroundColor('#7A8A99')
          .onClick(async () => { await this.pickForgeSkillMarkdown(); })
        Text(this.forgeSkillFileName.length > 0 ? '已选择：' + this.forgeSkillFileName : '尚未选择 skill.md')
          .fontSize(12).fontColor('#5D6C63').width('100%')
        if (this.forgeSourceValue.length > 0 && this.forgeSkillFileName.length > 0) {
          this.ForgeArtifactPanel('Skill.md 原文', this.forgeSourceValue)
        }
        Text('Skill.md 分析：' + GLM_DEFAULT_MODEL + ' · coding endpoint')
          .fontSize(11).fontColor('#756E66').width('100%')
      } else {
        Row({ space: 8 }) {
          Button('从相册选择').layoutWeight(1).onClick(async () => { await this.pickForgeImage(false); })
          Button('从文件选择').layoutWeight(1).onClick(async () => { await this.pickForgeImage(true); })
        }.width('100%')
        Text('已选 Skill 图片 / 素材 ' + this.nestedSession.assets.length.toString() + ' 张')
          .fontSize(12).fontColor('#5D6C63')
        Text('图片解析：' + GLM_VISION_MODEL + ' · 拥塞降级：' + GLM_VISION_FALLBACK_MODEL +
          ' · UI 设计：' + GLM_DEFAULT_MODEL)
          .fontSize(11).fontColor('#756E66').width('100%')
      }
      TextInput({ text: this.apiKey, placeholder: 'GLM API Key（分析前必填）' })
        .height(44).type(InputType.Password).backgroundColor('#FFFFFFAA')
        .onChange((value: string) => { this.apiKey = value; })
      if (this.nestedSession.errorMessage.length > 0) {
        Text(this.nestedSession.errorMessage).fontSize(12).fontColor('#9A574B').width('100%')
      }
      if (this.forgeVisionJson.length > 0) {
        this.ForgeArtifactPanel('视觉模型原始输出', this.forgeVisionJson)
      }
      if (this.forgeManifestJson.length > 0) {
        this.ForgeArtifactPanel('GLM-5.2 SkillManifest 原始输出', this.forgeManifestJson)
      }
      if (this.forgeSourceKind === 'repository') {
        Text('仓库链接会交给 glm-5.2 分析；仓库内容深度抓取由 RepositoryImporter 后续接入。')
          .fontSize(11).fontColor('#756E66').width('100%')
      }
      Row({ space: 8 }) {
        Button('返回').layoutWeight(1).backgroundColor('#9AADA0')
          .onClick(() => { this.nestedFlow = 'landing'; })
        Button('分析 Skill').id('nested-forge-analyze').layoutWeight(2).backgroundColor('#6D7E73')
          .onClick(async () => { await this.analyzeForgeSkill(); })
      }.width('100%')
    }.width('100%')
  }

  @Builder
  ForgeAnalyzeStage() {
    Column({ space: 12 }) {
      Text('2 · 能力分析').fontSize(18).fontWeight(FontWeight.Bold).fontColor('#394840').width('100%')
      Text(this.forgeDraft.manifest.skillName).fontSize(20).fontWeight(FontWeight.Bold).fontColor('#45534C')
      Text(this.forgeDraft.manifest.description).fontSize(13).fontColor('#5B675F').width('100%')
      Text('流程 ' + this.forgeDraft.manifest.workflow.length.toString() + ' 步 · 工具 ' +
        this.forgeDraft.manifest.toolContracts.length.toString() + ' 个')
        .fontSize(13).fontColor('#6B655E').width('100%')
      ForEach(this.forgeDraft.manifest.toolContracts, (tool: ToolContract) => {
        Row({ space: 8 }) {
          Text(tool.name).fontSize(12).fontColor('#45534C').layoutWeight(1)
          Text(tool.implemented ? '已接入' : '待接入').fontSize(11)
            .fontColor(tool.implemented ? '#47705A' : '#9A6D5F')
        }.padding(10).width('100%').backgroundColor('#FFFFFF88').borderRadius(10)
      })
      if (this.forgeVisionJson.length > 0) {
        this.ForgeArtifactPanel('视觉模型原始输出', this.forgeVisionJson)
      }
      this.ForgeArtifactPanel('GLM-5.2 SkillManifest', this.forgeManifestJson)
      Text(this.forgeDraft.trace).fontSize(12).fontColor('#6B655E').width('100%')
      Row({ space: 8 }) {
        Button('上一步').layoutWeight(1).backgroundColor('#9AADA0')
          .onClick(() => { this.forgeStage = 'import'; })
        Button('必要设置').layoutWeight(2).backgroundColor('#6D7E73')
          .onClick(() => { this.forgeStage = 'setup'; })
      }.width('100%')
    }.width('100%')
  }

  @Builder
  ForgeSetupStage() {
    Column({ space: 12 }) {
      Text('3 · 必要设置').fontSize(18).fontWeight(FontWeight.Bold).fontColor('#394840').width('100%')
      TextInput({ text: this.apiKey, placeholder: 'GLM API Key' })
        .height(44).type(InputType.Password).backgroundColor('#FFFFFFAA')
        .onChange((value: string) => { this.apiKey = value; })
      if (this.forgeDraft.manifest.skillId === 'SENIVERSE_WEATHER_V1') {
        TextInput({ text: this.seniverseApiKey, placeholder: 'Seniverse API Key（天气适配器接入后启用）' })
          .height(44).type(InputType.Password).backgroundColor('#FFFFFFAA')
          .onChange((value: string) => { this.seniverseApiKey = value; })
      }
      Text('MVP 骨架不持久化密钥。CredentialVault 将使用 HUKS 加密并只向 Tool Gateway 返回引用。')
        .fontSize(11).fontColor('#8A675C').width('100%')
      Text('Skill 图片使用 ' + GLM_VISION_MODEL + '，UI Blueprint 使用 ' + GLM_DEFAULT_MODEL + '。')
        .fontSize(11).fontColor('#756E66').width('100%')
      this.ForgeArtifactPanel('当前 SkillManifest', this.forgeManifestJson)
      if (this.forgeBlueprintJson.length > 0) {
        this.ForgeArtifactPanel('GLM-5.2 AppBlueprint 原始输出', this.forgeBlueprintJson)
      }
      if (this.nestedDslText.length > 0) {
        this.ForgeArtifactPanel('最终 Nested App DSL', this.nestedDslText)
      }
      if (this.nestedSession.errorMessage.length > 0) {
        Text(this.nestedSession.errorMessage).fontSize(12).fontColor('#9A574B').width('100%')
      }
      Row({ space: 8 }) {
        Button('上一步').layoutWeight(1).backgroundColor('#9AADA0')
          .onClick(() => { this.forgeStage = 'analyze'; })
        Button('生成预览').id('nested-forge-preview').layoutWeight(2).backgroundColor('#7A8A99')
          .onClick(async () => { await this.prepareForgePreview(); })
      }.width('100%')
    }.width('100%')
  }

  @Builder
  ForgePreviewStage() {
    Column({ space: 12 }) {
      Text('4 · 确认预览').fontSize(18).fontWeight(FontWeight.Bold).fontColor('#394840').width('100%')
      Text(this.forgeDraft.blueprint.title).fontSize(21).fontWeight(FontWeight.Bold).fontColor('#45534C')
      Text(this.forgeDraft.blueprint.summary).fontSize(13).fontColor('#5B675F').width('100%')
      Text('页面结构').fontSize(13).fontWeight(FontWeight.Medium).fontColor('#45534C').width('100%')
      ForEach(this.forgeDraft.uiSpec.pages, (pageSpec: ArkUiPage) => {
        Text(pageSpec.title + ' · 原生 Tailwind JSON 树')
          .fontSize(12).fontColor('#5B675F').padding(10).width('100%')
          .backgroundColor('#FFFFFF88').borderRadius(10)
      })
      this.ForgeArtifactPanel('SkillManifest', this.forgeManifestJson)
      this.ForgeArtifactPanel('GLM-5.2 AppBlueprint', this.forgeBlueprintJson)
      this.ForgeArtifactPanel('最终 Nested App DSL', this.nestedDslText)
      Text(this.forgeDraft.trace).fontSize(12).fontColor('#6B655E').width('100%')
      Row({ space: 8 }) {
        Button('调整设置').layoutWeight(1).backgroundColor('#9AADA0')
          .onClick(() => { this.forgeStage = 'setup'; })
        Button('重新设计').layoutWeight(1).backgroundColor('#7A8A99')
          .onClick(async () => { await this.prepareForgePreview(); })
        Button('创建应用').id('nested-forge-build').layoutWeight(1).backgroundColor('#9A7E78')
          .onClick(async () => { await this.installForgePreview(); })
      }.width('100%')
    }.width('100%')
  }

  @Builder
  ForgeArtifactPanel(title: string, content: string) {
    Column({ space: 6 }) {
      Text(title)
        .fontSize(12)
        .fontWeight(FontWeight.Medium)
        .fontColor('#45534C')
        .width('100%')
      Scroll() {
        Text(content.length > 0 ? content : '尚无产物')
          .fontSize(10)
          .fontColor('#343B37')
          .width('100%')
          .padding(10)
      }
      .height(168)
      .width('100%')
      .scrollBar(BarState.Auto)
      .backgroundColor('#FFFFFFAA')
      .borderRadius(8)
    }
    .width('100%')
  }

  @Builder
  NestedRuntime() {
    Column({ space: 14 }) {
      Stack({ alignContent: Alignment.TopStart }) {
        Column()
          .width('100%')
          .height(164)
          .borderRadius(18)
          .backgroundColor('#E8E3DC')
        Column()
          .width(250)
          .height(92)
          .margin({ left: 34, top: 8 })
          .borderRadius(46)
          .backgroundColor('#AEBDB2')
          .opacity(0.38)
        Column()
          .width(210)
          .height(68)
          .margin({ left: 140, top: 72 })
          .borderRadius(34)
          .backgroundColor('#C89B91')
          .opacity(0.28)
        Column({ space: 6 }) {
          Text(this.nestedSession.app.title)
            .fontSize(26)
            .fontWeight(FontWeight.Bold)
            .fontColor('#2E3A35')
          Text(this.nestedSession.app.subtitle)
            .fontSize(13)
            .fontColor('#56635D')
        }
        .padding(22)
        .width('100%')
      }
      .width('100%')
      .height(164)

      Row({ space: 8 }) {
        Button('返回 Forge')
          .layoutWeight(1)
          .backgroundColor('#6D7E73')
          .onClick(() => {
            this.nestedFlow = 'forge';
          })
        Button('重新生成')
          .layoutWeight(1)
          .backgroundColor('#9A7E78')
          .onClick(async () => {
            await this.generateNestedAppWithGlm();
          })
      }
      .width('100%')

      Text(this.nestedSession.agentTrace)
        .fontSize(12)
        .fontColor('#5B665F')
        .width('100%')

      Text('第 ' + this.nestedSession.routeStack.length.toString() + ' 层 · ' + this.nestedPageTitle())
        .fontSize(15)
        .fontWeight(FontWeight.Medium)
        .fontColor('#45534C')

      if (this.isNestedHome()) {
        Button('开始规划')
          .id('nested-start-planning')
          .width('100%')
          .height(46)
          .backgroundColor('#6D7E73')
          .fontColor('#FFFFFF')
          .onClick(() => {
            this.nestedSession = reduceNestedAction(this.nestedSession, this.startPlanningAction());
          })
      }

      ArkUiNodeRenderer({
        node: activeNestedPage(this.nestedSession).root,
        session: this.nestedSession,
        onAction: (current: NestedAction): void => { this.runNestedAction(current); },
        onValueChange: (key: string, value: string): void => {
          this.nestedSession = updateNestedField(this.nestedSession, key, value);
        }
      })

      if (this.nestedSession.errorMessage.length > 0) {
        Text(this.nestedSession.errorMessage)
          .fontSize(13)
          .fontColor('#9A4D4D')
          .padding(12)
          .width('100%')
          .backgroundColor('#F3DFDA')
          .borderRadius(12)
      }

      Text('当前 ArkUiSpec Tailwind DSL').fontSize(13).fontWeight(FontWeight.Medium).width('100%')
      TextArea({ text: this.nestedDslText, placeholder: 'ArkUiSpec JSON（可查看或粘贴 GLM 结果）' })
        .height(180)
        .fontSize(10)
        .onChange((value: string) => {
          this.nestedDslText = value;
        })
      Button('应用 ArkUiSpec JSON')
        .width('100%')
        .backgroundColor('#7A8A99')
        .onClick(() => {
          this.nestedSession = createNestedSession(normalizeNestedApp(this.nestedDslText, this.forgeDraft.uiSpec));
          this.nestedSession.agentTrace = '已应用受控 ArkUiSpec Tailwind DSL。';
        })
    }
    .width('100%')
  }

  @Builder
  NestedNodeView(node: NestedNode) {
    if (node.kind === 'heroMedia') {
      this.NestedHero(node)
    } else if (node.kind === 'formField') {
      this.NestedField(node)
    } else if (node.kind === 'choiceChips' || node.kind === 'entityPicker') {
      this.NestedChoices(node)
    } else if (node.kind === 'actionBar') {
      this.NestedActions(node)
    } else if (node.kind === 'mediaGallery') {
      this.NestedGallery(node)
    } else if (node.kind === 'timeline' || node.kind === 'resultList' || node.kind === 'dataChart' ||
      node.kind === 'compareTable') {
      this.NestedList(node)
    } else if (node.kind === 'metric') {
      this.NestedMetric(node)
    } else {
      this.NestedGlassPanel(node)
    }
  }

  @Builder
  NestedHero(node: NestedNode) {
    Stack({ alignContent: Alignment.BottomStart }) {
      if (this.nestedAsset(node.assetId).length > 0) {
        Image(this.nestedAsset(node.assetId))
          .width('100%')
          .height(218)
          .objectFit(ImageFit.Cover)
          .borderRadius(16)
      } else {
        Column()
          .width('100%')
          .height(218)
          .borderRadius(16)
          .backgroundColor('#BBC8C0')
      }
      Column({ space: 3 }) {
        Text(node.title)
          .fontSize(22)
          .fontWeight(FontWeight.Bold)
          .fontColor('#FFFFFF')
        Text(node.text)
          .fontSize(12)
          .fontColor('#F7F5F0')
      }
      .padding(18)
      .width('100%')
      .backgroundColor('#34423C88')
      this.NestedActions(node)
    }
    .width('100%')
    .height(218)
  }

  @Builder
  NestedField(node: NestedNode) {
    Column({ space: 6 }) {
      Text(node.title).fontSize(13).fontColor('#526158')
      TextInput({ text: this.nestedValue(node.binding), placeholder: node.text })
        .height(44)
        .backgroundColor('#FFFFFF99')
        .borderRadius(10)
        .onChange((value: string) => {
          this.nestedSession = updateNestedField(this.nestedSession, node.binding, value);
        })
    }
    .padding(14)
    .width('100%')
    .backgroundColor('#EDE9E1B8')
    .borderRadius(14)
    .border({ width: 1, color: '#FFFFFFAA' })
  }

  @Builder
  NestedChoices(node: NestedNode) {
    Column({ space: 10 }) {
      Text(node.title).fontSize(15).fontWeight(FontWeight.Medium).fontColor('#4E5C55')
      Row({ space: 8 }) {
        ForEach(node.items, (item: string) => {
          Button(item)
            .height(34)
            .backgroundColor(this.nestedValue(node.binding).indexOf(item) >= 0 ? '#849789' : '#FFFFFF99')
            .fontColor(this.nestedValue(node.binding).indexOf(item) >= 0 ? '#FFFFFF' : '#56635D')
            .onClick(() => {
              this.nestedSession = updateNestedField(this.nestedSession, node.binding, item);
            })
        })
      }
    }
    .padding(14)
    .width('100%')
    .backgroundColor('#DDE5DDB8')
    .borderRadius(14)
  }

  @Builder
  NestedGlassPanel(node: NestedNode) {
    Column({ space: 7 }) {
      Text(node.title).fontSize(17).fontWeight(FontWeight.Bold).fontColor('#394840')
      Text(node.binding.length > 0 ? this.nestedValue(node.binding) : node.text)
        .fontSize(13)
        .fontColor('#5B675F')
        .width('100%')
      this.NestedActions(node)
    }
    .padding(16)
    .width('100%')
    .backgroundColor(node.tone === 'accent' ? '#E7D8D1CC' : '#EEF0E8CC')
    .border({ width: 1, color: '#FFFFFFBB' })
    .borderRadius(16)
    .shadow({ radius: 14, color: '#52605820', offsetX: 0, offsetY: 6 })
  }

  @Builder
  NestedMetric(node: NestedNode) {
    Column({ space: 5 }) {
      Text(node.title).fontSize(13).fontColor('#5C665F')
      Text(this.nestedValue(node.binding)).fontSize(19).fontWeight(FontWeight.Bold).fontColor('#3E5148')
    }
    .padding(16)
    .width('100%')
    .backgroundColor('#D6E0D8CC')
    .borderRadius(16)
  }

  @Builder
  NestedList(node: NestedNode) {
    Column({ space: 8 }) {
      Text(node.title).fontSize(17).fontWeight(FontWeight.Bold).fontColor('#3E4C44')
      Text(node.binding.length > 0 && this.nestedValue(node.binding).length > 0 ? this.nestedValue(node.binding) : node.text)
        .fontSize(13)
        .fontColor('#58645D')
        .width('100%')
      ForEach(node.items, (item: string) => {
        Text(item)
          .fontSize(12)
          .fontColor('#4E5C55')
          .padding({ top: 4, bottom: 4, left: 8, right: 8 })
          .width('100%')
          .backgroundColor('#FFFFFF88')
          .borderRadius(8)
      })
    }
    .padding(16)
    .width('100%')
    .backgroundColor('#F0ECE5CC')
    .borderRadius(16)
  }

  @Builder
  NestedGallery(node: NestedNode) {
    Column({ space: 10 }) {
      Text(node.title).fontSize(17).fontWeight(FontWeight.Bold).fontColor('#3E4C44')
      if (this.nestedSession.assets.length === 0) {
        Text(node.text).fontSize(13).fontColor('#68736C')
      } else {
        Row({ space: 10 }) {
          ForEach(this.nestedSession.assets, (asset: LocalImageAsset) => {
            Image(asset.dataUrl)
              .width(112)
              .height(88)
              .objectFit(ImageFit.Cover)
              .borderRadius(12)
          })
        }
        .width('100%')
        .height(90)
      }
      this.NestedActions(node)
    }
    .padding(16)
    .width('100%')
    .backgroundColor('#E7E1D8CC')
    .borderRadius(16)
  }

  @Builder
  NestedActions(node: NestedNode) {
    if (node.actions.length > 0) {
      Row({ space: 8 }) {
        ForEach(node.actions, (current: NestedAction) => {
          Button(current.label)
            .layoutWeight(1)
            .height(38)
            .backgroundColor(current.kind === 'back' ? '#9AADA0' : '#6D7E73')
            .fontColor('#FFFFFF')
            .onClick(async () => {
              await this.runNestedAction(current);
            })
        })
      }
      .width('100%')
      .padding({ top: 10 })
    }
  }

  @Builder
  SkillWorkbenchPanel() {
    Column({ space: 12 }) {
      Text('Agent Skill Workbench')
        .fontSize(22)
        .fontWeight(FontWeight.Bold)
        .width('100%')

      Text(this.agentTrace)
        .fontSize(13)
        .fontColor('#4B5563')
        .width('100%')

      Row({ space: 8 }) {
        Button('上传 Skill 图片识别')
          .layoutWeight(1)
          .onClick(async () => {
            await this.extractSkillFromImage();
          })

        Button('加载旅行 Skill 示例')
          .layoutWeight(1)
          .onClick(async () => {
            this.skillSession = createSkillSession(defaultTravelSkillSpec());
            this.skillRawJson = JSON.stringify(this.skillSession.skillSpec);
            await saveSkillSession(this.context, this.skillSession);
            this.agentTrace = '已加载 TRAVEL_PLANNER_V1 示例，可直接填写参数';
          })
      }
      .width('100%')

      TextArea({ text: this.skillRawJson, placeholder: 'GLM 识别出的 SkillSpec JSON' })
        .height(92)
        .fontSize(11)
        .onChange((value: string) => {
          this.skillRawJson = value;
        })

      Button('应用 SkillSpec JSON')
        .width('100%')
        .onClick(async () => {
          try {
            this.skillSession = createSkillSession(normalizeSkillSpec(this.skillRawJson));
            await saveSkillSession(this.context, this.skillSession);
            this.agentTrace = 'SkillSpec 已编译为 ' + this.skillSession.skillSpec.skillId + ' 交互界面';
          } catch (error) {
            let err: Error = error as Error;
            this.agentTrace = err.message;
          }
        })

      if (this.skillSession.skillSpec.skillId === 'TRAVEL_PLANNER_V1') {
        this.SkillInputEditor()
      } else {
        this.GenericSkillInputEditor()
      }
      this.SkillCardRenderer()

      Row({ space: 8 }) {
        Button('执行当前动作')
          .layoutWeight(1)
          .onClick(async () => {
            await this.runSkillAction(this.primaryActionLabel());
          })

        Button('加到桌面')
          .layoutWeight(1)
          .onClick(async () => {
            await this.saveSkillToDesktop();
          })
      }
      .width('100%')
    }
    .width('100%')
  }

  @Builder
  SkillInputEditor() {
    Column({ space: 8 }) {
      Text('旅行参数')
        .fontSize(16)
        .fontWeight(FontWeight.Bold)
        .width('100%')

      Row({ space: 8 }) {
        TextInput({ text: this.skillSession.inputs.departure, placeholder: '出发地，如 上海' })
          .layoutWeight(1)
          .height(40)
          .onChange((value: string) => {
            this.updateTravelInput('departure', value);
          })
        TextInput({ text: this.skillSession.inputs.destination, placeholder: '目的地，如 成都' })
          .layoutWeight(1)
          .height(40)
          .onChange((value: string) => {
            this.updateTravelInput('destination', value);
          })
      }
      .width('100%')

      Row({ space: 8 }) {
        TextInput({ text: this.skillSession.inputs.startDate, placeholder: '开始日期' })
          .layoutWeight(1)
          .height(40)
          .onChange((value: string) => {
            this.updateTravelInput('startDate', value);
          })
        TextInput({ text: this.skillSession.inputs.endDate, placeholder: '结束日期' })
          .layoutWeight(1)
          .height(40)
          .onChange((value: string) => {
            this.updateTravelInput('endDate', value);
          })
      }
      .width('100%')

      Row({ space: 8 }) {
        TextInput({ text: this.skillSession.inputs.adults, placeholder: '成人' })
          .layoutWeight(1)
          .height(40)
          .onChange((value: string) => {
            this.updateTravelInput('adults', value);
          })
        TextInput({ text: this.skillSession.inputs.children, placeholder: '儿童' })
          .layoutWeight(1)
          .height(40)
          .onChange((value: string) => {
            this.updateTravelInput('children', value);
          })
        TextInput({ text: this.skillSession.inputs.budget, placeholder: '预算，如 5000' })
          .layoutWeight(1)
          .height(40)
          .onChange((value: string) => {
            this.updateTravelInput('budget', value);
          })
      }
      .width('100%')

      TextInput({ text: this.skillSession.inputs.preferences, placeholder: '偏好：美食、轻松游等' })
        .height(40)
        .onChange((value: string) => {
          this.updateTravelInput('preferences', value);
        })

      Row({ space: 8 }) {
        TextInput({ text: this.skillSession.inputs.lodging, placeholder: '住宿要求' })
          .layoutWeight(1)
          .height(40)
          .onChange((value: string) => {
            this.updateTravelInput('lodging', value);
          })
        TextInput({ text: this.skillSession.inputs.transport, placeholder: '交通偏好' })
          .layoutWeight(1)
          .height(40)
          .onChange((value: string) => {
            this.updateTravelInput('transport', value);
          })
      }
      .width('100%')
    }
    .width('100%')
    .padding(12)
    .borderRadius(8)
    .backgroundColor('#F9FAFB')
  }

  @Builder
  GenericSkillInputEditor() {
    Column({ space: 8 }) {
      Text(this.skillSession.skillSpec.skillName + ' 输入')
        .fontSize(16)
        .fontWeight(FontWeight.Bold)
        .width('100%')

      if (this.skillSession.skillSpec.inputFields.length === 0) {
        Text('该 Skill 不需要用户输入。')
          .fontSize(13)
          .fontColor('#4B5563')
          .width('100%')
      }

      ForEach(this.skillSession.skillSpec.inputFields, (field: SkillFieldSpec) => {
        Text(field.label + (field.required ? ' *' : ''))
          .fontSize(12)
          .fontColor('#45534C')
          .width('100%')
        TextInput({ text: this.genericSkillInputValue(field.id), placeholder: field.placeholder })
          .height(40)
          .onChange((value: string) => {
            this.updateGenericSkillInput(field.id, value);
          })
      })
    }
    .width('100%')
    .padding(12)
    .borderRadius(8)
    .backgroundColor('#F9FAFB')
  }

  @Builder
  SkillCardRenderer() {
    Column({ space: 8 }) {
      Text(activeCardTitle(this.skillSession))
        .fontSize(19)
        .fontWeight(FontWeight.Bold)
        .width('100%')

      Text(this.activeSkillCard().subtitle)
        .fontSize(12)
        .fontColor('#047857')
        .width('100%')

      Text(this.activeSkillCard().body)
        .fontSize(14)
        .fontColor('#111827')
        .width('100%')

      Text('状态: ' + this.skillSession.status + ' / 进度 ' + this.skillSession.progress.toString() + '%')
        .fontSize(12)
        .fontColor('#4B5563')
        .width('100%')

      if (this.skillSession.errorMessage.length > 0) {
        Text(this.skillSession.errorMessage)
          .fontSize(13)
          .fontColor('#B91C1C')
          .width('100%')
      }

      ForEach(this.activeSkillCard().actions, (action: SkillCardAction) => {
        Button(action.label)
          .width('100%')
          .height(36)
          .onClick(async () => {
            await this.runSkillAction(action.id);
          })
      })
    }
    .width('100%')
    .padding(16)
    .borderRadius(8)
    .backgroundColor('#ECFDF5')
  }

  @Builder
  CardPreview() {
    Column({ space: 8 }) {
      Text(this.preview.title)
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .width('100%')

      Text(this.preview.subtitle)
        .fontSize(13)
        .fontColor('#4B5563')
        .width('100%')

      Text(this.preview.body)
        .fontSize(15)
        .fontColor('#111827')
        .width('100%')

      Text(this.preview.itemsText)
        .fontSize(13)
        .fontColor('#374151')
        .width('100%')
    }
    .width('100%')
    .padding(16)
    .borderRadius(8)
    .backgroundColor('#F8FAFC')
  }

  async generateWithGlm(): Promise<void> {
    if (this.apiKey.length === 0) {
      this.statusText = '缺少 API key；P0 可先用示例 DSL 验证渲染链路';
      return;
    }

    let config: GlmLocalConfig = {
      baseUrl: this.baseUrl,
      apiKey: this.apiKey,
      model: this.model
    };

    try {
      this.statusText = '正在调用 GLM...';
      let dsl: string = await requestA2uiDslFromGlm(this.prompt, config);
      this.dslText = dsl;
      this.preview = projectDslToCardPreview(dsl);
      if (!isRenderableA2uiDsl(dsl)) {
        this.statusText = 'GLM 已返回，但不是可渲染 A2UI DSL；请检查 DSL 内容';
        return;
      }
      await saveLatestCard(this.context, this.preview);
      this.statusText = 'GLM DSL 已自动渲染并保存，可加到桌面';
    } catch (error) {
      let err: BusinessError = error as BusinessError;
      this.statusText = 'GLM 调用失败: ' + err.message;
    }
  }

  async saveCurrentPreview(): Promise<void> {
    if (!isRenderableA2uiDsl(this.dslText)) {
      this.statusText = '当前 DSL 不可渲染，未保存';
      return;
    }
    await saveLatestCard(this.context, this.preview);
    this.statusText = '当前卡片已保存，桌面卡片会读取这份内容';
  }

  async saveAndOpenFormManager(): Promise<void> {
    if (!isRenderableA2uiDsl(this.dslText)) {
      this.statusText = '当前 DSL 不可渲染，无法加桌';
      return;
    }
    await saveLatestCard(this.context, this.preview);
    this.openFormManager();
  }

  async extractSkillFromImage(): Promise<void> {
    if (this.apiKey.length === 0) {
      this.agentTrace = '缺少 API key，无法调用 GLM 图片识别';
      return;
    }
    let config: GlmLocalConfig = {
      baseUrl: GLM_GENERAL_ENDPOINT,
      apiKey: this.apiKey,
      model: GLM_VISION_MODEL
    };
    try {
      this.agentTrace = '正在选择图片...';
      let dataUrl: string = await pickImageAsDataUrl();
      this.agentTrace = '正在调用 GLM 识别 Skill 图片...';
      let rawSpec: string = await requestSkillSpecFromGlmImage(dataUrl, config);
      this.skillRawJson = rawSpec;
      this.skillSession = createSkillSession(normalizeSkillSpec(rawSpec));
      await saveSkillSession(this.context, this.skillSession);
      this.agentTrace = '已识别并编译为 ' + this.skillSession.skillSpec.skillId + ' 卡片集合';
    } catch (error) {
      let err: BusinessError = error as BusinessError;
      this.agentTrace = '图片识别失败: ' + err.message + '。如果当前模型不支持图片，请切换 visionModel / visionEndpoint，或先加载示例验证链路。';
    }
  }

  genericSkillInputValue(fieldId: string): string {
    if (!Array.isArray(this.skillSession.fieldValues)) {
      return '';
    }
    for (let i: number = 0; i < this.skillSession.fieldValues.length; i++) {
      if (this.skillSession.fieldValues[i].id === fieldId) {
        return this.skillSession.fieldValues[i].value;
      }
    }
    return '';
  }

  updateGenericSkillInput(fieldId: string, value: string): void {
    let next: SkillSessionState = JSON.parse(JSON.stringify(this.skillSession)) as SkillSessionState;
    if (!Array.isArray(next.fieldValues)) {
      next.fieldValues = [];
    }
    for (let i: number = 0; i < next.fieldValues.length; i++) {
      if (next.fieldValues[i].id === fieldId) {
        next.fieldValues[i].value = value;
        this.skillSession = next;
        return;
      }
    }
    next.fieldValues.push({ id: fieldId, value: value });
    this.skillSession = next;
  }

  async runSkillAction(actionId: string): Promise<void> {
    let usedGlmTool: boolean = false;
    if (this.shouldAskAgentForTool(actionId)) {
      usedGlmTool = await this.tryApplyAgentTurn(actionId);
    }
    if (!usedGlmTool) {
      this.skillSession = advanceSkillSession(this.skillSession, actionId);
    }
    await saveSkillSession(this.context, this.skillSession);
    await saveLatestCard(this.context, skillSessionToCardPreview(this.skillSession));
    if (!usedGlmTool) {
      this.agentTrace = '已执行: ' + actionId + '，当前卡片: ' + activeCardTitle(this.skillSession);
    }
  }

  async tryApplyAgentTurn(actionId: string): Promise<boolean> {
    if (this.apiKey.length === 0) {
      return false;
    }
    let config: GlmLocalConfig = {
      baseUrl: this.baseUrl,
      apiKey: this.apiKey,
      model: this.model
    };
    try {
      let turnJson: string = await requestAgentTurnFromGlm({
        actionId: actionId,
        session: this.skillSession,
        availableTools: TRAVEL_TOOL_NAMES
      }, config);
      let turn: AgentTurnResult = JSON.parse(turnJson) as AgentTurnResult;
      if (turn.toolCalls.length > 0) {
        this.skillSession = applyWhitelistedTravelTool(this.skillSession, turn.toolCalls[0].toolName);
        this.agentTrace = 'GLM Agent 调用工具: ' + turn.toolCalls[0].toolName;
        return true;
      }
    } catch (error) {
      let err: BusinessError = error as BusinessError;
      this.agentTrace = '本地工具已执行；GLM Agent Turn 调用失败: ' + err.message;
    }
    return false;
  }

  shouldAskAgentForTool(actionId: string): boolean {
    if (actionId === '执行下一步' || actionId === '生成最终方案') {
      return this.skillSession.activeCardId === 'plan_progress' ||
        this.skillSession.activeCardId === 'transport_card' ||
        this.skillSession.activeCardId === 'lodging_card' ||
        this.skillSession.activeCardId === 'itinerary_card' ||
        this.skillSession.activeCardId === 'budget_card' ||
        this.skillSession.activeCardId === 'checklist_card';
    }
    return false;
  }

  async saveSkillToDesktop(): Promise<void> {
    await saveSkillSession(this.context, this.skillSession);
    await saveLatestCard(this.context, skillSessionToCardPreview(this.skillSession));
    this.openFormManager();
  }

  updateTravelInput(key: string, value: string): void {
    let next: SkillSessionState = JSON.parse(JSON.stringify(this.skillSession)) as SkillSessionState;
    let inputs: TravelInputs = next.inputs;
    if (key === 'departure') {
      inputs.departure = value;
    } else if (key === 'destination') {
      inputs.destination = value;
    } else if (key === 'startDate') {
      inputs.startDate = value;
    } else if (key === 'endDate') {
      inputs.endDate = value;
    } else if (key === 'adults') {
      inputs.adults = value;
    } else if (key === 'children') {
      inputs.children = value;
    } else if (key === 'budget') {
      inputs.budget = value;
    } else if (key === 'preferences') {
      inputs.preferences = value;
    } else if (key === 'lodging') {
      inputs.lodging = value;
    } else if (key === 'transport') {
      inputs.transport = value;
    }
    next.inputs = inputs;
    this.skillSession = next;
  }

  activeSkillCard(): SkillCard {
    for (let i = 0; i < this.skillSession.cards.length; i++) {
      if (this.skillSession.cards[i].id === this.skillSession.activeCardId) {
        return this.skillSession.cards[i];
      }
    }
    return this.skillSession.cards[0];
  }

  primaryActionLabel(): string {
    let card: SkillCard = this.activeSkillCard();
    if (card.actions.length === 0) {
      return '执行下一步';
    }
    return card.actions[0].id;
  }

  forgeStageLabel(): string {
    if (this.forgeStage === 'import') {
      return '导入 Skill · 自动分析 · 必要设置 · 确认预览';
    }
    if (this.forgeStage === 'analyze') {
      return '已识别 Skill 能力、输入、工具和人工决策点';
    }
    if (this.forgeStage === 'setup') {
      return '只补充阻塞运行的模型或工具凭据';
    }
    return '确认 GLM 设计的页面结构并创建 Nested App';
  }

  async analyzeForgeSkill(): Promise<void> {
    let assetIds: string[] = this.forgeAssetIds();
    let sourceValue: string = this.forgeSourceKind === 'repository' ? this.forgeRepositoryUrl : this.forgeSourceValue;
    if (this.apiKey.trim().length === 0) {
      this.nestedSession.errorMessage = 'Skill 分析必须调用 GLM-5.2，请先输入 GLM API Key。';
      return;
    }
    if (this.forgeSourceKind === 'text') {
      if (this.forgeSkillFileName.length === 0 || sourceValue.trim().length === 0) {
        this.nestedSession.errorMessage = '请先从文件系统选择一个非空的 skill.md 文件。';
        return;
      }
    }
    if (this.forgeSourceKind === 'repository' && sourceValue.trim().length === 0) {
      this.nestedSession.errorMessage = '请输入 Skill 仓库链接。';
      return;
    }
    if (this.forgeSourceKind === 'image') {
      sourceValue = '用户选择的 Skill 图片，共 ' + assetIds.length.toString() + ' 张。';
      if (assetIds.length === 0) {
        this.nestedSession.errorMessage = '请先从相册或文件系统选择一张 Skill 图片。';
        return;
      }
    }
    this.nestedSession.errorMessage = '';
    this.forgeManifestJson = '';
    this.forgeVisionJson = '';
    this.forgeBlueprintJson = '';
    this.nestedDslText = '';
    let source: SkillSource = createSkillSource(this.forgeSourceKind, sourceValue, assetIds);
    let draft: ForgeDraft = createForgeDraft(source);
    let trace: string = '';
    try {
      let manifestSource: SkillSource = source;
      if (source.kind === 'image') {
        let imageDataUrl: string = this.forgePrimaryImageDataUrl();
        let visionConfig: GlmLocalConfig = {
          baseUrl: GLM_GENERAL_ENDPOINT,
          apiKey: this.apiKey,
          model: GLM_VISION_MODEL
        };
        this.statusText = 'GLM-4.6V-Flash 正在解析 Skill 图片...';
        this.forgeVisionJson = await this.requestForgeImageManifest(imageDataUrl, assetIds, visionConfig);
        manifestSource = createSkillSource('text', this.forgeVisionJson, assetIds);
      }

      this.statusText = 'glm-5.2 正在生成 SkillManifest...';
      let glmConfig: GlmLocalConfig = {
        baseUrl: GLM_CODING_ENDPOINT,
        apiKey: this.apiKey,
        model: GLM_DEFAULT_MODEL
      };
      this.forgeManifestJson = await requestSkillManifestFromGlm(manifestSource, glmConfig);
      let manifest = normalizeSkillManifest(this.forgeManifestJson, draft.manifest);
      if (manifest === draft.manifest) {
        throw new Error('glm-5.2 返回内容未通过 SkillManifest 校验');
      }
      trace = source.kind === 'image' ?
        '视觉模型完成图片识别，glm-5.2 已生成并校验 SkillManifest。' :
        'glm-5.2 已根据 ' + (source.kind === 'text' ? 'skill.md' : '仓库来源') + ' 生成并校验 SkillManifest。';
      draft = updateDraftManifest(draft, manifest, trace);
      this.statusText = 'SkillManifest 生成完成：' + manifest.skillName;
    } catch (error) {
      let err: BusinessError = error as BusinessError;
      this.nestedSession.errorMessage = 'Skill 分析失败：' + err.message;
      this.statusText = '分析已终止；原始产物已保留，不会使用本地旅行模板。';
      return;
    }
    this.forgeDraft = draft;
    this.forgeSkillName = draft.manifest.skillName;
    this.forgeSkillGoal = draft.manifest.description;
    this.forgeStage = 'analyze';
    try {
      await saveForgeDraft(this.context, this.forgeDraft);
    } catch (error) {
      this.forgeDraft.trace = this.forgeDraft.trace + ' 草稿持久化失败，但可继续预览。';
    }
  }

  async prepareForgePreview(): Promise<void> {
    let fallback: AppBlueprint = localBlueprintForManifest(this.forgeDraft.manifest);
    let uiFallback: ArkUiSpec = localArkUiSpecForManifest(this.forgeDraft.manifest);
    let trace: string = '';
    if (this.apiKey.trim().length === 0) {
      this.nestedSession.errorMessage = '生成 ArkUiSpec UI 需要 GLM API Key。';
      this.forgeStage = 'setup';
      return;
    }
    this.forgeBlueprintJson = '';
    this.nestedDslText = '';
    let config: GlmLocalConfig = {
      baseUrl: GLM_CODING_ENDPOINT,
      apiKey: this.apiKey,
      model: GLM_DEFAULT_MODEL
    };
    let blueprint: AppBlueprint = this.forgeDraft.blueprint;
    let primaryError: string = '';
    try {
      this.statusText = 'glm-5.2 正在根据 SkillManifest 设计页面计划...';
      this.forgeBlueprintJson = await requestAppBlueprintFromGlm(this.forgeDraft.manifest,
        this.forgeAssetIds(), config);
      blueprint = normalizeAppBlueprint(this.forgeBlueprintJson, fallback);
      if (blueprint === fallback) {
        throw new Error('glm-5.2 返回内容未通过 AppBlueprint 校验');
      }
      trace = 'glm-5.2 已生成并通过校验的 AppBlueprint。';
    } catch (error) {
      let err: BusinessError = error as BusinessError;
      primaryError = err.message;
      this.statusText = 'glm-5.2 UI 设计失败，正在切换 ' + GLM_BLUEPRINT_FALLBACK_MODEL + ' 兜底...';
      try {
        let fallbackConfig: GlmLocalConfig = {
          baseUrl: GLM_CODING_ENDPOINT,
          apiKey: this.apiKey,
          model: GLM_BLUEPRINT_FALLBACK_MODEL
        };
        this.forgeBlueprintJson = await requestAppBlueprintFromGlm(this.forgeDraft.manifest,
          this.forgeAssetIds(), fallbackConfig);
        blueprint = normalizeAppBlueprint(this.forgeBlueprintJson, fallback);
        if (blueprint === fallback) {
          throw new Error(GLM_BLUEPRINT_FALLBACK_MODEL + ' 返回内容未通过 AppBlueprint 校验');
        }
        trace = GLM_DEFAULT_MODEL + ' 失败后由 ' + GLM_BLUEPRINT_FALLBACK_MODEL +
          ' 生成并通过校验的 AppBlueprint。';
      } catch (fallbackError) {
        let fallbackErr: BusinessError = fallbackError as BusinessError;
        trace = 'UI 设计失败：' + GLM_DEFAULT_MODEL + '：' + primaryError +
          '；' + GLM_BLUEPRINT_FALLBACK_MODEL + '：' + fallbackErr.message;
        this.forgeDraft.trace = trace;
        this.forgeDraft.errorMessage = trace;
        this.nestedSession.errorMessage = trace;
        this.statusText = 'UI 生成已终止；已保留当前 Blueprint，不会替换为本地模板。';
        return;
      }
    }
    this.nestedSession.errorMessage = '';
    this.forgeDraft = updateDraftBlueprint(this.forgeDraft, blueprint, trace);
    let generatedPages: ArkUiPage[] = [];
    for (let i: number = 0; i < blueprint.pages.length; i++) {
      let localPage: ArkUiPage = this.fallbackArkUiPage(uiFallback, blueprint.pages[i].id);
      let page: ArkUiPage = localPage;
      let pageRaw: string = '';
      try {
        this.statusText = GLM_DEFAULT_MODEL + ' 正在生成页面 ' + (i + 1).toString() + '/' +
          blueprint.pages.length.toString() + '：' + blueprint.pages[i].title;
        pageRaw = await requestArkUiPageFromGlm(this.forgeDraft.manifest, blueprint, blueprint.pages[i],
          this.forgeAssetIds(), config);
        page = normalizeArkUiPage(pageRaw, localPage);
        if (page === localPage) { throw new Error('页面 JSON 未通过 ArkUiSpec 校验'); }
      } catch (pageError) {
        try {
          let pageFallbackConfig: GlmLocalConfig = { baseUrl: GLM_CODING_ENDPOINT, apiKey: this.apiKey,
            model: GLM_BLUEPRINT_FALLBACK_MODEL };
          this.statusText = GLM_BLUEPRINT_FALLBACK_MODEL + ' 正在兜底生成：' + blueprint.pages[i].title;
          pageRaw = await requestArkUiPageFromGlm(this.forgeDraft.manifest, blueprint, blueprint.pages[i],
            this.forgeAssetIds(), pageFallbackConfig);
          page = normalizeArkUiPage(pageRaw, localPage);
          if (page === localPage) { throw new Error('兜底模型页面 JSON 未通过 ArkUiSpec 校验'); }
        } catch (fallbackPageError) {
          let pageErr: BusinessError = pageError as BusinessError;
          let fallbackPageErr: BusinessError = fallbackPageError as BusinessError;
          trace = '页面生成失败：' + blueprint.pages[i].title + '；' + GLM_DEFAULT_MODEL + '：' +
            pageErr.message + '；' + GLM_BLUEPRINT_FALLBACK_MODEL + '：' + fallbackPageErr.message;
          this.forgeDraft.trace = trace;
          this.forgeDraft.errorMessage = trace;
          this.nestedSession.errorMessage = trace;
          this.statusText = '页面生成已终止；已保留当前 ArkUiSpec，不会注入本地旅行页面。';
          return;
        }
      }
      page.id = blueprint.pages[i].id;
      page.title = blueprint.pages[i].title;
      generatedPages.push(page);
      let partialSpec: ArkUiSpec = composeArkUiSpec(blueprint.appId, blueprint.title, blueprint.summary,
        generatedPages, uiFallback);
      this.nestedDslText = JSON.stringify(partialSpec);
    }
    let uiSpec: ArkUiSpec = composeArkUiSpec(blueprint.appId, blueprint.title, blueprint.summary,
      generatedPages, uiFallback);
    this.forgeDraft = updateDraftUiSpec(this.forgeDraft, uiSpec, trace + ' ArkUiSpec 已逐页生成。');
    this.nestedDslText = JSON.stringify(uiSpec);
    this.forgeStage = 'preview';
    try {
      this.statusText = 'ArkUiSpec 原生 UI 已生成，可确认后创建应用。';
      await saveForgeDraft(this.context, this.forgeDraft);
    } catch (error) {
      this.forgeDraft.trace = this.forgeDraft.trace + ' 草稿持久化失败，但可继续创建。';
    }
  }

  async installForgePreview(): Promise<void> {
    let assets: LocalImageAsset[] = this.nestedSession.assets;
    this.nestedSession = createNestedSession(compileBlueprint(this.forgeDraft.blueprint, this.forgeDraft.uiSpec));
    this.nestedSession.assets = assets;
    this.nestedSession.agentTrace = 'ArkUiSpec 应用已安装；本地动作即时响应，语义动作进入 GLM Runtime Turn。';
    this.nestedDslText = JSON.stringify(this.forgeDraft.uiSpec);
    try {
      await saveInstalledNestedApp(this.context, installBlueprint(this.forgeDraft));
    } catch (error) {
      this.nestedSession.agentTrace = this.nestedSession.agentTrace + ' 安装信息持久化失败。';
    }
    this.nestedFlow = 'runtime';
  }

  fallbackArkUiPage(spec: ArkUiSpec, pageId: string): ArkUiPage {
    for (let i: number = 0; i < spec.pages.length; i++) { if (spec.pages[i].id === pageId) { return spec.pages[i]; } }
    return spec.pages[0];
  }

  forgeAssetIds(): string[] {
    let ids: string[] = [];
    for (let i = 0; i < this.nestedSession.assets.length; i++) {
      ids.push(this.nestedSession.assets[i].id);
    }
    return ids;
  }

  forgePrimaryImageDataUrl(): string {
    if (this.nestedSession.assets.length === 0) {
      return '';
    }
    return this.nestedSession.assets[0].dataUrl;
  }

  async requestForgeImageManifest(imageDataUrl: string, assetIds: string[],
    primaryConfig: GlmLocalConfig): Promise<string> {
    try {
      return await requestSkillManifestFromGlmImage(imageDataUrl, assetIds, primaryConfig);
    } catch (error) {
      let err: BusinessError = error as BusinessError;
      if (err.message.indexOf('未返回') >= 0 || err.message.toLowerCase().indexOf('timeout') >= 0) {
        throw new Error(err.message);
      }
      this.statusText = GLM_VISION_MODEL + ' 连接或模型不兼容，正在切换视觉降级模型 ' + GLM_VISION_FALLBACK_MODEL + '...';
      let fallbackConfig: GlmLocalConfig = {
        baseUrl: GLM_GENERAL_ENDPOINT,
        apiKey: this.apiKey,
        model: GLM_VISION_FALLBACK_MODEL
      };
      return requestSkillManifestFromGlmImage(imageDataUrl, assetIds, fallbackConfig);
    }
  }

  async generateNestedAppWithGlm(): Promise<void> {
    if (this.apiKey.length === 0) {
      this.nestedSession.agentTrace = '缺少 API key，已保留当前本地 Nested App。';
      return;
    }
    await this.prepareForgePreview();
    if (this.forgeStage === 'preview') { await this.installForgePreview(); }
  }

  async runNestedAction(current: NestedAction): Promise<void> {
    if (current.kind === 'pickLocalImage') {
      try {
        let imageDataUrl: string = await pickImageAsDataUrl();
        this.nestedSession = addNestedAsset(this.nestedSession, '本地图片', imageDataUrl, current.payload);
      } catch (error) {
        let err: BusinessError = error as BusinessError;
        this.nestedSession.errorMessage = '图片选择失败：' + err.message;
      }
      return;
    }
    let shouldInvokeAgent: boolean = current.kind === 'invokeAgent' || current.handling === 'agent' ||
      current.handling === 'localThenAgent';
    if (shouldInvokeAgent && this.apiKey.length > 0) {
      let config: GlmLocalConfig = { baseUrl: GLM_CODING_ENDPOINT, apiKey: this.apiKey, model: GLM_DEFAULT_MODEL };
      try {
        if (current.handling === 'localThenAgent' && current.kind !== 'invokeAgent') {
          this.nestedSession = reduceNestedAction(this.nestedSession, current);
        }
        this.nestedSession.status = 'thinking';
        this.nestedSession.agentTrace = 'GLM 正在处理 UI 事件：' + current.label;
        let turn: RuntimeAgentTurnRequest = buildRuntimeAgentTurnRequest(this.nestedSession, current,
          this.forgeDraft.manifest);
        let raw: string = await requestNestedRuntimeTurnFromGlm(turn, config);
        let result: RuntimeAgentTurnResult = normalizeRuntimeAgentTurnResult(raw);
        this.nestedSession = applyRuntimeAgentTurn(this.nestedSession, result, this.forgeDraft.manifest);
      } catch (error) {
        let err: BusinessError = error as BusinessError;
        this.nestedSession.status = 'error';
        this.nestedSession.errorMessage = 'GLM Runtime Turn 失败：' + err.message;
        this.nestedSession.agentTrace = '保留上一份可用 UI，可重试或返回。';
      }
      return;
    }
    this.nestedSession = reduceNestedAction(this.nestedSession, current);
  }

  async pickNestedFileImage(): Promise<void> {
    try {
      let imageDataUrl: string = await pickFileSystemImageAsDataUrl(this.context);
      this.nestedSession = addNestedAsset(this.nestedSession, '文件系统图片', imageDataUrl, 'gallery');
    } catch (error) {
      let err: BusinessError = error as BusinessError;
      this.nestedSession.errorMessage = '文件系统图片选择失败：' + err.message;
    }
  }

  async pickForgeImage(useFileSystem: boolean): Promise<void> {
    try {
      let dataUrl: string = useFileSystem ? await pickFileSystemImageAsDataUrl(this.context) : await pickImageAsDataUrl();
      let slot: string = this.nestedSession.assets.length === 0 ? 'cover' : 'gallery-' + this.nestedSession.assets.length.toString();
      this.nestedSession = addNestedAsset(this.nestedSession, useFileSystem ? '文件系统图片' : '相册图片', dataUrl, slot);
      this.clearForgeArtifacts();
      this.nestedSession.errorMessage = '';
      this.statusText = 'Skill 图片已载入，可调用 GLM-4.6V-Flash 分析。';
    } catch (error) {
      let err: BusinessError = error as BusinessError;
      this.nestedSession.errorMessage = '素材选择失败：' + err.message;
    }
  }

  async pickForgeSkillMarkdown(): Promise<void> {
    try {
      let selected = await pickSkillMarkdownFile(this.context);
      this.forgeSourceKind = 'text';
      this.forgeSkillFileName = selected.displayName;
      this.forgeSourceValue = selected.content;
      this.clearForgeArtifacts();
      this.nestedSession.errorMessage = '';
      this.statusText = 'Skill.md 已载入，可调用 glm-5.2 分析。';
    } catch (error) {
      let err: BusinessError = error as BusinessError;
      this.nestedSession.errorMessage = 'Skill.md 选择失败：' + err.message;
    }
  }

  selectForgeSourceKind(kind: string): void {
    if (this.forgeSourceKind !== kind) {
      this.forgeSourceKind = kind;
      this.clearForgeArtifacts();
      this.nestedSession.errorMessage = '';
    }
  }

  clearForgeArtifacts(): void {
    this.forgeManifestJson = '';
    this.forgeVisionJson = '';
    this.forgeBlueprintJson = '';
    this.nestedDslText = '';
  }

  private async drainHdcDebugCommands(): Promise<void> {
    if (this.hdcDebugRunning) {
      return;
    }
    this.hdcDebugRunning = true;
    let command: HdcDebugCommand | undefined = takeNextHdcDebugCommand();
    while (command !== undefined) {
      await this.executeHdcDebugCommand(command);
      command = takeNextHdcDebugCommand();
    }
    this.hdcDebugRunning = false;
  }

  private async executeHdcDebugCommand(command: HdcDebugCommand): Promise<void> {
    let startedAt: number = Date.now();
    recordHdcDebugResult(runningHdcDebugResult(command, this.hdcDebugSnapshot()));
    try {
      await this.dispatchHdcDebugCommand(command);
      let result: HdcDebugResult = {
        requestId: command.requestId,
        action: command.action,
        status: 'succeeded',
        message: 'command completed',
        startedAt: startedAt,
        finishedAt: Date.now(),
        snapshot: this.hdcDebugSnapshot()
      };
      recordHdcDebugResult(result);
    } catch (error) {
      let err: Error = error as Error;
      let message: string = typeof err.message === 'string' ? err.message : 'command failed';
      this.statusText = '[HDC] ' + message;
      let result: HdcDebugResult = {
        requestId: command.requestId,
        action: command.action,
        status: 'failed',
        message: trimDebugText(message),
        startedAt: startedAt,
        finishedAt: Date.now(),
        snapshot: this.hdcDebugSnapshot()
      };
      recordHdcDebugResult(result);
    }
  }

  private async dispatchHdcDebugCommand(command: HdcDebugCommand): Promise<void> {
    switch (command.action) {
      case 'setForgeSource':
        this.setForgeSourceFromDebug(command.payload);
        return;
      case 'runForgeAnalyze':
        this.workspaceMode = 'nested';
        this.nestedFlow = 'forge';
        await this.analyzeForgeSkill();
        if (this.forgeManifestJson.length === 0) {
          throw new Error('Forge analysis did not produce a SkillManifest');
        }
        return;
      case 'runForgePreview':
        this.workspaceMode = 'nested';
        this.nestedFlow = 'forge';
        await this.prepareForgePreview();
        if (this.forgeBlueprintJson.length === 0 || this.nestedDslText.length === 0) {
          throw new Error('Forge preview did not produce AppBlueprint or DSL');
        }
        return;
      case 'installForgePreview':
        await this.installForgePreview();
        if (this.nestedFlow !== 'runtime') {
          throw new Error('Nested App was not installed');
        }
        return;
      case 'runForgePipeline':
        await this.runForgePipelineFromDebug(command.payload);
        return;
      case 'setSkillFields':
        this.setSkillFieldsFromDebug(command.payload);
        return;
      case 'runSkillAction':
        if (command.payload.trim().length === 0) {
          throw new Error('runSkillAction requires an action id');
        }
        await this.runSkillAction(command.payload);
        return;
      case 'setNestedFields':
        this.setNestedFieldsFromDebug(command.payload);
        return;
      case 'runNestedAction':
        await this.runNestedActionFromDebug(command.payload);
        return;
      case 'loadForgeImageFromDevice':
        this.loadForgeImageFromDevice(command.payload);
        return;
      case 'loadForgeImageDataUrl':
        this.loadForgeImageDataUrl(command.payload);
        return;
      case 'resetForgeImageTransfer':
        this.resetForgeImageTransfer();
        return;
      case 'appendForgeImageChunk':
        this.appendForgeImageChunk(command.payload);
        return;
      case 'finishForgeImageTransfer':
        this.finishForgeImageTransfer();
        return;
      case 'exportForgeArtifacts':
        this.exportForgeArtifacts(command.requestId);
        return;
      case 'exportCurrentArtifacts':
        this.exportCurrentArtifacts(command.requestId);
        return;
      case 'loadTravelDemo':
        await this.loadTravelDemoFromDebug();
        return;
      case 'resetWorkbench':
        this.resetWorkbenchFromDebug();
        return;
    }
  }

  private setForgeSourceFromDebug(payload: string): void {
    let data: Record<string, Object> = parseDebugObject(payload);
    let kind: string = debugObjectString(data, 'kind');
    let value: string = debugObjectString(data, 'value');
    if (kind !== 'repository' && kind !== 'text' && kind !== 'image') {
      throw new Error('setForgeSource kind must be repository, text, or image');
    }
    if (kind === 'image') {
      if (this.nestedSession.assets.length === 0) {
        throw new Error('image source requires an image already loaded in the app');
      }
    } else if (value.trim().length === 0) {
      throw new Error('setForgeSource requires a non-empty value');
    }
    this.workspaceMode = 'nested';
    this.nestedFlow = 'forge';
    this.forgeStage = 'import';
    this.forgeSourceKind = kind;
    if (kind === 'repository') {
      this.forgeRepositoryUrl = value;
      this.forgeSourceValue = '';
    } else if (kind === 'text') {
      this.forgeSourceValue = value;
      this.forgeSkillFileName = debugObjectString(data, 'fileName');
      if (this.forgeSkillFileName.length === 0) {
        this.forgeSkillFileName = 'debug-skill.md';
      }
    } else {
      this.forgeSourceValue = '';
    }
    this.clearForgeArtifacts();
    this.nestedSession.errorMessage = '';
    this.statusText = '[HDC] Forge source configured: ' + kind;
  }

  private async runForgePipelineFromDebug(payload: string): Promise<void> {
    if (payload.trim().length > 0) {
      this.setForgeSourceFromDebug(payload);
    } else if (this.forgeSourceKind.length === 0) {
      throw new Error('runForgePipeline requires a Forge source payload');
    }
    this.workspaceMode = 'nested';
    this.nestedFlow = 'forge';
    await this.analyzeForgeSkill();
    if (this.forgeManifestJson.length === 0) {
      throw new Error('Forge pipeline stopped after SkillManifest');
    }
    await this.prepareForgePreview();
    if (this.forgeBlueprintJson.length === 0 || this.nestedDslText.length === 0) {
      throw new Error('Forge pipeline stopped after AppBlueprint');
    }
    let data: Record<string, Object> = payload.trim().length > 0 ? parseDebugObject(payload) : {};
    if (debugObjectBoolean(data, 'install')) {
      await this.installForgePreview();
    }
  }

  private setSkillFieldsFromDebug(payload: string): void {
    let fields: Array<Record<string, Object>> = parseDebugFields(payload);
    for (let i: number = 0; i < fields.length; i++) {
      let id: string = debugObjectString(fields[i], 'id');
      let value: string = debugObjectString(fields[i], 'value');
      if (id.length === 0) {
        throw new Error('setSkillFields contains an empty id');
      }
      if (this.skillSession.skillSpec.skillId === 'TRAVEL_PLANNER_V1') {
        this.updateTravelInput(id, value);
      } else {
        this.updateGenericSkillInput(id, value);
      }
    }
  }

  private setNestedFieldsFromDebug(payload: string): void {
    let fields: Array<Record<string, Object>> = parseDebugFields(payload);
    for (let i: number = 0; i < fields.length; i++) {
      let key: string = debugObjectString(fields[i], 'key');
      let value: string = debugObjectString(fields[i], 'value');
      if (key.length === 0) {
        throw new Error('setNestedFields contains an empty key');
      }
      this.nestedSession = updateNestedField(this.nestedSession, key, value);
    }
  }

  private async runNestedActionFromDebug(payload: string): Promise<void> {
    let action: NestedAction = JSON.parse(payload) as NestedAction;
    if (action.id === undefined || action.label === undefined || action.targetPageId === undefined ||
      action.payload === undefined || !isDebugNestedActionKind(action.kind) ||
      (action.handling !== undefined && !isDebugNestedActionHandling(action.handling))) {
      throw new Error('invalid NestedAction payload');
    }
    await this.runNestedAction(action);
  }

  private loadForgeImageFromDevice(payload: string): void {
    let uri: string = payload.trim();
    if (uri.length === 0) {
      throw new Error('loadForgeImageFromDevice requires a device file path');
    }
    if (uri.indexOf('/data/local/tmp/') !== 0) {
      throw new Error('debug image path must stay under /data/local/tmp/');
    }
    let dataUrl: string = readImageFileAsDataUrl(uri);
    let nameStart: number = uri.lastIndexOf('/');
    let name: string = nameStart >= 0 ? uri.substring(nameStart + 1) : 'hdc-skill-image';
    let slot: string = this.nestedSession.assets.length === 0 ? 'cover' :
      'gallery-' + this.nestedSession.assets.length.toString();
    this.nestedSession = addNestedAsset(this.nestedSession, name, dataUrl, slot);
    this.workspaceMode = 'nested';
    this.nestedFlow = 'forge';
    this.forgeStage = 'import';
    this.forgeSourceKind = 'image';
    this.forgeSourceValue = '';
    this.clearForgeArtifacts();
    this.nestedSession.errorMessage = '';
    this.statusText = '[HDC] Skill image loaded from device: ' + name;
  }

  private loadForgeImageDataUrl(payload: string): void {
    let dataUrl: string = payload.trim();
    if (dataUrl.indexOf('data:image/') !== 0) {
      throw new Error('loadForgeImageDataUrl requires an image data URL');
    }
    if (dataUrl.length > 60 * 1024) {
      throw new Error('image data URL exceeds HDC debug payload limit');
    }
    let slot: string = this.nestedSession.assets.length === 0 ? 'cover' :
      'gallery-' + this.nestedSession.assets.length.toString();
    this.nestedSession = addNestedAsset(this.nestedSession, 'HDC image data URL', dataUrl, slot);
    this.workspaceMode = 'nested';
    this.nestedFlow = 'forge';
    this.forgeStage = 'import';
    this.forgeSourceKind = 'image';
    this.forgeSourceValue = '';
    this.clearForgeArtifacts();
    this.nestedSession.errorMessage = '';
    this.statusText = '[HDC] Skill image data URL loaded';
  }

  private resetForgeImageTransfer(): void {
    this.hdcImageChunks = {};
    this.hdcImageChunkTotal = 0;
    this.statusText = '[HDC] image transfer reset';
  }

  private appendForgeImageChunk(payload: string): void {
    let data: Record<string, Object> = parseDebugObject(payload);
    let index: number = debugObjectNumber(data, 'index');
    let total: number = debugObjectNumber(data, 'total');
    let chunk: string = debugObjectString(data, 'data');
    if (index < 0 || total <= 0 || total > 32 || index >= total || chunk.length === 0 || chunk.length > 16000) {
      throw new Error('invalid image chunk');
    }
    if (this.hdcImageChunkTotal !== 0 && this.hdcImageChunkTotal !== total) {
      throw new Error('image chunk total mismatch');
    }
    this.hdcImageChunkTotal = total;
    this.hdcImageChunks[index.toString()] = chunk;
  }

  private finishForgeImageTransfer(): void {
    if (this.hdcImageChunkTotal <= 0) {
      throw new Error('no image chunks received');
    }
    let base64: string = '';
    for (let i: number = 0; i < this.hdcImageChunkTotal; i++) {
      let chunk: string | undefined = this.hdcImageChunks[i.toString()];
      if (chunk === undefined || chunk.length === 0) {
        throw new Error('image chunk missing: ' + i.toString());
      }
      base64 = base64 + chunk;
    }
    let dataUrl: string = 'data:image/jpeg;base64,' + base64;
    this.loadForgeImageDataUrl(dataUrl);
    this.statusText = '[HDC] chunked Skill image loaded';
  }

  private exportForgeArtifacts(requestId: string): void {
    if (this.forgeManifestJson.length === 0) {
      throw new Error('no SkillManifest is available for export');
    }
    if (this.forgeBlueprintJson.length === 0) {
      throw new Error('no AppBlueprint is available for export');
    }
    recordHdcDebugArtifactExport(requestId, this.forgeManifestJson, this.forgeBlueprintJson);
    this.statusText = '[HDC] Forge artifacts exported';
  }

  private exportCurrentArtifacts(requestId: string): void {
    let manifest: string = this.forgeManifestJson.length > 0 ? this.forgeManifestJson :
      JSON.stringify(this.forgeDraft.manifest);
    let blueprint: string = this.forgeBlueprintJson.length > 0 ? this.forgeBlueprintJson :
      JSON.stringify(this.forgeDraft.blueprint);
    let dsl: string = this.nestedDslText.length > 0 ? this.nestedDslText :
      JSON.stringify(this.forgeDraft.uiSpec);
    recordHdcDebugArtifactExport(requestId, manifest, blueprint, dsl);
    this.statusText = '[HDC] current SkillManifest, AppBlueprint and ArkUiSpec exported';
  }

  private async loadTravelDemoFromDebug(): Promise<void> {
    this.workspaceMode = 'nested';
    this.forgeDraft = createForgeDraft(createSkillSource('text', '旅行规划助手 travel planner', []));
    this.nestedSession = createNestedSession(defaultTravelNestedApp());
    this.nestedDslText = JSON.stringify(this.forgeDraft.uiSpec);
    this.nestedFlow = 'runtime';
    this.statusText = '[HDC] travel ArkUiSpec app loaded';
  }

  private resetWorkbenchFromDebug(): void {
    this.workspaceMode = 'nested';
    this.nestedFlow = 'landing';
    this.forgeStage = 'import';
    this.forgeSourceKind = 'repository';
    this.forgeRepositoryUrl = 'https://github.com/seniverse/skills';
    this.forgeSourceValue = '';
    this.forgeSkillFileName = '';
    this.forgeDraft = createForgeDraft(createSkillSource('repository', this.forgeRepositoryUrl, []));
    this.skillSession = createSkillSession(defaultTravelSkillSpec());
    this.nestedSession = createNestedSession(defaultTravelNestedApp());
    this.nestedDslText = '';
    this.clearForgeArtifacts();
    this.statusText = '[HDC] workbench reset';
  }

  private hdcDebugSnapshot(): HdcDebugSnapshot {
    return {
      workspaceMode: this.workspaceMode,
      nestedFlow: this.nestedFlow,
      forgeStage: this.forgeStage,
      skillId: this.skillSession.skillSpec.skillId,
      activeSkillCardId: this.skillSession.activeCardId,
      nestedAppId: this.nestedSession.app.appId,
      activePageId: this.nestedSession.activePageId,
      skillProgress: this.skillSession.progress,
      statusText: trimDebugText(this.statusText),
      errorMessage: trimDebugText(this.nestedSession.errorMessage),
      manifestLength: this.forgeManifestJson.length,
      blueprintLength: this.forgeBlueprintJson.length,
      dslLength: this.nestedDslText.length
    };
  }

  async finishForge(): Promise<void> {
    await this.prepareForgePreview();
  }

  nestedValue(key: string): string {
    if (key.length === 0) {
      return '';
    }
    let value: string | undefined = this.nestedSession.data[key];
    return value === undefined ? '' : value;
  }

  nestedPageTitle(): string {
    return activeNestedPage(this.nestedSession).title;
  }

  nestedAsset(assetId: string): string {
    return assetDataUrl(this.nestedSession, assetId);
  }

  isNestedHome(): boolean {
    return this.nestedSession.activePageId === 'home';
  }

  startPlanningAction(): NestedAction {
    let current: NestedAction = {
      id: 'start-planning',
      label: '开始规划',
      kind: 'navigate',
      targetPageId: 'editor',
      payload: '',
      handling: 'local'
    };
    return current;
  }

  openFormManager(): void {
    try {
      formProvider.openFormManager({
        bundleName: 'com.example.glma2uicard',
        abilityName: 'EntryFormAbility',
        parameters: {
          'ohos.extra.param.key.form_dimension': 2,
          'ohos.extra.param.key.form_name': 'a2ui_card',
          'ohos.extra.param.key.module_name': 'entry'
        }
      });
      this.statusText = '已请求打开桌面卡片管理器';
    } catch (error) {
      let err: BusinessError = error as BusinessError;
      this.statusText = '打开桌面卡片管理器失败: ' + err.message;
    }
  }
}

function parseDebugObject(payload: string): Record<string, Object> {
  if (payload.trim().length === 0) {
    return {};
  }
  let value: Record<string, Object> = JSON.parse(payload) as Record<string, Object>;
  if (Array.isArray(value)) {
    throw new Error('debug payload must be a JSON object');
  }
  return value;
}

function parseDebugFields(payload: string): Array<Record<string, Object>> {
  let data: Record<string, Object> = parseDebugObject(payload);
  let value: Object | undefined = data['fields'];
  if (value === undefined || !Array.isArray(value)) {
    throw new Error('debug payload requires fields array');
  }
  let fields: Array<Object> = value as Array<Object>;
  let output: Array<Record<string, Object>> = [];
  for (let i: number = 0; i < fields.length; i++) {
    if (typeof fields[i] !== 'object' || fields[i] === null || Array.isArray(fields[i])) {
      throw new Error('debug fields must contain objects');
    }
    output.push(fields[i] as Record<string, Object>);
  }
  return output;
}

function debugObjectString(data: Record<string, Object>, key: string): string {
  let value: Object | undefined = data[key];
  if (value === undefined || typeof value !== 'string') {
    return '';
  }
  return value as string;
}

function debugObjectNumber(data: Record<string, Object>, key: string): number {
  let value: Object | undefined = data[key];
  if (typeof value === 'number') {
    return value as number;
  }
  if (typeof value === 'string') {
    let parsed: number = Number(value as string);
    return isNaN(parsed) ? -1 : parsed;
  }
  return -1;
}

function debugObjectBoolean(data: Record<string, Object>, key: string): boolean {
  let value: Object | undefined = data[key];
  if (value === true) {
    return true;
  }
  if (typeof value === 'string') {
    let text: string = value as string;
    return text === 'true' || text === '1';
  }
  return false;
}

function trimDebugText(value: string): string {
  return value.replace(/\r/g, ' ').replace(/\n/g, ' ').slice(0, 240);
}

function isDebugNestedActionKind(value: string): boolean {
  return value === 'navigate' || value === 'back' || value === 'invokeAgent' ||
    value === 'pickLocalImage' || value === 'reset';
}

function isDebugNestedActionHandling(value: string): boolean {
  return value === 'local' || value === 'agent' || value === 'localThenAgent';
}
