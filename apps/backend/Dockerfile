# Layered Maven build (P4 plan lock: backend Dockerfile is ours).
# deps -> build -> runtime keeps the dependency layer cache-correct:
# source changes rebuild only the build+runtime layers.
# Base images digest-pinned (mutable :21 / :3.9 aliases banned — same
# discipline the no-latest policy enforces on k8s manifests).
FROM maven:3.9-eclipse-temurin-21@sha256:6121cf54876c8bf54fee0d656cb9402ceb766a16fcf47c9a96b51a7a01c80d5c AS deps
WORKDIR /build
COPY pom.xml .
RUN mvn -B dependency:go-offline

FROM deps AS build
COPY src ./src
RUN mvn -B package -DskipTests

FROM eclipse-temurin:21-jre@sha256:21a40fbc3e7d46fa48487450a01c3fd998012fc2659dd955afeb17663142844f AS runtime
RUN useradd --system --uid 10001 spring
USER 10001
WORKDIR /app
COPY --from=build /build/target/*.jar app.jar
EXPOSE 8080
ENTRYPOINT ["java", "-jar", "/app/app.jar"]
