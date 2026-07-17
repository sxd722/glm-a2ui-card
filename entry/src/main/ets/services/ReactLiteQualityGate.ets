import { UiAction, UiIrNode, UiIrSpec } from './UiIrTypes';

export function runReactLiteQualityGate(spec: UiIrSpec): string[] {
  let diagnostics: string[] = [];
  for (let i: number = 0; i < spec.pages.length; i++) {
    inspectNode(spec.pages[i].root, diagnostics);
    let overlays: UiIrNode[] = spec.pages[i].overlays === undefined ? [] : spec.pages[i].overlays as UiIrNode[];
    for (let j: number = 0; j < overlays.length; j++) { inspectNode(overlays[j], diagnostics); }
  }
  return diagnostics;
}

function inspectNode(node: UiIrNode, diagnostics: string[]): void {
  let interactive: boolean = ['Button', 'IconButton', 'TextInput', 'TextArea', 'Toggle', 'Checkbox',
    'ChoiceChips', 'SegmentedControl', 'Tabs'].indexOf(node.component) >= 0;
  let actionCount: number = Object.keys(node.actions).length;
  if (interactive && node.binding.length === 0 && actionCount === 0) {
    diagnostics.push('RL_QUALITY_INTERACTIVE_BEHAVIOR_MISSING:' + node.id);
  }
  if (node.kind === 'forEach' && node.keyPath.length === 0) {
    diagnostics.push('RL_QUALITY_REPEAT_KEY_MISSING:' + node.id);
  }
  let actionKeys: string[] = Object.keys(node.actions);
  for (let i: number = 0; i < actionKeys.length; i++) { inspectAction(node.actions[actionKeys[i]], diagnostics); }
  for (let i: number = 0; i < node.children.length; i++) { inspectNode(node.children[i], diagnostics); }
}

function inspectAction(action: UiAction, diagnostics: string[]): void {
  if (action.kind === 'action.sequence') {
    if (action.steps.length === 0) { diagnostics.push('RL_QUALITY_EMPTY_SEQUENCE:' + action.id); }
    for (let i: number = 0; i < action.steps.length; i++) { inspectAction(action.steps[i], diagnostics); }
  }
  if (action.kind === 'agent.invoke') {
    if (action.intent.length === 0) { diagnostics.push('RL_QUALITY_AGENT_INTENT_MISSING:' + action.id); }
    if (action.toolArgs.kind !== 'object') { diagnostics.push('RL_QUALITY_AGENT_ARGS_NOT_OBJECT:' + action.id); }
    if (action.statusPath === undefined && Object.keys(action.resultBindings).length === 0) {
      diagnostics.push('RL_QUALITY_AGENT_OUTPUT_NOT_CONSUMED:' + action.id);
    }
    inspectSteps(action.successSteps, diagnostics);
    inspectSteps(action.errorSteps, diagnostics);
  }
  if (action.steps.length > 0 && action.kind !== 'action.sequence') {
    for (let i: number = 0; i < action.steps.length; i++) { inspectAction(action.steps[i], diagnostics); }
  }
}

function inspectSteps(steps: UiAction[] | undefined, diagnostics: string[]): void {
  if (steps === undefined) { return; }
  for (let i: number = 0; i < steps.length; i++) { inspectAction(steps[i], diagnostics); }
}
