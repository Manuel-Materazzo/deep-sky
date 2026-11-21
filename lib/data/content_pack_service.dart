import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:deep_sky/data/apk_update_service.dart';
import 'package:deep_sky/data/scene_manifest_parser.dart';
import 'package:deep_sky/data/secure_key_store.dart';
import 'package:deep_sky/domain/content/content_pack_models.dart';
import 'package:deep_sky/scene/scene_manifest.dart';
import 'package:http/http.dart' as http;

/// Verifies, caches, stages, hot-reloads, and rolls back signed file-by-file content packs
/// (`TC-10`, `AR-09`, `G5-07`, `S2-CTR-01`, `S2-APP-02`).
///
/// Cryptographic verification strictly executes Ed25519 signature checks over the raw
/// `pack-checksums.json` bytes using the `keyId` carried in `pack-checksums.json.sig`
/// **before** any JSON parsing occurs (`G5-07`).
class ContentPackService {
  ContentPackService({
    required this._keyStore,
    required Map<String, SimplePublicKey> trustedPublicKeys,
    http.Client? httpClient,
    this._manifestParser = const SceneManifestParser(),
    this._resolveStorageRootDir,
    this._isConnectionUnmetered,
    this.appProtocolVersion = 1,
    this.clientVersionCode = 1,
  }) : _trustedPublicKeys = Map<String, SimplePublicKey>.unmodifiable(
         trustedPublicKeys,
       ),
       _http = httpClient ?? http.Client();

  static const String _metaStorageKey = 'deepsky.content_pack.meta.v1';
  static const int maxFailedBootAttemptsBeforeRollback = 2;
  static final Ed25519 _ed25519 = Ed25519();
  static final RegExp _keyIdPattern = RegExp(r'^[a-z0-9][a-z0-9_-]{0,31}$');
  static final RegExp _sha256Pattern = RegExp(r'^[0-9a-f]{64}$');

  final SecureKeyStore _keyStore;
  final Map<String, SimplePublicKey> _trustedPublicKeys;
  final http.Client _http;
  final SceneManifestParser _manifestParser;
  final Future<String?> Function()? _resolveStorageRootDir;
  final Future<bool> Function()? _isConnectionUnmetered;
  final int appProtocolVersion;
  final int clientVersionCode;

  /// Parses trusted key maps (`keyId -> base64 SPKI or raw 32B Ed25519 public key`).
  static Map<String, SimplePublicKey> parseTrustedKeyMap(
    Map<String, String> encodedKeys,
  ) {
    final Map<String, SimplePublicKey> result = <String, SimplePublicKey>{};
    for (final MapEntry<String, String> e in encodedKeys.entries) {
      result[e.key] = ApkUpdateService.parseEd25519PublicKey(e.value);
    }
    return Map<String, SimplePublicKey>.unmodifiable(result);
  }

