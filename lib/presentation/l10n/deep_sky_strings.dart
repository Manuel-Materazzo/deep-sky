/// Bilingual (`it` / `en`) copy catalog (`P-02`, `V-08`, `V-10`..`V-12`, `N-07`).
class DeepSkyStrings {
  const DeepSkyStrings(this.languageCode);

  final String languageCode;

  bool get isIt => languageCode == 'it';

  String get appTitle => 'Deep Sky';
  String get homeTab => isIt ? 'Casa' : 'Home';
  String get usTab => isIt ? 'Noi' : 'Us';
  String get devicesTab => isIt ? 'Dispositivi' : 'Devices';
  String get settingsTab => isIt ? 'Impostazioni' : 'Settings';
  String get settingsButtonTooltip => isIt ? 'Impostazioni' : 'Settings';

  // Welcome & Invite (`S1-D02`, `S1-D03`, `S1-D05`, `S1-D06`, `S1-D10`)
  String get welcomeTitle => isIt ? 'La vostra casa' : 'Your home';
  String get welcomeSubtitle => isIt
      ? 'Uno spazio intimo e privato, solo per voi due. Invita la tua dolce metà.'
      : 'An intimate, private space, just for the two of you. Invite your other half.';
  String get joinTitle => isIt ? 'Raggiungi chi ami' : 'Reach your love';
  String get joinSubtitle => isIt
      ? 'Se il tuo partner è già pronto, inquadra il suo schermo o inserisci l\'invito.'
      : 'If your partner already lit your home, scan their screen or enter the invite.';
  String get recoverTitle =>
      isIt ? 'Ritrova la tua stanza' : 'Find your room again';
  String get recoverSubtitle => isIt
      ? 'Con le 24 parole segrete puoi rientrare nella vostra casa esattamente come l\'avete lasciata.'
      : 'With your 24 secret words you can step back into your home just as you left it.';

  String get inviteTab => isIt ? 'Invita' : 'Invite';
  String get joinSpaceTab => isIt ? 'Unisciti' : 'Join';
  String get recoverSpaceTab => isIt ? 'Recupera' : 'Recover';
  String get createSpaceTab => inviteTab;

  String get scanQrTitle => isIt ? 'Inquadra codice QR' : 'Scan QR code';
  String get scanQrDescription => isIt
      ? 'Rileva la chiave della casa e il server senza dover scrivere nulla.'
      : 'Detects your home invite and server right away with zero typing.';
  String get openCameraButton => isIt ? 'Apri fotocamera' : 'Open camera';
  String get scanQrActionLabel => isIt ? 'Scansiona QR' : 'Scan QR';
  String get scanQrInviteHint => isIt
      ? 'Inquadra il QR mostrato dal tuo partner'
      : 'Point at the QR code shown on your partner\'s phone';
  String get scanQrRecoveryHint => isIt
      ? 'Inquadra il QR della Recovery Key'
      : 'Point at your Recovery Key QR code';
  String get orEnterManuallyDivider =>
      isIt ? 'oppure manuale' : 'or enter manually';
  String get pasteButton => isIt ? 'Incolla' : 'Paste';
  String get cameraPermissionDeniedNotice => isIt
      ? 'Permesso fotocamera non concesso. Puoi incollare il link o il codice qui sotto.'
      : 'Camera permission was not granted. You can paste the link or code below.';
  String get cameraUnavailableNotice => isIt
      ? 'Scanner fotocamera non disponibile su questo dispositivo. Incolla il link o il codice qui sotto.'
      : 'Camera scanner is not available on this device. Paste the link or code below.';

  String get preparingHomeMessage =>
      isIt ? 'Preparazione della vostra casa...' : 'Preparing your home...';
  String get inviteErrorTitle => isIt
      ? 'Non riusciamo a preparare l\'invito'
      : 'We couldn\'t prepare the invite';
  String get inviteErrorBody => isIt
      ? 'Controlla la connessione o verifica l\'indirizzo del server qui sotto.'
      : 'Check your connection or verify the server address below.';
  String get retryButton => isIt ? 'Riprova' : 'Try again';

  String get qrSemanticsLabel =>
      isIt ? 'Codice QR d\'invito per il partner' : 'Partner invite QR code';
  String get qrCaption => isIt
      ? 'Inquadra con la fotocamera o invia il link'
      : 'Scan with your camera or send the link';
  String get shareInviteLinkButton =>
      isIt ? 'Condividi link d\'invito' : 'Share invite link';
  String get shareInviteMessage => isIt
      ? 'Ho preparato la nostra casa su Deep Sky. Apri questo link per raggiungermi:'
      : 'I prepared our home on Deep Sky. Open this link to join me:';
  String get shareFallbackCopiedNotice => isIt
      ? 'Link d\'invito copiato negli appunti.'
      : 'Invite link copied to clipboard.';
  String get copyButton => isIt ? 'Copia' : 'Copy';
  String get copiedButton => isIt ? 'Copiato!' : 'Copied!';

