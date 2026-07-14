# GLM Skill-to-Nested-App MVP

Current goal: validate a HarmonyOS flow where a user provides a Skill, GLM designs a structured multi-page Nested App, and later UI interactions can trigger structured GLM Agent Turns and whitelisted tools.

## MVP Skeleton Scope

- Four-stage Skill Forge: import, analyze, setup, preview.
- Three import paths: repository URL, a `skill.md` selected from the device file system, or a local Skill image.
- Generic `SkillManifest`, `AppBlueprint`, Nested App DSL, and Runtime Agent Turn contracts.
- Scrollable debug panels expose the source, vision output, raw `SkillManifest`, raw `AppBlueprint`, and final Nested App DSL.
- Hybrid interaction routing: deterministic actions stay local; `invokeAgent` uses GLM when configured.
- Existing local `travel.*` tool adapter and bounded State/UI Patch handling.
- Existing A2UI desktop card experiment remains available as a secondary mode.

## Local GLM Config

Local device builds load the API key from `entry/src/main/ets/config/GlmLocalSecrets.ets` at startup. The real file is Git-ignored; `GlmLocalSecrets.example.ets` is the tracked template. GLM calls have a 120-second hard request deadline and stop the active workflow with a visible error when it expires. A HUKS-backed CredentialVault remains deferred.

Image Skill Forge uses a two-model pipeline: `glm-4.6v-flash` reads the local Base64 image through the general endpoint, then `glm-5.2` normalizes it into a `SkillManifest` and generates an `AppBlueprint` through the Coding endpoint. The `skill.md` path reads a UTF-8 Markdown file (up to 1 MB) selected with the HarmonyOS document picker and sends its contents directly to `glm-5.2`. All Forge paths fail visibly and preserve raw model output instead of silently loading the travel fallback.

## Forge Debug Artifacts

Each generation stage renders its intermediate output in a fixed-height, independently scrollable panel:

- Skill source: selected `skill.md` contents, or the vision model's raw image analysis.
- Analysis: raw `glm-5.2` `SkillManifest` JSON.
- UI design: raw `glm-5.2` `AppBlueprint` JSON.
- Compile: final `NestedAppSpec` DSL rendered by the app.

The panels remain visible on validation or request failure so malformed model output can be inspected on-device.

## Local signing configuration

`build-profile.json5` is intentionally ignored because DevEco Studio writes local certificate paths and signing passwords into it. For a fresh checkout, copy `build-profile.example.json5` to `build-profile.json5`, then configure signing in DevEco Studio. Never commit the generated signing profile, certificate, keystore, API key, or `.env` file.

The coding endpoint remains `https://open.bigmodel.cn/api/coding/paas/v4`; the client appends `/chat/completions` exactly once.

## CLI Build SDK Root

This DevEco installation builds the HarmonyOS product with the OpenHarmony base components under `sdk/default/openharmony`. Set `DEVECO_SDK_HOME` to the SDK parent directory, not to `sdk/default`:

```powershell
$env:DEVECO_SDK_HOME='C:\Program Files\Huawei\DevEco Studio\sdk'
& 'C:\Program Files\Huawei\DevEco Studio\tools\hvigor\bin\hvigorw.bat' --mode module -p product=default -p module=entry@default assembleHap --no-daemon
```

## Local Demo Templates

- The bundled travel and weather templates remain available for the explicit local Demo entry and as internal schema sentinels.
- The GLM-backed Forge flow does not install these templates when model output is missing or invalid.
- Repository content fetching, Seniverse HTTP calls, secure credentials, dynamic view mounting, and the second GLM tool-result turn are explicitly deferred in [`docs/MVP-SKELETON-DEFERRED.md`](docs/MVP-SKELETON-DEFERRED.md).

## Explicit Non-goals For MVP

- Runtime generation/execution of ArkTS source or arbitrary code.
- Full A2UI catalog rendering.
- Silent desktop card installation.
- Arbitrary network domains or unregistered tools.
- Production-grade persistence migrations and broad tests.
