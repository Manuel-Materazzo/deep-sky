# SP-03 · Aggiornamento dell'APK e verifica crittografica (`TC-10`, `F-19`, `SEC-04`)

Specifiche del prototipo `proto/sp-03` (`docs/m0-m1-operative-plan.md`).

## 1. Catena di fiducia dell'aggiornamento

1. **Sorgente configurabile (default GitHub Releases o URL/repository alternativo):**
   - Il client scarica `manifest.json` e `manifest.json.sig` (prodotti offline da `scripts/sign-release.*`).
2. **Verifica firma Ed25519 su `manifest.json`:**
   - Prima di interpretare qualsiasi campo JSON, la firma Ed25519 in `manifest.json.sig` viene verificata sui byte grezzi di `manifest.json` rispetto alla chiave pubblica Ed25519 fidata.
   - Se `manifest.json` o la firma sono alterati, il client rifiuta subito l'aggiornamento con `signatureInvalid`.
3. **Controlli di versione, pacchetto e spazio:**
   - `manifest.packageId` deve coincidere con l'applicationId corrente (`com.vectevo.deep_sky`).
   - `manifest.versionCode` deve essere strettamente maggiore del `versionCode` installato (`versionNotHigher` se inferiore o uguale).
   - Lo spazio libero (`StatFs.availableBytes`) deve coprire `apkSizeBytes` + margine di sicurezza di 20 MB (`insufficientStorage`).
4. **Scarico con ripresa (`Range`) e controllo SHA-256:**
   - Il file `.part` viene ripreso via header HTTP `Range: bytes=<offset>-` se lo scarico si interrompe (`downloadInterrupted`).
   - A scarico completato viene verificata la dimensione esatta e l'impronta `SHA-256 == manifest.apkSha256` (`apkHashMismatch`).
5. **Pre-verifica certificato APK e sessione `PackageInstaller`:**
   - Prima di aprire la conferma Android, `ApkInstallerCoordinator` verifica `packageInfo.signingInfo` dell'APK scaricato contro i certificati di firma dell'app attualmente installata (`apkCertificateMismatch`), impedendo la perdita di dati da APK con chiave diversa.
   - Gestisce esplicitamente il permesso runtime `REQUEST_INSTALL_PACKAGES` (`Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES`).

## 2. Punti da registrare sui dispositivi fisici (`SP03-04`)

- Numero esatto di prompt/conferme mostrati da Android per le due versioni Android dei telefoni di test (prima volta vs aggiornamenti successivi).
- Conservazione dei dati locali (chiavi/SecureStorage) dopo installazione di APK reale con `versionCode` superiore firmato con la stessa chiave.
