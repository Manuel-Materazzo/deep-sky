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
}
