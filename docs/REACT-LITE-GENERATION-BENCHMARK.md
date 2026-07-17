# React Lite Generation Benchmark

This benchmark records generation behavior without inventing performance claims. Run each case once with a cold cache and at least three times with a warm cache for each configuration.

Configurations:

- `A`: current `main` baseline.
- `B`: `glm-5.2`, stable React Lite protocol, thinking disabled, `do_sample=false`, SSE enabled, compact output and quality gate.
- `C`: optional guarded `glm-4.7-flash` routing, disabled by default.

Record the raw result for every run. Do not report cache hits, speedups or quality improvements from a single request.

| Case | Domain | Pages | Cold result | Warm run 1 | Warm run 2 | Warm run 3 |
|---|---|---:|---|---|---|---|
| RL-01 | travel planner | 3 | pending | pending | pending | pending |
| RL-02 | todo list | 2 | pending | pending | pending | pending |
| RL-03 | weather briefing | 2 | pending | pending | pending | pending |
| RL-04 | recipe planner | 3 | pending | pending | pending | pending |
| RL-05 | fitness routine | 2 | pending | pending | pending | pending |
| RL-06 | study planner | 3 | pending | pending | pending | pending |
| RL-07 | expense tracker | 3 | pending | pending | pending | pending |
| RL-08 | event checklist | 2 | pending | pending | pending | pending |
| RL-09 | packing assistant | 2 | pending | pending | pending | pending |
| RL-10 | meeting assistant | 3 | pending | pending | pending | pending |
| RL-11 | customer intake | 3 | pending | pending | pending | pending |
| RL-12 | pet care plan | 2 | pending | pending | pending | pending |
| RL-13 | home maintenance | 3 | pending | pending | pending | pending |
| RL-14 | reading tracker | 2 | pending | pending | pending | pending |
| RL-15 | job application tracker | 3 | pending | pending | pending | pending |
| RL-16 | shopping planner | 2 | pending | pending | pending | pending |
| RL-17 | medication reminder | 2 | pending | pending | pending | pending |
| RL-18 | project launch plan | 3 | pending | pending | pending | pending |
| RL-19 | local guide | 3 | pending | pending | pending | pending |
| RL-20 | generic skill manifest | 2 | pending | pending | pending | pending |

For each run capture: TTFT p50/p95, total latency p50/p95, prompt tokens, cached tokens, cache ratio, completion tokens, source characters/lines, first parse pass, first compile pass, quality gate pass, repair rate, page coverage, primary action coverage, Agent contract coverage, runtime acceptance and visual review score.

The repository currently contains the measurement schema and case matrix. Numeric results require live GLM requests and are intentionally left as `pending` until collected.
