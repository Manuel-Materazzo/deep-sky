import 'dart:convert';
import 'dart:io';

import 'package:cryptography/cryptography.dart';
import 'package:deep_sky/domain/platform_capabilities.dart';
import 'package:deep_sky/domain/update/apk_update_models.dart';
import 'package:deep_sky/platform/native_bridge.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

/// Handles manifest signature verification, version checks, resumable APK download,
/// SHA-256 verification, and native PackageInstaller delegation (SP-03, TC-10, SEC-04).
class ApkUpdateService {
  ApkUpdateService({
    http.Client? httpClient,
    this.nativeBridge = const NativeBridge(),
  }) : _http = httpClient ?? http.Client();

  static const int storageSafetyMarginBytes = 20 * 1024 * 1024;
  static const Duration defaultReleaseCheckCooldown = Duration(hours: 6);
  static final Ed25519 _ed25519 = Ed25519();

  final http.Client _http;
  final NativeBridge nativeBridge;
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
      manifestResp = await _http.get(
        Uri.parse('$sourceBaseUri/manifest.json'),
        headers: headers,
      );
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
      sigResp = await _http.get(Uri.parse('$sourceBaseUri/manifest.json.sig'));
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
  /// (default source) or a custom HTTPS URL (alternate mirror / fork test).
  static Uri resolveSourceBaseUri(String sourceInput, {String tag = 'latest'}) {
    final String trimmed = sourceInput.trim().replaceAll(RegExp(r'/+$'), '');
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return Uri.parse(trimmed);
    }
    if (tag == 'latest') {
      return Uri.parse('https://github.com/$trimmed/releases/latest/download');
    }
    return Uri.parse('https://github.com/$trimmed/releases/download/$tag');
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
      manifestResp = await _http.get(Uri.parse('$sourceBaseUri/manifest.json'));
      sigResp = await _http.get(Uri.parse('$sourceBaseUri/manifest.json.sig'));
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
      final int existingLen = partFile.existsSync() ? partFile.lengthSync() : 0;
      if (existingLen >= manifest.apkSizeBytes) {
        break;
      }
      attempts++;
      try {
        final http.Request req = http.Request('GET', apkUri);
        if (existingLen > 0) {
          req.headers['Range'] = 'bytes=$existingLen-';
        }
        final http.StreamedResponse streamed = await _http.send(req);
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
        final IOSink sink = partFile.openWrite(mode: mode);
        try {
          await for (final List<int> chunk in streamed.stream) {
            sink.add(chunk);
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
      }
    }

    if (!partFile.existsSync() ||
        partFile.lengthSync() != manifest.apkSizeBytes) {
      throw ApkUpdateException(
        ApkUpdateErrorCode.apkHashMismatch,
        'Downloaded length ${partFile.existsSync() ? partFile.lengthSync() : 0} != ${manifest.apkSizeBytes}',
      );
    }

    final Uint8List apkBytes = await partFile.readAsBytes();
    final Hash digest = await Sha256().hash(apkBytes);
    final String actualHex = digest.bytes
        .map((int b) => b.toRadixString(16).padLeft(2, '0'))
        .join();
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