  /// Validates that [rawPath] is a safe POSIX relative path without traversal (`S2-CTR-01`, `G5-07`).
  static bool isSafeRelativePath(String rawPath) {
    if (rawPath.isEmpty || rawPath != rawPath.trim()) {
      return false;
    }
    if (rawPath.startsWith('/') ||
        rawPath.contains(r'\') ||
        rawPath.contains(':') ||
        rawPath.contains('\u0000')) {
      return false;
    }
    for (final String seg in rawPath.split('/')) {
      if (seg.isEmpty || seg == '.' || seg == '..') {
        return false;
      }
    }
    return true;
  }

  /// Computes the persistent minimum acceptable pack version (`S2-CTR-01`, `AD-06`).
  static SemanticVersion computeMinAcceptableVersion({
    required SemanticVersion bundledPackVersion,
    SemanticVersion? localMaxSeenPackVersion,
    SemanticVersion? serverMinPackVersion,
  }) {
    final List<SemanticVersion> candidates = <SemanticVersion>[
      bundledPackVersion,
      ?localMaxSeenPackVersion,
      ?serverMinPackVersion,
    ];
    return SemanticVersion.maxOf(candidates);
  }

  /// Verifies the Ed25519 signature over [rawChecksumsBytes] strictly **before** calling
  /// `jsonDecode`, then parses and validates `pack-checksums.json` (`G5-07`, `S2-SEC-01`).
  Future<ContentPackChecksums> verifyAndParseChecksums({
    required Uint8List rawChecksumsBytes,
    required Uint8List rawSignatureBytes,
  }) async {
    final ({String keyId, Uint8List sigBytes}) parsedSig = _parseSigEnvelope(
      rawSignatureBytes,
    );
    final SimplePublicKey? trustedKey = _trustedPublicKeys[parsedSig.keyId];
    if (trustedKey == null) {
      throw ContentPackException(
        ContentPackErrorCode.unknownKeyId,
        'Unknown content signing keyId "${parsedSig.keyId}".',
      );
    }

    final bool validSig = await _ed25519.verify(
      rawChecksumsBytes,
      signature: Signature(parsedSig.sigBytes, publicKey: trustedKey),
    );
    if (!validSig) {
      throw const ContentPackException(
        ContentPackErrorCode.signatureInvalid,
        'Ed25519 signature verification failed over raw pack-checksums.json bytes.',
      );
    }

    // JSON parsing happens ONLY after raw-byte Ed25519 verification succeeds (G5-07).
    final Object? decoded;
    try {
      decoded = jsonDecode(utf8.decode(rawChecksumsBytes));
    } catch (error) {
      throw ContentPackException(
        ContentPackErrorCode.checksumsInvalid,
        'Malformed pack-checksums.json: $error',
      );
    }
    if (decoded is! Map<String, Object?>) {
      throw const ContentPackException(
        ContentPackErrorCode.checksumsInvalid,
        'pack-checksums.json root must be a JSON object.',
      );
    }

    final int? schemaVersion = decoded['schemaVersion'] as int?;
    final String? payloadKeyId = decoded['keyId'] as String?;
    final String? packId = decoded['packId'] as String?;
    final String? packVersionRaw = decoded['packVersion'] as String?;
    final int? minAppProtocol = decoded['minAppProtocol'] as int?;
    final Object? rawFiles = decoded['files'];

    if (schemaVersion == null || schemaVersion < 1) {
      throw const ContentPackException(
        ContentPackErrorCode.checksumsInvalid,
        'Missing or invalid schemaVersion.',
      );
    }
    if (payloadKeyId == null || payloadKeyId != parsedSig.keyId) {
      throw ContentPackException(
        ContentPackErrorCode.keyIdMismatch,
        'Payload keyId "$payloadKeyId" does not match signature keyId "${parsedSig.keyId}".',
      );
    }
    if (packId == null || packId.trim().isEmpty) {
      throw const ContentPackException(
        ContentPackErrorCode.checksumsInvalid,
        'Missing packId.',
      );
    }
    final SemanticVersion? packVersion = SemanticVersion.tryParse(
      packVersionRaw,
    );
    if (packVersion == null) {
      throw ContentPackException(
        ContentPackErrorCode.checksumsInvalid,
        'Invalid packVersion "$packVersionRaw".',
      );
    }
    if (minAppProtocol == null || minAppProtocol < 1) {
      throw const ContentPackException(
        ContentPackErrorCode.checksumsInvalid,
        'Missing or invalid minAppProtocol.',
      );
    }
    if (minAppProtocol > appProtocolVersion) {
      throw ContentPackException(
        ContentPackErrorCode.protocolUnsupported,
        'Pack requires minAppProtocol=$minAppProtocol > appProtocol=$appProtocolVersion.',
      );
    }
    if (rawFiles is! Map<String, Object?> ||
        !rawFiles.containsKey('manifest.json')) {
      throw const ContentPackException(
        ContentPackErrorCode.checksumsInvalid,
        'files map must include manifest.json.',
      );
    }

    final Map<String, ContentPackFileEntry> entries =
        <String, ContentPackFileEntry>{};
    for (final MapEntry<String, Object?> item in rawFiles.entries) {
      final String relPath = item.key;
      if (!isSafeRelativePath(relPath)) {
        throw ContentPackException(
          ContentPackErrorCode.pathTraversal,
          'Unsafe relative path in pack-checksums.json: "$relPath".',
        );
      }
      final Object? val = item.value;
      if (val is! Map<String, Object?>) {
        throw ContentPackException(
          ContentPackErrorCode.checksumsInvalid,
          'Invalid file metadata for "$relPath".',
        );
      }
      final String sha = ((val['sha256'] as String?) ?? '')
          .trim()
          .toLowerCase();
      final int? sizeBytes = val['sizeBytes'] as int?;
      if (!_sha256Pattern.hasMatch(sha) || sizeBytes == null || sizeBytes < 0) {
        throw ContentPackException(
          ContentPackErrorCode.checksumsInvalid,
          'Invalid sha256 or sizeBytes for "$relPath".',
        );
      }
      entries[relPath] = ContentPackFileEntry(
        relativePath: relPath,
        sha256: sha,
        sizeBytes: sizeBytes,
      );
    }

    return ContentPackChecksums(
      schemaVersion: schemaVersion,
      keyId: payloadKeyId,
      packId: packId.trim(),
      packVersion: packVersion,
      minAppProtocol: minAppProtocol,
      files: Map<String, ContentPackFileEntry>.unmodifiable(entries),
    );
  }

  /// Resolves which pack to render on startup, promoting any verified `staged/` pack
  /// and automatically rolling back to `previous/` or `bundled` if `packBootAttempts >= 2`
  /// (`S2-CTR-01`, `S2-APP-02`).
  Future<ResolvedContentPack> resolveStartupPack({
    required SceneManifest bundledManifest,
    required String bundledAssetRoot,
    SemanticVersion? serverMinPackVersion,
  }) async {
    final String? rootPath = await _getStorageRootPath();
    if (rootPath == null) {
      return ResolvedContentPack(
        manifest: bundledManifest,
        assetRootPath: bundledAssetRoot,
        isFileSystem: false,
      );
    }

    final SemanticVersion bundledVer = SemanticVersion.parse(
      bundledManifest.packVersion,
    );
    _PackMeta meta = await _loadMeta();

    // 1) Promote any verified staged pack before counting boot attempts.
    if (meta.stagedVersion != null) {
      final SemanticVersion? stagedVer = SemanticVersion.tryParse(
        meta.stagedVersion,
      );
      final SemanticVersion minAllowed = computeMinAcceptableVersion(
        bundledPackVersion: bundledVer,
        localMaxSeenPackVersion: SemanticVersion.tryParse(meta.maxSeenVersion),
        serverMinPackVersion: serverMinPackVersion,
      );
      if (stagedVer != null &&
          stagedVer >= minAllowed &&
          meta.stagedVersion != meta.blockedVersion) {
        final Directory stagedDir = _packDir(
          rootPath,
          'staged',
          meta.stagedVersion!,
        );
        if (_loadVerifiedManifestFromDir(stagedDir) != null) {
          final String? prevActive = meta.activeVersion;
          if (prevActive != null && prevActive != meta.stagedVersion) {
            await _moveDirReplacing(
              _packDir(rootPath, 'active', prevActive),
              _packDir(rootPath, 'previous', prevActive),
            );
            meta = meta.copyWith(previousVersion: prevActive);
          }
          await _moveDirReplacing(
            stagedDir,
            _packDir(rootPath, 'active', meta.stagedVersion!),
          );
          final SemanticVersion nextMax = computeMinAcceptableVersion(
            bundledPackVersion: bundledVer,
            localMaxSeenPackVersion: SemanticVersion.tryParse(
              meta.maxSeenVersion,
            ),
            serverMinPackVersion: stagedVer,
          );
          meta = meta.copyWith(
            activeVersion: meta.stagedVersion,
            clearStagedVersion: true,
            maxSeenVersion: nextMax.toString(),
            packBootAttempts: 0,
          );
          await _saveMeta(meta);
        } else {
          meta = meta.copyWith(clearStagedVersion: true);
          await _saveMeta(meta);
        }
      } else {
        meta = meta.copyWith(clearStagedVersion: true);
        await _saveMeta(meta);
      }
    }

    // 2) Check active external pack and apply last-known-good rollback guard.
    if (meta.activeVersion != null) {
      final String activeVerStr = meta.activeVersion!;
      final SemanticVersion? activeVer = SemanticVersion.tryParse(activeVerStr);
      final SemanticVersion minAllowed = computeMinAcceptableVersion(
        bundledPackVersion: bundledVer,
        serverMinPackVersion: serverMinPackVersion,
      );

      final bool exceededBootFailures =
          meta.packBootAttempts >= maxFailedBootAttemptsBeforeRollback;
      final bool belowMinimum = activeVer == null || activeVer < minAllowed;

      if (exceededBootFailures || belowMinimum) {
        // Automatic rollback to previous known-good pack or bundled APK pack.
        final String? prevVerStr = meta.previousVersion;
        if (prevVerStr != null) {
          final Directory prevDir = _packDir(rootPath, 'previous', prevVerStr);
          final SceneManifest? prevManifest = _loadVerifiedManifestFromDir(
            prevDir,
          );
          final SemanticVersion? prevVer = SemanticVersion.tryParse(prevVerStr);
          if (prevManifest != null &&
              prevVer != null &&
              prevVer >= minAllowed) {
            await _moveDirReplacing(
              prevDir,
              _packDir(rootPath, 'active', prevVerStr),
            );
            meta = meta.copyWith(
              activeVersion: prevVerStr,
              clearPreviousVersion: true,
              blockedVersion: exceededBootFailures
                  ? activeVerStr
                  : meta.blockedVersion,
              packBootAttempts: 1,
            );
            await _saveMeta(meta);
            return ResolvedContentPack(
              manifest: prevManifest,
              assetRootPath: _packDir(rootPath, 'active', prevVerStr).path,
              isFileSystem: true,
              rolledBackFromVersion: activeVerStr,
            );
          }
        }

        // Fall back cleanly to APK-bundled pack.
        meta = meta.copyWith(
          clearActiveVersion: true,
          clearPreviousVersion: true,
          blockedVersion: exceededBootFailures
              ? activeVerStr
              : meta.blockedVersion,
          packBootAttempts: 0,
        );
        await _saveMeta(meta);
        return ResolvedContentPack(
          manifest: bundledManifest,
          assetRootPath: bundledAssetRoot,
          isFileSystem: false,
          rolledBackFromVersion: activeVerStr,
        );
      }

      final Directory activeDir = _packDir(rootPath, 'active', activeVerStr);
      final SceneManifest? activeManifest = _loadVerifiedManifestFromDir(
        activeDir,
      );
      if (activeManifest != null) {
        meta = meta.copyWith(packBootAttempts: meta.packBootAttempts + 1);
        await _saveMeta(meta);
        return ResolvedContentPack(
          manifest: activeManifest,
          assetRootPath: activeDir.path,
          isFileSystem: true,
        );
      }
    }

    return ResolvedContentPack(
      manifest: bundledManifest,
      assetRootPath: bundledAssetRoot,
      isFileSystem: false,
    );
  }

  /// Resets `packBootAttempts` to `0` once the Home first frame renders cleanly (`S2-APP-02`).
  Future<void> markHomeBootSucceeded() async {
    final _PackMeta meta = await _loadMeta();
    if (meta.packBootAttempts == 0) {
      return;
    }
    await _saveMeta(meta.copyWith(packBootAttempts: 0));
  }

  /// Downloads verified file-by-file content pack updates from [serverBaseUrl].
  ///
  /// - When [manualForce] is `false` (silent background mode), runs only on unmetered networks,
  ///   honors `If-None-Match` (`ETag`), and stages the update for the next app launch.
  /// - When [manualForce] is `true` (Settings "Aggiorna grafiche" button), downloads even on
  ///   metered networks and promotes the verified pack to `active/` immediately for hot reload.
  Future<ContentPackUpdateResult> syncFromServer({
    required String serverBaseUrl,
    required SemanticVersion bundledPackVersion,
    required SemanticVersion currentActivePackVersion,
    SemanticVersion? serverMinPackVersion,
    bool manualForce = false,
  }) async {
    if (!manualForce && _isConnectionUnmetered != null) {
      final bool unmetered = await _isConnectionUnmetered();
      if (!unmetered) {
        return const ContentPackUpdateResult(
          status: ContentPackUpdateStatus.skippedMeteredNetwork,
        );
      }
    }

    final String? rootPath = await _getStorageRootPath();
    if (rootPath == null) {
      return const ContentPackUpdateResult(
        status: ContentPackUpdateStatus.unavailable,
      );
    }

    final _PackMeta meta = await _loadMeta();
    final String base = serverBaseUrl.replaceAll(RegExp(r'/+$'), '');
    final Map<String, String> baseHeaders = <String, String>{
      'X-Client-Version-Code': clientVersionCode.toString(),
      'X-Protocol-Version': appProtocolVersion.toString(),
    };

    final Map<String, String> checksumHeaders = <String, String>{
      ...baseHeaders,
      if (!manualForce && meta.etag != null && meta.etag!.isNotEmpty)
        'If-None-Match': meta.etag!,
    };

    final http.Response checksumsResp;
    try {
      checksumsResp = await _http.get(
        Uri.parse('$base/api/v1/content/pack/checksums'),
        headers: checksumHeaders,
      );
    } catch (error) {
      throw ContentPackException(ContentPackErrorCode.networkError, '$error');
    }

    if (checksumsResp.statusCode == 304) {
      return const ContentPackUpdateResult(
        status: ContentPackUpdateStatus.notModified304,
      );
    }
    if (checksumsResp.statusCode == 404) {
      return const ContentPackUpdateResult(
        status: ContentPackUpdateStatus.unavailable,
      );
    }
    if (checksumsResp.statusCode != 200) {
      throw ContentPackException(
        ContentPackErrorCode.networkError,
        'HTTP ${checksumsResp.statusCode} fetching pack checksums',
      );
    }

    final http.Response sigResp;
    try {
      sigResp = await _http.get(
        Uri.parse('$base/api/v1/content/pack/checksums.sig'),
        headers: baseHeaders,
      );
    } catch (error) {
      throw ContentPackException(ContentPackErrorCode.networkError, '$error');
    }
    if (sigResp.statusCode != 200) {
      throw ContentPackException(
        ContentPackErrorCode.networkError,
        'HTTP ${sigResp.statusCode} fetching pack signature',
      );
    }

    final ContentPackChecksums checksums = await verifyAndParseChecksums(
      rawChecksumsBytes: Uint8List.fromList(checksumsResp.bodyBytes),
      rawSignatureBytes: Uint8List.fromList(sigResp.bodyBytes),
    );

    // Anti-downgrade guard: max(bundled, localMaxSeen, serverMin)
    final SemanticVersion minAllowed = computeMinAcceptableVersion(
      bundledPackVersion: bundledPackVersion,
      localMaxSeenPackVersion: SemanticVersion.tryParse(meta.maxSeenVersion),
      serverMinPackVersion: serverMinPackVersion,
    );
    if (checksums.packVersion < minAllowed) {
      throw ContentPackException(
        ContentPackErrorCode.downgradeRejected,
        'Remote pack ${checksums.packVersion} < min acceptable $minAllowed.',
      );
    }

    if (!manualForce &&
        meta.blockedVersion == checksums.packVersion.toString()) {
      return ContentPackUpdateResult(
        status: ContentPackUpdateStatus.upToDate,
        packVersion: currentActivePackVersion.toString(),
      );
    }

    if (checksums.packVersion == currentActivePackVersion &&
        !manualForce &&
        meta.activeVersion == checksums.packVersion.toString()) {
      await _saveMeta(
        meta.copyWith(etag: checksumsResp.headers['etag'] ?? meta.etag),
      );
      return ContentPackUpdateResult(
        status: ContentPackUpdateStatus.upToDate,
        packVersion: checksums.packVersion.toString(),
      );
    }
    if (checksums.packVersion == currentActivePackVersion &&
        checksums.packVersion == bundledPackVersion &&
        meta.activeVersion == null &&
        !manualForce) {
      await _saveMeta(
        meta.copyWith(etag: checksumsResp.headers['etag'] ?? meta.etag),
      );
      return ContentPackUpdateResult(
        status: ContentPackUpdateStatus.upToDate,
        packVersion: checksums.packVersion.toString(),
      );
    }

    // File-by-file download using content-addressed blob cache (`blobs/<sha256>`).
    final Directory blobsDir = Directory(
      '$rootPath${Platform.pathSeparator}blobs',
    )..createSync(recursive: true);
    final Directory stagingTarget = _packDir(
      rootPath,
      'staged',
      checksums.packVersion.toString(),
    );
    if (stagingTarget.existsSync()) {
      stagingTarget.deleteSync(recursive: true);
    }
    stagingTarget.createSync(recursive: true);

    int downloaded = 0;
    int reused = 0;

    try {
      for (final ContentPackFileEntry entry in checksums.files.values) {
        final File blobFile = File(
          '${blobsDir.path}${Platform.pathSeparator}${entry.sha256}',
        );
        Uint8List fileBytes;
        if (blobFile.existsSync() &&
            blobFile.lengthSync() == entry.sizeBytes &&
            await _sha256HexBytes(await blobFile.readAsBytes()) ==
                entry.sha256) {
          fileBytes = await blobFile.readAsBytes();
          reused++;
        } else {
          final http.Response fileResp;
          try {
            fileResp = await _http.get(
              Uri.parse(
                '$base/api/v1/content/pack/files/${entry.relativePath}',
              ),
              headers: baseHeaders,
            );
          } catch (error) {
            throw ContentPackException(
              ContentPackErrorCode.networkError,
              '$error',
            );
          }
          if (fileResp.statusCode != 200) {
            throw ContentPackException(
              ContentPackErrorCode.networkError,
              'HTTP ${fileResp.statusCode} fetching ${entry.relativePath}',
            );
          }
          fileBytes = Uint8List.fromList(fileResp.bodyBytes);
          if (fileBytes.length != entry.sizeBytes) {
            throw ContentPackException(
              ContentPackErrorCode.fileHashMismatch,
              'Size mismatch for ${entry.relativePath}: expected ${entry.sizeBytes}, got ${fileBytes.length}.',
            );
          }
          final String actualSha = await _sha256HexBytes(fileBytes);
          if (actualSha != entry.sha256) {
            throw ContentPackException(
              ContentPackErrorCode.fileHashMismatch,
              'SHA-256 mismatch for ${entry.relativePath}.',
            );
          }
          await blobFile.writeAsBytes(fileBytes, flush: true);
          downloaded++;
        }

        final File destFile = _safeChildFile(stagingTarget, entry.relativePath);
        destFile.parent.createSync(recursive: true);
        await destFile.writeAsBytes(fileBytes, flush: true);
      }

      // Validate manifest & every referenced asset before staging/promotion.
      final SceneManifest? parsedManifest = _loadVerifiedManifestFromDir(
        stagingTarget,
      );
      if (parsedManifest == null ||
          parsedManifest.packId != checksums.packId ||
          parsedManifest.packVersion != checksums.packVersion.toString()) {
        throw const ContentPackException(
          ContentPackErrorCode.manifestInvalid,
          'Staged manifest.json failed schema or identity validation.',
        );
      }

      final String? newEtag = checksumsResp.headers['etag'] ?? meta.etag;
      final SemanticVersion nextMaxSeen = computeMinAcceptableVersion(
        bundledPackVersion: bundledPackVersion,
        localMaxSeenPackVersion: SemanticVersion.tryParse(meta.maxSeenVersion),
        serverMinPackVersion: checksums.packVersion,
      );

      if (!manualForce) {
        await _saveMeta(
          meta.copyWith(
            stagedVersion: checksums.packVersion.toString(),
            maxSeenVersion: nextMaxSeen.toString(),
            etag: newEtag,
          ),
        );
        return ContentPackUpdateResult(
          status: ContentPackUpdateStatus.stagedForNextBoot,
          packVersion: checksums.packVersion.toString(),
          downloadedFiles: downloaded,
          reusedCachedFiles: reused,
        );
      }

      // Manual force mode: promote immediately to active/ for instant hot reload.
      final String targetVerStr = checksums.packVersion.toString();
      String? nextPrevious = meta.previousVersion;
      if (meta.activeVersion != null && meta.activeVersion != targetVerStr) {
        await _moveDirReplacing(
          _packDir(rootPath, 'active', meta.activeVersion!),
          _packDir(rootPath, 'previous', meta.activeVersion!),
        );
        nextPrevious = meta.activeVersion;
      }
      final Directory activeTarget = _packDir(rootPath, 'active', targetVerStr);
      await _moveDirReplacing(stagingTarget, activeTarget);

      await _saveMeta(
        meta.copyWith(
          activeVersion: targetVerStr,
          previousVersion: nextPrevious,
          clearStagedVersion: true,
          clearBlockedVersion: true,
          maxSeenVersion: nextMaxSeen.toString(),
          etag: newEtag,
          packBootAttempts: 0,
        ),
      );

      return ContentPackUpdateResult(
        status: ContentPackUpdateStatus.activatedHotReload,
        packVersion: targetVerStr,
        downloadedFiles: downloaded,
        reusedCachedFiles: reused,
        resolvedPack: ResolvedContentPack(
          manifest: parsedManifest,
          assetRootPath: activeTarget.path,
          isFileSystem: true,
        ),
      );
    } catch (_) {
      if (stagingTarget.existsSync()) {
        try {
          stagingTarget.deleteSync(recursive: true);
        } catch (_) {}
      }
      rethrow;
    }
  }

  SceneManifest? _loadVerifiedManifestFromDir(Directory packDir) {
    if (!packDir.existsSync()) {
      return null;
    }
    final File manifestFile = _safeChildFile(packDir, 'manifest.json');
    if (!manifestFile.existsSync()) {
      return null;
    }
    try {
      final SceneManifest manifest = _manifestParser.parseJson(
        manifestFile.readAsStringSync(),
      );
      if (manifest.minAppProtocol > appProtocolVersion) {
        return null;
      }
      final SceneBackground? bg = manifest.background;
      if (bg != null) {
        if (!_assetExistsInDir(packDir, bg.dayAsset) ||
            !_assetExistsInDir(packDir, bg.nightAsset)) {
          return null;
        }
      }
      for (final SceneSlot slot in manifest.slots) {
        for (final List<SceneLayer> layers in slot.states.values) {
          for (final SceneLayer layer in layers) {
            if (!_assetExistsInDir(packDir, layer.asset)) {
              return null;
            }
          }
        }
      }
      return manifest;
    } catch (_) {
      return null;
    }
  }

  bool _assetExistsInDir(Directory packDir, String relativeAsset) {
    if (!isSafeRelativePath(relativeAsset)) {
      return false;
    }
    final File file = _safeChildFile(packDir, relativeAsset);
    return file.existsSync();
  }

  File _safeChildFile(Directory root, String relativePosixPath) {
    if (!isSafeRelativePath(relativePosixPath)) {
      throw ContentPackException(
        ContentPackErrorCode.pathTraversal,
        'Unsafe path "$relativePosixPath".',
      );
    }
    final String joined = <String>[
      root.path,
      ...relativePosixPath.split('/'),
    ].join(Platform.pathSeparator);
    return File(joined);
  }

  Directory _packDir(String rootPath, String bucket, String version) {
    return Directory(
      '$rootPath${Platform.pathSeparator}$bucket${Platform.pathSeparator}$version',
    );
  }

  Future<void> _moveDirReplacing(Directory src, Directory dst) async {
    if (!src.existsSync()) {
      return;
    }
    if (dst.existsSync()) {
      dst.deleteSync(recursive: true);
    }
    dst.parent.createSync(recursive: true);
    try {
      src.renameSync(dst.path);
    } catch (_) {
      await _copyDirRecursive(src, dst);
      src.deleteSync(recursive: true);
    }
  }

  Future<void> _copyDirRecursive(Directory src, Directory dst) async {
    dst.createSync(recursive: true);
    for (final FileSystemEntity entity in src.listSync(recursive: false)) {
      final String name = entity.uri.pathSegments
          .where((String s) => s.isNotEmpty)
          .last;
      final String targetPath = '${dst.path}${Platform.pathSeparator}$name';
      if (entity is File) {
        await entity.copy(targetPath);
      } else if (entity is Directory) {
        await _copyDirRecursive(entity, Directory(targetPath));
      }
    }
  }

  Future<String?> _getStorageRootPath() async {
    if (_resolveStorageRootDir == null) {
      return null;
    }
    final String? path = await _resolveStorageRootDir();
    if (path == null || path.trim().isEmpty) {
      return null;
    }
    final Directory dir = Directory(path.trim());
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }
    return dir.path;
  }

