import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:deep_sky/domain/crypto/deep_sky_crypto.dart';
import 'package:deep_sky/domain/crypto/e2ee_models.dart';
import 'package:http/http.dart' as http;

class ApiRequestException implements Exception {
  const ApiRequestException(this.statusCode, this.message, {this.errorCode});

  final int statusCode;
  final String message;
  final String? errorCode;

  bool get isClockSkew {
    if (statusCode != 401) {
      return false;
    }
    if (errorCode == 'CLOCK_SKEW') {
      return true;
    }
    return message.toLowerCase().contains('timestamp');
  }

  bool get isDeviceUnknownOrRevoked {
    if (statusCode != 401 || isClockSkew) {
      return false;
    }
    if (errorCode == 'DEVICE_AUTH_FAILED') {
      return true;
    }
    if (errorCode == 'AUTH_HEADERS_INVALID' || errorCode == 'NONCE_REPLAYED') {
      return false;
    }
    final String lower = message.toLowerCase();
    return lower.contains('revoked') || lower.contains('unknown');
  }

  bool get isStaleKeyEpoch =>
      statusCode == 409 &&
      (errorCode == 'STALE_KEY_EPOCH' ||
          message.toLowerCase().contains('keyepoch'));

  @override
  String toString() => 'ApiRequestException($statusCode): $message';
}

class ClientUpgradeRequiredException extends ApiRequestException {
  const ClientUpgradeRequiredException({
    required String message,
    required this.minClientVersionCode,
    required this.minProtocolVersion,
  }) : super(426, message);

  final int minClientVersionCode;
  final int minProtocolVersion;
}

class CompatibilityPolicy {
  const CompatibilityPolicy({
    required this.minClientVersionCode,
    required this.minProtocolVersion,
    this.minPackVersion = '1.0.0',
  });

  final int minClientVersionCode;
  final int minProtocolVersion;
  final String minPackVersion;

  factory CompatibilityPolicy.fromJson(Map<String, Object?> json) {
    final String? rawPackVer = json['minPackVersion'] as String?;
    return CompatibilityPolicy(
      minClientVersionCode: json['minClientVersionCode'] as int? ?? 1,
      minProtocolVersion: json['minProtocolVersion'] as int? ?? 1,
      minPackVersion: (rawPackVer != null && rawPackVer.trim().isNotEmpty)
          ? rawPackVer.trim()
          : '1.0.0',
    );
  }
}

class CreateInviteResponse {
  const CreateInviteResponse({
    required this.coupleId,
    required this.deviceId,
    required this.inviteToken,
    required this.expiresAt,
    this.sasSecret,
  });

  final String coupleId;
  final String deviceId;
  final String inviteToken;
  final DateTime expiresAt;

  /// Client-generated out-of-band SAS secret carried only in the pairing link/QR (`CA-01`).
  /// Never sent to or received from the coordination server.
  final String? sasSecret;

  CreateInviteResponse copyWith({String? sasSecret}) {
    return CreateInviteResponse(
      coupleId: coupleId,
      deviceId: deviceId,
      inviteToken: inviteToken,
      expiresAt: expiresAt,
      sasSecret: sasSecret ?? this.sasSecret,
    );
  }
}

class AcceptInviteResponse {
  const AcceptInviteResponse({
    required this.coupleId,
    required this.deviceId,
    required this.peerDeviceId,
    required this.peerLabel,
    required this.peerAuthPublicKey,
    required this.peerKemPublicKey,
  });

  final String coupleId;
  final String deviceId;
  final String peerDeviceId;
  final String peerLabel;
  final Uint8List peerAuthPublicKey;
  final Uint8List peerKemPublicKey;
}

class InviteStatusResponse {
  const InviteStatusResponse({
    required this.accepted,
    this.acceptedDeviceId,
    this.acceptedLabel,
    this.acceptedAuthPublicKey,
    this.acceptedKemPublicKey,
  });

  final bool accepted;
  final String? acceptedDeviceId;
  final String? acceptedLabel;
  final Uint8List? acceptedAuthPublicKey;
  final Uint8List? acceptedKemPublicKey;
}

