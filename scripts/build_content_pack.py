#!/usr/bin/env python3
"""
Builds optimized runtime derivative PNGs from high-resolution master artwork in
content/masters/ into content/packs/<pack>/assets/ according to DD-10 specifications
(S2-CNT-01, A-02, A-04, DD-10).

Uses scripts/ImagePackTool.java (JDK standard library) for premultiplied bicubic
resizing and budget-aware PNG optimization, plus optional oxipng if installed.
"""

from __future__ import annotations

import argparse
import shutil
import subprocess
import sys
from pathlib import Path

# Target derivative dimensions and size budgets (bytes) from m3-operative-plan.md §6.3
ASSET_SPECS: dict[str, tuple[int, int, int]] = {
    "floor.png": (1440, 960, 400 * 1024),
    "window_frame.png": (450, 600, 250 * 1024),
    "window_sky_day.png": (450, 600, 250 * 1024),
    "window_sky_twilight.png": (450, 600, 250 * 1024),
    "window_sky_night.png": (450, 600, 250 * 1024),
    "rug.png": (900, 360, 250 * 1024),
    "couch.png": (960, 540, 250 * 1024),
    "floor_lamp_calm.png": (360, 720, 250 * 1024),
    "floor_lamp_lit.png": (360, 720, 250 * 1024),
    "couple_on_couch.png": (640, 480, 250 * 1024),
    "pet_sleeping.png": (384, 288, 250 * 1024),
}


def main() -> int:
    parser = argparse.ArgumentParser(description="Build optimized Deep Sky content pack derivatives.")
    parser.add_argument("--masters", required=True, help="Directory with high-res master PNGs")
    parser.add_argument("--out-assets", required=True, help="Output assets/ directory inside pack")
    args = parser.parse_args()

    repo_root = Path(__file__).resolve().parent.parent
    tool_path = repo_root / "scripts" / "ImagePackTool.java"
    masters_dir = Path(args.masters).resolve()
    out_assets = Path(args.out_assets).resolve()
    out_assets.mkdir(parents=True, exist_ok=True)
    oxipng = shutil.which("oxipng")

    master_files = sorted(masters_dir.glob("*.png"))
    if not master_files:
        print(f"No master PNG files found in {masters_dir}", file=sys.stderr)
        return 1

    total_bytes = 0
    errors: list[str] = []
    for master in master_files:
        spec = ASSET_SPECS.get(master.name)
        if spec is None:
            print(f"Skipping unknown asset '{master.name}' (add to ASSET_SPECS if intentional).")
            continue
        target_w, target_h, max_bytes = spec
        out_path = out_assets / master.name
        subprocess.run(
            [
                "java",
                str(tool_path),
                "resize",
                "--in",
                str(master),
                "--out",
                str(out_path),
                "--width",
                str(target_w),
                "--height",
                str(target_h),
                "--max-bytes",
                str(max_bytes),
            ],
            check=True,
        )
        if oxipng:
            subprocess.run([oxipng, "-o", "4", "--strip", "safe", str(out_path)], check=True)
        size = out_path.stat().st_size
        total_bytes += size
        print(f"  Verified {out_path.name}: {size:,} bytes (budget <= {max_bytes:,} bytes)")
        if size > max_bytes:
            errors.append(f"{out_path.name}: {size} bytes exceeds DD-10 budget {max_bytes} bytes")

    print(f"Total runtime assets size: {total_bytes:,} bytes ({total_bytes / 1024:.1f} KB)")
    if total_bytes > int(1.8 * 1024 * 1024):
        errors.append(f"Total pack size {total_bytes} exceeds DD-10 budget of 1.8 MB")

    if errors:
        for e in errors:
            print(f"ERROR: {e}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
