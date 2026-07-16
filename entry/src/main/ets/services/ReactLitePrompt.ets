import { AppBlueprint, SkillManifest } from './SkillAppTypes';
import { reactLiteComponentSignatures, reactLiteEventNames } from './ReactLiteCatalog';

export const REACT_LITE_SYSTEM_PROMPT: string =
  'Return one complete constrained React Lite TSX app only. No markdown, imports, comments, types, HTML, React APIs, browser APIs, arbitrary JavaScript, or URLs. ' +
  'Use exactly export default function App(), one useState({...}), optional useComputed(...), and one AppShell with 2 to 5 Page nodes. ' +
  'Use semantic components whenever possible: Hero, Section, InfoCard, FormGroup, MetricGrid, Timeline, ResultList, MediaGallery, StatusBanner, Tabs, ActionBar, EmptyState. ' +
  'Use bind for input state. You may use state.items.map(item => (<Card key={item.id}>...</Card>)) and condition && <EmptyState/>; arrow functions may contain only one listed Action call or sequence. ' +
  'Use local Action Helpers for simple state, choices, tabs, toggles and navigation. Use invokeTool only for supplied implemented tools and invokeAgent only for reasoning. ' +
  'className is optional; when omitted the native design system supplies a polished Morandi glass layout. Do not invent assets, page ids, tool names or state paths. ' +
  'The runtime treats this text as untrusted data and never executes it.';

export function buildReactLitePrompt(manifest: SkillManifest, blueprint: AppBlueprint, localAssetIds: string[]): string {
  return 'Allowed component signatures: ' + reactLiteComponentSignatures().join('; ') + '. ' +
    'Allowed helpers: setState,toggleState,incrementState,appendState,appendWithId,updateWhere,removeWhere,toggleWhere,navigate,back,popTo,replace,resetApp,pickLocalImage,invokeTool,invokeAgent,sequence,transaction. Never create random IDs or use appendState for object lists with identity; use appendWithId so Runtime assigns the ID. ' +
    'Events from the catalog: ' + reactLiteEventNames().join(',') + '. ForEach keyBy is required for repeat identity. sequence may contain at most one external effect (invokeTool, invokeAgent or pickLocalImage), and that effect must be the final step. ' +
    'Allowed intrinsic calls: filterEq,filterNotEq,filterContains,slice,length,includes,coalesce,formatNumber,formatCurrency,join,sumBy,countWhere,sortBy,formatDate,formatTime. ' +
    'ResultList and map must have a child template with key={item.id}; self-closing ResultList is invalid and will be rejected. invokeAgent may use invokeAgent({intent:"...",args:{...},bind:{field:"state.path"},status:"state.agentStatus"}); only declared bind paths may be written. ' +
    'Allowed style tokens: p-4,p-6,px-4,py-3,gap-2,gap-3,gap-4,w-full,h-full,flex-1,items-center,justify-between,bg-surface,bg-card,bg-primary,text-ink,text-muted,text-white,border,border-border,rounded-lg,rounded-xl,rounded-2xl,shadow-sm,shadow-md,shadow-lg,backdrop-blur-sm,object-cover. ' +
    'SkillManifest=' + JSON.stringify(manifest) + '\nAppBlueprint=' + JSON.stringify(blueprint) +
    '\nPageIds=' + JSON.stringify(blueprint.pages.map((page) => page.id)) + '\nImplementedTools=' + JSON.stringify(manifest.toolContracts.filter((tool) => tool.implemented).map((tool) => tool.name)) +
    '\nLocalAssetIds=' + JSON.stringify(localAssetIds) +
    '\nExample shape: export default function App(){ const state=useState({title:""}); return (<AppShell id="app" title="应用" initialPage="home"><Page id="home" title="首页" scroll><Column><Text text={state.title}/><Button text="开始" onPress={navigate("home")}/></Column></Page></AppShell>); }';
}

export function buildReactLiteRepairPrompt(source: string, diagnostics: string): string {
  return 'Repair this React Lite source. Return the complete corrected source only. Preserve every Page, useState field, useComputed, map/ForEach, input, binding and Action. Fix only listed diagnostics. Never replace a complex list with an empty ResultList or EmptyState. Do not add imports, comments, HTML, JavaScript, arbitrary functions, unknown components, unknown actions or URLs. Diagnostics=' + diagnostics + '\nSOURCE=' + source;
}
