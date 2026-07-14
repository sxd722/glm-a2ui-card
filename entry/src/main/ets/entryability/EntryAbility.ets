import { AbilityConstant, UIAbility, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';
import {
  HDC_DEBUG_EVENT,
  enqueueHdcDebugCommand,
  hdcDebugDumpLines,
  ingestHdcDebugWant,
  queuedHdcDebugResult,
  recordHdcDebugResult
} from '../services/HdcDebugBridge';

const DOMAIN = 0x0000;
const TAG = 'EmptyAbilitySmoke';

export default class EntryAbility extends UIAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    hilog.info(DOMAIN, TAG, 'EntryAbility onCreate. ability=%{public}s reason=%{public}d',
      want.abilityName ?? '', launchParam.launchReason);
    this.handleDebugWant(want);
  }

  onNewWant(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    hilog.info(DOMAIN, TAG, 'EntryAbility onNewWant. reason=%{public}d', launchParam.launchReason);
    this.handleDebugWant(want);
  }

  onDump(params: Array<string>): Array<string> {
    return hdcDebugDumpLines();
  }

  private handleDebugWant(want: Want): void {
    let parsed = ingestHdcDebugWant(want);
    if (parsed.command === undefined) {
      if (parsed.error.length > 0) {
        hilog.warn(0x0000, 'HdcDebug', 'Rejected request=%{public}s reason=%{public}s',
          parsed.requestId, parsed.error);
      }
      return;
    }
    let accepted: boolean = enqueueHdcDebugCommand(parsed.command);
    if (!accepted) {
      hilog.warn(0x0000, 'HdcDebug', 'Rejected duplicate or full queue request=%{public}s action=%{public}s',
        parsed.command.requestId, parsed.command.action);
      return;
    }
    recordHdcDebugResult(queuedHdcDebugResult(parsed.command));
    hilog.info(0x0000, 'HdcDebug', 'Queued request=%{public}s action=%{public}s payloadLength=%{public}d',
      parsed.command.requestId, parsed.command.action, parsed.command.payload.length);
    this.context.eventHub.emit(HDC_DEBUG_EVENT);
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    hilog.info(DOMAIN, TAG, 'EntryAbility onWindowStageCreate.');
    windowStage.loadContent('pages/Index', (err) => {
      if (err.code) {
        hilog.error(DOMAIN, TAG, 'Failed to load pages/Index. code=%{public}d message=%{public}s',
          err.code, err.message);
        return;
      }
      hilog.info(DOMAIN, TAG, 'pages/Index loaded.');
    });
  }

  onWindowStageDestroy(): void {
    hilog.info(DOMAIN, TAG, 'EntryAbility onWindowStageDestroy.');
  }

  onForeground(): void {
    hilog.info(DOMAIN, TAG, 'EntryAbility onForeground.');
  }

  onBackground(): void {
    hilog.info(DOMAIN, TAG, 'EntryAbility onBackground.');
  }
}
