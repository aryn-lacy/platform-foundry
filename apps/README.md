# apps/ — the payload

The application this platform delivers. **Placeholder, deliberately boring.**

- `backend/` — Spring Boot API (upstream: [marcusmonteirodesouza/realworld-backend-spring-boot-java-keycloak-postgresql](https://github.com/marcusmonteirodesouza/realworld-backend-spring-boot-java-keycloak-postgresql)), integrated with Keycloak as its identity provider.
- `frontend/` — React + nginx (upstream: [yurisldk/realworld-react-fsd](https://github.com/yurisldk/realworld-react-fsd)).

Both are RealWorld ("Conduit") implementations — a standard Medium-style demo
application spec. The app is **not the product**; it is realistic ballast that
exercises the delivery system: two buildable images, a database, an identity
provider, an ingress.

**Contract**

- CI workflows path-filter on these directories — only the changed image rebuilds.
- Upstream sources are imported and **credited**; the platform around them is the original work.
- App code is modified as little as possible. Additions live beside it (Dockerfile, .dockerignore), not inside it.
