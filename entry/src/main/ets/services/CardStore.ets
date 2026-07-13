import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import { CardPreviewModel } from './A2uiTypes';
import { defaultCardPreview } from './A2uiMvp';

const STORE_NAME: string = 'a2uiCardStore';
const LATEST_CARD_KEY: string = 'latestCard';

function getStore(context: common.Context): preferences.Preferences {
  let options: preferences.Options = {
    name: STORE_NAME
  };
  return preferences.getPreferencesSync(context, options);
}

export async function saveLatestCard(context: common.Context, preview: CardPreviewModel): Promise<void> {
  let store: preferences.Preferences = getStore(context);
  store.putSync(LATEST_CARD_KEY, JSON.stringify(preview));
  await store.flush();
}

export function readLatestCard(context: common.Context): CardPreviewModel {
  let store: preferences.Preferences = getStore(context);
  let raw: preferences.ValueType = store.getSync(LATEST_CARD_KEY, '');
  if (typeof raw !== 'string' || raw.length === 0) {
    return defaultCardPreview();
  }

  try {
    return JSON.parse(raw) as CardPreviewModel;
  } catch (e) {
    return defaultCardPreview();
  }
}
