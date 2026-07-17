import { TestRunner, abilityDelegatorRegistry } from '@kit.TestKit';
import { UIAbility } from '@kit.AbilityKit';

export default class OpenHarmonyTestRunner implements TestRunner {
  onPrepare(): void {}
  onRun(): void {
    let delegator = abilityDelegatorRegistry.getAbilityDelegator();
    let args = abilityDelegatorRegistry.getArguments();
    let moduleName = args.parameters['-m'];
    let want = { bundleName: args.bundleName, moduleName: moduleName, abilityName: 'TestAbility' };
    delegator.startAbility(want, () => {});
  }
}
