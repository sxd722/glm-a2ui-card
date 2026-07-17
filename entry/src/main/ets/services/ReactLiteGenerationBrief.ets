import { AppBlueprint, SkillManifest } from './SkillAppTypes';

export interface ReactLitePageBrief { id: string; title: string; purpose: string; primaryAction: string; }
export interface ReactLiteFieldBrief { id: string; label: string; kind: string; required: boolean; }
export interface ReactLiteToolBrief { name: string; description: string; }

export interface ReactLiteGenerationBrief {
  appId: string;
  title: string;
  summary: string;
  pages: ReactLitePageBrief[];
  fields: ReactLiteFieldBrief[];
  outputs: string[];
  tools: ReactLiteToolBrief[];
  assetIds: string[];
  palette: string[];
  constraints: string[];
}

export function buildReactLiteGenerationBrief(manifest: SkillManifest, blueprint: AppBlueprint,
  localAssetIds: string[]): ReactLiteGenerationBrief {
  let pages: ReactLitePageBrief[] = [];
  for (let i: number = 0; i < blueprint.pages.length; i++) {
    pages.push({ id: blueprint.pages[i].id, title: blueprint.pages[i].title, purpose: blueprint.pages[i].purpose,
      primaryAction: blueprint.pages[i].primaryAction });
  }
  let fields: ReactLiteFieldBrief[] = [];
  for (let i: number = 0; i < manifest.inputFields.length; i++) {
    let field = manifest.inputFields[i];
    fields.push({ id: field.id, label: field.label, kind: field.kind, required: field.required });
  }
  let tools: ReactLiteToolBrief[] = [];
  for (let i: number = 0; i < manifest.toolContracts.length; i++) {
    if (manifest.toolContracts[i].implemented) { tools.push({ name: manifest.toolContracts[i].name, description: manifest.toolContracts[i].description }); }
  }
  let constraints: string[] = ['Generate complete React Lite TSX.', 'Use local actions for simple UI state.', 'Every repeat requires a stable key.',
    'Every visible control needs a binding or real action.', 'Do not emit imports, comments, markdown, URLs or arbitrary JavaScript.'];
  return { appId: blueprint.appId, title: blueprint.title, summary: blueprint.summary, pages: pages, fields: fields,
    outputs: manifest.outputFields.slice(), tools: tools, assetIds: localAssetIds.slice(), palette: blueprint.palette.slice(), constraints: constraints };
}
