# Layered Maven build (P4 plan lock: backend Dockerfile is ours).
# deps -> build -> runtime keeps the dependency layer cache-correct:
# source changes rebuild only the build+runtime layers.
# Base images pinned to MANIFEST-LIST digests (platform-neutral: the
# registry resolves the per-arch manifest at pull time, so the same
# digest builds on arm64 workstations and amd64 CI runners — a
# per-arch digest would break the latter, as review round-2's first
# attempt showed).
FROM maven:3.9-eclipse-temurin-21@sha256:8f6ac126f7810bb5549c4cd122d2bf0e9cda5bdeb0838aa928f09e779fd8bef8 AS deps
WORKDIR /build
COPY pom.xml .
RUN mvn -B dependency:go-offline

FROM deps AS build
COPY src ./src
RUN mvn -B package -DskipTests

FROM eclipse-temurin:21-jre@sha256:7a65df4b22d2de92d4e04056e884f3b9122d70b21e2847fd66084278bd0ce037 AS runtime
RUN useradd --system --uid 10001 spring
USER 10001
WORKDIR /app
COPY --from=build /build/target/*.jar app.jar
EXPOSE 8080
ENTRYPOINT ["java", "-jar", "/app/app.jar"]
