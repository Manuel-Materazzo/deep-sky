# Procedura di emergenza e recupero — Deep Sky (`S1-DOC-01`, `G-3a`)

Documento operativo sintetico in linguaggio chiaro per gestire incidenti reali durante l'uso sul campo.

---

## 1. Il server non risponde / Rete assente
1. **Non disinstallare e non premere «Scollega dispositivo».** L'app entra automaticamente in modalità sola lettura offline mostrando i ricordi già decifrati sul telefono.
2. Verifica lato server (`deploy/`):
   ```bash
   docker compose ps
   curl -fsS https://deepsky.vectevo.com/actuator/health/liveness
   ```
3. Se il container `api` o `db` è fermo:
   ```bash
   cd deploy
   docker compose up -d
   docker compose logs --tail=100 api proxy
   ```
4. Appena il server torna raggiungibile, tocca il pulsante di aggiornamento nella Home: la coda locale e la sincronizzazione riprendono senza perdere la coppia.

---

## 2. Aggiornamento difettoso rilasciato sul canale *stabile* o *anteprima*
**Regola Android (`m3-operative-plan.md` cap. 3):** Android **non permette** il downgrade di versione a un `versionCode` inferiore o uguale.

1. Se solo il telefono su canale **anteprima** ha un bug:
   - Riporta il telefono su canale **stabile** nelle Impostazioni se necessario per le release future.
   - Pubblica una nuova release su GitHub (con **`versionCode` strettamente maggiore**, es. `+1` rispetto alla build difettosa) contenente il fix o il codice del commit precedente funzionante, firmata con la stessa chiave keystore Android e manifest Ed25519 (`scripts/sign-release.*`).
2. Se una vecchia versione client ha un bug critico bloccante verso il server:
   - Dopo aver pubblicato l'APK corretto con `versionCode` maggiore, alza `DEEPSKY_MIN_CLIENT_VERSION_CODE` nel `.env` del server e riavvia `api`: i vecchi client riceveranno `HTTP 426` e mostreranno la schermata gentile «Aggiornamento richiesto» con scaricamento diretto.

---

## 3. Smarrimento o sostituzione di UN telefono (l'altro partner ha ancora l'app)
1. Sul telefono rimasto attivo, apri **Dispositivi**:
   - Tocca **Revoca** accanto al telefono smarrito/vecchio e conferma. Il dispositivo revocato viene bloccato subito lato server (`HTTP 401`, token push rimosso).
   - Avvia un nuovo **arruolamento dispositivo** per generare QR / link temporaneo.
2. Sul nuovo telefono:
   - Installa l'APK ufficiale -> scegli **Unisciti** -> inquadra il QR o incolla il link.
   - Confrontate a voce il codice SAS a 6 cifre e completate l'ingresso.

---

## 4. Entrambi i telefoni persi o ripristinati (Recupero autonomo con Recovery Key `F-20`)
1. Installa l'APK ufficiale da `https://deepsky.vectevo.com/join` (o GitHub Releases).
2. Apri l'app -> scheda **Recupera** (`S1-D10`).
3. Inserisci le **24 parole BIP-39** nell'ordine esatto (oppure inquadra il QR di backup offline).
   - Se utilizzi un server self-hosted personalizzato, apri il pannello server in basso e inserisci l'URL prima di confermare.
4. Tocca **Ripristina e riaccendi la casa**: la chiave privata di recupero ricrea la sessione del nuovo dispositivo senza bisogno del vecchio telefono e decifra tutta la storia condivisa dal server.
5. Una volta rientrato, apri **Dispositivi** e revoca eventuali telefoni vecchi non più in tuo possesso.

---

## 5. Perdita totale della Recovery Key
Se **entrambi i telefoni** vanno persi **e** le 24 parole non sono state salvate, nessuno — neppure l'amministratore del server — può decifrare la stanza (`S-01`). L'unica strada è creare una nuova coppia dall'inizio e chiedere all'altro partner di fare altrettanto.
