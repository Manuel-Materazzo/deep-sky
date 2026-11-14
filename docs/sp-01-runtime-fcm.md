# SP-01 · Push con FCM e configurazione a runtime (`TC-04`, `S-02`, `AD-04`)

Specifiche tecniche per il prototipo `proto/sp-01` (Milestone M1, `docs/m0-m1-operative-plan.md`).

## 1. Principi di sicurezza e privacy (`S-02`, `TC-04`)

- **Nessuna credenziale Firebase compilata nel repository o nell'APK** (`AD-04`):
  - Nessun file `google-services.json`.
  - Nessun plugin Gradle `com.google.gms.google-services`.
  - Il client riceve a runtime solo i parametri pubblici (`projectId`, `apiKey`, `appId`, `senderId`) da `GET /api/v1/push/config` (o configurazione manuale di test nel prototipo) e inizializza `FirebaseApp` con `FirebaseOptions.Builder`.
  - Il server non espone mai `serviceAccountFile` né la chiave privata del service account.
- **Messaggi data-only privi di contenuti (`S-02`)**:
  - Il payload FCM HTTP v1 contiene solo `data`:
    ```json
    {
      "message": {
        "token": "<device-fcm-token>",
        "data": {
          "l10nKey": "wakeup.new_moment",
          "event": "wakeup",
          "ts": "1763159000"
        },
        "android": {
          "priority": "HIGH",
          "ttl": "86400s"
        }
      }
    }
    ```
  - Nessun blocco `notification` lato server: altrimenti Android mostrerebbe automaticamente testo deciso dal server invece di lasciar risolvere la stringa generica localizzata sul telefono.
  - Nessun nome, testo intimo, tipo di contenuto specifico o data sensibile transita attraverso Google/FCM.

## 2. Ciclo di vita del processo su Android

1. **Avvio a freddo da FCM (app chiusa dal task switcher o dopo riavvio):**
   - Android istanzia `DeepSkyApplication.onCreate()` **senza** avviare `MainActivity` né l'engine Flutter.
   - `DeepSkyApplication` chiama immediatamente `RuntimeFirebaseCoordinator.ensureInitializedFromStorage()`.
   - Se `SharedPreferences("deep_sky_runtime_firebase")` contiene la configurazione runtime salvata in precedenza, `FirebaseApp.initializeApp(this, options)` viene eseguito prima che `DeepSkyFirebaseMessagingService.onMessageReceived` gestisca il messaggio.
2. **Arrivo del wakeup (`DeepSkyFirebaseMessagingService`):**
   - `onMessageReceived(RemoteMessage)` legge esclusivamente `data["l10nKey"]`.
   - Risolve la stringa generica dalle risorse locali Android (`strings.xml` / `values-it/strings.xml`), crea se necessario il canale `deep_sky_updates`, e mostra la notifica locale.
3. **Rotazione o invalidazione del token:**
   - `onNewToken(String token)` salva il token aggiornato nelle `SharedPreferences` (`pending_fcm_token`) e notifica il canale Flutter se attivo; al prossimo avvio o sync Flutter chiama `NativeBridge.consumePendingFcmToken()` e aggiorna il server via `PUT /api/v1/push/token`.
   - Lato server, se FCM HTTP v1 risponde con `404 UNREGISTERED` (o `400` con token non registrato), `PushService` elimina il record obsoleto da `push_registrations`.

## 3. Nota sull'integrazione con SP-02 (`AD-02`)

Su questo branch standalone `proto/sp-01`, gli endpoint `/api/v1/push/**` sono accessibili direttamente per consentire la verifica sul campo senza accoppiare SP-01 ai flussi di pairing. Al momento della promozione su `development`:
- `GET /api/v1/push/config` resta accessibile in fase di configurazione iniziale;
- `PUT /api/v1/push/token`, `DELETE /api/v1/push/token/{deviceId}` e l'invio di wakeup vengono protetti da `DeviceAuthFilter` (firma Ed25519 per dispositivo).

## 4. Matrice di test su due telefoni fisici (`SP01-04`, per il promotore)

1. App aperta in foreground.
2. App in background.
3. App **chiusa con swipe dal task switcher**.
4. Telefono **riavviato** senza riaprire l'app prima dell'invio.
5. Schermo spento prolungato (Doze / risparmio energetico attivo).
6. **Arresto forzato** da Impostazioni -> App: ci si aspetta che Android sopprima la consegna finché l'utente non riapre manualmente l'app; comportamento da verificare e documentare in ADR.
