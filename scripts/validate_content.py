#!/usr/bin/env python3
"""
Validates Deep Sky scene pack manifests against content/schemas/scene-manifest.schema.json
and enforces semantic, path-safety, asset-existence, and DD-10 size-budget invariants
(CNT-01, TC-08, TC-09, DD-10, S2-CNT-01).
Uses Python standard library only so it runs offline in any environment.
"""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path, PurePosixPath

PACK_ID_RE = re.compile(r"^[a-z0-9][a-z0-9_-]{1,63}$")
LAYER_ID_RE = re.compile(r"^[a-z0-9][a-z0-9_-]{0,63}$")
SEMVER_RE = re.compile(r"^(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)$")
ASPECT_RE = re.compile(r"^[1-9]\d*:[1-9]\d*$")

ALLOWED_ANIM_TYPES = {"fade", "translateY", "translateX", "scale", "rotate"}
ALLOWED_CURVES = {"linear", "easeInOut", "easeIn", "easeOut"}
ALLOWED_REPEATS = {"none", "loop", "reverse"}

# DD-10 runtime budgets (applied to packs shipping real assets/)
MAX_FLOOR_ASSET_BYTES = 400 * 1024
MAX_OBJECT_ASSET_BYTES = 250 * 1024
MAX_PACK_TOTAL_BYTES = int(1.8 * 1024 * 1024)


def _is_int(v: object) -> bool:
    return isinstance(v, int) and not isinstance(v, bool)


def _is_num(v: object) -> bool:
    return isinstance(v, (int, float)) and not isinstance(v, bool)


def is_safe_relative_asset_path(raw: str) -> bool:
    """Rejects absolute paths, backslashes, drive letters, control chars, or '..' segments."""
    if not raw or raw != raw.strip():
        return False
    if "\\" in raw or ":" in raw or "\x00" in raw:
        return False
    if raw.startswith("/"):
        return False
    parts = PurePosixPath(raw).parts
    if not parts:
        return False
    for part in parts:
        if part in ("", ".", ".."):
            return False
    return True


def _check_keys(obj: dict, required: set[str], optional: set[str], ctx: str, errors: list[str]) -> None:
    keys = set(obj.keys())
    for r in sorted(required - keys):
        errors.append(f"{ctx}: missing required key '{r}'")
    for extra in sorted(keys - (required | optional)):
        errors.append(f"{ctx}: unexpected key '{extra}'")


def _check_localized(obj: object, ctx: str, errors: list[str]) -> None:
    if not isinstance(obj, dict):
        errors.append(f"{ctx}: must be an object with 'it' and 'en'")
        return
    _check_keys(obj, {"it", "en"}, set(), ctx, errors)
    for lang in ("it", "en"):
        val = obj.get(lang)
        if not isinstance(val, str) or len(val.strip()) == 0:
            errors.append(f"{ctx}.{lang}: must be a non-empty string")


def _check_rect(obj: object, ctx: str, errors: list[str]) -> None:
    if not isinstance(obj, dict):
        errors.append(f"{ctx}: must be an object")
        return
    _check_keys(obj, {"x", "y", "width", "height"}, set(), ctx, errors)
    for axis in ("x", "y"):
        v = obj.get(axis)
        if not _is_num(v) or not (0.0 <= float(v) <= 1.0):
            errors.append(f"{ctx}.{axis}: must be in [0.0, 1.0]")
    for dim in ("width", "height"):
        v = obj.get(dim)
        if not _is_num(v) or not (0.0 < float(v) <= 1.0):
            errors.append(f"{ctx}.{dim}: must be in (0.0, 1.0]")


