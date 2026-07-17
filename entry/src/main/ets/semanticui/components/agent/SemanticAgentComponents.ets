import { SemanticUiEvent, createSemanticEvent } from '../../foundation/SemanticEvents';
import { SemanticAgentStatus, SemanticThemeMode, SemanticTone } from '../../foundation/SemanticEnums';
import { SemanticTheme, createSemanticTheme } from '../../foundation/SemanticTheme';
import { SemanticActionModel, SemanticAgentModel } from '../../foundation/SemanticModels';
import { SemanticButton, SemanticSurface } from '../../internal/SemanticAtoms';

@ComponentV2
export struct AgentSuggestion {
  @Param model: SemanticAgentModel = new SemanticAgentModel();
  @Param theme: SemanticTheme = createSemanticTheme(SemanticThemeMode.LIGHT);
  @Event onEvent: (event: SemanticUiEvent) => void = () => {};
  build() { Column({ space: this.theme.spacing.sm }) { Row() { Text('AI 建议').fontWeight(FontWeight.Bold).layoutWeight(1); Text(this.statusText()).fontSize(this.theme.typography.caption).fontColor(this.theme.colors.primary); }.width('100%'); Text(this.model.body || this.model.title).fontColor(this.theme.colors.textSecondary); Row({ space: this.theme.spacing.sm }) { ForEach(this.model.actions, (item: SemanticActionModel) => { SemanticButton({ theme: this.theme, label: item.label, isEnabled: item.enabled, onEvent: () => this.onEvent(createSemanticEvent(item.id, 'press')) }); }, (item: SemanticActionModel) => item.id); }.width('100%'); }.width('100%').padding(this.theme.spacing.md).backgroundColor(this.theme.colors.primarySoft).borderRadius(this.theme.radius.lg); }
  private statusText(): string { if (this.model.agentStatus === SemanticAgentStatus.PENDING) { return '处理中'; } if (this.model.agentStatus === SemanticAgentStatus.ERROR) { return '需要重试'; } return '可审核'; }
}

@ComponentV2
export struct AgentResult {
  @Param model: SemanticAgentModel = new SemanticAgentModel();
  @Param theme: SemanticTheme = createSemanticTheme(SemanticThemeMode.LIGHT);
  @Event onEvent: (event: SemanticUiEvent) => void = () => {};
  build() { SemanticSurface({ theme: this.theme, title: this.model.title, body: this.model.body, tone: this.model.agentStatus === SemanticAgentStatus.ERROR ? SemanticTone.DANGER : SemanticTone.SUCCESS }); }
}

@ComponentV2
export struct ApprovalCard {
  @Param model: SemanticAgentModel = new SemanticAgentModel();
  @Param theme: SemanticTheme = createSemanticTheme(SemanticThemeMode.LIGHT);
  @Event onEvent: (event: SemanticUiEvent) => void = () => {};
  build() { Column({ space: this.theme.spacing.sm }) { Text(this.model.title).fontSize(this.theme.typography.title).fontWeight(FontWeight.Bold); Text(this.model.body).fontColor(this.theme.colors.textSecondary); if (this.model.riskLevel.length > 0) { Text('风险：' + this.model.riskLevel).fontColor(this.theme.colors.warning); } Row({ space: this.theme.spacing.sm }) { ForEach(this.model.actions, (item: SemanticActionModel) => { SemanticButton({ theme: this.theme, label: item.label, isEnabled: item.enabled, onEvent: () => this.onEvent(createSemanticEvent(item.id, 'press')) }); }, (item: SemanticActionModel) => item.id); }.width('100%'); }.width('100%').padding(this.theme.spacing.md).backgroundColor(this.theme.colors.surfaceElevated).borderRadius(this.theme.radius.lg); }
}

@ComponentV2
export struct ToolResultCard {
  @Param model: SemanticAgentModel = new SemanticAgentModel();
  @Param theme: SemanticTheme = createSemanticTheme(SemanticThemeMode.LIGHT);
  @Event onEvent: (event: SemanticUiEvent) => void = () => {};
  build() { Column({ space: this.theme.spacing.xs }) { Row() { Text('工具结果').fontWeight(FontWeight.Bold).layoutWeight(1); Text(this.model.agentStatus).fontSize(this.theme.typography.caption).fontColor(this.theme.colors.textSecondary); }.width('100%'); Text(this.model.body).fontColor(this.theme.colors.textPrimary); if (this.model.sources.length > 0) { Text('来源 ' + this.model.sources.length.toString()).fontSize(this.theme.typography.caption).fontColor(this.theme.colors.textSecondary); } }.width('100%').padding(this.theme.spacing.md).backgroundColor(this.theme.colors.surfaceMuted).borderRadius(this.theme.radius.md); }
}
