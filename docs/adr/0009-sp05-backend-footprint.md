# ADR-0009: Backend Memory Limits and Self-Hosting Footprint (`SP-05`)

- **Status:** Proposed (pending OCI ARM64 VM benchmark run)
- **Date:** 2026-11-14
- **Reference IDs:** `TC-02`, `TC-17`, `SRV-02`, `SP-05`

## Context

Deep Sky targets lightweight self-hosting on small ARM64 or x86_64 VMs (`deploy/docker-compose.yml`, `TC-02`), running Spring Boot 4 + Java 25, PostgreSQL 17, and Caddy in a tight RAM budget without OOM kills under burst traffic from dozens to a few hundred active couples.

## Decision

The prototype on branch `proto/sp-05` provides reproducible container limits, a profile-gated synthetic benchmark endpoint, and a stdlib Python load driver (`docs/sp-05-backend-footprint.md`):

- **Candidate JVM Profiles (`deploy/docker-compose.sp05.yml`):**
  - Tight (512 MB host): `-Xms64m -Xmx192m -XX:MaxMetaspaceSize=112m -XX:+UseSerialGC -XX:+ExitOnOutOfMemoryError` (`API_MEM_LIMIT=320M`)
  - Balanced (1 GB host, initial recommendation pending VM measurement): `-Xms64m -Xmx256m -XX:MaxMetaspaceSize=128m -XX:+ExitOnOutOfMemoryError` (`API_MEM_LIMIT=512M`, PostgreSQL `DB_MEM_LIMIT=384M`)
  - Extended (2+ GB host): `-Xms128m -Xmx512m -XX:MaxMetaspaceSize=128m` (`API_MEM_LIMIT=768M`)
- **Benchmark Harness (`Sp05BenchmarkController` + `scripts/benchmark_sp05.py`):** Activated strictly under Spring profile `benchmark` (never active in `prod`), simulates concurrent couples writing ciphertext envelopes to PostgreSQL (`sp05_events`) and binary blobs to disk while recording readiness startup latency, `jvm.memory.used`, `process.cpu.usage`, `docker stats` RSS, and HTTP p50/p95/p99 latency.

## Alternatives Considered

- **Leaving `-XX:MaxRAMPercentage` uncalibrated without synthetic PostgreSQL + blob I/O load tests:** Risks unexpected OOM kills on 512 MB / 1 GB ARM64 VMs under media upload spikes.

## Consequences

- **Verified in M1 automation (`proto/sp-05`):** `./mvnw.cmd -B clean verify` passed (10 tests including `Sp05BenchmarkIntegrationTest` against PostgreSQL 17 Testcontainers + `ArchitectureTest` + Actuator metrics exposure) and `scripts/benchmark_sp05.py` CLI validated.
- **Remaining before `G-1`:** Execute `scripts/benchmark_sp05.py` on the target OCI ARM64 VM across the candidate `-Xmx` profiles and fill the measured RAM/CPU/startup table in this ADR to lock minimum self-hosting hardware specs.
