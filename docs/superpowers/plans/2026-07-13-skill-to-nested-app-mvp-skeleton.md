# Skill-to-Nested-App MVP Skeleton Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a compilable HarmonyOS MVP skeleton that turns a Skill source into a generic Forge draft, previewable Nested App, and GLM-driven runtime interaction loop.

**Architecture:** Add generic contracts alongside the existing travel/card code, compile an `AppBlueprint` into the existing `NestedAppSpec`, and bridge `invokeAgent` actions to a structured GLM Runtime Turn. Existing travel tools remain the only implemented tool adapter; repository fetching, HUKS credentials, Seniverse HTTP tools, and advanced dynamic components are isolated and documented as deferred modules.

**Tech Stack:** HarmonyOS NEXT 6.0.2(22), ArkTS, ArkUI, `@kit.NetworkKit`, `@kit.ArkData`, Hvigor.

## Global Constraints

- Do not execute model-generated ArkTS, JavaScript, or arbitrary code.
- Do not add third-party dependencies.
- Preserve the existing card and Form experiment.
- Nested Apps are independent App experiences; desktop Form installation is optional.
- Keep GLM-generated output inside strict JSON contracts and existing component/action allowlists.
- Remove the real GLM API key from ArkTS source; manual input remains until the credential vault is implemented.
- Unitized integrations not required for the skeleton must have an exact deferred-work boundary in code and in `docs/MVP-SKELETON-DEFERRED.md`.
- Verification target is a successful signed debug HAP build, followed by device deployment when the connected Pura X is available.

---

### Task 1: Generic Skill, Blueprint, and Runtime Contracts

**Files:**
- Create: `entry/src/main/ets/services/SkillAppTypes.ets`
- Modify: `entry/src/main/ets/services/NestedAppTypes.ets`

**Interfaces:**
- Produces: `SkillSource`, `SkillManifest`, `ToolContract`, `AppBlueprint`, `ForgeDraft`, `InstalledNestedApp`, `RuntimeSession`, `RuntimeAgentTurnRequest`, `RuntimeAgentTurnResult`, `RuntimeToolCall`, `RuntimeStatePatch`, and `RuntimeUiPatch`.
- Extends: `NestedNodeKind` with six generic component kinds and `NestedAction` with optional `handling`.

- [ ] **Step 1: Add generic contracts**

Create explicit ArkTS interfaces using `Record<string, string>` for MVP state and string-array schemas for tool parameters. Avoid recursive or `any`-typed JSON contracts that ArkTS strict mode rejects.

- [ ] **Step 2: Extend the nested DSL allowlist**

Add `dataChart`, `compareTable`, `entityPicker`, `conversationPanel`, `credentialForm`, and `dynamicSlot`; add optional handling values `local`, `agent`, and `localThenAgent`.

- [ ] **Step 3: Build to validate ArkTS types**

Run the project Hvigor assemble task. Expected result: contract files compile with no ArkTS strict-mode errors.

### Task 2: Forge Compiler and Local Fallback Blueprints

**Files:**
- Create: `entry/src/main/ets/services/SkillAppMvp.ets`
- Modify: `entry/src/main/ets/services/NestedAppService.ets`

**Interfaces:**
- Consumes: contracts from Task 1 and `NestedAppSpec`.
- Produces: `createForgeDraft(source)`, `localManifestForSource(source)`, `localBlueprintForManifest(manifest)`, `normalizeSkillManifest(raw, fallback)`, `normalizeAppBlueprint(raw, fallback)`, `compileBlueprint(blueprint)`, and `installBlueprint(draft)`.

- [ ] **Step 1: Add local travel and weather manifests**

The weather fallback declares registered MVP tools but marks the Seniverse HTTP adapter as deferred. The travel fallback references existing local tools.

- [ ] **Step 2: Add local travel and weather Blueprint fallbacks**

Use the existing Nested App DSL to provide a working preview even when GLM is unavailable. Weather must demonstrate an instrument-panel homepage and settings page without claiming live weather data.

- [ ] **Step 3: Add strict normalization and compiler guards**

Invalid Manifest or Blueprint JSON returns the supplied local fallback. Compilation delegates to the nested DSL validator and preserves a last-known-good local app.

- [ ] **Step 4: Update nested validation**

Allow the six new node kinds and optional action handling while continuing to reject unknown pages, nodes, and actions.

- [ ] **Step 5: Build**

Run Hvigor assemble. Expected result: fallback travel and weather apps compile.

### Task 3: Structured GLM Forge and Runtime Requests

**Files:**
- Modify: `entry/src/main/ets/services/GlmClient.ets`

**Interfaces:**
- Consumes: `SkillSource`, `SkillManifest`, `AppBlueprint`, and `RuntimeAgentTurnRequest`.
- Produces: `requestSkillManifestFromGlm(source, config)`, `requestAppBlueprintFromGlm(manifest, localAssetIds, config)`, and `requestNestedRuntimeTurnFromGlm(turn, config)`.

- [ ] **Step 1: Remove the embedded API key**

Keep `GLM_LOCAL_API_KEY` as an empty compatibility default so existing UI imports remain valid. Add a concrete credential-vault deferred-work marker next to it.

- [ ] **Step 2: Add strict system prompts**

The analyzer returns a `SkillManifest`; the designer returns an `AppBlueprint` containing a `nestedApp`; runtime returns `RuntimeAgentTurnResult`. Prompts list allowed node kinds, action kinds, patch operations, and tool restrictions.

