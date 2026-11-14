#!/usr/bin/env python3
"""
Audits Flutter/Dart and Maven dependency licenses for compatibility with the
MIT codebase license (SEC-02, Development Plan 3.1).

Fails on strong copyleft licenses (GPL, AGPL, SSPL, EUPL) unless dual-licensed
with an acceptable permissive/weak-copyleft option (e.g. EPL, Apache-2.0, MIT, BSD)
or accompanied by the GNU Classpath exception.
"""

from __future__ import annotations

import argparse
import json
import os
import re
import subprocess
import sys
import xml.etree.ElementTree as ET
from pathlib import Path
from urllib.parse import unquote, urlparse

FORBIDDEN_UNCONDITIONAL = (
    "agpl",
    "affero",
    "gpl-3",
    "gplv3",
    "gpl-2",
    "gplv2",
    "gnu general public license",
    "sspl",
    "eupl",
)

ACCEPTABLE_INDICATORS = (
    "mit",
    "apache",
    "bsd",
    "isc",
    "zlib",
    "cc0",
    "unlicense",
    "eclipse public license",
    "epl",
    "cddl",
    "mpl",
    "mozilla public license",
    "public domain",
    "classpath-exception",
    "classpath exception",
    "lgpl",
)


def is_license_compatible(license_text: str) -> tuple[bool, str]:
    lower = license_text.lower()
    if not lower.strip():
        return True, "unknown (no license text found)"

    has_forbidden = any(tok in lower for tok in FORBIDDEN_UNCONDITIONAL)
    has_acceptable = any(tok in lower for tok in ACCEPTABLE_INDICATORS)

    # Dual-licensed packages (e.g. EPL-2.0 OR GPL-2.0 WITH Classpath-exception-2.0)
    if "classpath" in lower and "exception" in lower:
        return True, "permissive via Classpath exception"
    if has_forbidden and not has_acceptable:
        return False, "strong copyleft incompatible with MIT"
    if "gpl" in lower and "lgpl" not in lower and not has_acceptable:
        return False, "GPL without permissive dual-license"
    return True, "compatible"


def detect_pub_license(pkg_root: Path) -> str:
    for candidate in ("LICENSE", "LICENSE.md", "LICENSE.txt", "COPYING"):
        p = pkg_root / candidate
        if p.is_file():
            text = p.read_text(encoding="utf-8", errors="replace")
            first_lines = " ".join(text.splitlines()[:12])
            if "mit license" in text.lower() or "permission is hereby granted, free of charge" in text.lower():
                return "MIT"
            if "bsd" in text.lower() or "redistribution and use in source and binary forms" in text.lower():
                return "BSD"
            if "apache license" in text.lower():
                return "Apache-2.0"
            if "gnu general public license" in text.lower():
                return "GPL (" + first_lines[:80] + ")"
            if "mozilla public license" in text.lower():
                return "MPL-2.0"
            return first_lines[:80].strip() or "Custom"
    return "Unknown"


def audit_flutter(repo_root: Path) -> tuple[list[tuple[str, str, str]], list[str]]:
    pkg_cfg = repo_root / ".dart_tool" / "package_config.json"
    if not pkg_cfg.is_file():
        subprocess.run(["flutter", "pub", "get"], cwd=repo_root, check=True)

    data = json.loads(pkg_cfg.read_text(encoding="utf-8"))
    results: list[tuple[str, str, str]] = []
    failures: list[str] = []

    for pkg in data.get("packages", []):
        name = pkg["name"]
        if name == "deep_sky":
            continue
        root_uri = pkg["rootUri"]
        if root_uri.startswith("file://"):
            parsed = urlparse(root_uri)
            path_str = unquote(parsed.path)
            if os.name == "nt" and path_str.startswith("/") and len(path_str) > 2 and path_str[2] == ":":
                path_str = path_str[1:]
            pkg_root = Path(path_str)
        else:
            pkg_root = (pkg_cfg.parent / root_uri).resolve()

        lic = detect_pub_license(pkg_root)
        ok, reason = is_license_compatible(lic)
        results.append((name, lic, reason))
        if not ok:
            failures.append(f"Flutter package '{name}': {lic} ({reason})")

    results.sort(key=lambda r: r[0])
    return results, failures


def _pom_path(m2_repo: Path, group: str, artifact: str, version: str) -> Path:
    return m2_repo / Path(*group.split(".")) / artifact / version / f"{artifact}-{version}.pom"


