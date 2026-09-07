# diagrams/ — diagrams as code

Editable sources (exalidraw/mermaid) plus exported SVGs, referenced by
`docs/architecture.md`. Re-export on edit; never commit a stale export.

Planned diagrams:

- Fig. 1 — landing-zone context (assumed org, two LZs, tenant stack in scope)
- Fig. 2 — platform architecture (CI → ECR → git → Argo CD → canary'd workloads → data)