- [ ] **Step 3: Reuse the verified chat-completions URL resolver**

All three calls use `requestChatContent`, preserving `/chat/completions` resolution and response cleanup.

- [ ] **Step 4: Build**

Run Hvigor assemble. Expected result: imports and strict request payloads compile.

### Task 4: Runtime Agent Bridge and Patch Guard

**Files:**
- Create: `entry/src/main/ets/services/NestedAgentRuntime.ets`

**Interfaces:**
- Consumes: `NestedSessionState`, `NestedAction`, `SkillManifest`, runtime contracts, and existing travel tools.
- Produces: `createRuntimeSession(appId)`, `buildRuntimeAgentTurnRequest(session, action, manifest)`, `normalizeRuntimeAgentTurnResult(raw)`, and `applyRuntimeAgentTurn(session, result)`.

- [ ] **Step 1: Build a bounded request snapshot**

Send the current page, string state, action payload, registered tool summaries, and dynamic slot IDs. Do not send credentials or local image data URLs.

- [ ] **Step 2: Add result normalization**

Reject unknown status values, patch operations, and tool names. Invalid JSON returns a structured error result instead of throwing into the UI.

- [ ] **Step 3: Apply safe state and navigation patches**

Implement `setData`, `updateStatus`, and validated navigation. Map other allowed patch kinds to a trace message for the skeleton.

- [ ] **Step 4: Execute the existing local travel adapter**

Execute only `travel.*` tools already present in `SkillWorkbench`. Add concrete deferred-work markers for the second GLM turn, Seniverse adapter, credential injection, and dynamic-view mounting.

- [ ] **Step 5: Build**

Run Hvigor assemble. Expected result: the bridge compiles without broad casts or unknown dynamic types.

### Task 5: Four-Stage Forge UI and Runtime Wiring

**Files:**
- Modify: `entry/src/main/ets/pages/Index.ets`

**Interfaces:**
- Consumes: Forge/compiler functions, new GLM methods, and Runtime Agent Bridge.
- Produces: visible `import`, `analyze`, `setup`, and `preview` Forge stages plus a runtime launch path.

- [ ] **Step 1: Add Forge state**

Track source kind/value, stage, draft, Manifest JSON, Blueprint JSON, and Seniverse credential input separately from the current Nested App session.

- [ ] **Step 2: Split Forge into four builders**

Import supports image, repository URL, and text selection. Analyze shows extracted capability/tool counts. Setup exposes GLM and Skill credential fields. Preview renders the compiled app and allows creation.

- [ ] **Step 3: Add local-first Forge actions**

Every stage has a working local fallback. When a GLM key is present, analysis and design call the structured GLM functions; failures keep the local fallback and a visible trace.

- [ ] **Step 4: Wire `invokeAgent` to GLM Runtime Turn**

With a GLM key, create and send the generic runtime request, apply guarded results, and keep the page alive on failure. Without a key, retain the existing travel local reducer behavior.

- [ ] **Step 5: Render generic component kinds**

For the skeleton, map `dataChart` and `compareTable` to list rendering, `entityPicker` to choice rendering, and `conversationPanel`, `credentialForm`, and `dynamicSlot` to existing safe panel/field renderers.

- [ ] **Step 6: Build**

Run Hvigor assemble. Expected result: Forge can progress from landing to preview to runtime without compile errors.

### Task 6: Persistence Skeleton and Deferred-Module Documentation

**Files:**
- Create: `entry/src/main/ets/services/SkillAppStore.ets`
- Create: `docs/MVP-SKELETON-DEFERRED.md`
- Modify: `README.md`

**Interfaces:**
- Produces: `saveForgeDraft`, `readForgeDraft`, `saveInstalledNestedApp`, `readInstalledNestedApp`, `saveRuntimeSession`, and `readRuntimeSession` using Preferences for non-secret data.
- Documents: exact owners, inputs, outputs, and acceptance criteria for deferred units.

- [ ] **Step 1: Add non-secret Preferences persistence**

Use separate keys for Forge draft, installed app, and runtime session. Corrupt JSON returns `undefined` and never crashes startup.

- [ ] **Step 2: Document deferred modules**

Document `CredentialVault`, `RepositoryImporter`, `SeniverseWeatherAdapter`, `DynamicViewHost`, `AssetSearchGateway`, second-pass Tool Loop, schema migrations, and focused tests. Each entry states why it is deferred and the interface it must implement.

- [ ] **Step 3: Update README scope**

Describe the new Skill-to-Nested-App skeleton, local fallback behavior, GLM configuration, and explicit non-goals.

- [ ] **Step 4: Build**

Run Hvigor assemble. Expected result: final signed debug HAP is produced.

### Task 7: Device Smoke Verification

**Files:**
- No source changes unless build or runtime diagnostics reveal a blocking defect.

- [ ] **Step 1: Discover the active SDK, Hvigor, HDC, and connected device**

Use the existing DevEco/HarmonyOS toolchain and confirm the Pura X target.

- [ ] **Step 2: Install and launch the signed HAP**

Expected result: package installs and `EntryAbility` reaches the Nested Skill App landing screen.

- [ ] **Step 3: Exercise the skeleton flow**

Load the local Demo, traverse import/analyze/setup/preview, create the Nested App, navigate locally, and invoke one Agent action with or without configured GLM.

- [ ] **Step 4: Read hilog**

Expected result: no process crash, ArkTS exception, or rejected unknown page during the smoke flow.
