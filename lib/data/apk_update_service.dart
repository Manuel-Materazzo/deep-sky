import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cryptography/cryptography.dart';
import 'package:deep_sky/domain/pairing/invite_link_codec.dart';
import 'package:deep_sky/domain/platform_capabilities.dart';
import 'package:deep_sky/domain/update/apk_update_models.dart';
import 'package:deep_sky/platform/native_bridge.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

/// Handles manifest signature verification, version checks, resumable APK download,
/// streaming SHA-256 verification, and native PackageInstaller delegation (SP-03, TC-10, SEC-04, CA-11).
class ApkUpdateService {
  ApkUpdateService({
    http.Client? httpClient,
    this.nativeBridge = const NativeBridge(),
    Duration Function(int attempt)? retryDelay,
    this.requestTimeout = defaultRequestTimeout,
    this.chunkIdleTimeout = defaultChunkIdleTimeout,
  }) : _http = httpClient ?? http.Client(),
       _retryDelay = retryDelay ?? _defaultRetryDelay;

  static const int storageSafetyMarginBytes = 20 * 1024 * 1024;
  static const Duration defaultReleaseCheckCooldown = Duration(hours: 6);
  static const Duration defaultRequestTimeout = Duration(seconds: 15);
  static const Duration defaultChunkIdleTimeout = Duration(seconds: 30);
  static final Ed25519 _ed25519 = Ed25519();

  final http.Client _http;
  final NativeBridge nativeBridge;
  final Duration Function(int attempt) _retryDelay;
  final Duration requestTimeout;
  final Duration chunkIdleTimeout;

  static Duration _defaultRetryDelay(int attempt) =>
      Duration(milliseconds: 250 * (1 << (attempt - 1).clamp(0, 4)));
  final Map<String, ReleaseCheckCacheEntry> _releaseCheckCache =
      <String, ReleaseCheckCacheEntry>{};

  /// Checks for a signed release using a cooldown window and `If-None-Match` (`ETag`)
  /// conditional GET so periodic checks avoid GitHub API rate limits (PR-M2-05, §8.2).
  Future<ApkUpdateCheckResult> checkForUpdate({
    required Uri sourceBaseUri,
    required SimplePublicKey trustedPublicKey,
    required PlatformCapabilities currentApp,
    Duration cooldown = defaultReleaseCheckCooldown,
    bool force = false,
    DateTime Function()? nowUtc,
  }) async {
    final DateTime now = (nowUtc ?? () => DateTime.now().toUtc())();
    final String cacheKey = '$sourceBaseUri|${currentApp.packageName}';
    final ReleaseCheckCacheEntry? cached = _releaseCheckCache[cacheKey];

    if (!force &&
        cached != null &&
        now.difference(cached.checkedAtUtc) < cooldown) {
      final ApkReleaseManifest? cachedManifest = cached.lastManifest;
      final bool hasNewerCached =
          cachedManifest != null &&
          cachedManifest.versionCode > currentApp.versionCode;
      return ApkUpdateCheckResult(
        status: ApkUpdateCheckStatus.throttledByCooldown,
        cacheEntry: cached,
        manifest: hasNewerCached ? cachedManifest : null,
      );
    }

    final Map<String, String> headers = <String, String>{};
    if (cached?.etag != null && cached!.etag!.isNotEmpty) {
      headers['If-None-Match'] = cached.etag!;
    }

    final http.Response manifestResp;
    try {
      manifestResp = await _http
          .get(Uri.parse('$sourceBaseUri/manifest.json'), headers: headers)
          .timeout(requestTimeout);
    } catch (error) {
      throw ApkUpdateException(ApkUpdateErrorCode.networkError, '$error');
    }

    if (manifestResp.statusCode == 304 && cached != null) {
      final ReleaseCheckCacheEntry refreshed = ReleaseCheckCacheEntry(
        checkedAtUtc: now,
        etag: cached.etag,
        lastManifest: cached.lastManifest,
      );
      _releaseCheckCache[cacheKey] = refreshed;
      final ApkReleaseManifest? cachedManifest = refreshed.lastManifest;
      final bool hasNewerCached =
          cachedManifest != null &&
          cachedManifest.versionCode > currentApp.versionCode;
      return ApkUpdateCheckResult(
        status: ApkUpdateCheckStatus.notModified304,
        cacheEntry: refreshed,
        manifest: hasNewerCached ? cachedManifest : null,
      );
    }

    final http.Response sigResp;
    try {
      sigResp = await _http
          .get(Uri.parse('$sourceBaseUri/manifest.json.sig'))
          .timeout(requestTimeout);
    } catch (error) {
      throw ApkUpdateException(ApkUpdateErrorCode.networkError, '$error');
    }

    final ApkReleaseManifest manifest;
    try {
      manifest = await _verifyManifestResponses(
        manifestResp: manifestResp,
        sigResp: sigResp,
        trustedPublicKey: trustedPublicKey,
        currentApp: currentApp,
      );
    } on ApkUpdateException catch (ex) {
      if (ex.code == ApkUpdateErrorCode.versionNotHigher) {
        final ReleaseCheckCacheEntry upToDateEntry = ReleaseCheckCacheEntry(
          checkedAtUtc: now,
          etag: manifestResp.headers['etag'] ?? cached?.etag,
        );
        _releaseCheckCache[cacheKey] = upToDateEntry;
        return ApkUpdateCheckResult(
          status: ApkUpdateCheckStatus.upToDate,
          cacheEntry: upToDateEntry,
        );
      }
      rethrow;
    }

    final ReleaseCheckCacheEntry nextEntry = ReleaseCheckCacheEntry(
      checkedAtUtc: now,
      etag: manifestResp.headers['etag'],
      lastManifest: manifest,
    );
    _releaseCheckCache[cacheKey] = nextEntry;
    return ApkUpdateCheckResult(
      status: ApkUpdateCheckStatus.updateAvailable,
      cacheEntry: nextEntry,
      manifest: manifest,
    );
  }

