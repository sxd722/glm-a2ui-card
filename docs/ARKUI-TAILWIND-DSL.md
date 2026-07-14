# ArkUiSpec Tailwind DSL MVP

## Decision

`NestedAppSpec V1` is no longer a generated or persisted UI contract. The executable UI contract is `ArkUiSpec`:

```text
Skill source -> SkillManifest -> AppBlueprint -> ArkUiPage[] -> ArkUiSpec -> native ArkUI
```

- `AppBlueprint` contains product intent and 2-5 page plans. It does not contain UI nodes.
- GLM-5.2 generates each `ArkUiPage` separately with a non-streaming request and a 10-minute timeout.
- `ArkUiCompiler` accepts a small Tailwind-like utility whitelist and resolves it to typed ArkUI style data.
- `ArkUiNodeRenderer` recursively maps the JSON tree to native ArkUI components. No ArkTS, JSX, `eval`, WebView, or remote code is executed.
- User actions use a kind-first router: `localMutate` and `invokeTool` stay on-device; only `invokeAgent` can call GLM. Legacy `handling` is normalized and cannot promote a local action into a cloud request.

## Minimal Contract

```json
{
  "schemaVersion": "arkui-tailwind-2",
  "appId": "weather-skill-app",
  "title": "天气决策助手",
  "subtitle": "情境优先的天气工作台",
  "initialPageId": "home",
  "theme": { "colors": { "primary": "#FF6D7E73" } },
  "pages": [{
    "id": "home",
    "title": "当前天气",
    "scroll": true,
    "root": {
      "id": "root",
      "type": "Column",
      "className": "w-full gap-4 p-4 bg-surface",
      "props": {},
      "binding": "",
      "actions": [],
      "children": []
    }
  }]
}
```

Allowed nodes are `Column`, `Row`, `Stack`, `Scroll`, `Grid`, `List`, `Text`, `Image`, `Button`, `TextInput`, `TextArea`, `Toggle`, `ChoiceChips`, `SegmentedControl`, `Progress`, `Divider`, `Spacer`, `Badge`, and `DynamicSlot`.

## Local Interaction DSL

Simple interactions are represented as declarative effects and do not call GLM:

```json
{
  "id": "toggle-complete",
  "label": "完成",
  "kind": "localMutate",
  "targetPageId": "",
  "payload": "",
  "handling": "local",
  "effects": [{ "op": "toggle", "path": "isCompleted" }],
  "guards": []
}
```

Supported effects are `set`, `toggle`, `increment`, `append`, `remove`, `merge`, and `clear`. Deterministic registered capabilities use `invokeTool` with a tool name, bound arguments, and result bindings. GLM is reserved for reasoning, generation, ambiguity, and unstructured interpretation.

Runtime results accept the compact `{state,toolCalls,navigateTo,status}` shape as well as legacy `statePatches` and `uiPatches`. Missing optional fields, object tool arguments, Markdown fences, and extra surrounding text are repaired or ignored without discarding the whole turn.

## Failure Behavior

- Blueprint and page generation use non-streaming responses with a 10-minute timeout because GLM-5.2 may need several minutes for structured UI JSON.
- GLM-5.2 failure falls back to GLM-4.7-Flash per blueprint or page.
- If both GLM-5.2 and GLM-4.7-Flash fail validation, generation stops and preserves the last valid Blueprint/ArkUiSpec. It never injects a local travel or weather page for an unrelated Skill.
- Unknown nodes, utilities, pages, actions, and tools are ignored, repaired, or rejected by the native layer.
- Local mutations are applied transactionally; invalid paths or guards leave the previous session unchanged.

## Deferred

- Full Tailwind compatibility and arbitrary values.
- Runtime list expressions and repeat item mutation bindings.
- Animation and richer modal/picker DSL.
- Real-time background blur on every node; the MVP parses blur tokens but degrades expensive material effects.
- GLM-generated temporary page patches beyond the existing `DynamicSlot` placeholder.
- Automated screenshot scoring and visual repair turns.
- Migration of old persisted `NestedAppSpec V1` data. Old drafts should be regenerated.