def validate_manifest(manifest_path: Path, *, require_assets: bool | None = None) -> list[str]:
    errors: list[str] = []
    pack_dir = manifest_path.parent
    try:
        data = json.loads(manifest_path.read_text(encoding="utf-8"))
    except Exception as exc:
        return [f"{manifest_path}: invalid JSON ({exc})"]

    if not isinstance(data, dict):
        return [f"{manifest_path}: root must be a JSON object"]

    ctx = str(manifest_path)
    _check_keys(
        data,
        {"schemaVersion", "packId", "packVersion", "minAppProtocol", "name", "scene", "slots"},
        set(),
        ctx,
        errors,
    )

    if not _is_int(data.get("schemaVersion")) or data["schemaVersion"] < 1:
        errors.append(f"{ctx}.schemaVersion: must be integer >= 1")

    pack_id = data.get("packId")
    if not isinstance(pack_id, str) or not PACK_ID_RE.match(pack_id):
        errors.append(f"{ctx}.packId: invalid identifier '{pack_id}'")

    pack_ver = data.get("packVersion")
    if not isinstance(pack_ver, str) or not SEMVER_RE.match(pack_ver):
        errors.append(f"{ctx}.packVersion: invalid semver '{pack_ver}'")

    if not _is_int(data.get("minAppProtocol")) or data["minAppProtocol"] < 1:
        errors.append(f"{ctx}.minAppProtocol: must be integer >= 1")

    _check_localized(data.get("name"), f"{ctx}.name", errors)

    referenced_assets: set[str] = set()

    scene = data.get("scene")
    if not isinstance(scene, dict):
        errors.append(f"{ctx}.scene: must be an object")
    else:
        _check_keys(scene, {"aspectRatio", "bleed", "background"}, set(), f"{ctx}.scene", errors)
        ar = scene.get("aspectRatio")
        if not isinstance(ar, str) or not ASPECT_RE.match(ar):
            errors.append(f"{ctx}.scene.aspectRatio: invalid ratio '{ar}'")

        bleed = scene.get("bleed")
        if not isinstance(bleed, dict):
            errors.append(f"{ctx}.scene.bleed: must be an object")
        else:
            _check_keys(bleed, {"top", "bottom", "left", "right"}, set(), f"{ctx}.scene.bleed", errors)
            for side in ("top", "bottom", "left", "right"):
                v = bleed.get(side)
                if not _is_num(v) or not (0.0 <= float(v) <= 0.5):
                    errors.append(f"{ctx}.scene.bleed.{side}: must be in [0.0, 0.5]")

        bg = scene.get("background")
        if not isinstance(bg, dict):
            errors.append(f"{ctx}.scene.background: must be an object")
        else:
            _check_keys(bg, {"dayAsset", "nightAsset"}, set(), f"{ctx}.scene.background", errors)
            for key in ("dayAsset", "nightAsset"):
                v = bg.get(key)
                if v is not None:
                    if not isinstance(v, str) or len(v.strip()) == 0:
                        errors.append(f"{ctx}.scene.background.{key}: must be non-empty string or null")
                    elif not is_safe_relative_asset_path(v):
                        errors.append(f"{ctx}.scene.background.{key}: unsafe relative path '{v}'")
                    else:
                        referenced_assets.add(v)

    slots = data.get("slots")
    if not isinstance(slots, list):
        errors.append(f"{ctx}.slots: must be an array")
        return errors

    seen_slot_ids: set[str] = set()
    for idx, slot in enumerate(slots):
        s_ctx = f"{ctx}.slots[{idx}]"
        if not isinstance(slot, dict):
            errors.append(f"{s_ctx}: must be an object")
            continue

        _check_keys(
            slot,
            {
                "id",
                "description",
                "zIndex",
                "replaceable",
                "anchor",
                "bounds",
                "touchArea",
                "accessibilityLabel",
                "defaultState",
                "states",
                "animations",
            },
            set(),
            s_ctx,
            errors,
        )

        sid = slot.get("id")
        if not isinstance(sid, str) or not PACK_ID_RE.match(sid):
            errors.append(f"{s_ctx}.id: invalid slot id '{sid}'")
        elif sid in seen_slot_ids:
            errors.append(f"{s_ctx}.id: duplicate slot id '{sid}'")
        else:
            seen_slot_ids.add(sid)

        if not isinstance(slot.get("description"), str) or len(slot["description"].strip()) == 0:
            errors.append(f"{s_ctx}.description: must be non-empty string")
        if not _is_int(slot.get("zIndex")) or slot["zIndex"] < 0:
            errors.append(f"{s_ctx}.zIndex: must be integer >= 0")
        if not isinstance(slot.get("replaceable"), bool):
            errors.append(f"{s_ctx}.replaceable: must be boolean")

        anchor = slot.get("anchor")
        if not isinstance(anchor, dict):
            errors.append(f"{s_ctx}.anchor: must be an object")
        else:
            _check_keys(anchor, {"x", "y"}, set(), f"{s_ctx}.anchor", errors)
            for axis in ("x", "y"):
                v = anchor.get(axis)
                if not _is_num(v) or not (0.0 <= float(v) <= 1.0):
                    errors.append(f"{s_ctx}.anchor.{axis}: must be in [0.0, 1.0]")

        _check_rect(slot.get("bounds"), f"{s_ctx}.bounds", errors)
        _check_rect(slot.get("touchArea"), f"{s_ctx}.touchArea", errors)
        _check_localized(slot.get("accessibilityLabel"), f"{s_ctx}.accessibilityLabel", errors)

        states = slot.get("states")
        default_state = slot.get("defaultState")
        all_layer_ids: set[str] = set()
        if not isinstance(states, dict) or len(states) == 0:
            errors.append(f"{s_ctx}.states: must be a non-empty object")
        else:
            if not isinstance(default_state, str) or default_state not in states:
                errors.append(f"{s_ctx}.defaultState: '{default_state}' must exist in states")
            for state_name, state_obj in states.items():
                st_ctx = f"{s_ctx}.states.{state_name}"
                if not isinstance(state_obj, dict):
                    errors.append(f"{st_ctx}: must be an object")
                    continue
                _check_keys(state_obj, {"layers"}, set(), st_ctx, errors)
                layers = state_obj.get("layers")
                if not isinstance(layers, list):
                    errors.append(f"{st_ctx}.layers: must be an array")
                    continue
                for l_idx, layer in enumerate(layers):
                    l_ctx = f"{st_ctx}.layers[{l_idx}]"
                    if not isinstance(layer, dict):
                        errors.append(f"{l_ctx}: must be an object")
                        continue
                    _check_keys(layer, {"id", "asset", "zOffset"}, {"opacity"}, l_ctx, errors)
                    lid = layer.get("id")
                    if not isinstance(lid, str) or not LAYER_ID_RE.match(lid):
                        errors.append(f"{l_ctx}.id: invalid layer id '{lid}'")
                    else:
                        all_layer_ids.add(lid)
                    asset_val = layer.get("asset")
                    if not isinstance(asset_val, str) or len(asset_val.strip()) == 0:
                        errors.append(f"{l_ctx}.asset: must be non-empty string")
                    elif not is_safe_relative_asset_path(asset_val):
                        errors.append(f"{l_ctx}.asset: unsafe relative path '{asset_val}'")
                    else:
                        referenced_assets.add(asset_val)
                    if not _is_int(layer.get("zOffset")) or layer["zOffset"] < 0:
                        errors.append(f"{l_ctx}.zOffset: must be integer >= 0")
                    if "opacity" in layer:
                        op = layer["opacity"]
                        if not _is_num(op) or not (0.0 <= float(op) <= 1.0):
                            errors.append(f"{l_ctx}.opacity: must be in [0.0, 1.0]")

        anims = slot.get("animations")
        if not isinstance(anims, list):
            errors.append(f"{s_ctx}.animations: must be an array")
        else:
            for a_idx, anim in enumerate(anims):
                a_ctx = f"{s_ctx}.animations[{a_idx}]"
                if not isinstance(anim, dict):
                    errors.append(f"{a_ctx}: must be an object")
                    continue
                _check_keys(
                    anim,
                    {"layerId", "type", "durationMs", "curve", "repeat", "from", "to"},
                    set(),
                    a_ctx,
                    errors,
                )
                if anim.get("layerId") not in all_layer_ids:
                    errors.append(f"{a_ctx}.layerId: references unknown layer '{anim.get('layerId')}'")
                if anim.get("type") not in ALLOWED_ANIM_TYPES:
                    errors.append(f"{a_ctx}.type: invalid type '{anim.get('type')}'")
                dur = anim.get("durationMs")
                if not _is_int(dur) or not (100 <= dur <= 60000):
                    errors.append(f"{a_ctx}.durationMs: must be in [100, 60000]")
                if anim.get("curve") not in ALLOWED_CURVES:
                    errors.append(f"{a_ctx}.curve: invalid curve '{anim.get('curve')}'")
                if anim.get("repeat") not in ALLOWED_REPEATS:
                    errors.append(f"{a_ctx}.repeat: invalid repeat '{anim.get('repeat')}'")
                if not _is_num(anim.get("from")) or not _is_num(anim.get("to")):
                    errors.append(f"{a_ctx}: 'from' and 'to' must be numbers")

    # Asset existence & DD-10 weight budget checks for real packs (those with an assets/ folder
    # or explicitly requested via require_assets=True; example/base schema-only fixtures are skipped).
    should_check_files = require_assets if require_assets is not None else (pack_dir / "assets").is_dir()
    if should_check_files and referenced_assets:
        pack_root_resolved = pack_dir.resolve()
        total_asset_bytes = 0
        for rel_asset in sorted(referenced_assets):
            resolved = (pack_dir / rel_asset).resolve()
            try:
                resolved.relative_to(pack_root_resolved)
            except ValueError:
                errors.append(f"{ctx}: asset '{rel_asset}' escapes pack directory")
                continue
            if not resolved.is_file():
                errors.append(f"{ctx}: referenced asset file does not exist: '{rel_asset}'")
                continue
            size = resolved.stat().st_size
            total_asset_bytes += size
            limit = MAX_FLOOR_ASSET_BYTES if resolved.name == "floor.png" else MAX_OBJECT_ASSET_BYTES
            if size > limit:
                errors.append(
                    f"{ctx}: asset '{rel_asset}' size {size} bytes exceeds DD-10 limit ({limit} bytes)"
                )
        if total_asset_bytes > MAX_PACK_TOTAL_BYTES:
            errors.append(
                f"{ctx}: total referenced assets size {total_asset_bytes} bytes exceeds DD-10 limit ({MAX_PACK_TOTAL_BYTES} bytes)"
            )

    return errors


def main() -> int:
    repo_root = Path(__file__).resolve().parent.parent
    schema_path = repo_root / "content" / "schemas" / "scene-manifest.schema.json"
    if not schema_path.is_file():
        print(f"Schema not found: {schema_path}", file=sys.stderr)
        return 1

    # Ensure schema itself is valid JSON
    json.loads(schema_path.read_text(encoding="utf-8"))

    manifests = sorted((repo_root / "content" / "packs").glob("*/manifest.json"))
    if not manifests:
        print("No pack manifests found under content/packs/*/manifest.json", file=sys.stderr)
        return 1

    all_errors: list[str] = []
    for m in manifests:
        errs = validate_manifest(m)
        if errs:
            all_errors.extend(errs)
        else:
            print(f"OK: {m.relative_to(repo_root)}")

    if all_errors:
        print("\nValidation errors:", file=sys.stderr)
        for e in all_errors:
            print(f" - {e}", file=sys.stderr)
        return 1

    print(f"Validated {len(manifests)} content pack manifest(s) successfully.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
