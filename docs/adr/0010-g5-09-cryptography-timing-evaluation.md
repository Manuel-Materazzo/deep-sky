# ADR-0010 · Valutazione crittografica `cryptography` vs `cryptography_flutter` (`G5-09`)

- **Stato:** Proposta per revisione esterna **`G-5`** (richiesta tecnica preparata in `M2` / `G-2`)
- **Riferimenti:** `G5-09`, `S-01`, `S-06`, `N-06`, [Architettura](architecture.md) §7.1, [Piano di sviluppo](development-plan.md) cap. 6.3 / 6.7

## 1. Contesto e decisione attuale (M2)

Dalla revisione M2 (`PR-M2-01`, `PR-M2-04`), il client Flutter utilizza esclusivamente `package:cryptography ^2.9.0` (implementazione pure-Dart) per:

- **Ed25519:** firma per richiesta HTTP (`X-Signature` verso `DeviceAuthFilter`), verifica chiavi recovery (`RecoveryController`) e verifica manifest APK (`ApkUpdateService`);
- **X25519:** accordo chiave ECDH in pairing e enrollment multi-dispositivo (`AD-02`);
- **HKDF-SHA256:** derivazione di `K_root`, `recoveryAuthKeyPair`, chiavi di wrap e chiave cache locale offline (`AD-06`);
- **XChaCha20-Poly1305:** cifratura autenticata end-to-end di tutte le buste (`EVENT`, `SNAPSHOT`) e della cache locale cifrata.

`cryptography_flutter` non è ancora stato aggiunto in M2 per mantenere il build Android semplice e uniforme su Kotlin/Flutter prima dell'audit di sicurezza `G-5`.

## 2. Profilo di rischio temporizzazione (pure-Dart vs native FFI/BoringSSL/AndroidKeyStore)

| Aspetto | Stato attuale (`cryptography` pure-Dart) | Opzione candidata (`cryptography_flutter` + provider nativi) |
| :--- | :--- | :--- |
| **Modello di esecuzione** | VM Dart AOT (arm64/x86_64 Android) senza istruzioni SIMD/crypto dedicate garantite constant-time dal runtime | Delega a provider nativi Android (`Cipher` / BoringSSL / Conscrypt dove supportati) o fallback Dart |
| **Superficie d'attacco temporizzazione** | Esposizione remota **molto bassa**: le buste usano chiavi simmetriche per coppia e il server non è un oracolo interattivo di decifratura (`XChaCha20-Poly1305` verifica il tag prima del plaintext); **rischio residuo locale** in scenari multi-processo co-residenti (side-channel cache/timing) su operazioni scalari X25519/Ed25519 in Dart puro | Riduzione del side-channel locale per primitive supportate nativamente su Android; verifica necessaria su quali algoritmi abbiano effettivo backend nativo su API 26–35 (in particolare `XChaCha20` vs `AES-GCM` / `ChaCha20-Poly1305` standard) |
| **Impatto su Keystore / backup** | Le chiavi restano in `flutter_secure_storage` con `allowBackup="false"` (`AD-06`) | Da valutare in `G-5` se abbinare un wrapper `AndroidKeyStore` Hardware-backed per la chiave di device auth o per la chiave di cifratura della cache locale |

## 3. Quesiti formali per il revisore di sicurezza (`G-5`)

1. L'esecuzione pure-Dart di `cryptography` per **X25519** ed **Ed25519** su Android ARM64 comporta un rischio accettabile per il modello di minaccia di Deep Sky (coppia privata, dispositivo personale non condiviso, `allowBackup="false"`), oppure è richiesto l'upgrade a backend nativo constant-time (`cryptography_flutter` / FFI libsodium/BoringSSL)?
2. Per la cifratura locale/rete, `XChaCha20-Poly1305` in pure-Dart è preferibile rispetto a `ChaCha20-Poly1305` / `AES-256-GCM` accelerato via `cryptography_flutter` (Conscrypt/BoringSSL) su API >= 26?
3. È raccomandato introdurre il binding Hardware-backed `AndroidKeyStore` (`StrongBox` / `TEE`) per la chiave privata Ed25519 del dispositivo e per la chiave di cifratura della cache offline (`EncryptedLocalCache`), mantenendo portabile solo il seme di recupero a 24 parole (`F-20`)?

## 4. Criterio di uscita M2 (`G-2`) / decisione differita

In M2 non viene modificata la dipendenza (`cryptography: ^2.9.0` rimane bloccata in `pubspec.yaml` con annotazione `G5-09`). L'eventuale adozione di `cryptography_flutter` o di bindings nativi avverrà come PR dedicata dopo la risposta del revisore a valle del gate `G-5`, senza rompere il formato delle buste E2EE esistenti.
