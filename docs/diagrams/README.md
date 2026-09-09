# Fig. 1 — Landing-zone context

Two workload landing zones under one (assumed) organization: shared
network hub, identical stack per zone, `terraform workspace` selects the
target, promotion is a PR between overlays.

```mermaid
flowchart LR
    subgraph ORG["AWS Organization (assumed)"]
        HUB["Transit Gateway hub<br/>centralized egress · SCPs · DNS/IPAM"]
        subgraph DEV["DEV landing zone — workload account"]
            DEVSTACK["this stack<br/>one code path + dev tfvars<br/>workspace: dev"]
        end
        subgraph PROD["PROD landing zone — workload account"]
            PRODSTACK["this stack<br/>same code + prod tfvars<br/>workspace: prod"]
        end
    end
    HUB --- DEV
    HUB --- PROD
    DEVSTACK -- "promotion PR<br/>(moves the image tag)" --> PRODSTACK
```

# Fig. 2 — Platform architecture

CI builds, scans, and commits the deploy record; the cluster pulls; the
workload runs canaried with an AnalysisTemplate guard; per-tier RDS and
Secrets Manager serve state and credentials. The Prometheus plane is an
assumed external dependency ([assumption A3](../assumptions.md)).

```mermaid
flowchart TB
    subgraph CI["GitHub Actions — no cluster credentials"]
        BUILD["path-filtered CI<br/>lint · unit · integration (Testcontainers)"]
        SCAN["trivy (fail CRITICAL)<br/>tfsec/checkov (infra)<br/>conftest/OPA (manifests)"]
        SETIMG["kustomize edit set image<br/>+ commit (the deploy record)"]
        K6GATE["k6 perf gate<br/>vs committed baseline"]
    end
    subgraph CLUSTER["EKS Auto Mode — Argo CD app-of-apps"]
        ARGO["Argo CD<br/>dev auto-sync · prod gated"]
        subgraph CONDUIT["namespace: conduit"]
            CANARY["Rollouts canary<br/>20% → 50% → 100%<br/>AnalysisTemplate guard"]
        end
        subgraph KCNS["namespace: keycloak"]
            KEYCLOAK["Keycloak<br/>realm-as-code"]
        end
        CSI["Secrets Store CSI<br/>(ASCP + Pod Identity)"]
    end
    ECR[("ECR<br/>immutable tags")]
    subgraph STATE["state + identity"]
        RDSA[("RDS — app tier")]
        RDSK[("RDS — identity tier")]
        SM[("Secrets Manager")]
    end
    PROM["Prometheus plane<br/>(assumed — A3)"]

    BUILD --> SCAN --> ECR
    SCAN --> SETIMG --> ARGO
    K6GATE -.->|"post-deploy (dev)"| CANARY
    ARGO --> CANARY
    CANARY --> RDSA
    KEYCLOAK --> RDSK
    CANARY <-->|OIDC/JWT| KEYCLOAK
    CSI --> SM
    CANARY -.->|metrics/scrape| PROM
    KEYCLOAK -.-> PROM
```

# Regenerating

Sources are these Mermaid blocks. Render with any Mermaid-capable viewer
(GitHub renders them natively); if SVG exports are ever needed, export
from the rendered view — never commit a stale export.
