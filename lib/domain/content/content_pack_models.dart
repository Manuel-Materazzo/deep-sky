import 'package:deep_sky/scene/scene_manifest.dart';

/// Strict semantic version `MAJOR.MINOR.PATCH` for content pack anti-downgrade (`S2-CTR-01`).
class SemanticVersion implements Comparable<SemanticVersion> {
  const SemanticVersion(this.major, this.minor, this.patch);

  static final RegExp _pattern = RegExp(
    r'^(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)$',
  );

  final int major;
  final int minor;
  final int patch;

  factory SemanticVersion.parse(String raw) {
    final Match? match = _pattern.firstMatch(raw.trim());
    if (match == null) {
      throw FormatException('Invalid semantic version: "$raw"');
    }
    return SemanticVersion(
      int.parse(match.group(1)!),
      int.parse(match.group(2)!),
      int.parse(match.group(3)!),
    );
  }

  static SemanticVersion? tryParse(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return null;
    }
    try {
      return SemanticVersion.parse(raw);
    } on FormatException {
      return null;
    }
  }

  @override
  int compareTo(SemanticVersion other) {
    if (major != other.major) return major.compareTo(other.major);
    if (minor != other.minor) return minor.compareTo(other.minor);
    return patch.compareTo(other.patch);
  }

  bool operator <(SemanticVersion other) => compareTo(other) < 0;
  bool operator <=(SemanticVersion other) => compareTo(other) <= 0;
  bool operator >(SemanticVersion other) => compareTo(other) > 0;
  bool operator >=(SemanticVersion other) => compareTo(other) >= 0;

  static SemanticVersion maxOf(Iterable<SemanticVersion> versions) {
    SemanticVersion best = versions.first;
    for (final SemanticVersion v in versions.skip(1)) {
      if (v > best) {
        best = v;
      }
    }
    return best;
  }

  @override
  bool operator ==(Object other) =>
      other is SemanticVersion &&
      major == other.major &&
      minor == other.minor &&
      patch == other.patch;

  @override
  int get hashCode => Object.hash(major, minor, patch);

  @override
  String toString() => '$major.$minor.$patch';
}

class ContentPackFileEntry {
  const ContentPackFileEntry({
    required this.relativePath,
    required this.sha256,
    required this.sizeBytes,
  });

  final String relativePath;
  final String sha256;
  final int sizeBytes;
}

class ContentPackChecksums {
  const ContentPackChecksums({
    required this.schemaVersion,
    required this.keyId,
    required this.packId,
    required this.packVersion,
    required this.minAppProtocol,
    required this.files,
  });

  final int schemaVersion;
  final String keyId;
  final String packId;
  final SemanticVersion packVersion;
  final int minAppProtocol;
  final Map<String, ContentPackFileEntry> files;
}

/// Active scene pack source resolved by [ContentPackService] (`S2-APP-02`).
class ResolvedContentPack {
  const ResolvedContentPack({
    required this.manifest,
    required this.assetRootPath,
    required this.isFileSystem,
    this.rolledBackFromVersion,
  });

  final SceneManifest manifest;
  final String assetRootPath;
  final bool isFileSystem;
  final String? rolledBackFromVersion;

  String get packVersion => manifest.packVersion;
}

enum ContentPackUpdateStatus {
  upToDate,
  notModified304,
  stagedForNextBoot,
  activatedHotReload,
  skippedMeteredNetwork,
  unavailable,
}

class ContentPackUpdateResult {
  const ContentPackUpdateResult({
    required this.status,
    this.packVersion,
    this.downloadedFiles = 0,
    this.reusedCachedFiles = 0,
    this.resolvedPack,
  });

  final ContentPackUpdateStatus status;
  final String? packVersion;
  final int downloadedFiles;
  final int reusedCachedFiles;
  final ResolvedContentPack? resolvedPack;
}

enum ContentPackErrorCode {
  unknownKeyId,
  signatureInvalid,
  keyIdMismatch,
  checksumsInvalid,
  pathTraversal,
  downgradeRejected,
  packIdMismatch,
  protocolUnsupported,
  fileHashMismatch,
  manifestInvalid,
  networkError,
}

class ContentPackException implements Exception {
  const ContentPackException(this.code, this.message);

  final ContentPackErrorCode code;
  final String message;

  String localizedMessage(String languageCode) {
    final bool isIt = languageCode == 'it';
    switch (code) {
      case ContentPackErrorCode.unknownKeyId:
      case ContentPackErrorCode.signatureInvalid:
      case ContentPackErrorCode.keyIdMismatch:
        return isIt
            ? 'Firma crittografica delle grafiche non valida: aggiornamento bloccato per sicurezza.'
            : 'Invalid graphics pack cryptographic signature: update blocked for safety.';
      case ContentPackErrorCode.pathTraversal:
      case ContentPackErrorCode.fileHashMismatch:
      case ContentPackErrorCode.checksumsInvalid:
      case ContentPackErrorCode.manifestInvalid:
        return isIt
            ? 'Pacchetto grafico non integro: mantenute le grafiche attuali.'
            : 'Graphics pack integrity check failed: keeping current graphics.';
      case ContentPackErrorCode.downgradeRejected:
        return isIt
            ? 'Versione grafiche più vecchia di quella minima consentita: ignorata.'
            : 'Graphics pack version is older than the minimum allowed: ignored.';
      case ContentPackErrorCode.packIdMismatch:
        // IR-01: a validly signed pack for a different packId is never the Home scene.
        return isIt
            ? 'Queste grafiche non appartengono a questa scena: ignorate.'
            : 'This graphics pack is not for this scene: ignored.';
      case ContentPackErrorCode.protocolUnsupported:
        return isIt
            ? 'Queste nuove grafiche richiedono una versione più recente dell\'app.'
            : 'These newer graphics require a newer version of the app.';
      case ContentPackErrorCode.networkError:
        return isIt
            ? 'Impossibile contattare il server per le grafiche. Controlla la connessione.'
            : 'Unable to reach the server for graphics updates. Check your connection.';
    }
  }

  @override
  String toString() => 'ContentPackException($code): $message';
}
