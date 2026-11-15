/// Minimal bilingual (`it` / `en`) copy catalog for M2 skeleton flows (`P-02`, `V-08`).
class DeepSkyStrings {
  const DeepSkyStrings(this.languageCode);

  final String languageCode;

  bool get isIt => languageCode == 'it';

  String get appTitle => 'Deep Sky';
  String get homeTab => isIt ? 'Casa' : 'Home';
  String get devicesTab => isIt ? 'Dispositivi' : 'Devices';
  String get settingsTab => isIt ? 'Impostazioni' : 'Settings';

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

  String get createSpaceTab => isIt ? 'Crea casa' : 'Create home';
  String get joinSpaceTab => isIt ? 'Unisciti' : 'Join';
  String get recoverSpaceTab => isIt ? 'Recupera' : 'Recover';

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
}
