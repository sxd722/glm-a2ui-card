import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import { ForgeDraft, InstalledSkillApp, RuntimeSession } from './SkillAppTypes';

const STORE_NAME: string = 'skillAppMvpStore';
const FORGE_DRAFT_KEY: string = 'forgeDraft';
const INSTALLED_APP_KEY: string = 'installedNestedApp';
const RUNTIME_SESSION_KEY: string = 'runtimeSession';

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
