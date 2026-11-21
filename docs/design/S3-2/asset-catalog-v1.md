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
| `floor.png` | `floor` | `2160 × 1440` RGBA (`2,786,260 B`) | `1440 × 960` **PNG8-RGBA quantizzato** | `408,066 B` (≤ 400 KiB) | Alpha reale sopra battiscopa (`6.5%`), zero aloni | Approvato dal promotore (`v1.0.0`) |
| `window_frame.png` | `window` | `900 × 1200` RGBA (`235,973 B`) | `450 × 600` RGBA32 lossless | `79,158 B` (≤ 250 KiB) | Vetri ed esterno trasparenti (`83.2%`), zero aloni | Approvato dal promotore (`v1.0.0`) |
| `window_sky_day.png` | `window` (`day`) | `900 × 1200` RGBA (`889,270 B`) | `450 × 600` RGBA32 lossless | `246,455 B` (≤ 250 KiB) | Esterno arco trasparente (`26.4%`) | Approvato dal promotore (`v1.0.0`) |
| `window_sky_twilight.png` | `window` (`twilight`) | `900 × 1200` RGBA (`910,254 B`) | `450 × 600` RGBA32 lossless | `245,017 B` (≤ 250 KiB) | Esterno arco trasparente (`26.4%`) | Approvato dal promotore (`v1.0.0`) |
| `window_sky_night.png` | `window` (`night`) | `900 × 1200` RGBA (`1,045,752 B`) | `450 × 600` **PNG8-RGBA quantizzato** | `85,807 B` (≤ 250 KiB) | Esterno arco trasparente (`26.3%`) | Approvato dal promotore (`v1.0.0`) |

**Totale derivati `v1.0.0`:** `1,064,503 B` (`1.02 MiB` su budget complessivo `1.8 MiB` per `v1.0 + v1.1 + v1.2`). Nel piano `KB`/`MB` sono interpretati come `KiB`/`MiB` (1024 byte), coerentemente in `scripts/build_content_pack.py`, `scripts/ImagePackTool.java` e `scripts/validate_content.py`.

### 3.1 Derivati quantizzati (PNG8) — eccezione registrata alla regola lossless

Il piano (sezione 6.3) richiede derivati compressi **lossless**. La pipeline ora fallisce di default se il PNG lossless supera il budget; la quantizzazione a 256 colori è ammessa solo con il flag esplicito `--allow-palette`. Gli asset seguenti sono stati rigenerati con `--allow-palette` perché **non rientrano nel budget in modo lossless** (misurato con la codifica lossless della pipeline, con scelta adattiva dei filtri per riga; `oxipng` non era installato nell'ambiente di build):

| Asset | Lossless RGBA32 (misurato) | Budget | Esito |
| :-- | :-- | :-- | :-- |
| `floor.png` | `1,253,552 B` | `409,600 B` (400 KiB) | PNG8-RGBA 256 colori (`408,066 B`) — texture legno ricca di gradienti, lossless oltre 3× il budget |
| `window_sky_night.png` | `276,914 B` | `256,000 B` (250 KiB) | PNG8-RGBA 256 colori (`85,807 B`) — sforamento del ~8% |

Azione aperta: valutare con designer/promotore se accettare la quantizzazione (approvazione visiva già data sui derivati correnti) oppure semplificare il master / ridurre le dimensioni per restare lossless entro budget (ritentando con `oxipng -o 4` per `window_sky_night.png`, che è il caso più vicino al limite). I budget del piano non sono stati modificati.

### 3.2 Integrità, provenienza e licenza dei singoli asset (`A-07`, `A-08`)

Per ogni asset `A-07` richiede ID, slot, dimensioni master, SHA-256, prompt, strumento AI e termini dello strumento (`A-08`). SHA-256 calcolati dai file effettivamente presenti nel repository. I campi prompt / strumento AI / termini **non sono stati inventati**: restano da fornire.

| ID asset | Slot | Master (dim.) | SHA-256 master | SHA-256 derivato | Prompt | Strumento AI | Termini dello strumento (`A-08`) |
| :-- | :-- | :-- | :-- | :-- | :-- | :-- | :-- |
| `floor` | `floor` | `2160 × 1440` | `e7de2284a27a5c8130ea9814d745d8fa41c3b7bd4a7fe66277d888f4436a8fd7` | `daca1b7f365c5f17fa9c44f087062e4f35a1ee377915453e629fbf19e10a8df5` | da fornire (designer/promotore) | da fornire (designer/promotore) | da fornire (designer/promotore) |
| `window_frame` | `window` | `900 × 1200` | `5a18751fe54275c0a4983fffa54f5a19229c30eb5f9a84fb2065d1970e38c5dd` | `526b7148a98d80fd4c672de1c25b81386f33d89e6247a08c2e5a4c2fb1e39fb0` | da fornire (designer/promotore) | da fornire (designer/promotore) | da fornire (designer/promotore) |
| `window_sky_day` | `window` (`day`) | `900 × 1200` | `b783a15cafc5faa832a02305ef8474413209d79dae69e5ea8ba0a1664515ad28` | `07538c561aa9cb10573fae8ef90daf093282be455724d6be5025328fb6dfdb21` | da fornire (designer/promotore) | da fornire (designer/promotore) | da fornire (designer/promotore) |
| `window_sky_twilight` | `window` (`twilight`) | `900 × 1200` | `9c929427d8dcd314c6ec9c481a57a97685a611352abb6cc9ed442adf227ad90d` | `2035831e0f4194b5a9773bbc335d0b7eb6ec26f05293917f25ff17a7a4ced87d` | da fornire (designer/promotore) | da fornire (designer/promotore) | da fornire (designer/promotore) |
| `window_sky_night` | `window` (`night`) | `900 × 1200` | `a3bb94d571f8ec8c2d64bbda9ed0122b68ef8c7f6f7de72db8c30e7720562110` | `242f28b137f1831c3a83ef7347107384dbb47805085407ed2d86a546368df7c9` | da fornire (designer/promotore) | da fornire (designer/promotore) | da fornire (designer/promotore) |

Gli SHA-256 dei derivati vanno rigenerati (`sha256sum content/packs/v1/assets/*.png`) a ogni nuova build della pipeline.

## 4. Asset pianificati per i micro-pacchetti successivi

- **`v1.1.0` (Arredo & luce `F-03`):** `rug.png` (`900×360`), `couch.png` (`960×540`), `floor_lamp_calm.png` (`360×720`), `floor_lamp_lit.png` (`360×720`).
- **`v1.2.0` (Presenza nella stanza):** `couple_on_couch.png` (`640×480`), `pet_sleeping.png` (`384×288`).
