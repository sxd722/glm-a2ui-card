# React Lite Crash Hardening Plan

## Goal

Ensure finite GLM output, malformed React Lite source, and SSE callback failures
produce bounded diagnostics instead of terminating the HarmonyOS UI process.

## Order

1. Disable React Lite streaming by default and record the A/B result.
2. Make SSE settlement, decoder flush, timeout, cleanup, and output limits total.
3. Preserve bounded raw and normalized source artifacts with explicit Forge stages.
4. Make normalization, parsing, compilation, validation, and quality checks bounded.
5. Add explicit handling for fragments, spread, inline style, conditional JSX, and
   unsupported arrow blocks.
6. Add a hostile corpus and HDC entry point.
7. Build, install, run corpus and Travel acceptance on Pura X. Restore streaming
   only if the documented real-device gates pass; otherwise keep it disabled.

## Safety Rules

- Never execute generated TSX, JavaScript, or ArkTS.
- Never replace the last valid UI with an invalid result.
- Never log API keys, authorization headers, image data URLs, or full raw source
  to public hilog.
- Every parser, decoder, compiler, and evaluator loop must advance, terminate,
  or stop at an explicit budget.
