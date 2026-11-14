# Deep Sky Content Packs

Reference IDs: `CNT-01`, `CNT-02`, `TC-08`, `TC-09`, `A-09`.

> **Asset rule (`CNT-02`, `D-11`):** No AI-generated image assets are committed to this repository until the generation tool terms and asset license are approved by the promoter.

## Layout

- `schemas/scene-manifest.schema.json` — JSON Schema for scene pack manifests (slots, normalized touch areas, states, level-1 layered animations, accessibility labels).
- `packs/base/manifest.json` — Empty base content pack manifest (`slots: []`).
- `packs/example/manifest.json` — Reference example manifest illustrating slots, touch areas, multi-state layers, and level-1 animations (without binary image files).

## Validation & Signing

```bash
# Validate all pack manifests
python scripts/validate_content.py

# Compute file hashes and sign a pack manifest (using a test or offline Ed25519 key)
python scripts/sign_content.py --pack content/packs/base --key <ed25519-private.pkcs8.b64> --out-dir <out>
```
