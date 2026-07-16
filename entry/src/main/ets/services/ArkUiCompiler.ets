import {
  ArkUiNode,
  ArkUiPage,
  ArkUiSpec,
  ArkUiTheme,
  CompiledArkUiNode,
  CompiledArkUiPage,
  CompiledArkUiSpec,
  ResolvedArkUiStyle
} from './ArkUiTypes';
import { isSupportedUtilityToken } from './UiStyleRegistry';

const DEFAULT_COLORS: Record<string, string> = createDefaultColors();

const NODE_LIMIT: number = 240;
const DEPTH_LIMIT: number = 12;

class CompileCounter {
  count: number = 0;
}

export function compileArkUiSpec(spec: ArkUiSpec): CompiledArkUiSpec {
  let pages: CompiledArkUiPage[] = [];
  let counter: CompileCounter = new CompileCounter();
  for (let i: number = 0; i < spec.pages.length; i++) {
    pages.push(compilePage(spec.pages[i], spec.theme, counter));
  }
  return {
    schemaVersion: spec.schemaVersion,
    appId: spec.appId,
    title: spec.title,
    subtitle: spec.subtitle,
    initialPageId: spec.initialPageId,
    theme: spec.theme,
    pages: pages
  };
}

export function resolveTailwindStyle(className: string, theme: ArkUiTheme): ResolvedArkUiStyle {
  let style: ResolvedArkUiStyle = defaultStyle();
  let tokens: string[] = className.trim().split(/\s+/);
  for (let i: number = 0; i < tokens.length; i++) {
    applyToken(style, tokens[i], theme);
  }
  return style;
}

function compilePage(page: ArkUiPage, theme: ArkUiTheme, counter: CompileCounter): CompiledArkUiPage {
  return {
    id: page.id,
    title: page.title,
    scroll: page.scroll,
    root: compileNode(page.root, theme, counter, 0)
  };
}

function compileNode(node: ArkUiNode, theme: ArkUiTheme, counter: CompileCounter, depth: number): CompiledArkUiNode {
  counter.count++;
  let children: CompiledArkUiNode[] = [];
  if (depth < DEPTH_LIMIT && counter.count < NODE_LIMIT) {
    for (let i: number = 0; i < node.children.length; i++) {
      children.push(compileNode(node.children[i], theme, counter, depth + 1));
    }
  }
  return {
    id: node.id,
    type: node.type,
    props: node.props,
    binding: node.binding,
    repeat: node.repeat,
    actions: node.actions,
    children: children,
    visibleWhen: node.visibleWhen,
    enabledWhen: node.enabledWhen,
    selectedWhen: node.selectedWhen,
    style: resolveTailwindStyle(node.className, theme),
    kind: node.type,
    title: value(node.props, 'title'),
    text: value(node.props, 'text'),
    assetId: value(node.props, 'assetId'),
    items: [],
    tone: ''
  };
}

function value(props: Record<string, string>, key: string): string {
  let result: string | undefined = props[key];
  return result === undefined ? '' : result;
}

function defaultStyle(): ResolvedArkUiStyle {
  return {
    paddingTop: 0, paddingRight: 0, paddingBottom: 0, paddingLeft: 0,
    marginTop: 0, marginRight: 0, marginBottom: 0, marginLeft: 0,
    gap: 0,
    backgroundColor: '#00000000',
    foregroundColor: DEFAULT_COLORS['ink'],
    borderColor: '#00000000',
    borderWidth: 0,
    borderRadius: 0,
    fontSize: 14,
    fontWeight: 'normal',
    textAlign: 'start',
    opacity: 1,
    shadowRadius: 0,
    shadowColor: '#00000000',
    shadowOffsetY: 0,
    widthFull: false,
    heightFull: false,
    height: 0,
    layoutWeight: 0,
    align: 'start',
    justify: 'start',
    objectFit: 'cover',
    blurStyle: 'none',
    gradientFrom: '#00000000',
    gradientTo: '#00000000',
    gradientAngle: 135
  };
}

