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
    navigation: count(source, 'navigate(') + count(source, 'back(') + count(source, 'popTo(') + count(source, 'replace(')
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
  return diagnostics;
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
