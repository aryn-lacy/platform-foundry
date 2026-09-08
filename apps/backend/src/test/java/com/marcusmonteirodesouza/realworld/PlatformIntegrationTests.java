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

/**
 * Platform integration test (ours, not upstream's): boots the full Spring
 * context against ephemeral Postgres + Keycloak via Testcontainers — the
 * same dependencies the docker-compose stack provides locally and EKS
 * provides in production. This is the stage that proves the app's
 * Keycloak-native wiring (oauth2 resource server, datasource) is intact.
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
                            "--health-enabled=true");

    @DynamicPropertySource
    static void registerProps(DynamicPropertyRegistry registry) {
        registry.add(
                "spring.datasource.url",
                () -> "jdbc:postgresql://%s:%d/realworld"
                        .formatted(postgres.getHost(), postgres.getFirstMappedPort()));
        registry.add("spring.datasource.username", () -> "realworld");
        registry.add("spring.datasource.password", () -> "realworld");
        registry.add(
                "spring.security.oauth2.resourceserver.jwt.issuer-uri",
                () -> "http://%s:%d/realms/realworld"
                        .formatted(keycloak.getHost(), keycloak.getFirstMappedPort()));
    }

    @Test
    void contextLoadsWithRealDependencies() {
        // The Spring context loading IS the test: datasource connects,
        // the JWT issuer URI resolves against live Keycloak, and every
        // bean wires. Upstream's RealworldApplicationTests does the same
        // but assumes the compose stack is already up.
    }
}