  String get waitingForPartner =>
      isIt ? 'In attesa del partner' : 'Waiting for your partner';
  String expiresInMinutes(int minutes) {
    if (minutes <= 1) {
      return isIt ? 'Scade tra meno di 1 min' : 'Expires in under 1 min';
    }
    return isIt ? 'Scade tra $minutes min' : 'Expires in $minutes min';
  }

  String get inviteExpiredMessage => isIt
      ? 'Questo invito è scaduto per sicurezza.'
      : 'This invite expired for your safety.';
  String get checkPartnerJoinedButton => isIt ? 'Controlla ora' : 'Check now';
  String get waitingForNewDeviceAutoDetect => isIt
      ? 'In attesa del nuovo telefono · Rilevamento automatico'
      : 'Waiting for new phone · Detecting automatically';
  String get enrollmentInviteReadyNotice => isIt
      ? 'Invito pronto: scansionalo o inseriscilo dal nuovo telefono. Il collegamento verrà rilevato automaticamente.'
      : 'Invite ready: scan or enter it on the new phone. Connection will be detected automatically.';
  String get regenerateInviteButton => isIt ? 'Rigenera' : 'Regenerate';
  String get generateNewInviteButton =>
      isIt ? 'Genera nuovo invito' : 'Generate new invite';

  // Server Drawer (`S1-D02-D03-D05`)
  String get serverLabel => 'Server';
  String serverOfficialSummary(String host) =>
      isIt ? 'Ufficiale ($host)' : 'Official ($host)';
  String serverCustomSummary(String host) =>
      isIt ? 'Personalizzato ($host)' : 'Custom ($host)';
  String get customizeServerAction => isIt ? 'Personalizza' : 'Customize';
  String get closeDrawerAction => isIt ? 'Chiudi' : 'Close';
  String get serverDrawerDescription => isIt
      ? 'La vostra casa risiede al sicuro sul cloud ufficiale. Se volete usarne un altro, inserite l\'indirizzo qui sotto.'
      : 'Your home is safe on the official cloud. If you prefer to host it somewhere else, enter the address below.';
  String get customServerFieldLabel => isIt
      ? 'Indirizzo IP o Dominio dedicato'
      : 'Dedicated domain or IP address';
  String get customServerFieldHint => isIt
      ? 'Es. 192.168.1.100:8080 o casa.mioserver.it'
      : 'e.g. 192.168.1.100:8080 or home.myserver.org';
  String get saveButton => isIt ? 'Salva' : 'Save';
  String get resetOfficialServerButton =>
      isIt ? 'Usa server ufficiale' : 'Use official server';
  String get invalidServerAddress => isIt
      ? 'Inserisci un indirizzo valido (es. casa.mioserver.it o 192.168.1.100:8080).'
      : 'Enter a valid address (e.g. home.myserver.org or 192.168.1.100:8080).';
  String get serverSyncNote => isIt
      ? 'Il link d\'invito e il QR code si sincronizzeranno in automatico.'
      : 'Your invite link and QR code will update automatically.';
  String get customServerConfirmTitle =>
      isIt ? 'Conferma server personalizzato' : 'Confirm custom server';
  String customServerConfirmBody(String host, String fullUrl) => isIt
      ? 'Questo invito punta a un server diverso da quello ufficiale Deep Sky:\n\n$host\n($fullUrl)\n\nI metadati di abbinamento e i pacchetti cifrati passeranno da questo server. Vuoi continuare?'
      : 'This invite points to a server other than the official Deep Sky server:\n\n$host\n($fullUrl)\n\nPairing metadata and encrypted envelopes will go through this server. Do you want to continue?';
  String get customServerConfirmAction =>
      isIt ? 'Usa questo server' : 'Use this server';
  String get customServerInsecureError => isIt
      ? 'Per sicurezza i server esterni devono usare HTTPS. HTTP è consentito solo per indirizzi locali o privati.'
      : 'For safety, external servers must use HTTPS. HTTP is only allowed for local or private addresses.';
  String get welcomeFooterNote => isIt
      ? 'Crittografia punto a punto • Solo per voi due'
      : 'End-to-end encrypted • Just for the two of you';

  // Welcome Header Sheets
  String get helpButtonTooltip =>
      isIt ? 'Aiuto e informazioni' : 'Help & information';
  String get helpSheetTitle =>
      isIt ? 'Come funziona Deep Sky' : 'How Deep Sky works';
  String get helpPointSpaceTitle =>
      isIt ? 'Uno spazio per due' : 'A space for two';
  String get helpPointSpaceBody => isIt
      ? 'Nessuna pubblicità, nessuna classifica e nessuna pressione: solo piccoli segni della vostra presenza.'
      : 'No ads, no streaks, no pressure: just small signs of your presence.';
  String get helpPointPairingTitle =>
      isIt ? 'Abbinamento semplice' : 'Simple pairing';
  String get helpPointPairingBody => isIt
      ? 'Condividi il link o mostra il QR al tuo partner, poi confrontate insieme il codice di verifica.'
      : 'Share the link or show the QR to your partner, then compare the verification code together.';
  String get helpPointPrivacyTitle =>
      isIt ? 'Cifratura end-to-end' : 'End-to-end encryption';
  String get helpPointPrivacyBody => isIt
      ? 'Le chiavi restano sui vostri telefoni: nessuno può leggere i vostri ricordi.'
      : 'Keys stay on your phones: not even the server operator can read your memories.';

