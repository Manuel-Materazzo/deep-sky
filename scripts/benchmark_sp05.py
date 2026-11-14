#!/usr/bin/env python3
"""
SP-05 synthetic load generator and JVM footprint sampler (TC-02, TC-17).
Uses Python standard library only so it runs cleanly on an ARM64 VM or CI runner.
"""

from __future__ import annotations

import argparse
import concurrent.futures
import json
import os
import statistics
import subprocess
import time
import urllib.error
import urllib.request


def fetch_json(url: str) -> dict:
    with urllib.request.urlopen(url, timeout=5) as resp:
        return json.loads(resp.read().decode("utf-8"))


def post_octet(url: str, payload: bytes) -> float:
    req = urllib.request.Request(
        url,
        data=payload,
        method="POST",
        headers={"Content-Type": "application/octet-stream"},
    )
    start = time.perf_counter()
    with urllib.request.urlopen(req, timeout=15) as resp:
        resp.read()
    return (time.perf_counter() - start) * 1000.0


def sample_metric(base_url: str, name: str) -> float | None:
    try:
        data = fetch_json(f"{base_url}/actuator/metrics/{name}")
        for m in data.get("measurements", []):
            if m.get("statistic") in ("VALUE", "TOTAL_TIME", "COUNT"):
                return float(m["value"])
    except Exception:
        return None
    return None


def sample_docker_mem(container: str | None) -> str:
    if not container:
        return "n/a"
    try:
        out = subprocess.check_output(
            ["docker", "stats", "--no-stream", "--format", "{{.MemUsage}} | CPU {{.CPUPerc}}", container],
            text=True,
            timeout=5,
        ).strip()
        return out or "n/a"
    except Exception:
        return "n/a"


def wait_for_readiness(base_url: str, timeout_s: float) -> float:
    start = time.perf_counter()
    deadline = start + timeout_s
    while time.perf_counter() < deadline:
        try:
            data = fetch_json(f"{base_url}/actuator/health/readiness")
            if data.get("status") == "UP":
                return (time.perf_counter() - start) * 1000.0
        except Exception:
            pass
        time.sleep(0.25)
    raise TimeoutError(f"Server not ready within {timeout_s}s")


def percentile(values: list[float], pct: float) -> float:
    if not values:
        return 0.0
    ordered = sorted(values)
    idx = min(len(ordered) - 1, max(0, int(round((pct / 100.0) * (len(ordered) - 1)))))
    return ordered[idx]


def main() -> int:
    parser = argparse.ArgumentParser(description="SP-05 backend load & footprint benchmark")
    parser.add_argument("--base-url", default="http://127.0.0.1:8080")
    parser.add_argument("--couples", type=int, default=100)
    parser.add_argument("--events-per-couple", type=int, default=20)
    parser.add_argument("--blobs-per-couple", type=int, default=2)
    parser.add_argument("--blob-kb", type=int, default=128)
    parser.add_argument("--workers", type=int, default=16)
    parser.add_argument("--container", default=None, help="Optional Docker container name for RSS sampling")
    parser.add_argument("--ready-timeout", type=float, default=60.0)
    args = parser.parse_args()

    base = args.base_url.rstrip("/")
    ready_ms = wait_for_readiness(base, args.ready_timeout)

    idle_heap_mb = (sample_metric(base, "jvm.memory.used") or 0.0) / (1024 * 1024)
    idle_threads = sample_metric(base, "jvm.threads.live")
    idle_docker = sample_docker_mem(args.container)

    event_payload = os.urandom(512)
    blob_payload = os.urandom(args.blob_kb * 1024)

    jobs: list[tuple[str, bytes]] = []
    for c in range(args.couples):
        cid = f"couple-{c:04d}"
        for _ in range(args.events_per_couple):
            jobs.append((f"{base}/internal/benchmark/event?coupleId={cid}", event_payload))
        for _ in range(args.blobs_per_couple):
            jobs.append((f"{base}/internal/benchmark/blob", blob_payload))

    latencies_ms: list[float] = []
    failures = 0
    wall_start = time.perf_counter()
    with concurrent.futures.ThreadPoolExecutor(max_workers=args.workers) as pool:
        futures = [pool.submit(post_octet, url, body) for url, body in jobs]
        for fut in concurrent.futures.as_completed(futures):
            try:
                latencies_ms.append(fut.result())
            except Exception:
                failures += 1
    wall_s = time.perf_counter() - wall_start

    peak_heap_mb = (sample_metric(base, "jvm.memory.used") or 0.0) / (1024 * 1024)
    cpu_pct = (sample_metric(base, "process.cpu.usage") or 0.0) * 100.0
    load_docker = sample_docker_mem(args.container)

    report = {
        "couples": args.couples,
        "requestsTotal": len(jobs),
        "failures": failures,
        "readinessWaitMs": round(ready_ms, 1),
        "wallSeconds": round(wall_s, 2),
        "throughputReqPerSec": round(len(jobs) / max(wall_s, 0.001), 1),
        "latencyMs": {
            "p50": round(percentile(latencies_ms, 50), 2),
            "p95": round(percentile(latencies_ms, 95), 2),
            "p99": round(percentile(latencies_ms, 99), 2),
            "mean": round(statistics.fmean(latencies_ms), 2) if latencies_ms else 0.0,
        },
        "jvmMemoryUsedIdleMb": round(idle_heap_mb, 2),
        "jvmMemoryUsedAfterLoadMb": round(peak_heap_mb, 2),
        "jvmLiveThreadsIdle": idle_threads,
        "processCpuPercent": round(cpu_pct, 2),
        "dockerStatsIdle": idle_docker,
        "dockerStatsLoad": load_docker,
    }
    print(json.dumps(report, indent=2))
    return 1 if failures > 0 else 0


if __name__ == "__main__":
    raise SystemExit(main())
