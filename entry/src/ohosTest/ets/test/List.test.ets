import { describe, it, expect } from '@ohos/hypium';
import { SEMANTIC_COMPONENT_COUNT, SemanticComponentCatalog } from '../../../main/ets/semanticui/contracts/SemanticComponentCatalog';
import { createTodoTasks } from '../../../main/ets/semanticui/gallery/SemanticGalleryState';
import { createSemanticEvent, textPayload } from '../../../main/ets/semanticui/foundation/SemanticEvents';

export default function testsuite() {
  describe('SemanticUiKit', () => {
    it('catalogHas72Components', 0, () => {
      expect(SEMANTIC_COMPONENT_COUNT).assertEqual(72);
      expect(SemanticComponentCatalog.list().length).assertEqual(72);
    });
    it('todoFixtureHasStableIds', 0, () => {
      let tasks = createTodoTasks();
      expect(tasks.length).assertEqual(5);
      expect(tasks[0].id).assertEqual('task-1');
      expect(tasks[4].id).assertEqual('task-5');
    });
    it('eventUsesTypedPayload', 0, () => {
      let event = createSemanticEvent('todo-input', 'change', textPayload('new task'));
      expect(event.payload.textValue).assertEqual('new task');
      expect(event.name).assertEqual('change');
    });
  });
}