  String get preferencesTooltip =>
      isIt ? 'Preferenze e nome telefono' : 'Preferences & phone name';
  String get preferencesSheetTitle =>
      isIt ? 'Questo telefono e preferenze' : 'This phone & preferences';
  String get deviceNameFieldLabel =>
      isIt ? 'Nome di questo telefono' : 'Name of this phone';
  String get defaultDeviceLabel =>
      isIt ? 'Telefono principale' : 'Primary phone';
  String get nightThemeToggleLabel => isIt ? 'Tema notturno' : 'Night theme';
  String get languageSelectorLabel =>
      isIt ? 'Lingua / Language' : 'Language / Lingua';

  // Home & Legacy M2 flows
  String get ourHomeTitle => isIt ? 'La nostra casa' : 'Our home';
  String get calmSubtitle => isIt
      ? 'Uno spazio privato per due persone.\nPiccoli gesti, senza fretta.'
      : 'A private space for two people.\nSmall gestures, without rush.';
  String get incomingThoughtBanner => isIt
      ? 'Hai un pensiero in arrivo.'
      : 'A quiet thought is arriving for you.';
  String get offlineReadOnlyBanner => isIt
      ? 'Sei offline · Puoi rileggere i gesti salvati, ma per inviare nuovi pensieri serve connessione.'
      : 'You are offline · You can still read saved gestures, while sending new thoughts needs a connection.';

  String get sendThoughtLabel => isIt ? 'Ti penso' : 'Thinking of you';
  String get thoughtNoteHint => isIt
      ? 'Aggiungi una piccola nota (facoltativa)'
      : 'Add a short note (optional)';
  String get thoughtSentConfirmation =>
      isIt ? 'Pensiero inviato in modo cifrato.' : 'Encrypted thought sent.';
  String get syncNow => isIt ? 'Aggiorna' : 'Refresh';

  String get saveRecoveryFirstHint => isIt
      ? 'Prima di inviare pensieri, salva le 24 parole di recupero in un luogo sicuro.'
      : 'Before sending thoughts, save your 24 recovery words somewhere safe.';
  String get confirmRecoveryCheckbox => isIt
      ? 'Ho salvato le 24 parole o il QR in un luogo sicuro'
      : 'I have saved the 24 words or QR code somewhere safe';
  String get confirmRecoveryButton =>
      isIt ? 'Conferma salvataggio' : 'Confirm saved';

  String get upgradeRequiredTitle =>
      isIt ? 'Aggiornamento richiesto' : 'Update required';
  String get upgradeRequiredBody => isIt
      ? 'Questa versione dell\'app non è più compatibile con il server della coppia. Aggiorna per continuare in sicurezza senza perdere i tuoi dati.'
      : 'This app version is no longer compatible with the couple server. Update cleanly to continue without losing your data.';
  String get checkUpdatesButton =>
      isIt ? 'Controlla aggiornamenti' : 'Check for updates';
  String get installUpdateButton =>
      isIt ? 'Scarica e installa aggiornamento' : 'Download & install update';

  String get revokedDeviceBanner => isIt
      ? 'Questo dispositivo è stato scollegato dalla casa. Puoi pulire i dati locali per ricominciare o ricollegarti.'
      : 'This device has been unlinked from the home. You can clear local data to start fresh or reconnect.';
  String get clearLocalSpaceButton =>
      isIt ? 'Pulisci spazio locale' : 'Clear local space';
  String get unlinkThisDeviceButton => isIt
      ? 'Scollega questo dispositivo e pulisci spazio locale'
      : 'Unlink this device and clear local space';
  String get unlinkDialogTitle =>
      isIt ? 'Scollegare questo dispositivo?' : 'Unlink this device?';
  String get unlinkDialogBodyOnline => isIt
      ? 'Solo questo telefono verrà scollegato e i suoi dati locali verranno cancellati. Il partner e gli altri dispositivi collegati continueranno a funzionare.'
      : 'Only this phone will be unlinked and its local data cleared. Your partner and any other connected devices will keep working.';
  String get unlinkDialogBodyOffline => isIt
      ? 'Sei offline: i dati locali di questo telefono verranno cancellati, ma il dispositivo resterà nell\'elenco finché non verrà revocato da un altro telefono.'
      : 'You are offline: local data on this phone will be cleared, while the device will remain listed until revoked from another phone.';
  String get unlinkDialogConfirm =>
      isIt ? 'Scollega e pulisci' : 'Unlink & clear';