class DeviceSummary {
  const DeviceSummary({
    required this.deviceId,
    required this.label,
    required this.enrolledVia,
    required this.createdAt,
    this.revokedAt,
    this.kemPublicKey,
    this.approved = true,
  });

  final String deviceId;
  final String label;
  final String enrolledVia;
  final DateTime createdAt;
  final DateTime? revokedAt;
  final Uint8List? kemPublicKey;
  final bool approved;
}

class EnvelopePage {
  const EnvelopePage({
    required this.items,
    required this.nextAfterSeq,
    required this.hasMore,
    this.coupleKeyEpoch = 1,
  });

  final List<EncryptedEnvelope> items;
  final int nextAfterSeq;
  final bool hasMore;
  final int coupleKeyEpoch;
}

class RecoveryCompleteResponse {
  const RecoveryCompleteResponse({
    required this.deviceId,
    this.currentKeyEpoch = 1,
    this.recoveryKeyringNonce,
    this.recoveryKeyringCiphertextWithTag,
  });

  final String deviceId;
  final int currentKeyEpoch;
  final Uint8List? recoveryKeyringNonce;
  final Uint8List? recoveryKeyringCiphertextWithTag;
}

class EpochRotationStateResponse {
  const EpochRotationStateResponse({
    required this.currentKeyEpoch,
    this.pendingDelivery,
  });

  final int currentKeyEpoch;
  final WrappedKeyPackage? pendingDelivery;
}

class RecoveryChallengeResponse {
  const RecoveryChallengeResponse({
    required this.challengeId,
    required this.coupleId,
    required this.nonceB64,
    required this.expiresAt,
  });

  final String challengeId;
  final String coupleId;
  final String nonceB64;
  final DateTime expiresAt;
}

/// HTTP client for Deep Sky SP-02 pairing, recovery, sync, and visibility audit endpoints.
class CoupleApiClient {
  CoupleApiClient({
    required String baseUrl,
    http.Client? httpClient,
    DeepSkyCrypto? crypto,
    this._clientVersionCode = 1,
    this._protocolVersion = 1,
    this.requestTimeout = defaultRequestTimeout,
    this.uploadTimeout = defaultUploadTimeout,
  }) : _baseUrl = baseUrl.endsWith('/')
           ? baseUrl.substring(0, baseUrl.length - 1)
           : baseUrl,
       _http = httpClient ?? http.Client(),
       _crypto = crypto ?? DeepSkyCrypto();

  static const Duration defaultRequestTimeout = Duration(seconds: 15);
  static const Duration defaultUploadTimeout = Duration(seconds: 45);

  final String _baseUrl;
  final http.Client _http;
  final DeepSkyCrypto _crypto;
  final int _clientVersionCode;
  final int _protocolVersion;
  final Duration requestTimeout;
  final Duration uploadTimeout;

  /// Performs an unauthenticated GET request carrying client version headers.
  Future<Object?> unsignedGetJson(String pathWithQuery) async {
    final Uri uri = Uri.parse('$_baseUrl$pathWithQuery');
    final http.Response res = await _http
        .get(uri, headers: _versionHeaders())
        .timeout(requestTimeout);
    return _decodeResponse(res);
  }

  Future<CompatibilityPolicy> fetchCompatibilityPolicy() async {
    final Map<String, Object?> json =
        (await unsignedGetJson('/api/v1/system/compatibility'))!
            as Map<String, Object?>;
    return CompatibilityPolicy.fromJson(json);
  }

  Future<CreateInviteResponse> createInitialInvite({
    required String deviceLabel,
    required Uint8List deviceAuthPublicKey,
    required Uint8List deviceKemPublicKey,
    required Uint8List recoveryAuthPublicKey,
  }) async {
    final Map<String, Object?> json = await _postJson(
      '/api/v1/pairing/invites',
      <String, Object?>{
        'deviceLabel': deviceLabel,
        'deviceAuthPublicKeyB64': base64UrlEncode(deviceAuthPublicKey),
        'deviceKemPublicKeyB64': base64UrlEncode(deviceKemPublicKey),
        'recoveryAuthPublicKeyB64': base64UrlEncode(recoveryAuthPublicKey),
      },
    );
    return CreateInviteResponse(
      coupleId: json['coupleId'] as String,
      deviceId: json['deviceId'] as String,
      inviteToken: json['inviteToken'] as String,
      expiresAt: DateTime.parse(json['expiresAt'] as String).toUtc(),
    );
  }

