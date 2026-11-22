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

# Size budgets from m3-operative-plan.md §6.3 ("KB" in the plan is interpreted as KiB = 1024 bytes;
# scripts/validate_content.py uses the same constants and ImagePackTool receives exact bytes).
KIB = 1024

# Target derivative dimensions and size budgets (bytes) from m3-operative-plan.md §6.3
ASSET_SPECS: dict[str, tuple[int, int, int]] = {
    "floor.png": (1440, 960, 400 * KIB),
    "window_frame.png": (450, 600, 250 * KIB),
    "window_sky_day.png": (450, 600, 250 * KIB),
    "window_sky_twilight.png": (450, 600, 250 * KIB),
    "window_sky_night.png": (450, 600, 250 * KIB),
    "rug.png": (900, 360, 250 * KIB),
    "couch.png": (960, 540, 250 * KIB),
    "floor_lamp_calm.png": (360, 720, 250 * KIB),
    "floor_lamp_lit.png": (360, 720, 250 * KIB),
    "couple_on_couch.png": (640, 480, 250 * KIB),
    "pet_sleeping.png": (384, 288, 250 * KIB),
}


def main() -> int:
    parser = argparse.ArgumentParser(description="Build optimized Deep Sky content pack derivatives.")
    parser.add_argument("--masters", required=True, help="Directory with high-res master PNGs")
    parser.add_argument("--out-assets", required=True, help="Output assets/ directory inside pack")
    parser.add_argument(
        "--allow-palette",
        action="store_true",
        help="EXPLICIT lossy opt-in: when the lossless RGBA PNG exceeds the budget, fall back to a "
        "256-color indexed PNG instead of failing. Off by default (plan section 6.3 mandates lossless).",
    )
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
        cmd = [
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
        ]
        if args.allow_palette:
            cmd.append("--allow-palette")
        result = subprocess.run(cmd)
        if result.returncode != 0:
            errors.append(
                f"{master.name}: lossless output over budget {max_bytes} bytes ({max_bytes // KIB} KiB); "
                "rerun with --allow-palette only if lossy PNG8 quantization is explicitly accepted"
            )
            continue
        if oxipng:
            subprocess.run([oxipng, "-o", "4", "--strip", "safe", str(out_path)], check=True)
        size = out_path.stat().st_size
        total_bytes += size
        print(f"  Verified {out_path.name}: {size:,} bytes (budget <= {max_bytes:,} bytes = {max_bytes // KIB} KiB)")
        if size > max_bytes:
            errors.append(f"{out_path.name}: {size} bytes exceeds DD-10 budget {max_bytes} bytes")

    print(f"Total runtime assets size: {total_bytes:,} bytes ({total_bytes / KIB:.1f} KiB)")
    if total_bytes > int(1.8 * 1024 * KIB):
        errors.append(f"Total pack size {total_bytes} exceeds DD-10 budget of 1.8 MB")

    if errors:
        for e in errors:
            print(f"ERROR: {e}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