  String get unpairCoupleButton =>
      isIt ? 'Interrompi abbinamento per entrambi' : 'End pairing for both';
  String get unpairDialogTitle => isIt
      ? 'Interrompere l\'abbinamento per entrambi?'
      : 'End pairing for both?';
  String get unpairDialogBody => isIt
      ? 'Questa azione scollega tutti i dispositivi di entrambi i partner e chiude la casa condivisa sul server. Non può essere annullata.'
      : 'This disconnects all devices for both partners and closes the shared home on the server. It cannot be undone.';
  String get unpairDialogConfirm =>
      isIt ? 'Interrompi abbinamento' : 'End pairing';
  String get cancel => isIt ? 'Annulla' : 'Cancel';
  String get localResetDoneNotice => isIt
      ? 'Spazio locale pulito. Puoi creare una nuova casa o ricollegarti.'
      : 'Local space cleared. You can create a new home or reconnect.';

  // Code Verification (`S1-D07` / `S1-D08`)
  String get verificationAppBarTitle =>
      isIt ? 'Verifica abbinamento' : 'Partner verification';
  String get verificationBadge =>
      isIt ? 'Verifica della chiave a due' : 'Two-way key verification';
  String get verificationHeadline =>
      isIt ? 'Conferma con l\'altro telefono' : 'Confirm with the other phone';
  String get verificationSubtitle => isIt
      ? 'Chiedi al tuo partner di controllare se sullo schermo legge la stessa combinazione.'
      : 'Ask your partner to check if their screen shows the same code.';
  String verificationConnectedPeer(String label) =>
      isIt ? '$label vuole unirsi a voi' : '$label wants to join you';
  String verificationInvitedBy(String label) =>
      isIt ? 'Invito da $label' : 'Invite from $label';
  String get sharedSasCodeLabel =>
      isIt ? 'Codice SAS condiviso' : 'Shared SAS code';
  String get verificationWaitingForPartner =>
      isIt ? 'In attesa dell\'altro telefono…' : 'Waiting for the other phone…';
  String get verificationReadyToConfirm =>
      isIt ? 'Pronto per la tua conferma' : 'Ready for your confirmation';
  String get verificationSyncedTag => isIt ? 'Sincrono' : 'Synced';
  String get verificationConfirmInviterButton => isIt
      ? 'Il codice coincide • Completa chiavi'
      : 'Code matches • Complete keys';
  String get verificationConfirmJoinerButton => isIt
      ? 'Il codice coincide • Completa ricezione'
      : 'Code matches • Complete setup';
  String get verificationMismatchButton =>
      isIt ? 'Il codice non coincide' : 'Code doesn\'t match';
  String get verificationMismatchDialogTitle =>
      isIt ? 'Il codice non coincide?' : 'Code doesn\'t match?';
  String get verificationMismatchDialogBody => isIt
      ? 'Se i numeri sui due schermi sono diversi, non completare l\'abbinamento. Annulleremo questo tentativo in sicurezza per riprovare con un nuovo invito.'
      : 'If the numbers on both screens differ, do not complete pairing. We will safely cancel this attempt so you can try again with a new invite.';
  String get verificationMismatchConfirmButton =>
      isIt ? 'Annulla abbinamento' : 'Cancel pairing';
  String get verificationMismatchKeepButton =>
      isIt ? 'Torna al codice' : 'Back to code';
  String get verificationMismatchCancelledNotice => isIt
      ? 'Verifica annullata: i codici non coincidevano. Abbiamo chiuso il tentativo in sicurezza; riprova con un nuovo invito.'
      : 'Verification cancelled: the codes did not match. We safely closed this attempt; try again with a new invite.';
  String get verificationWhyTitle =>
      isIt ? 'Perché questo passaggio?' : 'Why this step?';
  String get verificationWhyBody => isIt
      ? 'È un piccolo rituale iniziale per accertarvi che nessun occhio esterno possa mai intercettare i vostri ricordi, foto o sussurri notturni. Una volta confermato, non vi sarà più richiesto.'
      : 'It is a small initial ritual to ensure no outside eyes can ever intercept your memories, photos, or late-night whispers. Once confirmed, you won\'t be asked again.';

  // Space & Name Setup (`S1-D07-2` / `S1-D09`)
  String get spaceSetupAppBarTitle =>
      isIt ? 'Il vostro spazio' : 'Our Space Setup';
  String get spaceSetupHeadline => isIt
      ? 'Come vi chiamate nei vostri momenti?'
      : 'How should your partner see you?';
  String get spaceSetupSubtitle => isIt
      ? 'Scegli il nome con cui chi ami ti vedrà.'
      : 'Choose the name your loved one will see in the app.';
  String get spaceSetupPreviewYouFallback => isIt ? 'Tu' : 'You';
  String get spaceSetupPreviewPartnerFallback => isIt ? 'Partner' : 'Partner';
  String get spaceSetupPreviewHomeLabel => isIt ? 'La nostra casa' : 'Our home';
  String get spaceSetupInputLabel =>
      isIt ? 'Il tuo nome o vezzeggiativo' : 'Your name or pet name';
  String get spaceSetupInputVisibleHint =>
      isIt ? 'Visibile a chi ami' : 'Visible to your partner';
  String get spaceSetupInputPlaceholder =>
      isIt ? 'es. Luca, Cucciolo, Luccio...' : 'e.g. Alex, Sam, Love...';
  String get spaceSetupClearTooltip => isIt ? 'Cancella nome' : 'Clear name';
  String get spaceSetupSubmitButton =>
      isIt ? 'Tutto pronto, entra nella casa' : 'All set, enter our home';
  String get spaceSetupSkipButton => isIt
      ? 'Puoi sempre cambiarlo più tardi nelle impostazioni'
      : 'You can always change it later in settings';
  String get settingsProfileCardTitle =>
      isIt ? 'Il tuo nome nella casa' : 'Your name in your home';
  String get settingsProfileCardSubtitle => isIt
      ? 'È il nome che vede chi ami nei dispositivi e nei vostri momenti condivisi.'
      : 'This is the name your partner sees in devices and shared moments.';
  String get settingsSaveNameButton => isIt ? 'Aggiorna nome' : 'Update name';
  String get deviceNameUpdatedNotice =>
      isIt ? 'Nome aggiornato.' : 'Name updated.';

