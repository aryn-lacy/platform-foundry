package com.marcusmonteirodesouza.realworld;

import org.junit.jupiter.api.Test;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.context.DynamicPropertyRegistry;
import org.springframework.test.context.DynamicPropertySource;
import org.testcontainers.containers.GenericContainer;
import org.testcontainers.containers.PostgreSQLContainer;
import org.testcontainers.junit.jupiter.Container;
import org.testcontainers.junit.jupiter.Testcontainers;
import org.testcontainers.utility.DockerImageName;
import org.testcontainers.utility.MountableFile;

/**
 * Platform integration test (ours, not upstream's): boots the full Spring
 * context against ephemeral Postgres + Keycloak via Testcontainers — the
 * same dependency set the docker-compose stack provides locally and EKS
 * provides in production.
 *
 * The app resolves EVERY config value from environment placeholders (see
 * .env.template) — in production they arrive via the Secrets Store CSI
 * driver. The test supplies the full env surface, mirroring that contract:
 * only the Keycloak URL, datasource coordinates, and issuer differ (they
 * point at the containers). Keycloak imports a minimal realworld realm
 * (realm + realworld-backend client), mirroring the platform's
 * realm-as-code posture, so OIDC discovery resolves.
 */
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
@ActiveProfiles("test")
@Testcontainers
class PlatformIntegrationTests {

    @Container
    static PostgreSQLContainer<?> postgres =
            new PostgreSQLContainer<>(DockerImageName.parse("postgres:16-alpine"))
                    .withDatabaseName("realworld")
                    .withUsername("realworld")
                    .withPassword("realworld");

    @Container
    static GenericContainer<?> keycloak =
            new GenericContainer<>(DockerImageName.parse("quay.io/keycloak/keycloak:26.0"))
                    .withExposedPorts(8080)
                    .withCommand(
                            "start-dev",
                            "--http-enabled=true",
                            "--hostname-strict=false",
                            "--import-realm")
                    .withCopyFileToContainer(
                            MountableFile.forClasspathResource("realworld-realm.json"),
                            "/opt/keycloak/data/import/realworld-realm.json");

    @DynamicPropertySource
    static void registerProps(DynamicPropertyRegistry registry) {
        String keycloakUrl =
                "http://%s:%d".formatted(keycloak.getHost(), keycloak.getFirstMappedPort());

        // Full env surface (application.properties resolves all of these;
        // values mirror .env.template / the compose stack)
        registry.add("PORT", () -> "8080");
        registry.add("KEYCLOAK_REALM", () -> "realworld");
        registry.add("KEYCLOAK_REALM_ADMIN", () -> "realworld_admin");
        registry.add("KEYCLOAK_REALM_ADMIN_PASSWORD", () -> "realworld_admin");
        registry.add("KEYCLOAK_REALM_CLIENT_ID", () -> "realworld-backend");
        registry.add("KEYCLOAK_REALM_CLIENT_SECRET", () -> "test-client-secret");
        registry.add("KEYCLOAK_SERVER_URL", () -> keycloakUrl);
        registry.add("APP_DB", () -> "realworld");
        registry.add("APP_DB_USERNAME", () -> "realworld");
        registry.add("APP_DB_PASSWORD", () -> "realworld");

        // Container-resolved coordinates (higher precedence than the
        // placeholder-composed values in application.properties)
        registry.add(
                "spring.datasource.url",
                () -> "jdbc:postgresql://%s:%d/realworld"
                        .formatted(postgres.getHost(), postgres.getFirstMappedPort()));
        registry.add(
                "spring.security.oauth2.resourceserver.jwt.issuer-uri",
                () -> "%s/realms/realworld".formatted(keycloakUrl));
    }

    @Test
    void contextLoadsWithRealDependencies() {
        // The Spring context loading IS the test: datasource connects,
        // the JWT issuer URI resolves against live Keycloak (realm
        // imported), and every bean wires against the full env contract.
    }
}