  /// Builds the base URL for release artifacts from either a `owner/repo` GitHub slug
  /// (default source) or a custom HTTPS URL (or local/private HTTP test mirror).
  static Uri resolveSourceBaseUri(String sourceInput, {String tag = 'latest'}) {
    final String trimmed = sourceInput.trim().replaceAll(RegExp(r'/+$'), '');
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return Uri.parse(InviteLinkCodec.normalizeServerUrl(trimmed));
    }
    if (tag == 'latest') {
      return Uri.parse('https://github.com/$trimmed/releases/latest/download');
    }
    return Uri.parse('https://github.com/$trimmed/releases/download/$tag');
  }

  /// Resolves the release artifact base URI honoring the selected [UpdateChannel] (`S1-UPD-01`).
  ///
  /// - Custom HTTPS mirrors (or local/private HTTP test mirrors) are returned normalized.
  /// - [UpdateChannel.stable] uses `/releases/latest/download` (GitHub ignores pre-releases).
  /// - [UpdateChannel.preview] queries the GitHub Releases API and picks the newest
  ///   non-draft release (including pre-releases), falling back to `latest` if none match.
  Future<Uri> resolveChannelBaseUri({
    required String sourceInput,
    required UpdateChannel channel,
  }) async {
    final String trimmed = sourceInput.trim().replaceAll(RegExp(r'/+$'), '');
    if (trimmed.isEmpty) {
      throw const FormatException('Empty update source.');
    }
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return Uri.parse(InviteLinkCodec.normalizeServerUrl(trimmed));
    }
    if (channel == UpdateChannel.stable) {
      return resolveSourceBaseUri(trimmed, tag: 'latest');
    }

    final Uri apiUri = Uri.parse(
      'https://api.github.com/repos/$trimmed/releases?per_page=10',
    );
    final http.Response resp;
    try {
      resp = await _http
          .get(
            apiUri,
            headers: const <String, String>{
              'Accept': 'application/vnd.github+json',
            },
          )
          .timeout(requestTimeout);
    } catch (error) {
      throw ApkUpdateException(ApkUpdateErrorCode.networkError, '$error');
    }
    if (resp.statusCode != 200) {
      throw ApkUpdateException(
        ApkUpdateErrorCode.networkError,
        'GitHub releases API HTTP ${resp.statusCode}',
      );
    }
    final Object? decoded;
    try {
      decoded = jsonDecode(resp.body);
    } catch (error) {
      throw ApkUpdateException(ApkUpdateErrorCode.manifestInvalid, '$error');
    }
    if (decoded is List) {
      for (final Object? item in decoded) {
        if (item is Map<String, dynamic>) {
          final bool isDraft = item['draft'] == true;
          final String tag = (item['tag_name'] as String? ?? '').trim();
          if (!isDraft && tag.isNotEmpty) {
            return resolveSourceBaseUri(trimmed, tag: tag);
          }
        }
      }
    }
    return resolveSourceBaseUri(trimmed, tag: 'latest');
  }

  /// Parses either a raw 32-byte base64 Ed25519 public key or an X.509 SPKI DER base64 key.
  static SimplePublicKey parseEd25519PublicKey(String encodedBase64) {
    final String cleaned = encodedBase64.replaceAll(RegExp(r'\s+'), '');
    final Uint8List decoded = base64Decode(cleaned);
    if (decoded.length == 32) {
      return SimplePublicKey(decoded, type: KeyPairType.ed25519);
    }
    // Standard RFC 8410 X.509 SPKI envelope for Ed25519 is 12-byte header + 32-byte key.
    if (decoded.length == 44) {
      return SimplePublicKey(decoded.sublist(12), type: KeyPairType.ed25519);
    }
    throw const FormatException(
      'Ed25519 public key must be 32 raw bytes or 44-byte X.509 SPKI.',
    );
  }

  Future<ApkReleaseManifest> fetchAndVerifyManifest({
    required Uri sourceBaseUri,
    required SimplePublicKey trustedPublicKey,
    required PlatformCapabilities currentApp,
  }) async {
    final http.Response manifestResp;
    final http.Response sigResp;
    try {
      manifestResp = await _http
          .get(Uri.parse('$sourceBaseUri/manifest.json'))
          .timeout(requestTimeout);
      sigResp = await _http
          .get(Uri.parse('$sourceBaseUri/manifest.json.sig'))
          .timeout(requestTimeout);
    } catch (error) {
      throw ApkUpdateException(ApkUpdateErrorCode.networkError, '$error');
    }

    return _verifyManifestResponses(
      manifestResp: manifestResp,
      sigResp: sigResp,
      trustedPublicKey: trustedPublicKey,
      currentApp: currentApp,
    );
  }

  Future<ApkReleaseManifest> _verifyManifestResponses({
    required http.Response manifestResp,
    required http.Response sigResp,
    required SimplePublicKey trustedPublicKey,
    required PlatformCapabilities currentApp,
  }) async {
    if (manifestResp.statusCode != 200 || sigResp.statusCode != 200) {
      throw ApkUpdateException(
        ApkUpdateErrorCode.networkError,
        'HTTP manifest=${manifestResp.statusCode}, sig=${sigResp.statusCode}',
      );
    }

    final Uint8List manifestBytes = Uint8List.fromList(manifestResp.bodyBytes);
    final Uint8List sigBytes = _decodeSignatureBytes(sigResp.bodyBytes);
    if (sigBytes.length != 64) {
      throw const ApkUpdateException(
        ApkUpdateErrorCode.signatureInvalid,
        'Signature must be 64 bytes.',
      );
    }

    final bool validSig = await _ed25519.verify(
      manifestBytes,
      signature: Signature(sigBytes, publicKey: trustedPublicKey),
    );
    if (!validSig) {
      throw const ApkUpdateException(
        ApkUpdateErrorCode.signatureInvalid,
        'Ed25519 signature mismatch over manifest.json.',
      );
    }

    final ApkReleaseManifest manifest;
    try {
      final Object? parsed = jsonDecode(utf8.decode(manifestBytes));
      if (parsed is! Map<String, dynamic>) {
        throw const FormatException('Manifest JSON root is not an object.');
      }
      manifest = ApkReleaseManifest.fromJson(parsed);
    } catch (error) {
      throw ApkUpdateException(ApkUpdateErrorCode.manifestInvalid, '$error');
    }

    if (manifest.packageId != currentApp.packageName) {
      throw ApkUpdateException(
        ApkUpdateErrorCode.packageMismatch,
        'Expected ${currentApp.packageName}, got ${manifest.packageId}',
      );
    }
    if (manifest.versionCode <= currentApp.versionCode) {
      throw ApkUpdateException(
        ApkUpdateErrorCode.versionNotHigher,
        'Remote ${manifest.versionCode} <= installed ${currentApp.versionCode}',
      );
    }
    return manifest;
  }

  /// Downloads [manifest.apkFile] into [stagingDir] resuming from any `.part` file,
  /// verifies exact size and SHA-256, and delegates installation to Android `PackageInstaller`.
  Future<File> downloadAndVerifyApk({
    required Uri sourceBaseUri,
    required ApkReleaseManifest manifest,
    required String stagingDir,
    required int availableBytes,
    int maxResumeAttempts = 3,
    void Function(int receivedBytes, int totalBytes)? onProgress,
  }) async {
    if (availableBytes < manifest.apkSizeBytes + storageSafetyMarginBytes) {
      throw ApkUpdateException(
        ApkUpdateErrorCode.insufficientStorage,
        'Available $availableBytes < required ${manifest.apkSizeBytes + storageSafetyMarginBytes}',
      );
    }

    final Directory dir = Directory(stagingDir);
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }

    final File partFile = File(
      '${dir.path}${Platform.pathSeparator}${manifest.apkFile}.part',
    );
    final File finalFile = File(
      '${dir.path}${Platform.pathSeparator}${manifest.apkFile}',
    );
    final Uri apkUri = Uri.parse('$sourceBaseUri/${manifest.apkFile}');

    int attempts = 0;
    while (true) {
      if (partFile.existsSync() &&
          partFile.lengthSync() > manifest.apkSizeBytes) {
        await partFile.delete();
      }
      final int existingLen = partFile.existsSync() ? partFile.lengthSync() : 0;
      if (existingLen == manifest.apkSizeBytes) {
        onProgress?.call(manifest.apkSizeBytes, manifest.apkSizeBytes);
        break;
      }
      attempts++;
      try {
        final http.Request req = http.Request('GET', apkUri);
        if (existingLen > 0) {
          req.headers['Range'] = 'bytes=$existingLen-';
        }
        final http.StreamedResponse streamed = await _http
            .send(req)
            .timeout(requestTimeout);
        if (streamed.statusCode != 200 && streamed.statusCode != 206) {
          throw ApkUpdateException(
            ApkUpdateErrorCode.downloadInterrupted,
            'HTTP ${streamed.statusCode} downloading APK',
          );
        }

        // If server ignored Range and returned 200 full body, truncate partFile first.
        final FileMode mode = streamed.statusCode == 206
            ? FileMode.append
            : FileMode.write;
        int received = streamed.statusCode == 206 ? existingLen : 0;
        onProgress?.call(received, manifest.apkSizeBytes);
        final IOSink sink = partFile.openWrite(mode: mode);
        try {
          await for (final List<int> chunk in streamed.stream.timeout(
            chunkIdleTimeout,
          )) {
            sink.add(chunk);
            received += chunk.length;
            onProgress?.call(
              received.clamp(0, manifest.apkSizeBytes),
              manifest.apkSizeBytes,
            );
          }
          await sink.flush();
        } finally {
          await sink.close();
        }
      } catch (error) {
        if (attempts >= maxResumeAttempts) {
          if (error is ApkUpdateException) {
            rethrow;
          }
          throw ApkUpdateException(
            ApkUpdateErrorCode.downloadInterrupted,
            '$error',
          );
        }
        final Duration delay = _retryDelay(attempts);
        if (delay > Duration.zero) {
          await Future<void>.delayed(delay);
        }
      }
    }

    if (!partFile.existsSync() ||
        partFile.lengthSync() != manifest.apkSizeBytes) {
      final int actualLen = partFile.existsSync() ? partFile.lengthSync() : 0;
      if (partFile.existsSync()) {
        await partFile.delete();
      }
      throw ApkUpdateException(
        ApkUpdateErrorCode.apkHashMismatch,
        'Downloaded length $actualLen != ${manifest.apkSizeBytes}',
      );
    }

    final String actualHex = await computeFileSha256Hex(partFile);
    if (actualHex != manifest.apkSha256) {
      await partFile.delete();
      throw ApkUpdateException(
        ApkUpdateErrorCode.apkHashMismatch,
        'SHA-256 mismatch: expected ${manifest.apkSha256}, actual $actualHex',
      );
    }

    if (finalFile.existsSync()) {
      await finalFile.delete();
    }
    return partFile.rename(finalFile.path);
  }

  /// Computes the lowercase hex SHA-256 digest of [file] by streaming chunks (`CA-11`).
  static Future<String> computeFileSha256Hex(File file) async {
    final HashSink sink = Sha256().newHashSink();
    await for (final List<int> chunk in file.openRead()) {
      sink.add(chunk);
    }
    sink.close();
    final Hash digest = await sink.hash();
    return digest.bytes
        .map((int b) => b.toRadixString(16).padLeft(2, '0'))
        .join();
  }

  Future<String> installApkFile(File verifiedApk) async {
    final bool canInstall = await nativeBridge.canRequestPackageInstalls();
    if (!canInstall) {
      throw const ApkUpdateException(
        ApkUpdateErrorCode.permissionDenied,
        'canRequestPackageInstalls() is false.',
      );
    }
    try {
      return await nativeBridge.installVerifiedApk(verifiedApk.path);
    } on PlatformException catch (ex) {
      switch (ex.code) {
        case 'permission_denied':
          throw ApkUpdateException(
            ApkUpdateErrorCode.permissionDenied,
            ex.message ?? '',
          );
        case 'apk_certificate_mismatch':
          throw ApkUpdateException(
            ApkUpdateErrorCode.apkCertificateMismatch,
            ex.message ?? '',
          );
        case 'version_not_higher':
          throw ApkUpdateException(
            ApkUpdateErrorCode.versionNotHigher,
            ex.message ?? '',
          );
        case 'package_mismatch':
          throw ApkUpdateException(
            ApkUpdateErrorCode.packageMismatch,
            ex.message ?? '',
          );
        default:
          throw ApkUpdateException(
            ApkUpdateErrorCode.manifestInvalid,
            '${ex.code}: ${ex.message}',
          );
      }
    }
  }

  static Uint8List _decodeSignatureBytes(List<int> raw) {
    if (raw.length == 64) {
      return Uint8List.fromList(raw);
    }
    final String text = utf8.decode(raw, allowMalformed: true).trim();
    try {
      return base64Decode(text);
    } catch (_) {
      return Uint8List(0);
    }
  }
}
