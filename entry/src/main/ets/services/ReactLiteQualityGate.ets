import { UiAction, UiIrNode, UiIrSpec } from './UiIrTypes';

const MAX_QUALITY_NODES: number = 320;
const MAX_QUALITY_ACTIONS: number = 640;
const MAX_QUALITY_DEPTH: number = 64;

export function runReactLiteQualityGate(spec: UiIrSpec): string[] {
  let diagnostics: string[] = [];
  let budget: QualityBudget = { nodes: 0, actions: 0 };
  for (let i: number = 0; i < spec.pages.length; i++) {
    inspectNode(spec.pages[i].root, diagnostics, 0, budget);
    let overlays: UiIrNode[] = spec.pages[i].overlays === undefined ? [] : spec.pages[i].overlays as UiIrNode[];
    for (let j: number = 0; j < overlays.length; j++) { inspectNode(overlays[j], diagnostics, 0, budget); }
  }
  return diagnostics;
}

interface QualityBudget { nodes: number; actions: number; }

function inspectNode(node: UiIrNode, diagnostics: string[], depth: number, budget: QualityBudget): void {
  if (budget.nodes >= MAX_QUALITY_NODES) { addOnce(diagnostics, 'RL_QUALITY_NODE_LIMIT'); return; }
  if (depth > MAX_QUALITY_DEPTH) { addOnce(diagnostics, 'RL_QUALITY_DEPTH_LIMIT'); return; }
  budget.nodes++;
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
  for (let i: number = 0; i < actionKeys.length; i++) { inspectAction(node.actions[actionKeys[i]], diagnostics, 0, budget); }
  for (let i: number = 0; i < node.children.length; i++) { inspectNode(node.children[i], diagnostics, depth + 1, budget); }
}

function inspectAction(action: UiAction, diagnostics: string[], depth: number, budget: QualityBudget): void {
  if (budget.actions >= MAX_QUALITY_ACTIONS) { addOnce(diagnostics, 'RL_QUALITY_ACTION_LIMIT'); return; }
  if (depth > MAX_QUALITY_DEPTH) { addOnce(diagnostics, 'RL_QUALITY_ACTION_DEPTH_LIMIT'); return; }
  budget.actions++;
  if (action.kind === 'action.sequence') {
    if (action.steps.length === 0) { diagnostics.push('RL_QUALITY_EMPTY_SEQUENCE:' + action.id); }
    for (let i: number = 0; i < action.steps.length; i++) { inspectAction(action.steps[i], diagnostics, depth + 1, budget); }
  }
  if (action.kind === 'agent.invoke') {
    if (action.intent.length === 0) { diagnostics.push('RL_QUALITY_AGENT_INTENT_MISSING:' + action.id); }
    if (action.toolArgs.kind !== 'object') { diagnostics.push('RL_QUALITY_AGENT_ARGS_NOT_OBJECT:' + action.id); }
    if (action.statusPath === undefined && Object.keys(action.resultBindings).length === 0) {
      diagnostics.push('RL_QUALITY_AGENT_OUTPUT_NOT_CONSUMED:' + action.id);
    }
    inspectSteps(action.successSteps, diagnostics, depth + 1, budget);
    inspectSteps(action.errorSteps, diagnostics, depth + 1, budget);
  }
  if (action.steps.length > 0 && action.kind !== 'action.sequence') {
    for (let i: number = 0; i < action.steps.length; i++) { inspectAction(action.steps[i], diagnostics, depth + 1, budget); }
  }
}

function inspectSteps(steps: UiAction[] | undefined, diagnostics: string[], depth: number, budget: QualityBudget): void {
  if (steps === undefined) { return; }
  for (let i: number = 0; i < steps.length; i++) { inspectAction(steps[i], diagnostics, depth, budget); }
}

function addOnce(diagnostics: string[], code: string): void {
  if (diagnostics.indexOf(code) < 0) { diagnostics.push(code); }
}
