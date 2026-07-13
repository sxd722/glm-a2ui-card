# GLM Skill-to-Nested-App MVP

Current goal: validate a HarmonyOS flow where a user provides a Skill, GLM designs a structured multi-page Nested App, and later UI interactions can trigger structured GLM Agent Turns and whitelisted tools.

## MVP Skeleton Scope

- Four-stage Skill Forge: import, analyze, setup, preview.
- Generic `SkillManifest`, `AppBlueprint`, Nested App DSL, and Runtime Agent Turn contracts.
- Local travel and weather Blueprint fallbacks when GLM is unavailable or returns invalid JSON.
- Hybrid interaction routing: deterministic actions stay local; `invokeAgent` uses GLM when configured.
- Existing local `travel.*` tool adapter and bounded State/UI Patch handling.
- Existing A2UI desktop card experiment remains available as a secondary mode.

## Local GLM Config

The source tree contains no real GLM API key. Enter the GLM key in the Forge setup screen or legacy experiment screen. It is held in memory only until the HUKS-backed CredentialVault is implemented.

## Local signing configuration

`build-profile.json5` is intentionally ignored because DevEco Studio writes local certificate paths and signing passwords into it. For a fresh checkout, copy `build-profile.example.json5` to `build-profile.json5`, then configure signing in DevEco Studio. Never commit the generated signing profile, certificate, keystore, API key, or `.env` file.

The coding endpoint remains `https://open.bigmodel.cn/api/coding/paas/v4`; the client appends `/chat/completions` exactly once.

## CLI Build SDK Root

This DevEco installation builds the HarmonyOS product with the OpenHarmony base components under `sdk/default/openharmony`. Set `DEVECO_SDK_HOME` to the SDK parent directory, not to `sdk/default`:

```powershell
$env:DEVECO_SDK_HOME='C:\Program Files\Huawei\DevEco Studio\sdk'
& 'C:\Program Files\Huawei\DevEco Studio\tools\hvigor\bin\hvigorw.bat' --mode module -p product=default -p module=entry@default assembleHap --no-daemon
```

## Local Fallbacks

- A repository URL containing `seniverse` or `weather` produces the weather dashboard skeleton.
- Other text/image sources produce the travel workflow fallback.
- Repository content fetching, Seniverse HTTP calls, secure credentials, dynamic view mounting, and the second GLM tool-result turn are explicitly deferred in [`docs/MVP-SKELETON-DEFERRED.md`](docs/MVP-SKELETON-DEFERRED.md).

## Explicit Non-goals For MVP

- Runtime generation/execution of ArkTS source or arbitrary code.
- Full A2UI catalog rendering.
- Silent desktop card installation.
- Arbitrary network domains or unregistered tools.
- Production-grade persistence migrations and broad tests.
