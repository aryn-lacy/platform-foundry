# diagrams/ — diagrams as code

Editable sources (mermaid/excalidraw) plus exported SVGs, referenced by
`docs/architecture.md`. Re-export on edit; never commit a stale export.

Normative layouts (until SVG exports land):

- **Fig. 1 — landing-zone context:** two LZ accounts under one org, shared
  network hub (assumed), this stack deployed identically per workspace,
  promotion as a PR between overlays. See `docs/architecture.md` §2.
- **Fig. 2 — platform architecture:** CI → ECR → set-image commit →
  Argo CD → canary'd workloads → per-tier RDS + Secrets Manager, with the
  assumed Prometheus plane drawn as a dashed external dependency. See §5
  and `docs/assumptions.md` A3.

Status: ASCII versions in `architecture.md` are normative; rendered
diagrams follow as P6 polish.
