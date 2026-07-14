# ArkUiSpec Tailwind DSL MVP

## Decision

`NestedAppSpec V1` is no longer a generated or persisted UI contract. The executable UI contract is `ArkUiSpec`:

```text
Skill source -> SkillManifest -> AppBlueprint -> ArkUiPage[] -> ArkUiSpec -> native ArkUI
```

- `AppBlueprint` contains product intent and 2-5 page plans. It does not contain UI nodes.
- GLM-5.2 generates each `ArkUiPage` separately with streaming output.
- `ArkUiCompiler` accepts a small Tailwind-like utility whitelist and resolves it to typed ArkUI style data.
- `ArkUiNodeRenderer` recursively maps the JSON tree to native ArkUI components. No ArkTS, JSX, `eval`, WebView, or remote code is executed.
- User actions are routed through the existing local/agent/localThenAgent interaction router and tool whitelist.

## Minimal Contract

```json
{
  "schemaVersion": "arkui-tailwind-1",
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

Allowed nodes are `Column`, `Row`, `Stack`, `Scroll`, `Grid`, `List`, `Text`, `Image`, `Button`, `TextInput`, `TextArea`, `Toggle`, `Progress`, `Divider`, `Spacer`, `Badge`, and `DynamicSlot`.

## Failure Behavior

- The streaming timeout is an idle timeout. Each received chunk resets the 120-second timer.
- If a stream ends abnormally after yielding content, the accumulated content is still parsed.
- GLM-5.2 failure falls back to GLM-4.7-Flash per blueprint or page.
- Invalid page JSON falls back only that page to a local safe page; already generated pages remain visible in the DSL artifact panel.
- Unknown nodes, utilities, pages, actions, and tools are ignored, repaired, or rejected by the native layer.

## Deferred

- Full Tailwind compatibility and arbitrary values.
- Runtime list expressions and repeat bindings.
- Conditional visibility and animation DSL.
- Real-time background blur on every node; the MVP parses blur tokens but degrades expensive material effects.
- GLM-generated temporary page patches beyond the existing `DynamicSlot` placeholder.
- Automated screenshot scoring and visual repair turns.
- Migration of old persisted `NestedAppSpec V1` data. Old drafts should be regenerated.
