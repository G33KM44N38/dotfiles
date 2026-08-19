---
name: performance-first-review
description: Review and improve end-to-end application performance. Use for code changes, API or UI work, performance audits, slow loading, latency regressions, Lighthouse or Playwright measurement, database/query optimization, caching, deployment verification, or whenever performance should be treated as a release requirement.
---

# Performance-First Review

Treat performance as correctness, not optional polish.

## Workflow

1. Define the user-visible critical path and target before changing code.
2. Measure the current path. Capture network waterfall, request count, TTFB, render milestones, server duration, and external dependencies where relevant.
3. Trace from user action through frontend, API, database, cache, and third parties. Fix the lowest shared bottleneck.
4. Remove sequential waterfalls. Parallelize independent work; batch dependent work.
5. Keep external services off initial render paths. Prefer local source-of-truth data, cached aggregates, background hydration, or graceful fallback.
6. Fetch only necessary fields. Use pagination for scale; when the product requires all records, use one purpose-built bulk query rather than client pagination loops.
7. Render useful content as soon as authoritative core data arrives. Hydrate secondary metadata without blocking interaction.
8. Add regression coverage for request count, critical-path behavior, or query shape when practical.
9. Re-measure the same scenario after the change. Report before/after evidence, not intuition.
10. After deployment, verify the exact SHA, CI, service health, real production timing, and error/performance telemetry until stable.

## Review Gate

Block handoff when a changed critical path introduces:

- sequential requests that can be combined or parallelized;
- repeated counts/enrichment per page;
- third-party calls required before first useful render;
- unbounded payloads without an explicit product requirement;
- loading states that hide already-available useful data;
- missing timeout, cache, fallback, or error observability;
- claims of improvement without comparable measurements.

## Evidence

Use the smallest adequate set: browser network/Playwright, Lighthouse for page delivery, server traces, database explain/profiling, bundle analysis, Sentry/APM, and production platform deploy/runtime signals. Lighthouse alone does not prove authenticated data-path speed.
