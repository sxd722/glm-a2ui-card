import { ArkUiAction, ArkUiNode, ArkUiPage, ArkUiSpec } from './ArkUiTypes';
import { UiAction, UiExpression, UiIrNode, UiIrPage, UiIrSpec } from './UiIrTypes';
import { stringValue } from './UiValue';

export function convertArkUiSpecToUiIr(spec: ArkUiSpec): UiIrSpec {
  let pages: UiIrPage[] = [];
  for (let i: number = 0; i < spec.pages.length; i++) {
    let page: ArkUiPage = spec.pages[i];
    pages.push({ id: page.id, title: page.title, scroll: page.scroll, layoutPreset: 'legacy', root: convertNode(page.root) });
  }
  return { schemaVersion: 'ui-ir-1', appId: spec.appId, title: spec.title, subtitle: spec.subtitle,
    initialPageId: spec.initialPageId, theme: { name: 'legacy-adapter', tokens: spec.theme.colors }, initialState: {}, computed: [], pages: pages };
}

function convertNode(node: ArkUiNode): UiIrNode {
  let children: UiIrNode[] = [];
  for (let i: number = 0; i < node.children.length; i++) { children.push(convertNode(node.children[i])); }
  let props: Record<string, UiExpression> = {};
  let propNames: string[] = Object.keys(node.props);
  for (let i: number = 0; i < propNames.length; i++) { props[propNames[i]] = literalText(node.props[propNames[i]]); }
  if (node.items.length > 0) { props['items'] = literalArray(node.items); }
  let actions: Record<string, UiAction> = {};
  for (let i: number = 0; i < node.actions.length; i++) { actions['action-' + i.toString()] = convertAction(node.actions[i]); }
  let result: UiIrNode = { kind: 'element', id: node.id, component: componentFor(node.type), props: props, binding: node.binding,
    className: node.className, actions: actions, children: children, itemAlias: '', keyPath: '' };
  if (node.repeat !== undefined) {
    result = { kind: 'forEach', id: node.id + '-repeat', component: 'Column', props: {}, binding: '', className: '', actions: {},
      children: [result], source: pathExpression(node.repeat.source), itemAlias: node.repeat.itemAlias, keyPath: node.repeat.keyPath === undefined ? 'id' : node.repeat.keyPath };
  }
  if (node.visibleWhen !== undefined) {
    result = { kind: 'if', id: node.id + '-visible', component: 'Column', props: {}, binding: '', className: '', actions: {},
      children: [result], condition: pathExpression(node.visibleWhen.path), itemAlias: '', keyPath: '' };
  }
  return result;
}

function convertAction(action: ArkUiAction): UiAction {
  let result: UiAction = { id: action.id, kind: 'state.set', targetPageId: action.targetPageId, path: '', keyField: '',
    targetField: '', toolName: '', toolArgs: literalText(action.payload), resultBindings: {}, intent: action.label,
    assetSlotId: '', steps: [] };
  if (action.kind === 'navigate') { result.kind = 'navigation.push'; }
  else if (action.kind === 'back') { result.kind = 'navigation.back'; }
  else if (action.kind === 'reset') { result.kind = 'app.reset'; }
  else if (action.kind === 'pickLocalImage') { result.kind = 'asset.pickLocalImage'; result.assetSlotId = action.payload; }
  else if (action.kind === 'invokeAgent') { result.kind = 'agent.invoke'; result.intent = action.label; result.toolArgs = literalText(action.payload); }
  else if (action.kind === 'invokeTool' && action.tool !== undefined) { result.kind = 'tool.invoke'; result.toolName = action.tool.name; result.toolArgs = objectText(action.tool.args); }
  else if (action.kind === 'localMutate' && action.effects !== undefined && action.effects.length > 0) {
    let effect = action.effects[0]; result.path = effect.path;
    if (effect.op === 'toggle') { result.kind = 'state.toggle'; }
    else if (effect.op === 'increment') { result.kind = 'state.increment'; }
    else if (effect.op === 'append') { result.kind = 'list.append'; result.value = literalText(effect.value); }
    else if (effect.op === 'remove') { result.kind = 'list.removeWhere'; }
    else { result.kind = 'state.set'; result.value = literalText(effect.value); }
  }
  return result;
}

function componentFor(type: string): UiIrNode['component'] {
  if (type === 'DynamicSlot') { return 'Card'; }
  return type as UiIrNode['component'];
}
function literalText(value: string): UiExpression { return { kind: 'literal', literalValue: stringValue(value), root: '', segments: [], operator: '', items: [], properties: [], callee: '', args: [] }; }
function literalArray(values: string[]): UiExpression { let items: UiExpression[] = []; for (let i: number = 0; i < values.length; i++) { items.push(literalText(values[i])); } return { kind: 'array', root: '', segments: [], operator: '', items: items, properties: [], callee: '', args: [] }; }
function objectText(values: Record<string, string>): UiExpression { let properties: { key: string; value: UiExpression }[] = []; let keys: string[] = Object.keys(values); for (let i: number = 0; i < keys.length; i++) { properties.push({ key: keys[i], value: literalText(values[keys[i]]) }); } return { kind: 'object', root: '', segments: [], operator: '', items: [], properties: properties, callee: '', args: [] }; }
function pathExpression(path: string): UiExpression { let parts: string[] = path.split('.'); let root: string = parts.length === 0 ? '' : parts[0]; if (parts.length > 0) { parts.splice(0, 1); } return { kind: 'path', root: root, segments: parts, operator: '', items: [], properties: [], callee: '', args: [] }; }
