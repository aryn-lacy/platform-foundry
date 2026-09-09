# platform-foundry frontend (vendored)

Vendored **unmodified** from
[yurisldk/realworld-react-fsd](https://github.com/yurisldk/realworld-react-fsd)
(MIT) — a RealWorld ("Conduit") frontend: React + TypeScript + React Query
+ Zustand, FSD architecture, orval-generated API client.

Placeholder payload, same as the backend: the platform is the product.
The vendored tree keeps upstream's own multi-stage Dockerfile
(node -> nginx with the `API_URL` build arg) and nginx.conf as-shipped.
Heavy binary assets (screenshots/GIFs) and upstream CI dotfiles were
dropped from the vendor copy; everything else is as-cloned.