function applyToken(style: ResolvedArkUiStyle, token: string, theme: ArkUiTheme): void {
  if (!isSupportedUtilityToken(token)) { return; }
  if (token.length === 0 || token === 'flex' || token === 'flex-col' || token === 'flex-row' ||
    token === 'relative' || token === 'overflow-hidden') {
    return;
  }
  if (token === 'w-full') { style.widthFull = true; return; }
  if (token === 'h-full') { style.heightFull = true; return; }
  if (token === 'flex-1') { style.layoutWeight = 1; return; }
  if (token === 'font-medium') { style.fontWeight = 'medium'; return; }
  if (token === 'font-semibold') { style.fontWeight = 'semibold'; return; }
  if (token === 'font-bold') { style.fontWeight = 'bold'; return; }
  if (token === 'text-center') { style.textAlign = 'center'; return; }
  if (token === 'text-right') { style.textAlign = 'end'; return; }
  if (token === 'items-center') { style.align = 'center'; return; }
  if (token === 'items-end') { style.align = 'end'; return; }
  if (token === 'justify-center') { style.justify = 'center'; return; }
  if (token === 'justify-between') { style.justify = 'between'; return; }
  if (token === 'justify-end') { style.justify = 'end'; return; }
  if (token === 'object-contain') { style.objectFit = 'contain'; return; }
  if (token === 'object-cover') { style.objectFit = 'cover'; return; }
  if (token === 'backdrop-blur-sm') { style.blurStyle = 'thin'; return; }
  if (token === 'backdrop-blur-md') { style.blurStyle = 'regular'; return; }
  if (token === 'shadow-sm') { setShadow(style, 6, 2); return; }
  if (token === 'shadow-md') { setShadow(style, 12, 5); return; }
  if (token === 'shadow-lg') { setShadow(style, 20, 8); return; }
  if (token.indexOf('p-') === 0) { setPadding(style, spacing(token.substring(2))); return; }
  if (token.indexOf('px-') === 0) { let v: number = spacing(token.substring(3)); style.paddingLeft = v; style.paddingRight = v; return; }
  if (token.indexOf('py-') === 0) { let v: number = spacing(token.substring(3)); style.paddingTop = v; style.paddingBottom = v; return; }
  if (token.indexOf('pt-') === 0) { style.paddingTop = spacing(token.substring(3)); return; }
  if (token.indexOf('pr-') === 0) { style.paddingRight = spacing(token.substring(3)); return; }
  if (token.indexOf('pb-') === 0) { style.paddingBottom = spacing(token.substring(3)); return; }
  if (token.indexOf('pl-') === 0) { style.paddingLeft = spacing(token.substring(3)); return; }
  if (token.indexOf('m-') === 0) { setMargin(style, spacing(token.substring(2))); return; }
  if (token.indexOf('mx-') === 0) { let v: number = spacing(token.substring(3)); style.marginLeft = v; style.marginRight = v; return; }
  if (token.indexOf('my-') === 0) { let v: number = spacing(token.substring(3)); style.marginTop = v; style.marginBottom = v; return; }
  if (token.indexOf('mt-') === 0) { style.marginTop = spacing(token.substring(3)); return; }
  if (token.indexOf('mr-') === 0) { style.marginRight = spacing(token.substring(3)); return; }
  if (token.indexOf('mb-') === 0) { style.marginBottom = spacing(token.substring(3)); return; }
  if (token.indexOf('ml-') === 0) { style.marginLeft = spacing(token.substring(3)); return; }
  if (token.indexOf('gap-') === 0) { style.gap = spacing(token.substring(4)); return; }
  if (token.indexOf('h-') === 0) { style.height = spacing(token.substring(2)); return; }
  if (token.indexOf('rounded') === 0) { style.borderRadius = radius(token); return; }
  if (token.indexOf('border-') === 0) { style.borderWidth = 1; style.borderColor = color(token.substring(7), theme); return; }
  if (token === 'border') { style.borderWidth = 1; style.borderColor = color('border', theme); return; }
  if (token.indexOf('bg-') === 0) { style.backgroundColor = color(token.substring(3), theme); return; }
  if (token.indexOf('from-') === 0) { style.gradientFrom = color(token.substring(5), theme); return; }
  if (token.indexOf('to-') === 0) { style.gradientTo = color(token.substring(3), theme); return; }
  if (token === 'bg-gradient-to-r') { style.gradientAngle = 90; return; }
  if (token === 'bg-gradient-to-b') { style.gradientAngle = 180; return; }
  if (token === 'bg-gradient-to-br') { style.gradientAngle = 135; return; }
  if (token.indexOf('opacity-') === 0) { style.opacity = opacity(token.substring(8)); return; }
  if (token.indexOf('text-') === 0) {
    let textValue: string = token.substring(5);
    let size: number = fontSize(textValue);
    if (size > 0) {
      style.fontSize = size;
    } else {
      style.foregroundColor = color(textValue, theme);
    }
  }
}

