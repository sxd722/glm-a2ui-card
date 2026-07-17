import { SemanticComponentCategory, SemanticComponentMaturity, SemanticDensity, SemanticTone, SemanticValueType } from '../foundation/SemanticEnums';

export class SemanticPropertyDescriptor {
  name: string = '';
  valueType: SemanticValueType = SemanticValueType.STRING;
  required: boolean = false;
  modelName: string = '';
  enumValues: string[] = [];
}

export class SemanticComponentDescriptor {
  type: string = '';
  arktsName: string = '';
  version: number = 1;
  category: SemanticComponentCategory = SemanticComponentCategory.PRESENTATION;
  modelName: string = '';
  variants: string[] = ['standard'];
  tones: SemanticTone[] = [SemanticTone.NEUTRAL, SemanticTone.PRIMARY, SemanticTone.INFO, SemanticTone.SUCCESS, SemanticTone.WARNING, SemanticTone.DANGER];
  densities: SemanticDensity[] = [SemanticDensity.COMPACT, SemanticDensity.COMFORTABLE, SemanticDensity.SPACIOUS];
  events: string[] = [];
  slots: string[] = [];
  properties: SemanticPropertyDescriptor[] = [];
  minApi: number = 12;
  maturity: SemanticComponentMaturity = SemanticComponentMaturity.BETA;
}

export function semanticProperty(name: string, valueType: SemanticValueType, required: boolean = false,
  modelName: string = '', enumValues: string[] = []): SemanticPropertyDescriptor {
  let property: SemanticPropertyDescriptor = new SemanticPropertyDescriptor();
  property.name = name;
  property.valueType = valueType;
  property.required = required;
  property.modelName = modelName;
  property.enumValues = enumValues;
  return property;
}
