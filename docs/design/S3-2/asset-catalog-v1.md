# Asset Catalog v1 & Style Bible (`DS-5`, `S2-D08`, `A-01..A-09`)

**Version:** 1.1 (micro-packs `v1.0.0` and `v1.1.0` delivered; `v1.2.0` ready for production) · **Date:** November 22, 2026
**Asset license:** `CC-BY-4.0` ([content/LICENSE-ASSETS](../../../content/LICENSE-ASSETS)), excluding the `Deep Sky` name, logo, and icon (`D-11`).
**Storage:** high-resolution masters in `content/masters/v1/` on **Git LFS**; runtime derivatives in `content/packs/v1/assets/` on standard Git (`S2-CNT-01`).

---

## 1. Concise Style Bible (`A-03`, `V-01`, `V-04`, `V-05`)

- **Visual direction:** *Intimate Sanctuary* — warm 2D illustration in front/light cross-section view, clean and soft linework (consistent weight, dark brown/indigo instead of pure black `#000000`), soft painterly rendering like a cozy editorial illustration for adults (not childish, not pixel art, not glossy 3D).
- **Palette:** warm honey/chestnut woods for floor and baseboard; indigo blue and velvety plum for the window frame and nocturnal accents; petal pink (`#F472B6`, `#FDA4AF`) for textile details; soft amber (`#FBBF24`, `<= 5%` of area) reserved for the floor lamp light and stars.
- **Cutout and transparency (`A-01`, `A-04`):** 8-bit sRGB RGBA PNG with a real alpha channel, zero opaque wall in object backgrounds, ~4–5% transparent padding on sides subject to cropping, verified against `day` (`#FAF2EC` / `#2D3652`), `twilight` (`#F3DDE7` / `#311F3E`), and `night` (`#E5DFEE` / `#1C2337`) walls.
- **No text or trademarks (`A-06`):** no embedded text (`"NOI"` removed), no logos or trademarks in assets.
- **Common negative prompts:** `text, watermark, signature, logo, wall background, vignette, frame border, harsh black outline, photorealistic 3d, chibi baby style`.

---

## 2. Slot Table (`A-09`, `4:3` logical canvas `1440×1080`)

| Slot ID | Micro-pack | `zIndex` | Anchor (`x, y`) | Bounds (`x, y, w, h`) | Replaceable (`F-18`) | States |
| :-- | :-- | :-- | :-- | :-- | :-- | :-- |
| `floor` | `v1.0.0` | `5` | `0.50, 0.56` | `0.00, 0.56, 1.00, 0.44` (+ continuous downward extension) | No | `default` |
| `window` | `v1.0.0` | `10` | `0.30, 0.29` | `0.14, 0.06, 0.33, 0.46` | No | `day`, `twilight`, `night` |
| `rug` | `v1.1.0` | `20` | `0.47, 0.83` | `0.15, 0.66, 0.64, 0.34` | Yes | `default` |
| `couch` | `v1.1.0` | `30` | `0.47, 0.64` | `0.19, 0.43, 0.56, 0.42` | Yes | `default` |
| `floor_lamp` | `v1.1.0` | `35` | `0.82, 0.53` | `0.73, 0.28, 0.19, 0.50` | Yes | `calm`, `lit` |
| `couple_on_couch` | `v1.2.0` | `40` | `0.50, 0.54` | `0.30, 0.36, 0.40, 0.34` *(planned)* | Yes | `resting` |
| `pet_sleeping` | `v1.2.0` | `45` | `0.62, 0.78` | `0.52, 0.68, 0.20, 0.16` *(planned)* | Yes | `sleeping` |

---

## 3. Delivered Asset Catalog (`v1.0.0` + `v1.1.0`, `A-07`, `DD-10`)

Reproducible build from masters to derivatives:
```bash
python scripts/build_content_pack.py --masters content/masters/v1 --out-assets content/packs/v1/assets --allow-palette
python scripts/validate_content.py
```

