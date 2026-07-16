import { UiValue } from './UiIrTypes';

export function nullValue(): UiValue {
  return { kind: 'null', stringValue: '', numberValue: 0, booleanValue: false, arrayValue: [], objectValue: {} };
}

export function stringValue(value: string): UiValue {
  return { kind: 'string', stringValue: value, numberValue: 0, booleanValue: value.length > 0,
    arrayValue: [], objectValue: {} };
}

export function numberValue(value: number): UiValue {
  return { kind: 'number', stringValue: value.toString(), numberValue: value, booleanValue: value !== 0,
    arrayValue: [], objectValue: {} };
}

export function booleanValue(value: boolean): UiValue {
  return { kind: 'boolean', stringValue: value ? 'true' : 'false', numberValue: value ? 1 : 0,
    booleanValue: value, arrayValue: [], objectValue: {} };
}

export function arrayValue(value: UiValue[]): UiValue {
  return { kind: 'array', stringValue: '', numberValue: 0, booleanValue: value.length > 0,
    arrayValue: cloneUiValues(value), objectValue: {} };
}

export function objectValue(value: Record<string, UiValue>): UiValue {
  return { kind: 'object', stringValue: '', numberValue: 0, booleanValue: Object.keys(value).length > 0,
    arrayValue: [], objectValue: cloneUiRecord(value) };
}

export function uiValueFromObject(raw: Object): UiValue {
  if (raw === null || raw === undefined) { return nullValue(); }
  if (typeof raw === 'string') { return stringValue(raw as string); }
  if (typeof raw === 'number') { return numberValue(raw as number); }
  if (typeof raw === 'boolean') { return booleanValue(raw as boolean); }
  if (Array.isArray(raw)) {
    let values: UiValue[] = [];
    let source: Object[] = raw as Object[];
    for (let i: number = 0; i < source.length; i++) { values.push(uiValueFromObject(source[i])); }
    return arrayValue(values);
  }
  let result: Record<string, UiValue> = {};
  let record: Record<string, Object> = raw as Record<string, Object>;
  let keys: string[] = Object.keys(record);
  for (let i: number = 0; i < keys.length; i++) {
    if (!isSafeKey(keys[i])) { continue; }
    result[keys[i]] = uiValueFromObject(record[keys[i]]);
  }
  return objectValue(result);
}

export function uiValueToDisplayString(value: UiValue | undefined): string {
  if (value === undefined || value.kind === 'null') { return ''; }
  if (value.kind === 'string' || value.kind === 'number' || value.kind === 'boolean') { return value.stringValue; }
  return JSON.stringify(value);
}

// Convert the internal tagged representation into the ordinary JSON shape
// expected by the Agent wire contract. Keep this boundary explicit so tagged
// UiValue implementation fields never leak into a network payload.
export function uiValueToPlainObject(value: UiValue): Object {
  if (value.kind === 'null') { return JSON.parse('null') as Object; }
  if (value.kind === 'string') { return value.stringValue; }
  if (value.kind === 'number') { return value.numberValue; }
  if (value.kind === 'boolean') { return value.booleanValue; }
  if (value.kind === 'array') {
    let result: Object[] = [];
    for (let i: number = 0; i < value.arrayValue.length; i++) {
      result.push(uiValueToPlainObject(value.arrayValue[i]));
    }
    return result;
  }
  let record: Record<string, Object> = {};
  let keys: string[] = Object.keys(value.objectValue);
  for (let i: number = 0; i < keys.length; i++) {
    if (isSafeKey(keys[i])) { record[keys[i]] = uiValueToPlainObject(value.objectValue[keys[i]]); }
  }
  return record;
}

export function uiRecordToPlainObject(value: Record<string, UiValue>): Record<string, Object> {
  let result: Record<string, Object> = {};
  let keys: string[] = Object.keys(value);
  for (let i: number = 0; i < keys.length; i++) {
    if (isSafeKey(keys[i])) { result[keys[i]] = uiValueToPlainObject(value[keys[i]]); }
  }
  return result;
}

export function uiValueToBoolean(value: UiValue | undefined): boolean {
  if (value === undefined || value.kind === 'null') { return false; }
  if (value.kind === 'boolean') { return value.booleanValue; }
  if (value.kind === 'number') { return value.numberValue !== 0; }
  if (value.kind === 'string') { return value.stringValue.length > 0 && value.stringValue !== 'false'; }
  return value.arrayValue.length > 0 || Object.keys(value.objectValue).length > 0;
}

export function uiValueToNumber(value: UiValue | undefined): number {
  if (value === undefined || value.kind === 'null') { return 0; }
  if (value.kind === 'number') { return value.numberValue; }
  let parsed: number = Number(value.stringValue);
  return isNaN(parsed) ? 0 : parsed;
}

export function uiValueEquals(left: UiValue | undefined, right: UiValue | undefined): boolean {
  if (left === undefined || right === undefined) { return left === right; }
  return JSON.stringify(left) === JSON.stringify(right);
}

export function cloneUiValue(value: UiValue): UiValue {
  return JSON.parse(JSON.stringify(value)) as UiValue;
}

export function cloneUiRecord(value: Record<string, UiValue>): Record<string, UiValue> {
  return JSON.parse(JSON.stringify(value)) as Record<string, UiValue>;
}

export function uiRecordFromJson(raw: string): Record<string, UiValue> {
  try {
    let parsed: Object = JSON.parse(raw) as Object;
    let value: UiValue = uiValueFromObject(parsed);
    return value.kind === 'object' ? value.objectValue : {};
  } catch (e) {
    return {};
  }
}

function cloneUiValues(values: UiValue[]): UiValue[] {
  return JSON.parse(JSON.stringify(values)) as UiValue[];
}

function isSafeKey(value: string): boolean {
  return value !== '__proto__' && value !== 'constructor' && value !== 'prototype';
}