  Future<_PackMeta> _loadMeta() async {
    try {
      final String? raw = await _keyStore.read(_metaStorageKey);
      if (raw == null || raw.isEmpty) {
        return const _PackMeta();
      }
      final Object? decoded = jsonDecode(raw);
      if (decoded is Map<String, Object?>) {
        return _PackMeta.fromJson(decoded);
      }
    } catch (_) {}
    return const _PackMeta();
  }

  Future<void> _saveMeta(_PackMeta meta) {
    return _keyStore.write(_metaStorageKey, jsonEncode(meta.toJson()));
  }

  static ({String keyId, Uint8List sigBytes}) _parseSigEnvelope(
    Uint8List rawSigBytes,
  ) {
    if (rawSigBytes.length == 64) {
      return (keyId: 'v1', sigBytes: rawSigBytes);
    }
    final String text = utf8.decode(rawSigBytes, allowMalformed: true).trim();
    final int colon = text.indexOf(':');
    final String keyId;
    final String sigB64;
    if (colon > 0) {
      keyId = text.substring(0, colon).trim();
      sigB64 = text.substring(colon + 1).trim();
    } else {
      keyId = 'v1';
      sigB64 = text;
    }
    if (!_keyIdPattern.hasMatch(keyId)) {
      throw const ContentPackException(
        ContentPackErrorCode.unknownKeyId,
        'Invalid keyId syntax in signature envelope.',
      );
    }
    final Uint8List decoded;
    try {
      decoded = base64Decode(sigB64);
    } catch (_) {
      throw const ContentPackException(
        ContentPackErrorCode.signatureInvalid,
        'Signature envelope is not valid base64.',
      );
    }
    if (decoded.length != 64) {
      throw const ContentPackException(
        ContentPackErrorCode.signatureInvalid,
        'Ed25519 signature must be exactly 64 bytes.',
      );
    }
    return (keyId: keyId, sigBytes: decoded);
  }