  Future<AcceptInviteResponse> acceptInvite({
    required String inviteToken,
    required String deviceLabel,
    required Uint8List deviceAuthPublicKey,
    required Uint8List deviceKemPublicKey,
  }) async {
    final Map<String, Object?> json = await _postJson(
      '/api/v1/pairing/invites/accept',
      <String, Object?>{
        'inviteToken': inviteToken,
        'deviceLabel': deviceLabel,
        'deviceAuthPublicKeyB64': base64UrlEncode(deviceAuthPublicKey),
        'deviceKemPublicKeyB64': base64UrlEncode(deviceKemPublicKey),
      },
    );
    return AcceptInviteResponse(
      coupleId: json['coupleId'] as String,
      deviceId: json['deviceId'] as String,
      peerDeviceId: json['peerDeviceId'] as String,
      peerLabel: json['peerLabel'] as String,
      peerAuthPublicKey: _decodeB64(json['peerAuthPublicKeyB64'] as String),
      peerKemPublicKey: _decodeB64(json['peerKemPublicKeyB64'] as String),
    );
  }

  Future<InviteStatusResponse> getInviteStatus({
    required LocalDeviceIdentity identity,
    required String inviteToken,
  }) async {
    final Object? raw = await _signedRequest(
      method: 'POST',
      pathWithQuery: '/api/v1/pairing/invites/status',
      identity: identity,
      body: <String, Object?>{'inviteToken': inviteToken},
    );
    final Map<String, Object?> json = raw! as Map<String, Object?>;
    final bool accepted = json['accepted'] as bool;
    return InviteStatusResponse(
      accepted: accepted,
      acceptedDeviceId: json['acceptedDeviceId'] as String?,
      acceptedLabel: json['acceptedLabel'] as String?,
      acceptedAuthPublicKey: json['acceptedAuthPublicKeyB64'] == null
          ? null
          : _decodeB64(json['acceptedAuthPublicKeyB64'] as String),
      acceptedKemPublicKey: json['acceptedKemPublicKeyB64'] == null
          ? null
          : _decodeB64(json['acceptedKemPublicKeyB64'] as String),
    );
  }

  Future<CreateInviteResponse> createEnrollmentInvite({
    required LocalDeviceIdentity identity,
  }) async {
    final Object? raw = await _signedRequest(
      method: 'POST',
      pathWithQuery: '/api/v1/pairing/enrollment-invites',
      identity: identity,
    );
    final Map<String, Object?> json = raw! as Map<String, Object?>;
    return CreateInviteResponse(
      coupleId: json['coupleId'] as String,
      deviceId: json['deviceId'] as String,
      inviteToken: json['inviteToken'] as String,
      expiresAt: DateTime.parse(json['expiresAt'] as String).toUtc(),
    );
  }

  Future<void> uploadKeyDelivery({
    required LocalDeviceIdentity identity,
    required WrappedKeyPackage package,
  }) async {
    await _signedRequest(
      method: 'POST',
      pathWithQuery: '/api/v1/pairing/key-deliveries',
      identity: identity,
      body: package.toJson(),
    );
  }

  Future<WrappedKeyPackage> fetchMyKeyDelivery({
    required LocalDeviceIdentity identity,
  }) async {
    final Object? raw = await _signedRequest(
      method: 'GET',
      pathWithQuery: '/api/v1/pairing/key-deliveries/me',
      identity: identity,
    );
    return WrappedKeyPackage.fromJson(raw! as Map<String, Object?>);
  }

  Future<List<DeviceSummary>> listDevices({
    required LocalDeviceIdentity identity,
  }) async {
    final Object? raw = await _signedRequest(
      method: 'GET',
      pathWithQuery: '/api/v1/pairing/devices',
      identity: identity,
    );
    final List<Object?> items = raw! as List<Object?>;
    return items
        .cast<Map<String, Object?>>()
        .map(_deviceSummaryFromJson)
        .toList(growable: false);
  }

