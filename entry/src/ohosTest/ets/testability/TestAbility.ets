import { AbilityConstant, UIAbility, Want } from '@kit.AbilityKit';
import { abilityDelegatorRegistry } from '@kit.TestKit';
import { Hypium } from '@ohos/hypium';
import { window } from '@kit.ArkUI';
import testsuite from '../test/List.test';

export default class TestAbility extends UIAbility {
  onCreate(_want: Want, _launchParam: AbilityConstant.LaunchParam): void {
    let delegator = abilityDelegatorRegistry.getAbilityDelegator();
    let args = abilityDelegatorRegistry.getArguments();
    Hypium.hypiumTest(delegator, args, testsuite);
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    windowStage.loadContent('testability/pages/Index');
  }
}
