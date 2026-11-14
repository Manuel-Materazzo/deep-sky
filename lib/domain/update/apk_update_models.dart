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
    final int schemaVersion = json['schemaVersion'] as int? ?? 0;
    final String packageId = (json['packageId'] as String? ?? '').trim();
    final int versionCode = json['versionCode'] as int? ?? 0;
    final String versionName = (json['versionName'] as String? ?? '').trim();
    final String apkFile = (json['apkFile'] as String? ?? '').trim();
    final String apkSha256 = (json['apkSha256'] as String? ?? '')
        .trim()
        .toLowerCase();
    final int apkSizeBytes = json['apkSizeBytes'] as int? ?? 0;
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

  String get friendlyMessage {
    switch (code) {
      case ApkUpdateErrorCode.signatureInvalid:
        return 'Aggiornamento rifiutato: la firma di sicurezza del manifest non è valida.';
      case ApkUpdateErrorCode.manifestInvalid:
        return 'Aggiornamento non riuscito: il file di descrizione rilascio è danneggiato.';
      case ApkUpdateErrorCode.packageMismatch:
        return 'Aggiornamento rifiutato: il pacchetto appartiene a una app diversa.';
      case ApkUpdateErrorCode.versionNotHigher:
        return 'Nessun aggiornamento più recente disponibile (la versione remota non è superiore a quella installata).';
      case ApkUpdateErrorCode.insufficientStorage:
        return 'Spazio libero insufficiente sul telefono per scaricare questo aggiornamento. Libera spazio e riprova.';
      case ApkUpdateErrorCode.permissionDenied:
        return 'Permesso richiesto: abilita "Installa app sconosciute" per Deep Sky nelle impostazioni Android e riprova.';
      case ApkUpdateErrorCode.downloadInterrupted:
        return 'Scarico interrotto dalla rete. Tocca Riprova per continuare dal punto interrotto.';
      case ApkUpdateErrorCode.apkHashMismatch:
        return 'Aggiornamento rifiutato: il file APK scaricato è corrotto o alterato.';
      case ApkUpdateErrorCode.apkCertificateMismatch:
        return 'Aggiornamento rifiutato: il file APK è firmato con una chiave diversa; i tuoi dati non sono stati toccati.';
      case ApkUpdateErrorCode.networkError:
        return 'Impossibile contattare il server degli aggiornamenti al momento.';
    }
  }

  @override
  String toString() =>
      'ApkUpdateException(${code.name}): $friendlyMessage [$technicalDetail]';
}
