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
  saveSkillSession,
  skillSessionToCardPreview,
  TRAVEL_TOOL_NAMES
} from '../services/SkillWorkbench';
import { AgentTurnResult, SkillCard, SkillCardAction, SkillSessionState, TravelInputs } from '../services/SkillTypes';
import { LocalImageAsset, NestedAction, NestedNode, NestedPageSpec, NestedSessionState } from '../services/NestedAppTypes';
import {
  activeNestedPage,
  addNestedAsset,
  assetDataUrl,
  createNestedSession,
  defaultTravelNestedApp,
  normalizeNestedApp,
  reduceNestedAction,
  updateNestedField
} from '../services/NestedAppService';
import {
  GLM_ALTERNATE_MODEL,
  GLM_CODING_ENDPOINT,
  GLM_DEFAULT_MODEL,
  GLM_LOCAL_API_KEY,
  requestA2uiDslFromGlm,
  requestAgentTurnFromGlm,
  requestAppBlueprintFromGlm,
  requestNestedRuntimeTurnFromGlm,
  requestSkillManifestFromGlm,
  requestSkillSpecFromGlmImage
} from '../services/GlmClient';
import {
  compileBlueprint,
  createForgeDraft,
  createSkillSource,
  installBlueprint,
  localBlueprintForManifest,
  normalizeAppBlueprint,
  normalizeSkillManifest,
  updateDraftBlueprint,
  updateDraftManifest
} from '../services/SkillAppMvp';
import { AppBlueprint, ForgeDraft, RuntimeAgentTurnRequest, RuntimeAgentTurnResult, SkillSource, ToolContract } from '../services/SkillAppTypes';
import { applyRuntimeAgentTurn, buildRuntimeAgentTurnRequest, normalizeRuntimeAgentTurnResult } from '../services/NestedAgentRuntime';
import { saveForgeDraft, saveInstalledNestedApp } from '../services/SkillAppStore';

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
  @State forgeSourceValue: string = 'https://github.com/seniverse/skills';
  @State forgeSkillName: string = '旅行规划助手';
  @State forgeSkillGoal: string = '生成一套可交互的旅行规划应用';
  @State seniverseApiKey: string = '';
  @State forgeDraft: ForgeDraft = createForgeDraft(createSkillSource('repository', 'https://github.com/seniverse/skills', []));
  @State forgeManifestJson: string = '';
  @State forgeBlueprintJson: string = '';
  @State nestedSession: NestedSessionState = createNestedSession(defaultTravelNestedApp());
  @State nestedDslText: string = '';
  private context: common.UIAbilityContext = this.getUIContext().getHostContext() as common.UIAbilityContext;

  aboutToAppear(): void {
    this.preview = projectDslToCardPreview(this.dslText);
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
          .onClick(() => { this.forgeSourceKind = 'repository'; })
        Button('文字描述').layoutWeight(1)
          .backgroundColor(this.forgeSourceKind === 'text' ? '#6D7E73' : '#B7C1BA')
          .onClick(() => { this.forgeSourceKind = 'text'; })
        Button('图片').layoutWeight(1)
          .backgroundColor(this.forgeSourceKind === 'image' ? '#6D7E73' : '#B7C1BA')
          .onClick(() => { this.forgeSourceKind = 'image'; })
      }.width('100%')
      if (this.forgeSourceKind === 'repository') {
        TextInput({ text: this.forgeSourceValue, placeholder: 'https://github.com/.../skills' })
          .height(44).backgroundColor('#FFFFFFAA')
          .onChange((value: string) => { this.forgeSourceValue = value; })
      } else if (this.forgeSourceKind === 'text') {
        TextArea({ text: this.forgeSourceValue, placeholder: '描述 Skill 的目标、输入、工具和输出' })
          .height(100).backgroundColor('#FFFFFFAA')
          .onChange((value: string) => { this.forgeSourceValue = value; })
      } else {
        Row({ space: 8 }) {
          Button('从相册选择').layoutWeight(1).onClick(async () => { await this.pickForgeImage(false); })
          Button('从文件选择').layoutWeight(1).onClick(async () => { await this.pickForgeImage(true); })
        }.width('100%')
        Text('已选 Skill 图片 / 素材 ' + this.nestedSession.assets.length.toString() + ' 张')
          .fontSize(12).fontColor('#5D6C63')
      }
      Text('仓库导入当前使用受控本地识别；深度读取由 RepositoryImporter 后续接入。')
        .fontSize(11).fontColor('#756E66').width('100%')
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
      ForEach(this.forgeDraft.blueprint.nestedApp.pages, (pageSpec: NestedPageSpec) => {
        Text(pageSpec.title + ' · ' + pageSpec.nodes.length.toString() + ' 个组件')
          .fontSize(12).fontColor('#5B675F').padding(10).width('100%')
          .backgroundColor('#FFFFFF88').borderRadius(10)
      })
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

      ForEach(activeNestedPage(this.nestedSession).nodes, (node: NestedNode) => {
        this.NestedNodeView(node)
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

      TextArea({ text: this.nestedDslText, placeholder: 'NestedAppSpec JSON（可查看或粘贴 GLM 结果）' })
        .height(82)
        .fontSize(10)
        .onChange((value: string) => {
          this.nestedDslText = value;
        })
      Button('应用 NestedAppSpec JSON')
        .width('100%')
        .backgroundColor('#7A8A99')
        .onClick(() => {
          this.nestedSession = createNestedSession(normalizeNestedApp(this.nestedDslText));
          this.nestedSession.agentTrace = '已应用受控 Nested App DSL。';
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
          this.skillSession = createSkillSession(normalizeSkillSpec(this.skillRawJson));
          await saveSkillSession(this.context, this.skillSession);
          this.agentTrace = 'SkillSpec 已编译为卡片集合';
        })

      this.SkillInputEditor()
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
      baseUrl: this.baseUrl,
      apiKey: this.apiKey,
      model: this.model
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
    let sourceValue: string = this.forgeSourceValue;
    if (this.forgeSourceKind === 'image') {
      sourceValue = '用户选择的 Skill 图片，共 ' + assetIds.length.toString() + ' 张。';
    }
    let source: SkillSource = createSkillSource(this.forgeSourceKind, sourceValue, assetIds);
    let draft: ForgeDraft = createForgeDraft(source);
    let trace: string = '已使用本地通用分析器生成 SkillManifest 回退结果。';
    if (this.apiKey.length > 0 && source.kind !== 'image') {
      let config: GlmLocalConfig = { baseUrl: this.baseUrl, apiKey: this.apiKey, model: this.model };
      try {
        let raw: string = await requestSkillManifestFromGlm(source, config);
        this.forgeManifestJson = raw;
        draft = updateDraftManifest(draft, normalizeSkillManifest(raw, draft.manifest), 'GLM 已生成 SkillManifest。');
        trace = draft.trace;
      } catch (error) {
        let err: BusinessError = error as BusinessError;
        trace = 'GLM 分析失败，已保留本地回退 Manifest：' + err.message;
      }
    } else if (source.kind === 'image') {
      // TODO(MVP-next): Route image sources through a configurable visionModel and convert the result to SkillManifest.
      trace = '图片已保留；视觉模型路由尚未接入，当前使用本地旅行 SkillManifest。';
    }
    draft = updateDraftManifest(draft, draft.manifest, trace);
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
    let blueprint: AppBlueprint = fallback;
    let trace: string = '已生成本地可运行 Blueprint 预览。';
    if (this.apiKey.length > 0) {
      let config: GlmLocalConfig = { baseUrl: this.baseUrl, apiKey: this.apiKey, model: this.model };
      try {
        let raw: string = await requestAppBlueprintFromGlm(this.forgeDraft.manifest, this.forgeAssetIds(), config);
        this.forgeBlueprintJson = raw;
        blueprint = normalizeAppBlueprint(raw, fallback);
        trace = blueprint === fallback ? 'GLM Blueprint 未通过校验，已使用本地回退预览。' : 'GLM Blueprint 已通过骨架校验。';
      } catch (error) {
        let err: BusinessError = error as BusinessError;
        trace = 'GLM 设计失败，已使用本地回退 Blueprint：' + err.message;
      }
    }
    this.forgeDraft = updateDraftBlueprint(this.forgeDraft, blueprint, trace);
    this.nestedDslText = JSON.stringify(compileBlueprint(blueprint));
    this.forgeStage = 'preview';
    try {
      await saveForgeDraft(this.context, this.forgeDraft);
    } catch (error) {
      this.forgeDraft.trace = this.forgeDraft.trace + ' 草稿持久化失败，但可继续创建。';
    }
  }

  async installForgePreview(): Promise<void> {
    let assets: LocalImageAsset[] = this.nestedSession.assets;
    this.nestedSession = createNestedSession(compileBlueprint(this.forgeDraft.blueprint));
    this.nestedSession.assets = assets;
    this.nestedSession.agentTrace = 'Nested App 已安装；本地动作即时响应，语义动作进入 GLM Runtime Turn。';
    this.nestedDslText = JSON.stringify(this.nestedSession.app);
    try {
      await saveInstalledNestedApp(this.context, installBlueprint(this.forgeDraft));
    } catch (error) {
      this.nestedSession.agentTrace = this.nestedSession.agentTrace + ' 安装信息持久化失败。';
    }
    this.nestedFlow = 'runtime';
  }

  forgeAssetIds(): string[] {
    let ids: string[] = [];
    for (let i = 0; i < this.nestedSession.assets.length; i++) {
      ids.push(this.nestedSession.assets[i].id);
    }
    return ids;
  }

  async generateNestedAppWithGlm(): Promise<void> {
    if (this.apiKey.length === 0) {
      this.nestedSession.agentTrace = '缺少 API key，已保留当前本地 Nested App。';
      return;
    }
    let config: GlmLocalConfig = { baseUrl: this.baseUrl, apiKey: this.apiKey, model: this.model };
    try {
      this.nestedSession.agentTrace = 'GLM 正在重新设计受控 AppBlueprint...';
      let raw: string = await requestAppBlueprintFromGlm(this.forgeDraft.manifest, this.forgeAssetIds(), config);
      let fallback: AppBlueprint = localBlueprintForManifest(this.forgeDraft.manifest);
      let blueprint: AppBlueprint = normalizeAppBlueprint(raw, fallback);
      this.forgeDraft = updateDraftBlueprint(this.forgeDraft, blueprint, 'Runtime 中已重新生成 Blueprint。');
      this.nestedDslText = JSON.stringify(compileBlueprint(blueprint));
      let next: NestedSessionState = createNestedSession(compileBlueprint(blueprint));
      next.assets = this.nestedSession.assets;
      next.agentTrace = 'GLM Nested App 已加载；材质与交互由本地 ArkUI 控制。';
      this.nestedSession = next;
      this.nestedFlow = 'runtime';
    } catch (error) {
      let err: BusinessError = error as BusinessError;
      this.nestedSession.agentTrace = 'GLM 生成失败，已继续使用本地 Demo：' + err.message;
      this.nestedFlow = 'runtime';
    }
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
      let config: GlmLocalConfig = { baseUrl: this.baseUrl, apiKey: this.apiKey, model: this.model };
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
    } catch (error) {
      let err: BusinessError = error as BusinessError;
      this.nestedSession.errorMessage = '素材选择失败：' + err.message;
    }
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
      payload: ''
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
