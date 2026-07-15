import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import { ForgeDraft, InstalledSkillApp, RunnerSessionSnapshot, RuntimeSession, UiIrRunnerSessionSnapshot } from './SkillAppTypes';

const STORE_NAME: string = 'skillAppMvpStore';
const FORGE_DRAFT_KEY: string = 'forgeDraft';
const INSTALLED_APP_KEY: string = 'installedNestedApp';
const RUNTIME_SESSION_KEY: string = 'runtimeSession';
const INSTALLED_APP_PREFIX: string = 'installedNestedApp:';
const RUNNER_SESSION_PREFIX: string = 'runnerSession:';
const UI_IR_RUNNER_SESSION_PREFIX: string = 'uiIrRunnerSession:';

export async function saveForgeDraft(context: common.Context, draft: ForgeDraft): Promise<void> {
  let store: preferences.Preferences = preferences.getPreferencesSync(context, { name: STORE_NAME });
  store.putSync(FORGE_DRAFT_KEY, JSON.stringify(draft));
  await store.flush();
}

export function readForgeDraft(context: common.Context): ForgeDraft | undefined {
  let store: preferences.Preferences = preferences.getPreferencesSync(context, { name: STORE_NAME });
  let raw: preferences.ValueType = store.getSync(FORGE_DRAFT_KEY, '');
  if (typeof raw === 'string' && raw.length > 0) {
    try {
      return JSON.parse(raw) as ForgeDraft;
    } catch (e) {
    }
  }
  return undefined;
}

export async function saveInstalledNestedApp(context: common.Context, app: InstalledSkillApp): Promise<void> {
  let store: preferences.Preferences = preferences.getPreferencesSync(context, { name: STORE_NAME });
  store.putSync(INSTALLED_APP_KEY, JSON.stringify(app));
  store.putSync(INSTALLED_APP_PREFIX + app.appId, JSON.stringify(app));
  await store.flush();
}

export function readInstalledNestedApp(context: common.Context): InstalledSkillApp | undefined {
  let store: preferences.Preferences = preferences.getPreferencesSync(context, { name: STORE_NAME });
  let raw: preferences.ValueType = store.getSync(INSTALLED_APP_KEY, '');
  if (typeof raw === 'string' && raw.length > 0) {
    try {
      return JSON.parse(raw) as InstalledSkillApp;
    } catch (e) {
    }
  }
  return undefined;
}

export function readInstalledNestedAppById(context: common.Context, appId: string): InstalledSkillApp | undefined {
  let store: preferences.Preferences = preferences.getPreferencesSync(context, { name: STORE_NAME });
  let raw: preferences.ValueType = store.getSync(INSTALLED_APP_PREFIX + appId, '');
  if (typeof raw === 'string' && raw.length > 0) {
    try {
      return JSON.parse(raw) as InstalledSkillApp;
    } catch (e) {
    }
  }
  return readInstalledNestedApp(context);
}

export async function saveRunnerSession(context: common.Context, snapshot: RunnerSessionSnapshot): Promise<void> {
  let store: preferences.Preferences = preferences.getPreferencesSync(context, { name: STORE_NAME });
  store.putSync(RUNNER_SESSION_PREFIX + snapshot.sessionId, JSON.stringify(snapshot));
  await store.flush();
}

export function readRunnerSession(context: common.Context, sessionId: string): RunnerSessionSnapshot | undefined {
  let store: preferences.Preferences = preferences.getPreferencesSync(context, { name: STORE_NAME });
  let raw: preferences.ValueType = store.getSync(RUNNER_SESSION_PREFIX + sessionId, '');
  if (typeof raw === 'string' && raw.length > 0) {
    try {
      return JSON.parse(raw) as RunnerSessionSnapshot;
    } catch (e) {
    }
  }
  return undefined;
}

export async function saveUiIrRunnerSession(context: common.Context, snapshot: UiIrRunnerSessionSnapshot): Promise<void> {
  let store: preferences.Preferences = preferences.getPreferencesSync(context, { name: STORE_NAME });
  store.putSync(UI_IR_RUNNER_SESSION_PREFIX + snapshot.sessionId, JSON.stringify(snapshot));
  await store.flush();
}

export function readUiIrRunnerSession(context: common.Context, sessionId: string): UiIrRunnerSessionSnapshot | undefined {
  let store: preferences.Preferences = preferences.getPreferencesSync(context, { name: STORE_NAME });
  let raw: preferences.ValueType = store.getSync(UI_IR_RUNNER_SESSION_PREFIX + sessionId, '');
  if (typeof raw === 'string' && raw.length > 0) {
    try {
      return JSON.parse(raw) as UiIrRunnerSessionSnapshot;
    } catch (e) {
    }
  }
  return undefined;
}

export async function saveRuntimeSession(context: common.Context, session: RuntimeSession): Promise<void> {
  let store: preferences.Preferences = preferences.getPreferencesSync(context, { name: STORE_NAME });
  store.putSync(RUNTIME_SESSION_KEY, JSON.stringify(session));
  await store.flush();
}

export function readRuntimeSession(context: common.Context): RuntimeSession | undefined {
  let store: preferences.Preferences = preferences.getPreferencesSync(context, { name: STORE_NAME });
  let raw: preferences.ValueType = store.getSync(RUNTIME_SESSION_KEY, '');
  if (typeof raw === 'string' && raw.length > 0) {
    try {
      return JSON.parse(raw) as RuntimeSession;
    } catch (e) {
    }
  }
  return undefined;
}

// TODO(MVP-next): Add schema-version validation and last-known-good snapshot rotation before production use.
// Secrets are intentionally excluded. CredentialVault owns GLM and tool API keys.