  // Recovery Key Setup (`S1-D04` / `S1-APP-02`)
  String get recoverySetupAppBarTitle =>
      isIt ? 'Chiave di recupero' : 'Recovery Key';
  String get recoverySetupHeadline => isIt
      ? 'Conserva la tua chiave di recupero'
      : 'Save your recovery key safely';
  String get recoverySetupSubtitle => isIt
      ? 'Queste 24 parole sono l\'unico modo per riaccendere la vostra casa se perdi o cambi entrambi i telefoni. Nessun server le conosce.'
      : 'These 24 words are the only way to restore your home if both phones are lost or replaced. No server knows them.';
  String get recoveryShowWordsTab => isIt ? '24 Parole' : '24 Words';
  String get recoveryShowQrTab => isIt ? 'Codice QR' : 'QR Code';
  String get recoveryCopyWordsButton =>
      isIt ? 'Copia frase (24 parole)' : 'Copy phrase (24 words)';
  String get recoveryCopiedNotice => isIt
      ? 'Frase di recupero copiata negli appunti.'
      : 'Recovery phrase copied to clipboard.';
  String get recoveryExportButton =>
      isIt ? 'Esporta promemoria offline' : 'Export offline reminder';
  String get recoveryWarningTitle =>
      isIt ? 'Come proteggerla davvero' : 'How to keep it truly safe';
  String get recoveryWarningBody => isIt
      ? '• Evita screenshot o foto che finiscono su cloud non cifrati.\n• Scrivila su carta o salvala in un gestore password cifrato offline.'
      : '• Avoid screenshots or photos synced to unencrypted cloud backups.\n• Write it on paper or save it in an offline encrypted password vault.';

  // Guided 24-word Recovery (`S1-D10` / `S1-APP-04`)
  String get recoverSectionHeadline =>
      isIt ? 'Ritrova la tua stanza' : 'Find your room again';
  String get recoverSectionSubtitle => isIt
      ? 'Inserisci le 24 parole di recupero nell\'ordine esatto, oppure inquadra il QR di recupero.'
      : 'Enter the 24 recovery words in exact order, or scan your saved recovery QR code.';
  String get recoverFieldPlaceholder => isIt
      ? 'Scrivi o incolla qui le tue 24 parole (es. abandon ability ...)'
      : 'Type or paste your 24 words here (e.g. abandon ability ...)';
  String recoverMissingWordsCounter(int missing) =>
      isIt ? '... $missing parole mancanti' : '... $missing words remaining';
  String get recoverWordsComplete =>
      isIt ? '✓ 24 parole complete' : '✓ All 24 words entered';
  String recoverInvalidWordsHint(int count) => isIt
      ? 'Controlla $count ${count == 1 ? 'parola non riconosciuta' : 'parole non riconosciute'} nel dizionario BIP-39.'
      : 'Check $count unrecognized ${count == 1 ? 'word' : 'words'} against the BIP-39 dictionary.';
  String get recoverSubmitButton =>
      isIt ? 'Ripristina e riaccendi la casa' : 'Restore and relight your home';
  String get recoverCalmFailureMessage => isIt
      ? 'Non siamo riusciti a sbloccare la stanza con questa chiave e questo server. Controlla l\'ordine delle 24 parole o l\'indirizzo del server e riprova.'
      : 'We could not unlock a room with this key and server. Check the 24 words order or server address and try again.';

  // Devices Tab & Calm Revocation (`S1-D11` / `S1-APP-05`)
  String devicesSectionTitle(int count) =>
      isIt ? 'Dispositivi collegati ($count)' : 'Connected devices ($count)';
  String get deviceStatusRevoked => isIt ? 'Revocato' : 'Revoked';
  String get deviceStatusThisPhone =>
      isIt ? 'Attivo · questo telefono' : 'Active · this phone';
  String get deviceStatusActive => isIt ? 'Attivo' : 'Active';
  String get revokeDeviceAction => isIt ? 'Revoca' : 'Revoke';
  String get revokeDialogTitle =>
      isIt ? 'Revocare questo dispositivo?' : 'Revoke this device?';
  String revokeDialogBody(String label) => isIt
      ? '«$label» perderà subito l\'accesso ai vostri ricordi su questo telefono. I dati cifrati condivisi restano al sicuro per gli altri dispositivi attivi.'
      : '"$label" will immediately lose access to your memories on that device. Your shared encrypted home remains intact on active devices.';
  String get revokeDialogConfirm => isIt ? 'Revoca accesso' : 'Revoke access';

