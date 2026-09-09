# apps/ — the payload

The application this platform delivers: a RealWorld ("Conduit") stack —
Spring Boot API (Keycloak-native OAuth2) + React frontend, PostgreSQL
persistence. **The platform is the product; the app is placeholder
payload** — realistic enough to exercise every part of the delivery
system, unimportant enough to swap for anything.

- `backend/` — vendored from
  [marcusmonteirodesouza/realworld-backend-spring-boot-java-keycloak-postgresql](https://github.com/marcusmonteirodesouza/realworld-backend-spring-boot-java-keycloak-postgresql)
- `frontend/` — vendored from
  [yurisldk/realworld-react-fsd](https://github.com/yurisldk/realworld-react-fsd)

Both vendored unmodified (heavier binaries/CI dotfiles stripped); see the
per-app READMEs. CI path-filters on these directories (`.github/workflows/`)
— the payload exists so the pipeline demonstrably ships something.
