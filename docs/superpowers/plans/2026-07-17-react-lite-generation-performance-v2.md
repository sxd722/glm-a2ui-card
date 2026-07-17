# React Lite Generation Performance V2

## Scope

Improve first-pass React Lite generation while preserving the existing Travel
fixture, A2UI path, Legacy ArkUiSpec path, local Action DSL, and last-valid-UI
fallback behavior. All edits remain on `main` per repository workflow.

## Order

1. Make the Travel acceptance self-test compile the real `TRAVEL_REACT_LITE_SOURCE`
   and inspect the resulting UI IR contract, while retaining state mutation and
   plain JSON checks.
2. Replace the duplicated UI IR Agent request fields with a discriminated
   `mode: 'ui-ir'` request and enforce complete response outputs.
3. Give repeated ArkUI controls a stable per-item instance identity without
   adding global `stateRevision` to all keys.
4. Add generation metrics and deterministic request policy, including dynamic
   React Lite token budgets and truncation retry metadata.
5. Split the React Lite protocol prompt from a compact, stable generation brief
   and add compact-output/quality-gate rules.
6. Add a standalone UTF-8-safe SSE decoder and stream-progress model. Network
   streaming is used only when the SDK API is available; non-stream fallback is
   explicit and measured.
7. Normalize generated source deterministically and keep semantic regression
   checks as a repair gate.
8. Build, run available self-tests, and perform device validation only when a
   device is actually connected.

## Constraints

- No React runtime, WebView, eval, dynamic ArkTS, or generated-code execution.
- No Flash UI plus Pro Action merge.
- No global revision in every ForEach key.
- No API key, image data URL, full sensitive manifest, or private user input in
  metrics or logs.
- Do not claim cache hits, streaming, speedups, or device success without
  measured evidence.