  // Contextual Push Opt-in (`S1-D12` / `S1-APP-05`) & Settings (`S1-D13`/`S1-D14`)
  String get pushPromptTitle => isIt
      ? 'Avvisi discreti sul telefono'
      : 'Quiet notifications on this phone';
  String get pushPromptBody => isIt
      ? 'Ricevi un semplice risveglio anonimo quando il tuo partner ti pensa o chiede accesso: il server non invia mai testi o nomi.'
      : 'Receive a quiet anonymous nudge when your partner thinks of you or requests device approval—no names or message content ever leave your phones.';
  String get pushPromptEnableButton =>
      isIt ? 'Attiva notifiche discrete' : 'Enable quiet notifications';
  String get pushPromptLaterButton => isIt ? 'Non ora' : 'Not now';
  String get settingsPrefsTitle =>
      isIt ? 'Preferenze stanza e lingua' : 'Room & language preferences';
  String get settingsNightMode =>
      isIt ? 'Atmosfera notturna' : 'Night atmosphere';
  String get settingsReduceMotion =>
      isIt ? 'Riduci movimento' : 'Reduce motion';
  String get settingsLanguageLabel => 'Lingua / Language';
  String get settingsPushTitle => isIt
      ? 'Notifiche push discrete (FCM runtime)'
      : 'Quiet push notifications (runtime FCM)';
  String settingsPushActiveCount(int count) => isIt
      ? 'Attive (risvegli ricevuti: $count)'
      : 'Active (wakeups received: $count)';
  String get settingsPushInactive => isIt
      ? 'Non ancora attivate su questo telefono.'
      : 'Not yet enabled on this device.';
  String get settingsPushEnableButton => isIt
      ? 'Attiva notifiche su questo telefono'
      : 'Enable notifications on this phone';
  String get settingsOpenNotificationSettingsButton =>
      isIt ? 'Apri impostazioni notifiche' : 'Open notification settings';
  String get settingsPushPermissionGranted =>
      isIt ? 'Permesso di sistema: consentito' : 'System permission: allowed';
  String get settingsPushPermissionMissing => isIt
      ? 'Permesso di sistema: disattivato nelle impostazioni del telefono'
      : 'System permission: disabled in phone settings';
  String get pushServerDisabledError => isIt
      ? 'Le notifiche push non risultano attive su questo server.'
      : 'Push notifications are not enabled on this server.';
  String get pushPermissionDeniedError => isIt
      ? 'Il telefono blocca ancora le notifiche per Deep Sky. Apri le impostazioni per consentirle.'
      : 'Phone notification permission is still blocked. Open settings to allow it.';
  String get pushGmsUnavailableError => isIt
      ? 'Google Play Services non è disponibile o è limitato su questo telefono: le notifiche push richiedono Play Services attivi.'
      : 'Google Play Services is unavailable or restricted on this phone: push notifications require active Play Services.';
  String get pushTimeoutError => isIt
      ? 'Tempo scaduto durante la registrazione push con Google Play Services. Controlla rete o risparmio energetico e riprova.'
      : 'Timed out registering push notifications with Google Play Services. Check network or battery restrictions and try again.';
  String pushTokenFailedError(String detail) => isIt
      ? 'Impossibile attivare le notifiche su questo telefono ($detail).'
      : 'Unable to enable notifications on this phone ($detail).';
  String get settingsUpdatesTitle => isIt
      ? 'Aggiornamenti app (APK firmato offline)'
      : 'App updates (offline-signed APK)';
  String settingsVersionLine(String name, int code) =>
      isIt ? 'Versione: $name ($code)' : 'Version: $name ($code)';
  String get updateChannelLabel =>
      isIt ? 'Canale aggiornamenti' : 'Update channel';
  String get updateSourceFieldLabel => isIt
      ? 'Sorgente release (owner/repo o URL)'
      : 'Release source (owner/repo or URL)';
  String get updatePublicKeyFieldLabel =>
      isIt ? 'Chiave pubblica Ed25519 (base64)' : 'Ed25519 public key (base64)';
  String get advancedUpdateOptionsLabel =>
      isIt ? 'Opzioni avanzate sviluppatore' : 'Advanced developer options';
  String get allowCustomUpdateAnchorLabel => isIt
      ? 'Consenti sorgente o chiave personalizzata'
      : 'Allow custom update source or trust key';
  String get allowCustomUpdateAnchorHint => isIt
      ? 'Usa solo per test locali o fork fidati.'
      : 'Use only for local testing or trusted forks.';
  String updateDownloadProgress(int percent) => isIt
      ? 'Scaricamento aggiornamento… $percent%'
      : 'Downloading update… $percent%';
  String upgradeVersionSummary(
    String installedName,
    int installedCode,
    int? minCode,
  ) => isIt
      ? 'Versione installata: $installedName (codice $installedCode) · Minima server: ${minCode ?? '?'}'
      : 'Installed version: $installedName (code $installedCode) · Server minimum: ${minCode ?? '?'}';