function spacing(value: string): number {
  if (value === '0') { return 0; }
  if (value === '1') { return 4; }
  if (value === '2') { return 8; }
  if (value === '3') { return 12; }
  if (value === '4') { return 16; }
  if (value === '5') { return 20; }
  if (value === '6') { return 24; }
  if (value === '8') { return 32; }
  if (value === '10') { return 40; }
  if (value === '12') { return 48; }
  if (value === '16') { return 64; }
  if (value === '20') { return 80; }
  if (value === '24') { return 96; }
  if (value === '32') { return 128; }
  return 0;
}

function fontSize(value: string): number {
  if (value === 'xs') { return 11; }
  if (value === 'sm') { return 13; }
  if (value === 'base') { return 15; }
  if (value === 'lg') { return 18; }
  if (value === 'xl') { return 21; }
  if (value === '2xl') { return 26; }
  if (value === '3xl') { return 32; }
  if (value === '4xl') { return 38; }
  return 0;
}

function radius(token: string): number {
  if (token === 'rounded-sm') { return 4; }
  if (token === 'rounded') { return 6; }
  if (token === 'rounded-md') { return 8; }
  if (token === 'rounded-lg') { return 12; }
  if (token === 'rounded-xl') { return 16; }
  if (token === 'rounded-2xl') { return 20; }
  if (token === 'rounded-3xl') { return 28; }
  if (token === 'rounded-full') { return 999; }
  return 0;
}

function opacity(value: string): number {
  if (value === '0') { return 0; }
  if (value === '25') { return 0.25; }
  if (value === '50') { return 0.5; }
  if (value === '60') { return 0.6; }
  if (value === '70') { return 0.7; }
  if (value === '80') { return 0.8; }
  if (value === '90') { return 0.9; }
  return 1;
}

function color(value: string, theme: ArkUiTheme): string {
  let parts: string[] = value.split('/');
  let name: string = parts[0];
  let resolved: string | undefined = theme.colors[name];
  if (resolved === undefined) {
    resolved = DEFAULT_COLORS[name];
  }
  if (resolved === undefined || resolved.length === 0) {
    resolved = DEFAULT_COLORS['transparent'];
  }
  if (parts.length > 1) {
    return withAlpha(resolved, parts[1]);
  }
  return resolved;
}

function createDefaultColors(): Record<string, string> {
  let colors: Record<string, string> = {};
  colors['transparent'] = '#00000000'; colors['white'] = '#FFFFFFFF'; colors['black'] = '#FF111513';
  colors['surface'] = '#F2F4F1EE'; colors['card'] = '#E8ECE8DC'; colors['primary'] = '#FF66786E';
  colors['secondary'] = '#FFC7A9A0'; colors['accent'] = '#FF77919A'; colors['ink'] = '#FF26332D';
  colors['muted'] = '#FF66716B'; colors['danger'] = '#FF9A5751'; colors['success'] = '#FF5D7C69';
  colors['border'] = '#66FFFFFF'; return colors;
}

function withAlpha(value: string, alphaText: string): string {
  let alpha: string = 'FF';
  if (alphaText === '10') { alpha = '1A'; }
  if (alphaText === '20') { alpha = '33'; }
  if (alphaText === '30') { alpha = '4D'; }
  if (alphaText === '40') { alpha = '66'; }
  if (alphaText === '50') { alpha = '80'; }
  if (alphaText === '60') { alpha = '99'; }
  if (alphaText === '70') { alpha = 'B3'; }
  if (alphaText === '80') { alpha = 'CC'; }
  if (alphaText === '90') { alpha = 'E6'; }
  if (value.length === 7 && value.indexOf('#') === 0) {
    return '#' + alpha + value.substring(1);
  }
  if (value.length === 9 && value.indexOf('#') === 0) {
    return '#' + alpha + value.substring(3);
  }
  return value;
}

function setPadding(style: ResolvedArkUiStyle, value: number): void {
  style.paddingTop = value; style.paddingRight = value; style.paddingBottom = value; style.paddingLeft = value;
}

function setMargin(style: ResolvedArkUiStyle, value: number): void {
  style.marginTop = value; style.marginRight = value; style.marginBottom = value; style.marginLeft = value;
}

function setShadow(style: ResolvedArkUiStyle, radius: number, offsetY: number): void {
  style.shadowRadius = radius;
  style.shadowOffsetY = offsetY;
  style.shadowColor = '#260F1A15';
}
