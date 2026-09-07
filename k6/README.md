# k6/ — performance regression gates

Load profiles and the baselines they are judged against. The performance
bonus requirement, made executable.

**Layout** (lands with Phase 5, `#5`)

- `smoke.js` — VU ramp scenarios against login/articles endpoints; thresholds on p95 and error rate
- `baselines/dev.json` — committed p95/p99 baseline; the versioned regression reference

**How the gate works**

1. CI (post-deploy to dev) runs the fixed load profile via `k6 run`
2. Summary metrics are exported and diffed against the committed baseline
3. Regression beyond tolerance → **non-zero exit → the workflow fails**

Baselines change deliberately (`scripts/seed-baseline.sh`), in review — never silently.

**Contract**

- Thresholds encode "fast enough"; baselines encode "not worse than last known good." Both are reviewable artifacts.