  String get inviteMissingSasSecretError => isIt
      ? 'Questo codice è incompleto: incolla l\'intero link d\'invito o il codice completo ricevuto dal partner, oppure scansiona il QR.'
      : 'This invite code is incomplete: paste the full invite link or full pairing code from your partner, or scan the QR.';

  // S3-2 Home, Dual-State Thinking of You, Welcome Back & Content Packs (`S2-D05`, `S2-D07`, `S2-D09`)
  String get partnerFallbackName => isIt ? 'Il tuo partner' : 'Your partner';

  String partnerThoughtOfYouTitle(String partnerName) =>
      isIt ? '$partnerName ti ha pensato' : '$partnerName thought of you';

  String get replyThoughtButton => isIt ? 'Ricambia' : 'Send back';

  String get replyThoughtNoteHint => isIt
      ? 'Rispondi con una nota (facoltativa)'
      : 'Add a short note back (optional)';

  String get thoughtSentBannerTitle =>
      isIt ? 'Pensiero inviato' : 'Thought sent';

  String thoughtSentBannerSubtitle(String partnerName) => isIt
      ? 'Una luce gentile è partita verso $partnerName.'
      : 'A gentle light is on its way to $partnerName.';

  String get thoughtSentBannerCloseTooltip =>
      isIt ? 'Scrivi un altro pensiero' : 'Send another thought';

  String thoughtRelativeCaption(Duration elapsed) {
    final String rel;
    if (elapsed.inMinutes < 1) {
      rel = isIt ? 'Poco fa' : 'Just now';
    } else if (elapsed.inMinutes < 60) {
      rel = isIt ? '${elapsed.inMinutes}m fa' : '${elapsed.inMinutes}m ago';
    } else {
      rel = isIt ? '${elapsed.inHours}h fa' : '${elapsed.inHours}h ago';
    }
    return isIt
        ? '$rel • Un pensiero per te'
        : '$rel • A quiet thought for you';
  }

  String get quickThoughtTitle =>
      isIt ? 'Lascia un pensiero' : 'Leave a quiet thought';

  String get thoughtHistoryButtonTooltip =>
      isIt ? 'Storico pensieri' : 'Thought history';

  String get thoughtHistorySheetTitle => isIt ? 'Ti Penso' : 'Thinking of you';

  String get thoughtHistoryCloseTooltip => isIt ? 'Chiudi' : 'Close';

  String get thoughtHistoryEyebrow =>
      isIt ? 'I NOSTRI PENSIERI CONDIVISI' : 'OUR SHARED THOUGHTS';

  String thoughtHistoryCount(int count) {
    if (isIt) {
      return count == 1 ? '1 pensiero' : '$count pensieri';
    }
    return count == 1 ? '1 thought' : '$count thoughts';
  }

  String get thoughtHistoryCountSuffix => isIt ? 'insieme' : 'together';

  String get thoughtHistorySubtitle => isIt
      ? 'Ogni luce è un pensiero lasciato senza fretta.'
      : 'Every light is a thought left without rush.';

  String get thoughtHistoryToday => isIt ? 'OGGI' : 'TODAY';

  String get thoughtHistoryYesterday => isIt ? 'IERI' : 'YESTERDAY';

  String thoughtHistorySelfLabel(String myName) =>
      isIt ? 'Tu ($myName)' : 'You ($myName)';

  String get thoughtHistorySelfFallbackName => isIt ? 'Io' : 'Me';

  String get thoughtHistorySilentBadge =>
      isIt ? 'Pensiero silenzioso' : 'Silent thought';

  String get thoughtHistorySilentCaption => isIt
      ? 'Nessun testo, un tocco rapido sulla lampada accanto al divano.'
      : 'No text, a quick tap on the lamp by the couch.';

  String get thoughtHistoryEmptyTitle =>
      isIt ? 'Nessun pensiero ancora' : 'No thoughts yet';

  String get thoughtHistoryEmptyBody => isIt
      ? 'Quando lascerete una luce nella casa, apparirà qui.'
      : 'Whenever you leave a gentle light in your home, it will appear here.';