| Asset (`content/packs/v1/assets/`) | Slot | Master (`content/masters/v1/`) | Runtime derivative | Derivative size (`DD-10`) | Transparency (`A-04`) | Status |
| :-- | :-- | :-- | :-- | :-- | :-- | :-- |
| `floor.png` | `floor` | `2160 × 1440` RGBA (`2,786,260 B`) | `1440 × 960` **quantized PNG8-RGBA** | `408,066 B` (≤ 400 KiB) | Real alpha above baseboard (`6.5%`), zero halos | Approved by sponsor (`v1.0.0`) |
| `window_frame.png` | `window` | `900 × 1200` RGBA (`235,973 B`) | `450 × 600` RGBA32 lossless | `79,158 B` (≤ 250 KiB) | Transparent panes and exterior (`83.2%`), zero halos | Approved by sponsor (`v1.0.0`) |
| `window_sky_day.png` | `window` (`day`) | `900 × 1200` RGBA (`889,270 B`) | `450 × 600` RGBA32 lossless | `246,455 B` (≤ 250 KiB) | Transparent arch exterior (`26.4%`) | Approved by sponsor (`v1.0.0`) |
| `window_sky_twilight.png` | `window` (`twilight`) | `900 × 1200` RGBA (`910,254 B`) | `450 × 600` RGBA32 lossless | `245,017 B` (≤ 250 KiB) | Transparent arch exterior (`26.4%`) | Approved by sponsor (`v1.0.0`) |
| `window_sky_night.png` | `window` (`night`) | `900 × 1200` RGBA (`1,045,752 B`) | `450 × 600` **quantized PNG8-RGBA** | `85,807 B` (≤ 250 KiB) | Transparent arch exterior (`26.3%`) | Approved by sponsor (`v1.0.0`) |
| `rug.png` | `rug` | `1800 × 720` RGBA (`1,345,079 B`) | `900 × 360` **quantized PNG8-RGBA** | `78,668 B` (≤ 250 KiB) | Transparent exterior (`52.3%`), zero halos | Integrated (`v1.1.0`) |
| `couch.png` | `couch` | `1920 × 1080` RGBA (`920,322 B`) | `960 × 540` **quantized PNG8-RGBA** | `96,987 B` (≤ 250 KiB) | Transparent exterior + soft ground shadow (`37.4%`), zero halos | Integrated (`v1.1.0`) |
| `floor_lamp_calm.png` | `floor_lamp` (`calm`) | `720 × 1440` RGBA (`225,358 B`) | `360 × 720` RGBA32 lossless | `57,648 B` (≤ 250 KiB) | Transparent exterior (`83.9%`), zero halos | Integrated (`v1.1.0`) |
| `floor_lamp_lit.png` | `floor_lamp` (`lit`) | `720 × 1440` RGBA (`544,657 B`) | `360 × 720` RGBA32 lossless | `147,191 B` (≤ 250 KiB) | Transparent exterior + directional light cone (`54.0%`), zero halos | Integrated (`v1.1.0`) |

**Total `v1.0.0 + v1.1.0` derivatives:** `1,444,997 B` (`1.38 MiB` out of `1.8 MiB` total budget for `v1.0 + v1.1 + v1.2`, leaving `~432 KiB` for `v1.2.0`). All `v1.0.0` derivative SHA-256 hashes remain bit-for-bit identical for file-by-file cache reuse (`S2-CTR-01`). In the plan, `KB`/`MB` are interpreted as `KiB`/`MiB` (1024 bytes), consistently across `scripts/build_content_pack.py`, `scripts/ImagePackTool.java`, and `scripts/validate_content.py`.

### 3.1 Quantized derivatives (PNG8) — recorded exception to the lossless rule

