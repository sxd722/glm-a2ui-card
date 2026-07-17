import { SemanticUiEvent, createSemanticEvent } from '../../foundation/SemanticEvents';
import { SemanticComponentBaseModel, SemanticTextModel } from '../../foundation/SemanticModels';
import { SemanticTheme, createSemanticTheme } from '../../foundation/SemanticTheme';
import { SemanticThemeMode } from '../../foundation/SemanticEnums';

@ComponentV2
export struct AppShell {
  @Param @Require model: SemanticComponentBaseModel;
  @Param theme: SemanticTheme = createSemanticTheme(SemanticThemeMode.LIGHT);
  @Param pathStack: NavPathStack = new NavPathStack();
  @BuilderParam top: () => void;
  @BuilderParam body: () => void;
  @BuilderParam bottom: () => void;
  @BuilderParam overlaySlot: () => void;
  @Event onEvent: (event: SemanticUiEvent) => void = () => {};

  build() {
    Navigation(this.pathStack) {
      Stack({ alignContent: Alignment.Bottom }) {
        Column() {
          this.top();
          Column() { this.body(); }.layoutWeight(1).width('100%');
          this.bottom();
        }
        this.overlaySlot();
      }
      .width('100%')
      .height('100%')
      .safeAreaPadding({ top: this.theme.spacing.sm, bottom: this.theme.spacing.sm });
    }
    .hideTitleBar(true);
  }
}

@ComponentV2
export struct ListPage {
  @Param @Require model: SemanticComponentBaseModel;
  @Param theme: SemanticTheme = createSemanticTheme(SemanticThemeMode.LIGHT);
  @BuilderParam header: () => void;
  @BuilderParam list: () => void;
  @BuilderParam empty: () => void;

  build() {
    Column({ space: this.theme.spacing.md }) {
      this.header();
      Column() { this.list(); }.layoutWeight(1).width('100%');
    }.width('100%').height('100%').padding(this.theme.spacing.md);
  }
}

@ComponentV2
export struct DetailPage {
  @Param @Require model: SemanticComponentBaseModel;
  @Param theme: SemanticTheme = createSemanticTheme(SemanticThemeMode.LIGHT);
  @BuilderParam header: () => void;
  @BuilderParam body: () => void;
  @BuilderParam actions: () => void;

  build() {
    Scroll() {
      Column({ space: this.theme.spacing.lg }) { this.header(); this.body(); this.actions(); }
      .width('100%').padding(this.theme.spacing.md);
    }.width('100%').height('100%').scrollBar(BarState.Off);
  }
}

@ComponentV2
export struct FormPage {
  @Param @Require model: SemanticComponentBaseModel;
  @Param theme: SemanticTheme = createSemanticTheme(SemanticThemeMode.LIGHT);
  @BuilderParam header: () => void;
  @BuilderParam fields: () => void;
  @BuilderParam actions: () => void;

  build() {
    Scroll() {
      Column({ space: this.theme.spacing.lg }) { this.header(); this.fields(); this.actions(); }
      .width('100%').padding(this.theme.spacing.md);
    }.width('100%').height('100%').scrollBar(BarState.Off);
  }
}

@ComponentV2
export struct DashboardPage {
  @Param @Require model: SemanticComponentBaseModel;
  @Param theme: SemanticTheme = createSemanticTheme(SemanticThemeMode.LIGHT);
  @BuilderParam header: () => void;
  @BuilderParam body: () => void;

  build() {
    Scroll() {
      Column({ space: this.theme.spacing.lg }) { this.header(); this.body(); }
      .width('100%').padding(this.theme.spacing.md);
    }.width('100%').height('100%').scrollBar(BarState.Off);
  }
}

@ComponentV2
export struct SearchPage {
  @Param @Require model: SemanticComponentBaseModel;
  @Param theme: SemanticTheme = createSemanticTheme(SemanticThemeMode.LIGHT);
  @BuilderParam search: () => void;
  @BuilderParam filters: () => void;
  @BuilderParam results: () => void;

  build() {
    Column({ space: this.theme.spacing.sm }) {
      this.search();
      this.filters();
      Column() { this.results(); }.layoutWeight(1).width('100%');
    }.width('100%').height('100%').padding(this.theme.spacing.md);
  }
}

@ComponentV2
export struct WizardPage {
  @Param @Require model: SemanticComponentBaseModel;
  @Param theme: SemanticTheme = createSemanticTheme(SemanticThemeMode.LIGHT);
  @BuilderParam header: () => void;
  @BuilderParam step: () => void;
  @BuilderParam actions: () => void;

  build() {
    Scroll() {
      Column({ space: this.theme.spacing.lg }) { this.header(); this.step(); this.actions(); }
      .width('100%').padding(this.theme.spacing.md);
    }.width('100%').height('100%').scrollBar(BarState.Off);
  }
}

@ComponentV2
export struct AgentPage {
  @Param @Require model: SemanticComponentBaseModel;
  @Param theme: SemanticTheme = createSemanticTheme(SemanticThemeMode.LIGHT);
  @BuilderParam header: () => void;
  @BuilderParam messages: () => void;
  @BuilderParam composer: () => void;

  build() {
    Column({ space: this.theme.spacing.sm }) {
      this.header();
      Column() { this.messages(); }.layoutWeight(1).width('100%');
      this.composer();
    }.width('100%').height('100%').padding(this.theme.spacing.md);
  }
}
