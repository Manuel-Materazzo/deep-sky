# Catalogo Asset v1 & Style Bible (`DS-5`, `S2-D08`, `A-01..A-09`)

**Versione:** 1.0 (micro-pacchetto `v1.0.0` consegnato; `v1.1.0` e `v1.2.0` pronti per la produzione) · **Data:** 21 novembre 2026
**Licenza asset:** `CC-BY-4.0` ([content/LICENSE-ASSETS](../../../content/LICENSE-ASSETS)), esclusi nome, logo e icona `Deep Sky` (`D-11`).
**Custodia:** master ad alta risoluzione in `content/masters/v1/` su **Git LFS**; derivati runtime in `content/packs/v1/assets/` su Git standard (`S2-CNT-01`).

---

## 1. Style Bible sintetica (`A-03`, `V-01`, `V-04`, `V-05`)

- **Direzione visiva:** *Intimate Sanctuary* — illustrazione 2D calda in vista frontale/sezione leggera, tratto pulito e morbido (spessore coerente, marrone/indaco scuro anziché nero puro `#000000`), resa pittorica morbida tipo illustrazione editoriale accogliente per adulti (non infantile, non pixel art, non 3D lucido).
- **Palette:** legni caldi miele/castagno per pavimento e battiscopa; blu indaco e prugna vellutata per la cornice finestra e gli accenti notturni; rosa petalo (`#F472B6`, `#FDA4AF`) per i dettagli tessili; ambra soffusa (`#FBBF24`, `<= 5%` dell'area) riservata alla luce della lampada da terra e alle stelle.
- **Scontorno e trasparenza (`A-01`, `A-04`):** PNG RGBA 8-bit sRGB con canale alpha reale, zero muro opaco nello sfondo degli oggetti, padding trasparente ~4–5% sui lati soggetti a ritaglio, verifica su muro `giorno` (`#FAF2EC` / `#2D3652`), `crepuscolo` (`#F3DDE7` / `#311F3E`) e `notte` (`#E5DFEE` / `#1C2337`).
- **Divieto di testo e marchi (`A-06`):** nessun testo incorporato (rimosso `"NOI"`), nessun logo o marchio negli asset.
- **Prompt negativi comuni:** `text, watermark, signature, logo, wall background, vignette, frame border, harsh black outline, photorealistic 3d, chibi baby style`.

---

## 2. Tabella degli slot (`A-09`, tela logica `4:3` `1440×1080`)

| Slot ID | Micro-pack | `zIndex` | Anchor (`x, y`) | Bounds (`x, y, w, h`) | Sostituibile (`F-18`) | Stati |
| :-- | :-- | :-- | :-- | :-- | :-- | :-- |
| `floor` | `v1.0.0` | `5` | `0.50, 0.56` | `0.00, 0.56, 1.00, 0.44` (+ estensione continua verso il basso) | No | `default` |
| `window` | `v1.0.0` | `10` | `0.30, 0.29` | `0.14, 0.06, 0.33, 0.46` | No | `day`, `twilight`, `night` |
| `rug` | `v1.1.0` | `20` | `0.50, 0.80` | `0.18, 0.68, 0.64, 0.24` *(pianificato)* | Sì | `default` |
| `couch` | `v1.1.0` | `30` | `0.50, 0.62` | `0.21, 0.44, 0.58, 0.34` *(pianificato)* | Sì | `default` |
| `floor_lamp` | `v1.1.0` | `35` | `0.83, 0.54` | `0.75, 0.30, 0.16, 0.48` *(pianificato)* | Sì | `calm`, `lit` |
| `couple_on_couch` | `v1.2.0` | `40` | `0.50, 0.54` | `0.30, 0.36, 0.40, 0.34` *(pianificato)* | Sì | `resting` |
| `pet_sleeping` | `v1.2.0` | `45` | `0.62, 0.78` | `0.52, 0.68, 0.20, 0.16` *(pianificato)* | Sì | `sleeping` |

---

## 3. Catalogo asset consegnati (`v1.0.0`, `A-07`, `DD-10`)

Build riproducibile da master a derivati:
```bash
python scripts/build_content_pack.py --masters content/masters/v1 --out-assets content/packs/v1/assets
python scripts/validate_content.py
```

| Asset (`content/packs/v1/assets/`) | Slot | Master (`content/masters/v1/`) | Derivato runtime | Peso derivato (`DD-10`) | Trasparenza (`A-04`) | Stato |
| :-- | :-- | :-- | :-- | :-- | :-- | :-- |
| `floor.png` | `floor` | `2160 × 1440` RGBA (`2,786,260 B`) | `1440 × 960` PNG8-RGBA | `408,066 B` (≤ 400 KiB) | Alpha reale sopra battiscopa (`6.5%`), zero aloni | Approvato (`v1.0.0`) |
| `window_frame.png` | `window` | `900 × 1200` RGBA (`235,973 B`) | `450 × 600` RGBA32 | `82,419 B` (≤ 250 KiB) | Vetri ed esterno trasparenti (`83.2%`), zero aloni | Approvato (`v1.0.0`) |
| `window_sky_day.png` | `window` (`day`) | `900 × 1200` RGBA (`889,270 B`) | `450 × 600` RGBA32 | `246,455 B` (≤ 250 KiB) | Esterno arco trasparente (`26.4%`) | Approvato (`v1.0.0`) |
| `window_sky_twilight.png` | `window` (`twilight`) | `900 × 1200` RGBA (`910,254 B`) | `450 × 600` RGBA32 | `245,017 B` (≤ 250 KiB) | Esterno arco trasparente (`26.4%`) | Approvato (`v1.0.0`) |
| `window_sky_night.png` | `window` (`night`) | `900 × 1200` RGBA (`1,045,752 B`) | `450 × 600` PNG8-RGBA | `85,807 B` (≤ 250 KiB) | Esterno arco trasparente (`26.3%`) | Approvato (`v1.0.0`) |

**Totale derivati `v1.0.0`:** `1,067,764 B` (`1.02 MB` su budget complessivo `1.8 MB` per `v1.0 + v1.1 + v1.2`).

## 4. Asset pianificati per i micro-pacchetti successivi

- **`v1.1.0` (Arredo & luce `F-03`):** `rug.png` (`900×360`), `couch.png` (`960×540`), `floor_lamp_calm.png` (`360×720`), `floor_lamp_lit.png` (`360×720`).
- **`v1.2.0` (Presenza nella stanza):** `couple_on_couch.png` (`640×480`), `pet_sleeping.png` (`384×288`).