  Future<DeviceSummary> updateMyDeviceLabel({
    required LocalDeviceIdentity identity,
    required String deviceLabel,
  }) async {
    final Object? raw = await _signedRequest(
      method: 'PATCH',
      pathWithQuery: '/api/v1/pairing/devices/me',
      identity: identity,
      body: <String, Object?>{'deviceLabel': deviceLabel},
    );
    return _deviceSummaryFromJson(raw! as Map<String, Object?>);
  }

  static DeviceSummary _deviceSummaryFromJson(Map<String, Object?> d) {
    final String? kemB64 = d['kemPublicKeyB64'] as String?;
    return DeviceSummary(
      deviceId: d['deviceId'] as String,
      label: d['label'] as String,
      enrolledVia: d['enrolledVia'] as String,
      createdAt: DateTime.parse(d['createdAt'] as String).toUtc(),
      revokedAt: d['revokedAt'] == null
          ? null
          : DateTime.parse(d['revokedAt'] as String).toUtc(),
      kemPublicKey: kemB64 == null || kemB64.isEmpty
          ? null
          : _decodeB64(kemB64),
      approved: d['approved'] as bool? ?? true,
    );
  }

  Future<void> revokeDevice({
    required LocalDeviceIdentity identity,
    required String targetDeviceId,
    Map<String, Object?>? rotationBody,
  }) async {
    await _signedRequest(
      method: 'POST',
      pathWithQuery: '/api/v1/pairing/devices/$targetDeviceId/revoke',
      identity: identity,
      body: rotationBody,
    );
  }

  Future<EpochRotationStateResponse> fetchMyEpochRotation({
    required LocalDeviceIdentity identity,
  }) async {
    final Object? raw = await _signedRequest(
      method: 'GET',
      pathWithQuery: '/api/v1/pairing/epoch-rotations/me',
      identity: identity,
    );
    final Map<String, Object?> json = raw! as Map<String, Object?>;
    final Object? rawPending = json['pendingDelivery'];
    return EpochRotationStateResponse(
      currentKeyEpoch: json['currentKeyEpoch'] as int? ?? 1,
      pendingDelivery: rawPending is Map<String, Object?>
          ? WrappedKeyPackage.fromJson(rawPending)
          : null,
    );
  }

  Future<void> unpair({required LocalDeviceIdentity identity}) async {
    await _signedRequest(
      method: 'POST',
      pathWithQuery: '/api/v1/pairing/unpair',
      identity: identity,
    );
  }

  Future<RecoveryChallengeResponse> createRecoveryChallenge({
    required Uint8List recoveryAuthPublicKey,
  }) async {
    final Map<String, Object?> json = await _postJson(
      '/api/v1/recovery/challenges',
      <String, Object?>{
        'recoveryAuthPublicKeyB64': base64UrlEncode(recoveryAuthPublicKey),
      },
    );
    return RecoveryChallengeResponse(
      challengeId: json['challengeId'] as String,
      coupleId: json['coupleId'] as String,
      nonceB64: json['nonceB64'] as String,
      expiresAt: DateTime.parse(json['expiresAt'] as String).toUtc(),
    );
  }

  Future<RecoveryCompleteResponse> completeRecovery({
    required String challengeId,
    required String deviceLabel,
    required Uint8List newDeviceAuthPublicKey,
    required Uint8List newDeviceKemPublicKey,
    required String recoverySignatureB64,
  }) async {
    final Map<String, Object?> json = await _postJson(
      '/api/v1/recovery/complete',
      <String, Object?>{
        'challengeId': challengeId,
        'deviceLabel': deviceLabel,
        'newDeviceAuthPublicKeyB64': base64UrlEncode(newDeviceAuthPublicKey),
        'newDeviceKemPublicKeyB64': base64UrlEncode(newDeviceKemPublicKey),
        'recoverySignatureB64': recoverySignatureB64,
      },
    );
    final String? nonceB64 = json['recoveryKeyringNonceB64'] as String?;
    final String? cipherB64 = json['recoveryKeyringCiphertextB64'] as String?;
    return RecoveryCompleteResponse(
      deviceId: json['deviceId'] as String,
      currentKeyEpoch: json['currentKeyEpoch'] as int? ?? 1,
      recoveryKeyringNonce: nonceB64 == null || nonceB64.isEmpty
          ? null
          : _decodeB64(nonceB64),
      recoveryKeyringCiphertextWithTag: cipherB64 == null || cipherB64.isEmpty
          ? null
          : _decodeB64(cipherB64),
    );
  }

