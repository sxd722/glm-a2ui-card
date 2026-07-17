import { ReactLiteDiagnostic } from './ReactLiteTypes';

export interface ReactLiteSemanticFingerprint {
  pages: number;
  stateFields: number;
  computed: number;
  repeats: number;
  conditions: number;
  actions: number;
  bindings: number;
  inputs: number;
  navigation: number;
  pageIds: string[];
  computedNames: string[];
  repeatSources: string[];
  repeatKeys: string[];
  actionKinds: string[];
  navigationTargets: string[];
  agentIntents: string[];
  bindingPaths: string[];
}

export function fingerprintReactLite(source: string): ReactLiteSemanticFingerprint {
  return {
    pages: count(source, '<Page'),
    stateFields: stateFieldCount(source),
    computed: count(source, 'useComputed('),
    repeats: count(source, '<ForEach') + count(source, '.map('),
    conditions: count(source, '<If') + count(source, '&& <'),
    actions: count(source, 'onPress=') + count(source, 'onSubmit=') + count(source, 'onChange=') +
      count(source, 'onSelect=') + count(source, 'onDismiss=') + count(source, 'onReachEnd=') + count(source, 'onLongPress='),
    bindings: count(source, 'bind='),
    inputs: count(source, '<TextInput') + count(source, '<TextArea') + count(source, '<Toggle') + count(source, '<Checkbox'),
    navigation: count(source, 'navigate(') + count(source, 'back(') + count(source, 'popTo(') + count(source, 'replace('),
    pageIds: values(source, /<Page\s+id="([^"]+)"/g),
    computedNames: values(source, /useComputed\s*\([^)]*\)\s*;?/g),
    repeatSources: values(source, /<ForEach\s+items=\{([^}]+)\}/g),
    repeatKeys: values(source, /keyBy="([^"]+)"/g),
    actionKinds: values(source, /(?:navigate|back|popTo|replace|setState|toggleWhere|updateWhere|removeWhere|appendWithId|invokeAgent)\s*\(/g),
    navigationTargets: values(source, /(?:navigate|popTo|replace)\("([^"]+)"\)/g),
    agentIntents: values(source, /intent:\s*"([^"]+)"/g),
    bindingPaths: values(source, /bind="([^"]+)"/g)
  };
}

export function semanticRegression(before: ReactLiteSemanticFingerprint, after: ReactLiteSemanticFingerprint): ReactLiteDiagnostic[] {
  let diagnostics: ReactLiteDiagnostic[] = [];
  compare('pages', before.pages, after.pages, diagnostics);
  compare('state fields', before.stateFields, after.stateFields, diagnostics);
  compare('computed', before.computed, after.computed, diagnostics);
  compare('repeat/map', before.repeats, after.repeats, diagnostics);
  compare('conditions', before.conditions, after.conditions, diagnostics);
  compare('actions', before.actions, after.actions, diagnostics);
  compare('bindings', before.bindings, after.bindings, diagnostics);
  compare('inputs', before.inputs, after.inputs, diagnostics);
  compare('navigation', before.navigation, after.navigation, diagnostics);
  compareValues('page IDs', before.pageIds, after.pageIds, diagnostics);
  compareValues('computed names', before.computedNames, after.computedNames, diagnostics);
  compareValues('repeat sources', before.repeatSources, after.repeatSources, diagnostics);
  compareValues('repeat keys', before.repeatKeys, after.repeatKeys, diagnostics);
  compareValues('action kinds', before.actionKinds, after.actionKinds, diagnostics);
  compareValues('navigation targets', before.navigationTargets, after.navigationTargets, diagnostics);
  compareValues('agent intents', before.agentIntents, after.agentIntents, diagnostics);
  compareValues('bindings', before.bindingPaths, after.bindingPaths, diagnostics);
  return diagnostics;
}

function compareValues(name: string, before: string[], after: string[], diagnostics: ReactLiteDiagnostic[]): void {
  for (let i: number = 0; i < before.length; i++) {
    if (after.indexOf(before[i]) < 0) {
      diagnostics.push({ code: 'RL_REPAIR_SEMANTIC_REGRESSION', severity: 'error',
        message: 'Repair 删除了 ' + name + '：' + before[i], line: 0, column: 0, length: 1,
        suggestion: '保留原有语义，只修复诊断项。' });
    }
  }
}

function compare(name: string, before: number, after: number, diagnostics: ReactLiteDiagnostic[]): void {
  if (before > 0 && after < before) {
    diagnostics.push({ code: 'RL_REPAIR_SEMANTIC_REGRESSION', severity: 'error',
      message: 'Repair 删除了 ' + name + '：' + before.toString() + ' -> ' + after.toString(), line: 0, column: 0, length: 1,
      suggestion: '保留原有页面、列表、computed、绑定和动作，只修复诊断项。' });
  }
}

function stateFieldCount(source: string): number {
  let start: number = source.indexOf('useState(');
  if (start < 0) { return 0; }
  let open: number = source.indexOf('{', start);
  let close: number = source.indexOf('});', open);
  if (open < 0 || close < 0) { return 0; }
  let body: string = source.substring(open + 1, close);
  let matches = body.match(/[A-Za-z_$][A-Za-z0-9_$-]*\s*:/g);
  return matches === null ? 0 : matches.length;
}

function count(source: string, token: string): number {
  let result: number = 0; let offset: number = 0;
  while (offset < source.length) {
    let index: number = source.indexOf(token, offset);
    if (index < 0) { break; }
    result++; offset = index + token.length;
  }
  return result;
}

function values(source: string, pattern: RegExp): string[] {
  let result: string[] = [];
  let matches: RegExpMatchArray | null = source.match(pattern);
  if (matches === null) { return result; }
  for (let i: number = 0; i < matches.length; i++) {
    let value: string = matches[i];
    let open: number = value.indexOf('"');
    let close: number = value.lastIndexOf('"');
    if (open >= 0 && close > open) { result.push(value.substring(open + 1, close)); }
    else { result.push(value); }
  }
  return result;
}
