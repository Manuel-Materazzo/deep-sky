# SP-05 · Footprint del backend e profili JVM (`TC-02`, `TC-17`, `SRV-02`)

Specifiche di test e profili per il prototipo `proto/sp-05` (`docs/m0-m1-operative-plan.md`).

## 1. Profili JVM da confrontare sulla VM ARM64

Utilizzando `deploy/docker-compose.yml` + `deploy/docker-compose.sp05.yml`:

1. **Profilo ristretto (512 MB VM):**
   `JAVA_TOOL_OPTIONS="-Xms64m -Xmx192m -XX:MaxMetaspaceSize=112m -XX:+UseSerialGC -XX:+ExitOnOutOfMemoryError"` (`API_MEM_LIMIT=320M`)
2. **Profilo bilanciato (1 GB VM — consigliato per produzione iniziale):**
   `JAVA_TOOL_OPTIONS="-Xms64m -Xmx256m -XX:MaxMetaspaceSize=128m -XX:+ExitOnOutOfMemoryError"` (`API_MEM_LIMIT=512M`)
3. **Profilo esteso (2+ GB VM / picco centinaia di coppie):**
   `JAVA_TOOL_OPTIONS="-Xms128m -Xmx512m -XX:MaxMetaspaceSize=128m -XX:+ExitOnOutOfMemoryError"` (`API_MEM_LIMIT=768M`)

## 2. Procedura sulla VM ARM64 (Oracle Cloud Ampere / Raspberry Pi 4+)

```bash
docker compose -f deploy/docker-compose.yml -f deploy/docker-compose.sp05.yml up -d --build
python3 scripts/benchmark_sp05.py \
  --base-url http://127.0.0.1:8080 \
  --couples 150 \
  --events-per-couple 20 \
  --blobs-per-couple 2 \
  --blob-kb 128 \
  --container deep-sky-api-1
```

Al termine delle misure, riportare in ADR:
- tempo di avvio fino a `/actuator/health/readiness=UP`
- memoria container a riposo e sotto carico (`docker stats`) e `jvm.memory.used`
- CPU di picco e latenza p50/p95/p99 per 50 / 150 / 300 coppie simulate
- requisiti minimi confermati (RAM totale VM, disco, limite `-Xmx` e `API_MEM_LIMIT`).