  Future<EncryptedEnvelope> uploadEnvelope({
    required LocalDeviceIdentity identity,
    required EncryptedEnvelope envelope,
  }) async {
    final Object? raw = await _signedRequest(
      method: 'POST',
      pathWithQuery: '/api/v1/sync/envelopes',
      identity: identity,
      body: envelope.toUploadJson(),
      timeout: uploadTimeout,
    );
    return EncryptedEnvelope.fromJson(raw! as Map<String, Object?>);
  }

  Future<EnvelopePage> listEnvelopesPage({
    required LocalDeviceIdentity identity,
    int afterSeq = 0,
    int limit = 100,
  }) async {
    final Object? raw = await _signedRequest(
      method: 'GET',
      pathWithQuery: '/api/v1/sync/envelopes?afterSeq=$afterSeq&limit=$limit',
      identity: identity,
    );
    if (raw is List<Object?>) {
      final List<EncryptedEnvelope> items = raw
          .cast<Map<String, Object?>>()
          .map(EncryptedEnvelope.fromJson)
          .toList(growable: false);
      return EnvelopePage(
        items: items,
        nextAfterSeq: items.isEmpty ? afterSeq : (items.last.seq ?? afterSeq),
        hasMore: false,
      );
    }
    final Map<String, Object?> page = raw! as Map<String, Object?>;
    final List<Object?> rawItems =
        page['items'] as List<Object?>? ?? const <Object?>[];
    final List<EncryptedEnvelope> items = rawItems
        .cast<Map<String, Object?>>()
        .map(EncryptedEnvelope.fromJson)
        .toList(growable: false);
    final int nextSeq =
        (page['nextAfterSeq'] as int?) ??
        (items.isEmpty ? afterSeq : (items.last.seq ?? afterSeq));
    final bool hasMore = page['hasMore'] as bool? ?? false;
    final int coupleKeyEpoch = page['coupleKeyEpoch'] as int? ?? 1;
    return EnvelopePage(
      items: items,
      nextAfterSeq: nextSeq,
      hasMore: hasMore,
      coupleKeyEpoch: coupleKeyEpoch,
    );
  }

  Future<({List<EncryptedEnvelope> envelopes, int coupleKeyEpoch})>
  listEnvelopesWithEpoch({
    required LocalDeviceIdentity identity,
    int afterSeq = 0,
    int limit = 100,
  }) async {
    final List<EncryptedEnvelope> all = <EncryptedEnvelope>[];
    int cursor = afterSeq;
    int coupleKeyEpoch = 1;
    while (true) {
      final EnvelopePage page = await listEnvelopesPage(
        identity: identity,
        afterSeq: cursor,
        limit: limit,
      );
      coupleKeyEpoch = page.coupleKeyEpoch;
      all.addAll(page.items);
      if (!page.hasMore || page.nextAfterSeq <= cursor) {
        break;
      }
      cursor = page.nextAfterSeq;
    }
    return (envelopes: all, coupleKeyEpoch: coupleKeyEpoch);
  }

  Future<List<EncryptedEnvelope>> listEnvelopes({
    required LocalDeviceIdentity identity,
    int afterSeq = 0,
    int limit = 100,
  }) async {
    final res = await listEnvelopesWithEpoch(
      identity: identity,
      afterSeq: afterSeq,
      limit: limit,
    );
    return res.envelopes;
  }

  Future<Map<String, Object?>> fetchVisibilityAudit({
    required LocalDeviceIdentity identity,
  }) async {
    final Object? pairing = await _signedRequest(
      method: 'GET',
      pathWithQuery: '/api/v1/pairing/visibility',
      identity: identity,
    );
    final Object? sync = await _signedRequest(
      method: 'GET',
      pathWithQuery: '/api/v1/sync/visibility',
      identity: identity,
    );
    return <String, Object?>{'pairing': pairing, 'sync': sync};
  }