The plan (section 6.3) requires **lossless** compressed derivatives. The pipeline fails by default if a lossless PNG exceeds the budget; 256-color quantization is allowed only with the explicit `--allow-palette` flag. The following assets were regenerated with `--allow-palette` because they **do not fit within the budget losslessly** (measured with the pipeline's lossless encoding, using adaptive per-row filter selection; `oxipng` was not installed in the build environment):

| Asset | Lossless RGBA32 (measured) | Budget | Outcome |
| :-- | :-- | :-- | :-- |
| `floor.png` | `1,253,552 B` | `409,600 B` (400 KiB) | 256-color PNG8-RGBA (`408,066 B`) — gradient-rich wood texture, lossless over 3× budget |
| `window_sky_night.png` | `276,914 B` | `256,000 B` (250 KiB) | 256-color PNG8-RGBA (`85,807 B`) — ~8% over budget |
| `rug.png` | `284,382 B` | `256,000 B` (250 KiB) | 256-color PNG8-RGBA (`78,668 B`) — ~11% over budget; keeps total pack well under `1.8 MiB` for `v1.2.0` |
| `couch.png` | `320,059 B` | `256,000 B` (250 KiB) | 256-color PNG8-RGBA (`96,987 B`) — ~25% over budget; visually clean on day/twilight/night walls |

Open action: evaluate with designer/sponsor whether to accept quantization (visual approval already given on `v1.0.0` derivatives; `v1.1.0` goldens updated for review) or simplify the masters / reduce dimensions to remain lossless within budget (retrying with `oxipng -o 4` for assets closest to the limit). Plan budgets have not been modified.

### 3.2 Integrity, provenance, and licensing of individual assets (`A-07`, `A-08`)

For each asset, `A-07` requires ID, slot, master dimensions, SHA-256, prompt, AI tool, and tool terms (`A-08`). SHA-256 hashes are computed from the files actually present in the repository. The prompt / AI tool / terms fields **have not been fabricated**: they remain to be provided.

| Asset ID | Slot | Master (dim.) | Master SHA-256 | Derivative SHA-256 | Prompt | AI Tool | Tool Terms (`A-08`) |
| :-- | :-- | :-- | :-- | :-- | :-- | :-- | :-- |
| `floor` | `floor` | `2160 × 1440` | `e7de2284a27a5c8130ea9814d745d8fa41c3b7bd4a7fe66277d888f4436a8fd7` | `daca1b7f365c5f17fa9c44f087062e4f35a1ee377915453e629fbf19e10a8df5` | to be provided (designer/sponsor) | to be provided (designer/sponsor) | to be provided (designer/sponsor) |
| `window_frame` | `window` | `900 × 1200` | `5a18751fe54275c0a4983fffa54f5a19229c30eb5f9a84fb2065d1970e38c5dd` | `526b7148a98d80fd4c672de1c25b81386f33d89e6247a08c2e5a4c2fb1e39fb0` | to be provided (designer/sponsor) | to be provided (designer/sponsor) | to be provided (designer/sponsor) |
| `window_sky_day` | `window` (`day`) | `900 × 1200` | `b783a15cafc5faa832a02305ef8474413209d79dae69e5ea8ba0a1664515ad28` | `07538c561aa9cb10573fae8ef90daf093282be455724d6be5025328fb6dfdb21` | to be provided (designer/sponsor) | to be provided (designer/sponsor) | to be provided (designer/sponsor) |
| `window_sky_twilight` | `window` (`twilight`) | `900 × 1200` | `9c929427d8dcd314c6ec9c481a57a97685a611352abb6cc9ed442adf227ad90d` | `2035831e0f4194b5a9773bbc335d0b7eb6ec26f05293917f25ff17a7a4ced87d` | to be provided (designer/sponsor) | to be provided (designer/sponsor) | to be provided (designer/sponsor) |
| `window_sky_night` | `window` (`night`) | `900 × 1200` | `a3bb94d571f8ec8c2d64bbda9ed0122b68ef8c7f6f7de72db8c30e7720562110` | `242f28b137f1831c3a83ef7347107384dbb47805085407ed2d86a546368df7c9` | to be provided (designer/sponsor) | to be provided (designer/sponsor) | to be provided (designer/sponsor) |
| `rug` | `rug` | `1800 × 720` | `8fece8a2344cf4e30800957ab4ad2c06d8ddceae4b98fa66c7117c9ae2b282f5` | `6bc2056c33b81b757690a9ac043ab1699a315790a199720ab09ce206aec59fee` | to be provided (designer/sponsor) | to be provided (designer/sponsor) | to be provided (designer/sponsor) |
| `couch` | `couch` | `1920 × 1080` | `986f3286ce670af7391ccd6b48d7a7a4f80f2f8cf7a02bb836d4208edeec6141` | `4f52cec5d03b1061f6145e68961b8656a3d0d67b5e11432d1168a9964177e34c` | to be provided (designer/sponsor) | to be provided (designer/sponsor) | to be provided (designer/sponsor) |
| `floor_lamp_calm` | `floor_lamp` (`calm`) | `720 × 1440` | `f865c54aa4549dca7918a1107fc0cada5aeff6c252480a2318db9dc5e2e7b5e3` | `ad5e210fc8905da6f42b8556cd3237e1a303af3899d3b7c9cbc01ab7a2d87b70` | to be provided (designer/sponsor) | to be provided (designer/sponsor) | to be provided (designer/sponsor) |
| `floor_lamp_lit` | `floor_lamp` (`lit`) | `720 × 1440` | `b6a441f6cd7daa2ec3b92f6c01beab6c148c74e33d9971fa31dac264f117c194` | `dcc6de25c869bbeac0f85edd4d1a6c643a681b3ac561ddbf26e5af9d987954ea` | to be provided (designer/sponsor) | to be provided (designer/sponsor) | to be provided (designer/sponsor) |

Derivative SHA-256 hashes must be regenerated (`sha256sum content/packs/v1/assets/*.png`) on every new pipeline build.

## 4. Planned Assets for Subsequent Micro-Packs

- **`v1.2.0` (Presence in the room):** `couple_on_couch.png` (`640×480`), `pet_sleeping.png` (`384×288`).