  static Future<String> _sha256HexBytes(List<int> bytes) async {
    final Hash digest = await Sha256().hash(bytes);
    return digest.bytes
        .map((int b) => b.toRadixString(16).padLeft(2, '0'))
        .join();
  }
}

class _PackMeta {
  const _PackMeta({
    this.activeVersion,
    this.previousVersion,
    this.stagedVersion,
    this.blockedVersion,
    this.maxSeenVersion,
    this.etag,
    this.packBootAttempts = 0,
  });

  final String? activeVersion;
  final String? previousVersion;
  final String? stagedVersion;
  final String? blockedVersion;
  final String? maxSeenVersion;
  final String? etag;
  final int packBootAttempts;

  _PackMeta copyWith({
    String? activeVersion,
    bool clearActiveVersion = false,
    String? previousVersion,
    bool clearPreviousVersion = false,
    String? stagedVersion,
    bool clearStagedVersion = false,
    String? blockedVersion,
    bool clearBlockedVersion = false,
    String? maxSeenVersion,
    String? etag,
    int? packBootAttempts,
  }) {
    return _PackMeta(
      activeVersion: clearActiveVersion
          ? null
          : (activeVersion ?? this.activeVersion),
      previousVersion: clearPreviousVersion
          ? null
          : (previousVersion ?? this.previousVersion),
      stagedVersion: clearStagedVersion
          ? null
          : (stagedVersion ?? this.stagedVersion),
      blockedVersion: clearBlockedVersion
          ? null
          : (blockedVersion ?? this.blockedVersion),
      maxSeenVersion: maxSeenVersion ?? this.maxSeenVersion,
      etag: etag ?? this.etag,
      packBootAttempts: packBootAttempts ?? this.packBootAttempts,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'activeVersion': activeVersion,
    'previousVersion': previousVersion,
    'stagedVersion': stagedVersion,
    'blockedVersion': blockedVersion,
    'maxSeenVersion': maxSeenVersion,
    'etag': etag,
    'packBootAttempts': packBootAttempts,
  };

  factory _PackMeta.fromJson(Map<String, Object?> json) {
    return _PackMeta(
      activeVersion: json['activeVersion'] as String?,
      previousVersion: json['previousVersion'] as String?,
      stagedVersion: json['stagedVersion'] as String?,
      blockedVersion: json['blockedVersion'] as String?,
      maxSeenVersion: json['maxSeenVersion'] as String?,
      etag: json['etag'] as String?,
      packBootAttempts: json['packBootAttempts'] as int? ?? 0,
    );
  }
}