  /// Executes an Ed25519-signed request against any protected `/api/v1/**` endpoint (`AD-02`).
  Future<Object?> signedJsonRequest({
    required String method,
    required String pathWithQuery,
    required LocalDeviceIdentity identity,
    Map<String, Object?>? body,
  }) => _signedRequest(
    method: method,
    pathWithQuery: pathWithQuery,
    identity: identity,
    body: body,
  );

  Future<Map<String, Object?>> _postJson(
    String path,
    Map<String, Object?> body,
  ) async {
    final Uri uri = Uri.parse('$_baseUrl$path');
    final http.Response res = await _http
        .post(
          uri,
          headers: <String, String>{
            ..._versionHeaders(),
            'Content-Type': 'application/json',
          },
          body: jsonEncode(body),
        )
        .timeout(requestTimeout);
    return _decodeResponse(res)! as Map<String, Object?>;
  }

  Future<Object?> _signedRequest({
    required String method,
    required String pathWithQuery,
    required LocalDeviceIdentity identity,
    Map<String, Object?>? body,
    Duration? timeout,
  }) async {
    final List<int> bodyBytes = body == null
        ? const <int>[]
        : utf8.encode(jsonEncode(body));
    final int timestamp = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
    final String nonce = _crypto.generateUuidV4();
    final SimpleKeyPair authKp = await _crypto.deviceAuthKeyPairFromSeed(
      identity.authPrivateKeySeed,
    );
    final String signature = await _crypto.signHttpRequest(
      deviceAuthKeyPair: authKp,
      method: method,
      pathWithQuery: pathWithQuery,
      timestampSeconds: timestamp,
      nonce: nonce,
      bodyBytes: bodyBytes,
    );

    final Map<String, String> headers = <String, String>{
      ..._versionHeaders(),
      'X-Device-Id': identity.deviceId,
      'X-Timestamp': timestamp.toString(),
      'X-Nonce': nonce,
      'X-Signature': signature,
      if (body != null) 'Content-Type': 'application/json',
    };

    final Uri uri = Uri.parse('$_baseUrl$pathWithQuery');
    final Duration effectiveTimeout = timeout ?? requestTimeout;
    final Future<http.Response> responseFuture = switch (method.toUpperCase()) {
      'GET' => _http.get(uri, headers: headers),
      'POST' => _http.post(uri, headers: headers, body: bodyBytes),
      'PATCH' => _http.patch(uri, headers: headers, body: bodyBytes),
      'DELETE' => _http.delete(uri, headers: headers),
      _ => throw UnsupportedError('Unsupported method $method'),
    };
    final http.Response res = await responseFuture.timeout(effectiveTimeout);
    return _decodeResponse(res);
  }

  Map<String, String> _versionHeaders() => <String, String>{
    'X-Client-Version-Code': _clientVersionCode.toString(),
    'X-Protocol-Version': _protocolVersion.toString(),
  };

  static Object? _decodeResponse(http.Response res) {
    if (res.statusCode < 200 || res.statusCode >= 300) {
      String msg = res.body;
      String? errCode;
      int minClient = 1;
      int minProto = 1;
      try {
        final Object? decoded = jsonDecode(res.body);
        if (decoded is Map<String, Object?>) {
          if (decoded['code'] is String) {
            errCode = decoded['code']! as String;
          }
          if (decoded['message'] is String) {
            msg = decoded['message']! as String;
          }
          if (decoded['minClientVersionCode'] is int) {
            minClient = decoded['minClientVersionCode']! as int;
          }
          if (decoded['minProtocolVersion'] is int) {
            minProto = decoded['minProtocolVersion']! as int;
          }
        }
      } catch (_) {}
      if (res.statusCode == 426) {
        throw ClientUpgradeRequiredException(
          message: msg,
          minClientVersionCode: minClient,
          minProtocolVersion: minProto,
        );
      }
      throw ApiRequestException(res.statusCode, msg, errorCode: errCode);
    }
    if (res.body.trim().isEmpty) {
      return null;
    }
    return jsonDecode(res.body);
  }

  static Uint8List _decodeB64(String value) {
    final int rem = value.length % 4;
    final String padded = rem == 0
        ? value
        : value.padRight(value.length + (4 - rem), '=');
    return Uint8List.fromList(base64Url.decode(padded));
  }
}
