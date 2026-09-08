# Layered Maven build (P4 plan lock: backend Dockerfile is ours).
# deps -> build -> runtime keeps the dependency layer cache-correct:
# source changes rebuild only the build+runtime layers.
FROM maven:3.9-eclipse-temurin-21 AS deps
WORKDIR /build
COPY pom.xml .
RUN mvn -B dependency:go-offline

FROM deps AS build
COPY src ./src
RUN mvn -B package -DskipTests

FROM eclipse-temurin:21-jre AS runtime
RUN useradd --system --uid 10001 spring
USER 10001
WORKDIR /app
COPY --from=build /build/target/*.jar app.jar
EXPOSE 8080
ENTRYPOINT ["java", "-jar", "/app/app.jar"]