def _extract_pom_licenses(m2_repo: Path, group: str, artifact: str, version: str, depth: int = 0) -> list[str]:
    if depth > 5:
        return []
    pom_file = _pom_path(m2_repo, group, artifact, version)
    if not pom_file.is_file():
        return []
    try:
        tree = ET.parse(pom_file)
    except ET.ParseError:
        return []
    root = tree.getroot()
    ns = ""
    if root.tag.startswith("{"):
        ns = root.tag[: root.tag.index("}") + 1]

    licenses = [
        el.text.strip()
        for el in root.findall(f"./{ns}licenses/{ns}license/{ns}name")
        if el.text and el.text.strip()
    ]
    if licenses:
        return licenses

    parent = root.find(f"./{ns}parent")
    if parent is not None:
        pg = parent.findtext(f"{ns}groupId", "").strip()
        pa = parent.findtext(f"{ns}artifactId", "").strip()
        pv = parent.findtext(f"{ns}version", "").strip()
        if pg and pa and pv:
            return _extract_pom_licenses(m2_repo, pg, pa, pv, depth + 1)
    return []


def audit_maven(repo_root: Path) -> tuple[list[tuple[str, str, str, str]], list[str]]:
    server_dir = repo_root / "server"
    deps_out = server_dir / "target" / "dependency-list.txt"
    deps_out.parent.mkdir(parents=True, exist_ok=True)
    mvnw = "mvnw.cmd" if os.name == "nt" else "./mvnw"
    subprocess.run(
        [str(server_dir / mvnw), "-B", "-q", f"-DoutputFile={deps_out}", "dependency:list"],
        cwd=server_dir,
        check=True,
    )

    m2_repo = Path.home() / ".m2" / "repository"
    dep_re = re.compile(r"^\s*([^:\s]+):([^:\s]+):[^:\s]+:([^:\s]+):([^:\s]+)")
    seen: dict[tuple[str, str, str], str] = {}
    for line in deps_out.read_text(encoding="utf-8", errors="replace").splitlines():
        m = dep_re.match(line)
        if m:
            g, a, v, scope = m.groups()
            key = (g, a, v)
            if key not in seen or scope != "test":
                seen[key] = scope

    results: list[tuple[str, str, str, str]] = []
    failures: list[str] = []
    for (g, a, v), scope in sorted(seen.items()):
        lics = _extract_pom_licenses(m2_repo, g, a, v)
        lic_str = "; ".join(lics) if lics else "Unknown"
        ok, reason = is_license_compatible(lic_str)
        results.append((f"{g}:{a}:{v}", scope, lic_str, reason))
        if not ok:
            failures.append(f"Maven artifact '{g}:{a}:{v}' ({scope}): {lic_str} ({reason})")

    return results, failures


def write_inventory(
    out_path: Path,
    flutter_results: list[tuple[str, str, str]],
    maven_results: list[tuple[str, str, str, str]],
) -> None:
    lines = [
        "# Dependency Licenses Inventory",
        "",
        "Reference IDs: `SEC-02`, `PD-13`, [Piano di sviluppo](development-plan.md) section 3.1.",
        "",
        "Generated via `python scripts/check-licenses.py --write-doc docs/dependencies-licenses.md`.",
        "",
        f"## Flutter / Dart Packages ({len(flutter_results)})",
        "",
        "| Package | Detected License | Status |",
        "| :-- | :-- | :-- |",
    ]
    for name, lic, reason in flutter_results:
        lines.append(f"| `{name}` | {lic} | {reason} |")

    lines.extend([
        "",
        f"## Backend Maven Artifacts ({len(maven_results)})",
        "",
        "| Coordinate | Scope | POM License(s) | Status |",
        "| :-- | :-- | :-- | :-- |",
    ])
    for coord, scope, lic, reason in maven_results:
        lines.append(f"| `{coord}` | `{scope}` | {lic} | {reason} |")

    lines.append("")
    out_path.write_text("\n".join(lines), encoding="utf-8")


def main() -> int:
    parser = argparse.ArgumentParser(description="Check dependency licenses for MIT compatibility.")
    parser.add_argument("--skip-flutter", action="store_true")
    parser.add_argument("--skip-maven", action="store_true")
    parser.add_argument("--write-doc", help="Write Markdown inventory to this path")
    args = parser.parse_args()

    repo_root = Path(__file__).resolve().parent.parent
    flutter_results: list[tuple[str, str, str]] = []
    maven_results: list[tuple[str, str, str, str]] = []
    failures: list[str] = []

    if not args.skip_flutter:
        flutter_results, f_fail = audit_flutter(repo_root)
        failures.extend(f_fail)
        print(f"Checked {len(flutter_results)} Flutter/Dart packages.")

    if not args.skip_maven:
        maven_results, m_fail = audit_maven(repo_root)
        failures.extend(m_fail)
        print(f"Checked {len(maven_results)} Maven artifacts.")

    if args.write_doc:
        write_inventory((repo_root / args.write_doc).resolve(), flutter_results, maven_results)
        print(f"Wrote license inventory to {args.write_doc}")

    if failures:
        print("\nIncompatible licenses found:", file=sys.stderr)
        for item in failures:
            print(f" - {item}", file=sys.stderr)
        return 1

    print("License compatibility check PASSED.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
