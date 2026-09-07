# docs/ — the paper trail

- `architecture.md` — the system, end to end: diagrams, decisions, flow (lands with P6, `#6`)
- `assumptions.md` — the register: what is assumed vs. built, and where each appears
- `decisions/` — numbered ADRs, one decision per file
- `runbooks/` — operational procedures that only exist if written down
- `diagrams/` — editable sources + exported SVGs; diagrams are code

**Contract**

- Every architectural claim in the README traces to a section here.
- Every "we decided X over Y" traces to an ADR.
- Every assumed dependency appears in the assumptions register — nothing silent.
