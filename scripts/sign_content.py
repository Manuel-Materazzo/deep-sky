#!/usr/bin/env python3
"""
Computes SHA-256 hashes of all files in a content pack and signs the resulting
pack-checksums.json manifest using scripts/Ed25519Tool.java (CNT-01, TC-10, S2-CTR-01, S2-CNT-01).

The signature file uses the single-line format `<keyId>:<base64-ed25519-sig>` so clients
can select the trusted Ed25519 public key and verify the raw bytes of pack-checksums.json
strictly BEFORE parsing any JSON (G5-07).
"""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import subprocess
import sys
from pathlib import Path

from validate_content import is_safe_relative_asset_path, validate_manifest

KEY_ID_RE = re.compile(r"^[a-z0-9][a-z0-9_-]{0,31}$")


def sha256_file(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(65536), b""):
            h.update(chunk)
    return h.hexdigest()


def main() -> int:
    parser = argparse.ArgumentParser(description="Hash and sign a Deep Sky content pack.")
    parser.add_argument("--pack", required=True, help="Path to content pack directory (must contain manifest.json)")
    parser.add_argument("--key", required=True, help="Path to Ed25519 private key (PKCS#8 base64)")
    parser.add_argument("--key-id", default="v1", help="Key identifier bound into pack-checksums.json and .sig (default: v1)")
    parser.add_argument("--pub", help="Optional Ed25519 public key (X.509 base64) to verify signature")
    parser.add_argument("--out-dir", required=True, help="Directory to write pack-checksums.json and signature")
    args = parser.parse_args()

    key_id = args.key_id.strip()
    if not KEY_ID_RE.match(key_id):
        print(f"Invalid --key-id '{key_id}' (expected ^[a-z0-9][a-z0-9_-]{{0,31}}$)", file=sys.stderr)
        return 1

    pack_dir = Path(args.pack).resolve()
    manifest_path = pack_dir / "manifest.json"
    if not manifest_path.is_file():
        print(f"Missing manifest.json in {pack_dir}", file=sys.stderr)
        return 1

    errors = validate_manifest(manifest_path, require_assets=True)
    if errors:
        print("Manifest validation failed:", file=sys.stderr)
        for e in errors:
            print(f" - {e}", file=sys.stderr)
        return 1

    manifest_data = json.loads(manifest_path.read_text(encoding="utf-8"))
    files = {}
    for file_path in sorted(p for p in pack_dir.rglob("*") if p.is_file()):
        rel = file_path.relative_to(pack_dir).as_posix()
        if rel in ("pack-checksums.json", "pack-checksums.json.sig"):
            continue
        if not is_safe_relative_asset_path(rel):
            print(f"Unsafe file path inside pack: '{rel}'", file=sys.stderr)
            return 1
        files[rel] = {
            "sha256": sha256_file(file_path),
            "sizeBytes": file_path.stat().st_size,
        }

    out_dir = Path(args.out_dir).resolve()
    out_dir.mkdir(parents=True, exist_ok=True)
    checksums_path = out_dir / "pack-checksums.json"
    raw_sig_path = out_dir / ".pack-checksums.raw.sig"
    sig_path = out_dir / "pack-checksums.json.sig"

    payload = {
        "schemaVersion": 1,
        "keyId": key_id,
        "packId": manifest_data["packId"],
        "packVersion": manifest_data["packVersion"],
        "minAppProtocol": manifest_data["minAppProtocol"],
        "files": files,
    }
    checksums_path.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")

    tool_path = Path(__file__).resolve().parent / "Ed25519Tool.java"
    subprocess.run(
        ["java", str(tool_path), "sign", "--key", args.key, "--in", str(checksums_path), "--out", str(raw_sig_path)],
        check=True,
    )
    sig_b64 = raw_sig_path.read_text(encoding="utf-8").strip()
    sig_path.write_text(f"{key_id}:{sig_b64}\n", encoding="utf-8")

    if args.pub:
        subprocess.run(
            ["java", str(tool_path), "verify", "--pub", args.pub, "--in", str(checksums_path), "--sig", str(raw_sig_path)],
            check=True,
        )
    raw_sig_path.unlink(missing_ok=True)

    print(f"Pack signed (keyId={key_id}): {checksums_path} + {sig_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
