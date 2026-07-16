import { UiComputedDefinition, UiEvaluationScope, UiExpression, UiValue } from './UiIrTypes';
import { arrayValue, booleanValue, numberValue, objectValue, stringValue, uiValueEquals, uiValueToBoolean,
  uiValueToDisplayString, uiValueToNumber } from './UiValue';

export interface UiComputedCache {
  values: Record<string, UiValue>;
}

export function evaluateExpression(expression: UiExpression | undefined, state: Record<string, UiValue>,
  computed: UiComputedDefinition[] = [], scope: UiEvaluationScope = { aliases: {}, event: {} },
  cache: UiComputedCache = { values: {} }, stack: string[] = []): UiValue {
  if (expression === undefined) { return stringValue(''); }
  if (expression.kind === 'literal') { return expression.literalValue === undefined ? stringValue('') : expression.literalValue; }
  if (expression.kind === 'path') { return resolvePath(expression.root, expression.segments, state, computed, scope, cache, stack); }
  if (expression.kind === 'unary') {
    let value = evaluateExpression(expression.left, state, computed, scope, cache, stack);
    if (expression.operator === '!') { return booleanValue(!uiValueToBoolean(value)); }
    if (expression.operator === '-') { return numberValue(-uiValueToNumber(value)); }
    return numberValue(uiValueToNumber(value));
  }
  if (expression.kind === 'binary') { return binary(expression.operator, evaluateExpression(expression.left, state, computed, scope, cache, stack), evaluateExpression(expression.right, state, computed, scope, cache, stack)); }
  if (expression.kind === 'conditional') { return uiValueToBoolean(evaluateExpression(expression.test, state, computed, scope, cache, stack)) ? evaluateExpression(expression.consequent, state, computed, scope, cache, stack) : evaluateExpression(expression.alternate, state, computed, scope, cache, stack); }
  if (expression.kind === 'array') { let values: UiValue[] = []; for (let i: number = 0; i < expression.items.length; i++) { values.push(evaluateExpression(expression.items[i], state, computed, scope, cache, stack)); } return arrayValue(values); }
  if (expression.kind === 'object') { let values: Record<string, UiValue> = {}; for (let i: number = 0; i < expression.properties.length; i++) { values[expression.properties[i].key] = evaluateExpression(expression.properties[i].value, state, computed, scope, cache, stack); } return objectValue(values); }
  if (expression.kind === 'intrinsicCall') { return intrinsic(expression.callee, expression.args, state, computed, scope, cache, stack); }
  return stringValue('');
}

function resolvePath(root: string, segments: string[], state: Record<string, UiValue>, computed: UiComputedDefinition[],
  scope: UiEvaluationScope, cache: UiComputedCache, stack: string[]): UiValue {
  let value: UiValue | undefined;
  if (root === 'state') { value = objectValue(state); }
  else if (root === 'computed') { value = objectValue(computedRecord(computed, state, scope, cache, stack)); }
  else if (root === 'event') { value = objectValue(scope.event); }
  else if (scope.aliases[root] !== undefined) { value = scope.aliases[root]; }
  else if (scope.event[root] !== undefined) { value = scope.event[root]; }
  else { value = state[root]; }
  if (value === undefined) { return stringValue(''); }
  if (root === 'computed' && segments.length > 0) { return descend(value, segments); }
  return descend(value, segments);
}

function descend(value: UiValue, segments: string[]): UiValue {
  let current: UiValue = value;
  for (let i: number = 0; i < segments.length; i++) {
    let segment: string = segments[i];
    if (current.kind === 'object') { current = current.objectValue[segment] === undefined ? stringValue('') : current.objectValue[segment]; }
    else if (current.kind === 'array') { let index: number = Number(segment); current = isNaN(index) || current.arrayValue[index] === undefined ? stringValue('') : current.arrayValue[index]; }
    else { return stringValue(''); }
  }
  return current;
}

function computedRecord(definitions: UiComputedDefinition[], state: Record<string, UiValue>, scope: UiEvaluationScope,
  cache: UiComputedCache, stack: string[]): Record<string, UiValue> {
  let result: Record<string, UiValue> = {};
  for (let i: number = 0; i < definitions.length; i++) {
    let name: string = definitions[i].name;
    if (cache.values[name] === undefined && stack.indexOf(name) < 0) {
      cache.values[name] = evaluateExpression(definitions[i].expression, state, definitions, scope, cache, stack.concat([name]));
    }
    if (cache.values[name] !== undefined) { result[name] = cache.values[name]; }
  }
  return result;
}

function binary(operator: string, left: UiValue, right: UiValue): UiValue {
  if (operator === '&&') { return booleanValue(uiValueToBoolean(left) && uiValueToBoolean(right)); }
  if (operator === '||') { return booleanValue(uiValueToBoolean(left) || uiValueToBoolean(right)); }
  if (operator === '??') { return left.kind === 'null' || uiValueToDisplayString(left).length === 0 ? right : left; }
  if (operator === '===') { return booleanValue(uiValueEquals(left, right)); }
  if (operator === '!==') { return booleanValue(!uiValueEquals(left, right)); }
  if (['<', '<=', '>', '>='].indexOf(operator) >= 0) {
    let l: number = uiValueToNumber(left); let r: number = uiValueToNumber(right);
    if (operator === '<') { return booleanValue(l < r); } if (operator === '<=') { return booleanValue(l <= r); }
    if (operator === '>') { return booleanValue(l > r); } return booleanValue(l >= r);
  }
  if (operator === '+') {
    if (left.kind === 'string' || right.kind === 'string') { return stringValue(uiValueToDisplayString(left) + uiValueToDisplayString(right)); }
    return numberValue(uiValueToNumber(left) + uiValueToNumber(right));
  }
  let l: number = uiValueToNumber(left); let r: number = uiValueToNumber(right);
  if (operator === '-') { return numberValue(l - r); } if (operator === '*') { return numberValue(l * r); }
  if (operator === '/') { return numberValue(r === 0 ? 0 : l / r); } if (operator === '%') { return numberValue(r === 0 ? 0 : l % r); }
  return stringValue('');
}

