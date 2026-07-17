# Semantic UI Kit MVP

## Scope

`entry/src/main/ets/semanticui` is an independent, native ArkUI component path. It does not import the legacy React Lite, UI IR, Tailwind resolver, GLM client, or expression/action runtime. Models are typed, parents own state, and components emit `SemanticUiEvent`.

## API surface

- 72 catalog descriptors in `SemanticComponentCatalog.ets`, grouped as Page, Navigation, Presentation, Collection, Form, Feedback, Media, and Agent.
- 12 internal atoms in `internal/SemanticAtoms.ets`.
- Light/Dark semantic tokens with density, size, tone, and scale controls.
- Collection components use `ForEach` with explicit model IDs as render keys. No component mutates a model in place.
- Form components emit typed string, number, boolean, selection, and submit events.
- Overlay components provide snackbar, confirmation, sheet, action-sheet, and loading states.

## Gallery

`pages/SemanticGalleryPage.ets` is the active entry page. It exposes a searchable catalog and four small fixtures: Todo, Travel, Search, and Agent Review. Todo demonstrates five stable task IDs, local checkbox updates, a quick-capture sheet state, and typed form events. Travel demonstrates Hero, metrics, itinerary, route preview, and chart components.

## Validation

The Hypium skeleton is under `entry/src/ohosTest`. It checks the 72-component catalog, stable Todo fixture IDs, and typed event payloads. Run on a connected device with:

```text
hdc shell aa test -b com.example.glma2uicard -m entry_test -s unittest OpenHarmonyTestRunner
```

The current MVP intentionally leaves GLM generation, arbitrary DSL parsing, remote APIs, map rendering, animation, and real persistence outside this path.