  String thoughtHistoryDateLabel(DateTime localDate, DateTime nowLocal) {
    const List<String> monthsIt = <String>[
      'gen',
      'feb',
      'mar',
      'apr',
      'mag',
      'giu',
      'lug',
      'ago',
      'set',
      'ott',
      'nov',
      'dic',
    ];
    const List<String> monthsEn = <String>[
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final String month = isIt
        ? monthsIt[localDate.month - 1]
        : monthsEn[localDate.month - 1];
    final String base = isIt
        ? '${localDate.day} $month'
        : '$month ${localDate.day}';
    return localDate.year == nowLocal.year ? base : '$base ${localDate.year}';
  }

  String get welcomeBackTitle => isIt
      ? 'Che bello rivederti, la casa ti aspettava.'
      : 'Welcome back, home was waiting for you.';

  String get welcomeBackSubtitle => isIt
      ? 'Tutto è rimasto com\'era, senza fretta.'
      : 'Everything stayed just as you left it, no rush.';

  String get dismissWelcomeBackTooltip => isIt ? 'Chiudi' : 'Dismiss';

  String get skyPreferenceLabel =>
      isIt ? 'Cielo e luce della casa' : 'Home sky & atmosphere';

  String get settingsGraphicsTitle =>
      isIt ? 'Grafiche della casa' : 'Home graphics';

  String settingsGraphicsActiveVersion(String version, bool isExternal) {
    final String source = isExternal
        ? (isIt ? 'aggiornate dal server' : 'updated from server')
        : (isIt ? 'incluse nell\'app' : 'bundled in app');
    return isIt
        ? 'Pacchetto attivo: v$version ($source)'
        : 'Active pack: v$version ($source)';
  }

  String get settingsGraphicsUpdateButton =>
      isIt ? 'Aggiorna grafiche' : 'Update graphics';

  String settingsGraphicsUpdatedHotReload(String version) => isIt
      ? 'Grafiche aggiornate a v$version e ricaricate subito.'
      : 'Graphics updated to v$version and reloaded right away.';

  String settingsGraphicsStagedNextLaunch(String version) => isIt
      ? 'Nuove grafiche v$version pronte al prossimo avvio.'
      : 'New graphics v$version ready for next launch.';

  String get settingsGraphicsUpToDate => isIt
      ? 'Hai già le grafiche più recenti.'
      : 'You already have the latest graphics.';

  String get settingsGraphicsUnavailable => isIt
      ? 'Nessun pacchetto grafico aggiuntivo disponibile sul server al momento.'
      : 'No additional graphics pack is published on the server yet.';

  String settingsGraphicsRolledBack(String failedVersion) => isIt
      ? 'Ripristinate automaticamente le grafiche funzionanti precedenti (v$failedVersion ignorata).'
      : 'Automatically restored the last known-good graphics (skipped v$failedVersion).';

  String get usSectionTitle => isIt ? 'La vostra coppia' : 'Your couple';

  String get usSyncNowButton => isIt ? 'Sincronizza ora' : 'Sync now';

  String unreadableEnvelopesNotice(int count) {
    if (count == 1) {
      return isIt
          ? 'Un elemento non può essere letto su questo dispositivo.'
          : 'One item could not be read on this device.';
    }
    return isIt
        ? '$count elementi non possono essere letti su questo dispositivo.'
        : '$count items could not be read on this device.';
  }

  // Friendly localized errors (`AU-16`, `AU-17`)
  String get clockSkewError => isIt
      ? 'L\'orologio del telefono sembra fuori sincrono. Controlla data e ora automatiche e riprova.'
      : 'Your phone\'s clock seems out of sync. Check automatic date & time settings and try again.';

  String get networkErrorGeneric => isIt
      ? 'Impossibile raggiungere il server. Controlla la connessione e riprova.'
      : 'Could not reach the server. Check your connection and try again.';

  String get rateLimitedError => isIt
      ? 'Troppi tentativi ravvicinati. Attendi un momento prima di riprovare.'
      : 'Too many attempts in a short time. Please wait a moment and try again.';

  String get payloadTooLargeError => isIt
      ? 'Contenuto troppo grande per essere inviato.'
      : 'The content is too large to send.';

  String get conflictErrorGeneric => isIt
      ? 'Operazione non completata: lo stato potrebbe essere cambiato. Riprova.'
      : 'Action could not be completed: state may have changed. Please try again.';

  String get serverErrorGeneric => isIt
      ? 'Il server ha riscontrato un problema temporaneo. Riprova tra poco.'
      : 'The server encountered a temporary problem. Please try again shortly.';

  String get unexpectedErrorGeneric => isIt
      ? 'Si è verificato un errore imprevisto. Riprova tra un momento.'
      : 'Something unexpected went wrong. Please try again in a moment.';

  String get joinAuthCheckError => isIt
      ? 'Impossibile verificare l\'accesso in questo momento. Riprova oppure richiedi un nuovo invito al partner.'
      : 'Could not verify access right now. Try again or ask your partner for a new invite.';

  String get inviteNotAcceptedYetError => isIt
      ? 'L\'altro telefono non ha ancora aperto l\'invito.'
      : 'The other phone has not opened the invite yet.';

  String get partnerNotConfirmedSasYetError => isIt
      ? 'L\'altro telefono non ha ancora confermato il codice SAS. Conferma prima sull\'altro telefono, poi riprova.'
      : 'The other phone has not confirmed the SAS code yet. Confirm on the other device first, then try again.';

  String get keysDeliveredNotice => isIt
      ? 'Chiavi inviate in modo cifrato. Ora completa la ricezione sull\'altro telefono.'
      : 'Keys delivered in encrypted form. Now finish receiving on the other phone.';
}
