# UI IR Reactivity and Agent Wire Fix

## Goal

Repair the Travel React Lite MVP without replacing the existing renderer or
runtime. The work keeps A2UI and legacy ArkUiSpec paths intact.

## Execution Order

1. Establish reproducible state/computed checks for date selection and list
   mutations. Use the existing runtime APIs first; only change them if the
   checks expose a runtime defect.
2. Make the Travel date selector state-bound and add observable data for an
   empty date. Make `done` and `liked` state visible through controlled UI
   properties and status text.
3. Add focused renderer diagnostics for repeat keys and choice selection. If
   state and computed values update but ArkUI reuses stale rows, use a key made
   from the stable business key plus a deterministic item-content hash. Do not
   append a global revision to every key.
4. Normalize UI IR Agent arguments to ordinary JSON recursively. Keep one
   canonical `uiIrAction` wire payload and reject tagged-value leakage.
5. Tighten the runtime Agent prompt/response contract and preserve current UI
   state on malformed or contract-invalid responses.
6. Convert the Travel Agent action to the structured intent/args/bind/status
   form, with explicit success and error behavior.
7. Add the smallest available source-level acceptance checks and a self-test
   entry point where the existing test harness does not exist.
8. Run diff checks, build the HAP, install and exercise the Travel flow on the
   connected device. Record actual results; do not claim unexecuted checks.

## Constraints

- No React runtime, WebView, eval, dynamic ArkTS, or arbitrary JavaScript.
- Do not overwrite `UiIrRenderer.ets` or `AppRunner.ets` wholesale.
- Do not use a global `stateRevision` in all list keys.
- Keep legacy A2UI and ArkUiSpec construction paths compatible.
- Commit each completed phase separately on this branch when the phase is
  independently buildable.

## Deferred or Limited MVP Work

- Full HarmonyOS unit-test integration is not present in this checkout; use
  deterministic exported self-check helpers and HDC evidence where needed.
- Agent network verification depends on the configured GLM endpoint and device
  connectivity; malformed-response handling remains local and deterministic.