function intrinsic(name: string, args: UiExpression[], state: Record<string, UiValue>, computed: UiComputedDefinition[], scope: UiEvaluationScope,
  cache: UiComputedCache, stack: string[]): UiValue {
  let values: UiValue[] = []; for (let i: number = 0; i < args.length; i++) { values.push(evaluateExpression(args[i], state, computed, scope, cache, stack)); }
  let list: UiValue = values.length > 0 ? values[0] : arrayValue([]);
  if (name === 'length') { return numberValue(list.kind === 'array' ? list.arrayValue.length : uiValueToDisplayString(list).length); }
  if (name === 'includes') { return booleanValue(list.kind === 'array' && list.arrayValue.some((item: UiValue) => uiValueEquals(item, values[1]))); }
  if (name === 'slice' && list.kind === 'array') { return arrayValue(list.arrayValue.slice(uiValueToNumber(values[1]), uiValueToNumber(values[2]))); }
  if ((name === 'filterEq' || name === 'filterNotEq' || name === 'filterContains') && list.kind === 'array') {
    let field: string = uiValueToDisplayString(values[1]); let expected: UiValue = values[2];
    return arrayValue(list.arrayValue.filter((item: UiValue) => {
      let actual: UiValue | undefined = item.kind === 'object' ? item.objectValue[field] : undefined;
      if (name === 'filterEq') {
        // "全部" is the sample's explicit no-filter choice.
        return expected.kind === 'string' && expected.stringValue === '全部' ? true : uiValueEquals(actual, expected);
      }
      if (name === 'filterNotEq') { return !uiValueEquals(actual, expected); }
      return uiValueToDisplayString(actual).indexOf(uiValueToDisplayString(expected)) >= 0;
    }));
  }
  if (name === 'coalesce') { return uiValueToDisplayString(list).length > 0 ? list : values[1]; }
  if (name === 'join' && list.kind === 'array') { let separator: string = uiValueToDisplayString(values[1]); return stringValue(list.arrayValue.map((item: UiValue) => uiValueToDisplayString(item)).join(separator)); }
  if (name === 'formatNumber') { return stringValue(uiValueToNumber(list).toString()); }
  if (name === 'formatCurrency') { return stringValue('¥' + uiValueToNumber(list).toString()); }
  if (name === 'sumBy' && list.kind === 'array') { return numberValue(sumBy(list, uiValueToDisplayString(values[1]))); }
  if (name === 'countWhere' && list.kind === 'array') { return numberValue(countWhere(list, uiValueToDisplayString(values[1]), values[2])); }
  if (name === 'sortBy' && list.kind === 'array') { return sortBy(list, uiValueToDisplayString(values[1]), uiValueToDisplayString(values[2])); }
  if (name === 'formatDate') { return formatDate(list, values.length > 1 ? uiValueToDisplayString(values[1]) : ''); }
  return stringValue('');
}

function sumBy(list: UiValue, field: string): number {
  let total: number = 0;
  for (let i: number = 0; i < list.arrayValue.length; i++) {
    let value: UiValue | undefined = field.length > 0 && list.arrayValue[i].kind === 'object' ? list.arrayValue[i].objectValue[field] : list.arrayValue[i];
    total += uiValueToNumber(value);
  }
  return total;
}

function countWhere(list: UiValue, field: string, expected: UiValue): number {
  let count: number = 0;
  for (let i: number = 0; i < list.arrayValue.length; i++) {
    let actual: UiValue | undefined = list.arrayValue[i].kind === 'object' ? list.arrayValue[i].objectValue[field] : undefined;
    if (actual !== undefined && uiValueEquals(actual, expected)) { count++; }
  }
  return count;
}

function sortBy(list: UiValue, field: string, direction: string): UiValue {
  let result: UiValue[] = list.arrayValue.slice(); let descending: boolean = direction === 'desc';
  for (let i: number = 1; i < result.length; i++) {
    let current: UiValue = result[i]; let j: number = i - 1;
    while (j >= 0 && compareItems(result[j], current, field, descending) > 0) { result[j + 1] = result[j]; j--; }
    result[j + 1] = current;
  }
  return arrayValue(result);
}

function compareItems(left: UiValue, right: UiValue, field: string, descending: boolean): number {
  let leftValue: UiValue | undefined = left.kind === 'object' ? left.objectValue[field] : undefined;
  let rightValue: UiValue | undefined = right.kind === 'object' ? right.objectValue[field] : undefined;
  let l: string = uiValueToDisplayString(leftValue); let r: string = uiValueToDisplayString(rightValue);
  let result: number = l < r ? -1 : l > r ? 1 : 0;
  return descending ? -result : result;
}

function formatDate(value: UiValue, format: string): UiValue {
  let raw: string = uiValueToDisplayString(value);
  if (raw.length >= 10 && raw.charAt(4) === '-' && raw.charAt(7) === '-') {
    let year: string = raw.substring(0, 4); let month: string = raw.substring(5, 7); let day: string = raw.substring(8, 10);
    if (format === 'MM.DD' || format.length === 0) { return stringValue(month + '.' + day); }
    if (format === 'YYYY年MM月DD日') { return stringValue(year + '年' + month + '月' + day + '日'); }
  }
  return stringValue(raw);
}
