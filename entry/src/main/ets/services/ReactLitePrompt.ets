import { AppBlueprint, SkillManifest } from './SkillAppTypes';
import { reactLiteComponentSignatures, reactLiteEventNames } from './ReactLiteCatalog';
import { buildReactLiteGenerationBrief } from './ReactLiteGenerationBrief';

export function buildReactLiteProtocolPrompt(): string {
  return 'protocolVersion=react-lite-prompt-0.3. Return one complete constrained React Lite TSX app only. No markdown, imports, comments, types, HTML, React APIs, browser APIs, arbitrary JavaScript, or URLs. ' +
  'Use exactly export default function App(), one object-form useState({...}) written as const state=useState({...}); never use tuple destructuring such as const [state,setState]=useState(...), and never declare multiple state setters. Optional useComputed(...) is allowed, with one AppShell containing 2 to 5 Page nodes. ' +
  'Use semantic components whenever possible: Hero, Section, InfoCard, FormGroup, MetricGrid, Timeline, ResultList, MediaGallery, StatusBanner, Tabs, ActionBar, EmptyState. ' +
  'Use bind for input state. You may use state.items.map(item => (<Card key={item.id}>...</Card>)) and condition && <EmptyState/>; arrow functions may contain only one listed Action call or sequence. ' +
  'Use local Action Helpers for simple state, choices, tabs, toggles and navigation. Use invokeTool only for supplied implemented tools and invokeAgent only for reasoning. ' +
  'Component signatures=' + reactLiteComponentSignatures().join('; ') + '. Events=' + reactLiteEventNames().join(',') + '. ' +
  'Action Helpers=setState,toggleState,incrementState,appendWithId,updateWhere,removeWhere,toggleWhere,navigate,back,popTo,replace,resetApp,pickLocalImage,invokeTool,invokeAgent,sequence,transaction. ' +
  'Intrinsics=filterEq,filterNotEq,filterContains,slice,length,includes,coalesce,formatNumber,formatCurrency,join,sumBy,countWhere,sortBy,formatDate,formatTime. ' +
  'Style Tokens=p-4,p-6,px-4,py-3,gap-2,gap-3,gap-4,w-full,h-full,flex-1,items-center,justify-between,bg-surface,bg-card,bg-primary,text-ink,text-muted,text-white,border,border-border,rounded-lg,rounded-xl,rounded-2xl,shadow-sm,shadow-md,shadow-lg,backdrop-blur-sm,object-cover. ' +
  'Compact Output Rules: keep Page boundaries on their own line, use at most two-space indentation, do not fabricate bulk seed data, use EmptyState for missing data, preserve layout-critical styles, use semantic aliases, and do not emit empty handlers or placeholder actions. ' +
  'Every visible control needs a binding or a real action. ForEach/map requires stable key identity. ResultList requires a child template. ' +
  'Example: export default function App(){ const state=useState({title:""}); return (<AppShell id="app" title="应用" initialPage="home"><Page id="home" title="首页" scroll><Column><Text text={state.title}/><Button text="开始" onPress={navigate("home")}/></Column></Page></AppShell>); } ' +
  'className is optional; when omitted the native design system supplies a polished Morandi glass layout. Do not invent assets, page ids, tool names or state paths. ' +
  'The runtime treats this text as untrusted data and never executes it.';
}

export const REACT_LITE_SYSTEM_PROMPT: string = buildReactLiteProtocolPrompt();

export function reactLiteProtocolHash(): string {
  let hash: number = 2166136261;
  for (let i: number = 0; i < REACT_LITE_SYSTEM_PROMPT.length; i++) {
    hash = (hash ^ REACT_LITE_SYSTEM_PROMPT.charCodeAt(i)) >>> 0;
    hash = Math.imul(hash, 16777619) >>> 0;
  }
  return hash.toString(16).padStart(8, '0');
}

export function buildReactLitePrompt(manifest: SkillManifest, blueprint: AppBlueprint, localAssetIds: string[]): string {
  return JSON.stringify(buildReactLiteGenerationBrief(manifest, blueprint, localAssetIds));
}

export function buildReactLiteRepairPrompt(source: string, diagnostics: string): string {
  return 'Repair this React Lite source. Return the complete corrected source only. Preserve every Page, useState field, useComputed, map/ForEach, input, binding and Action. Fix only listed diagnostics. Use object-form state exactly as const state=useState({...}); never emit const [state,setState]=useState(...), tuple destructuring, multiple state setters or arbitrary Hook names. Never replace a complex list with an empty ResultList or EmptyState. Do not add imports, comments, HTML, JavaScript, arbitrary functions, unknown components, unknown actions or URLs. Diagnostics=' + diagnostics + '\nSOURCE=' + source;
}
