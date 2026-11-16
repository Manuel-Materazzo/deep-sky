# ADR-0002: Java and Spring Boot Baseline Versions

- **Status:** Accepted
- **Date:** 2026-11-14
- **Reference IDs:** `SRV-01`, `TC-02`, `TC-03`

## Context

The backend is a thin, self-hostable service storing only encrypted payloads/blobs and minimal operational metadata (`TC-02`, `TC-05`). It must run smoothly on both ARM64 (OCI Ampere VM) and AMD64 hosts inside Docker Compose with explicit memory limits (`TC-03`, `SP-05`).

## Decision

We standardize on:

- **Java:** **25** (LTS, Eclipse Temurin runtime image `eclipse-temurin:25-jre-alpine` / `25-jdk-alpine`)
- **Spring Boot:** **4.1.2** (`spring-boot-starter-parent`)
- **Database:** **PostgreSQL 17** (`postgres:17-alpine`) with **Flyway** schema migrations
- **Architecture & Integration Verification:** **ArchUnit** (JUnit 5) for modular boundary enforcement and **Testcontainers** with real PostgreSQL for integration tests (`SRV-01`)

## Alternatives Considered

- **Java 21 + Spring Boot 3.x:** Pros: longer field history across third-party tutorials. Cons: misses Java 25 LTS and Spring Boot 4 baseline already initialized in `server/pom.xml`.
- **Go + SQLite:** Previously evaluated and rejected by promoter (`TC-02`) in favor of Java/Spring Boot + PostgreSQL due to maintainer expertise and existing OCI backup scripts.

## Consequences

- Multi-arch builds (`linux/amd64`, `linux/arm64`) must use a JDK/JRE 25 base image supporting both architectures.
- Initial AMD64 baseline (`SRV-02`, measured locally with `deploy/docker-compose.yml` under `prod` profile + Docker secrets):
  - Runtime image size (`eclipse-temurin:25-jre-alpine`): `291,504,306` bytes (~278 MiB)
  - Startup to healthy (`api` + `db`): <= 15s (`api` healthy within 15s)
  - Idle memory (`docker stats --no-stream`): `220.9 MiB / 512 MiB` (`api`), `72.68 MiB / 256 MiB` (`db`) — limits as of this baseline; the current defaults are `API_MEM_LIMIT=512M` / `DB_MEM_LIMIT=384M` per [ADR-0009](0009-sp05-backend-footprint.md)
- ARM64 OCI VM footprint and load benchmarks will be measured explicitly in `SP-05`.
