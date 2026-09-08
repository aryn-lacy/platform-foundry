# platform-foundry backend (vendored)

Vendored **unmodified** from
[marcusmonteirodesouza/realworld-backend-spring-boot-java-keycloak-postgresql](https://github.com/marcusmonteirodesouza/realworld-backend-spring-boot-java-keycloak-postgresql)
— a RealWorld ("Conduit") API: Spring Boot + Spring Security OAuth2 against
Keycloak, PostgreSQL persistence.

The application is placeholder payload: this repository's product is the
delivery platform around it (infra, GitOps, progressive delivery, policy
gates). The app itself is deliberately untouched — all customization lives
in `k8s/` overlays and CI. Upstream ships no LICENSE file; it is vendored
here for demonstration purposes with credit, per the upstream README.

The layered Dockerfile in this directory is ours (cache-correct multi-stage
Maven build); everything else is upstream source as-cloned.

## Local run

See upstream README for the original docker-compose (Keycloak + Postgres).
In this platform the app runs on EKS with secrets via CSI and the identity
tier in its own namespace — `docs/architecture.md` has the full picture.
