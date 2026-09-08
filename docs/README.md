# docs/ — the paper trail

- `architecture.md` — **the system, end to end**: posture, landing zones,
  estate, cluster, pipeline, observability, security model, promotion, roadmap
- `assumptions.md` — the register: what is assumed (A1–A7) vs. built, each
  traced to where it appears
- `decisions/` — **ADRs 001–010**, all accepted and reflected in code
- `runbooks/` — `db-restore.md` (per-tier RDS restore), `rollback.md`
  (canary abort + git-revert promotion rollback)
- `diagrams/` — diagrams-as-code (ASCII in architecture.md is normative
  until rendered exports land)

**Contract**

- Every architectural claim in the README traces to a section here.
- Every "we decided X over Y" traces to an ADR.
- Every assumed dependency appears in the assumptions register — nothing silent.
