import { Want } from '@kit.AbilityKit';
import { formBindingData, FormExtensionAbility, formProvider } from '@kit.FormKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { toFormData } from '../services/A2uiMvp';
import { readLatestCard } from '../services/CardStore';

const DOMAIN: number = 0x0001;
const TAG: string = 'EntryFormAbility';

export default class EntryFormAbility extends FormExtensionAbility {
  onAddForm(want: Want): formBindingData.FormBindingData {
    hilog.info(DOMAIN, TAG, 'onAddForm');
    return formBindingData.createFormBindingData(toFormData(readLatestCard(this.context)));
  }

  onUpdateForm(formId: string): void {
    hilog.info(DOMAIN, TAG, 'onUpdateForm %{public}s', formId);
    let data: formBindingData.FormBindingData =
      formBindingData.createFormBindingData(toFormData(readLatestCard(this.context)));
    formProvider.updateForm(formId, data);
  }

  onFormEvent(formId: string, message: string): void {
    hilog.info(DOMAIN, TAG, 'onFormEvent %{public}s %{public}s', formId, message);
  }

  onRemoveForm(formId: string): void {
    hilog.info(DOMAIN, TAG, 'onRemoveForm %{public}s', formId);
  }
}
