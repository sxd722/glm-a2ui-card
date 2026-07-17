export class SemanticEventPayload {
  actionId: string = '';
  itemId: string = '';
  index: number = -1;
  textValue: string = '';
  numberValue: number = 0;
  booleanValue: boolean = false;
  textValues: string[] = [];
}

export class SemanticUiEvent {
  sourceId: string = '';
  name: string = '';
  payload: SemanticEventPayload = new SemanticEventPayload();
}

export function createSemanticEvent(sourceId: string, name: string, payload?: SemanticEventPayload): SemanticUiEvent {
  let event: SemanticUiEvent = new SemanticUiEvent();
  event.sourceId = sourceId;
  event.name = name;
  event.payload = payload === undefined ? new SemanticEventPayload() : payload;
  return event;
}

export function actionPayload(actionId: string): SemanticEventPayload {
  let payload: SemanticEventPayload = new SemanticEventPayload();
  payload.actionId = actionId;
  return payload;
}

export function itemPayload(itemId: string, index: number): SemanticEventPayload {
  let payload: SemanticEventPayload = new SemanticEventPayload();
  payload.itemId = itemId;
  payload.index = index;
  return payload;
}

export function textPayload(value: string): SemanticEventPayload {
  let payload: SemanticEventPayload = new SemanticEventPayload();
  payload.textValue = value;
  return payload;
}

export function booleanPayload(value: boolean): SemanticEventPayload {
  let payload: SemanticEventPayload = new SemanticEventPayload();
  payload.booleanValue = value;
  return payload;
}

export function itemBooleanPayload(itemId: string, value: boolean): SemanticEventPayload {
  let payload: SemanticEventPayload = booleanPayload(value);
  payload.actionId = itemId;
  payload.itemId = itemId;
  return payload;
}

export function numberPayload(value: number): SemanticEventPayload {
  let payload: SemanticEventPayload = new SemanticEventPayload();
  payload.numberValue = value;
  return payload;
}
