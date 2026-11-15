/// Bilingual (`it` / `en`) copy catalog (`P-02`, `V-08`, `V-10`..`V-12`, `N-07`).
class DeepSkyStrings {
  const DeepSkyStrings(this.languageCode);

  final String languageCode;

  bool get isIt => languageCode == 'it';

  String get appTitle => 'Deep Sky';
  String get homeTab => isIt ? 'Casa' : 'Home';
  String get devicesTab => isIt ? 'Dispositivi' : 'Devices';
  String get settingsTab => isIt ? 'Impostazioni' : 'Settings';

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
      ? 'Rileva all\'istante la chiave della casa e il server senza dover scrivere nulla.'
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
  String get checkPartnerJoinedButton =>
      isIt ? 'Verifica se si è unito' : 'Check if partner joined';
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
      ? 'La vostra casa risiede al sicuro sul cloud ufficiale. Se desiderate ospitarla sul vostro server personale o IP privato, inseritelo qui sotto.'
      : 'Your home lives safely on the official cloud. If you prefer to host it on your personal server or private IP, enter it below.';
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
      ? 'Le chiavi restano sui vostri telefoni: nemmeno chi gestisce il server può leggere i vostri ricordi.'
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
      ? 'Chiedi al tuo partner di controllare se sullo schermo legge la stessa combinazione luminosa.'
      : 'Ask your partner to check if their screen shows the same luminous code.';
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
  String get spaceSetupBadge =>
      isIt ? 'Fase finale di accoglienza' : 'Final welcome step';
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
}
