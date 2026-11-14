# SP-04 · Home ibrida, scene e prestazioni (`AR-07`, `AR-08`, `TC-08`, `TC-09`)

Specifiche e soglie concordate prima delle misure per il prototipo `proto/sp-04` (`docs/m0-m1-operative-plan.md`).

## 1. Soglie di prestazione concordate (`SP04-06`)

Da verificare su due telefoni fisici (di cui il riferimento con meno RAM / più datato) prima dell'uscita da M1:

| Metrica | Soglia bersaglio | Note |
| :--- | :--- | :--- |
| Frame budget @ 60 Hz | **>= 95% dei frame <= 16,7 ms** durante scorrimento Home + animazioni di livello 1 | Ogni layer animato è isolato in `RepaintBoundary` |
| Picco memoria processo | **<= 180 MB RSS** sul dispositivo di fascia bassa | Asset raster dimensionati al formato target; nessun video continuo |
| Aree di tocco e layout | **Zero overflow**, hit-box allineati alle coordinate normalizzate del manifest a `9:16`, `9:20` e `16:10` | `AspectRatio` + `LayoutBuilder` con coordinate normalizzate `[0, 1]` |
| Accessibilità | `Semantics` espliciti e ordine `OrdinalSortKey` verificato con TalkBack su dispositivo | Etichette localizzate `it`/`en` per ogni slot interattivo |

## 2. Regole di composizione rispettate

- **Nessuna card semitrasparente sopra i layer animati (`SP04`):** la card di stato, il canvas della scena e la card countdown sono blocchi distinti e opachi nella `CustomScrollView` (niente blur `BackdropFilter` sopra animazioni).
- **Animazioni di livello 1 (`TC-09`):** `fade` (glow finestra 2800 ms reverse), `scale` (respiro pet 2400 ms reverse), `translateY` (vapore tazza 2200 ms reverse). Tutte controllate dal manifest e fermate istantaneamente quando **Riduci movimento** è attivo (`MediaQuery.disableAnimations` o toggle dedicato).
- **Override degli asset (`SP04-05`):** `AssetOverrideRegistry` sovrascrive l'asset di un `(slotId, layerId)` mantenendo il `manifest.json` immutato e consentendo il ripristino immediato al valore predefinito.
