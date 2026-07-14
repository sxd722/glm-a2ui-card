// Compatibility exports for existing runtime call sites. The V1 node schema is removed;
// every alias below points to the Tailwind-like ArkUiSpec runtime.
export {
  ArkUiAction as NestedAction,
  ArkUiActionHandling as NestedActionHandling,
  ArkUiActionKind as NestedActionKind,
  ArkUiSessionState as NestedSessionState,
  CompiledArkUiNode as NestedNode,
  CompiledArkUiPage as NestedPageSpec,
  LocalImageAsset
} from './ArkUiTypes';
