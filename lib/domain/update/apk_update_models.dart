/// Signed update manifest emitted by `scripts/sign-release.*` (SP-03, SEC-04, TC-10).
class ApkReleaseManifest {
  const ApkReleaseManifest({
    required this.schemaVersion,
    required this.packageId,
    required this.versionCode,
    required this.versionName,
    required this.apkFile,
    required this.apkSha256,
    required this.apkSizeBytes,
    required this.createdAt,
  });

  factory ApkReleaseManifest.fromJson(Map<String, dynamic> json) {
    final int schemaVersion = _parseInt(json['schemaVersion']);
    final String packageId = (json['packageId'] as String? ?? '').trim();
    final int versionCode = _parseInt(json['versionCode']);
    final String versionName = (json['versionName'] as String? ?? '').trim();
    final String apkFile = (json['apkFile'] as String? ?? '').trim();
    final String apkSha256 = (json['apkSha256'] as String? ?? '')
        .trim()
        .toLowerCase();
    final int apkSizeBytes = _parseInt(json['apkSizeBytes']);
    final String createdAt = (json['createdAt'] as String? ?? '').trim();

    if (schemaVersion != 1 ||
        packageId.isEmpty ||
        versionCode <= 0 ||
        versionName.isEmpty ||
        apkFile.isEmpty ||
        apkSha256.length != 64 ||
        apkSizeBytes <= 0) {
      throw const FormatException('Invalid APK release manifest fields.');
    }

    return ApkReleaseManifest(
      schemaVersion: schemaVersion,
      packageId: packageId,
      versionCode: versionCode,
      versionName: versionName,
      apkFile: apkFile,
      apkSha256: apkSha256,
      apkSizeBytes: apkSizeBytes,
      createdAt: createdAt,
    );
  }

  final int schemaVersion;
  final String packageId;
  final int versionCode;
  final String versionName;
  final String apkFile;
  final String apkSha256;
  final int apkSizeBytes;
  final String createdAt;

  static int _parseInt(Object? raw) {
    if (raw is int) {
      return raw;
    }
    if (raw is String) {
      return int.tryParse(raw.trim()) ?? 0;
    }
    return 0;
  }
}

/// Release distribution channel (`S1-D13`, `S1-UPD-01`).
enum UpdateChannel {
  stable('stable'),
  preview('preview');

  const UpdateChannel(this.storageValue);

  final String storageValue;

  static UpdateChannel fromStorage(String? raw) {
    return raw?.trim().toLowerCase() == 'preview'
        ? UpdateChannel.preview
        : UpdateChannel.stable;
  }

  String localizedLabel(String languageCode) {
    final bool isIt = languageCode == 'it';
    switch (this) {
      case UpdateChannel.stable:
        return isIt ? 'Stabile (consigliato)' : 'Stable (recommended)';
      case UpdateChannel.preview:
        return isIt ? 'Anteprima (pre-release)' : 'Preview (pre-release)';
    }
  }
}

class UpdateStorageInfo {
  const UpdateStorageInfo({
    required this.stagingDir,
    required this.availableBytes,
  });

  factory UpdateStorageInfo.fromMap(Map<Object?, Object?> map) {
    return UpdateStorageInfo(
      stagingDir: (map['stagingDir'] as String?) ?? '',
      availableBytes: (map['availableBytes'] as int?) ?? 0,
    );
  }

  final String stagingDir;
  final int availableBytes;
}

/// Conditional HTTP cache state for GitHub release manifest polling (`ETag` + cooldown).
class ReleaseCheckCacheEntry {
  const ReleaseCheckCacheEntry({
    required this.checkedAtUtc,
    this.etag,
    this.lastManifest,
  });

  final DateTime checkedAtUtc;
  final String? etag;
  final ApkReleaseManifest? lastManifest;
}

enum ApkUpdateCheckStatus {
  updateAvailable,
  upToDate,
  notModified304,
  throttledByCooldown,
}

class ApkUpdateCheckResult {
  const ApkUpdateCheckResult({
    required this.status,
    required this.cacheEntry,
    this.manifest,
  });

  final ApkUpdateCheckStatus status;
  final ReleaseCheckCacheEntry cacheEntry;
  final ApkReleaseManifest? manifest;
}

enum ApkUpdateErrorCode {
  signatureInvalid,
  manifestInvalid,
  packageMismatch,
  versionNotHigher,
  insufficientStorage,
  permissionDenied,
  downloadInterrupted,
  apkHashMismatch,
  apkCertificateMismatch,
  networkError,
}

/// Structured exception mapping every SP-03 failure scenario to a calm, plain-language message.
class ApkUpdateException implements Exception {
  const ApkUpdateException(this.code, this.technicalDetail);

  final ApkUpdateErrorCode code;
  final String technicalDetail;

  String get friendlyMessage => localizedMessage('it');

  String localizedMessage(String languageCode) {
    final bool isIt = languageCode == 'it';
    switch (code) {
      case ApkUpdateErrorCode.signatureInvalid:
        return isIt
            ? 'Aggiornamento rifiutato: la firma di sicurezza del manifest non è valida.'
            : 'Update rejected: release manifest signature is invalid.';
      case ApkUpdateErrorCode.manifestInvalid:
        return isIt
            ? 'Aggiornamento non riuscito: il file di descrizione rilascio è danneggiato.'
            : 'Update failed: release metadata file is damaged.';
      case ApkUpdateErrorCode.packageMismatch:
        return isIt
            ? 'Aggiornamento rifiutato: il pacchetto appartiene a una app diversa.'
            : 'Update rejected: package ID does not match Deep Sky.';
      case ApkUpdateErrorCode.versionNotHigher:
        return isIt
            ? 'Nessun aggiornamento più recente disponibile (la versione remota non è superiore a quella installata).'
            : 'No newer update available (remote version is not higher than installed).';
      case ApkUpdateErrorCode.insufficientStorage:
        return isIt
            ? 'Spazio libero insufficiente sul telefono per scaricare questo aggiornamento. Libera spazio e riprova.'
            : 'Not enough free storage on this phone to download this update.';
      case ApkUpdateErrorCode.permissionDenied:
        return isIt
            ? 'Permesso richiesto: abilita "Installa app sconosciute" per Deep Sky nelle impostazioni Android e riprova.'
            : 'Permission required: allow "Install unknown apps" for Deep Sky in Android settings and try again.';
      case ApkUpdateErrorCode.downloadInterrupted:
        return isIt
            ? 'Scarico interrotto dalla rete. Tocca Riprova per continuare dal punto interrotto.'
            : 'Download interrupted by network. Tap retry to resume cleanly.';
      case ApkUpdateErrorCode.apkHashMismatch:
        return isIt
            ? 'Aggiornamento rifiutato: il file APK scaricato è corrotto o alterato.'
            : 'Update rejected: downloaded APK file is corrupted or altered.';
      case ApkUpdateErrorCode.apkCertificateMismatch:
        return isIt
            ? 'Aggiornamento rifiutato: il file APK è firmato con una chiave diversa; i tuoi dati non sono stati toccati.'
            : 'Update rejected: APK is signed with a different key; your data is untouched.';
      case ApkUpdateErrorCode.networkError:
        return isIt
            ? 'Impossibile contattare il server degli aggiornamenti al momento.'
            : 'Unable to reach the update server right now.';
    }
  }

  @override
  String toString() =>
      'ApkUpdateException(${code.name}): $friendlyMessage [$technicalDetail]';
}
