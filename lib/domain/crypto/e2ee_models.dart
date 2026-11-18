import 'dart:convert';
import 'dart:typed_data';

/// Logical encrypted envelope channel stored on the server (`SP02-01`).
/// Note: Never encodes the semantic event type (e.g. mood, capsule, drawing).
enum EnvelopeChannel {
  event('EVENT'),
  snapshot('SNAPSHOT');

  const EnvelopeChannel(this.wireValue);

  final String wireValue;

  static EnvelopeChannel fromWire(String value) {
    for (final EnvelopeChannel channel in EnvelopeChannel.values) {
      if (channel.wireValue == value) {
        return channel;
      }
    }
    throw FormatException('Unknown envelope channel "$value".');
  }
}

/// Plaintext payload encrypted inside an [EncryptedEnvelope].
class DecryptedEnvelopePayload {
  const DecryptedEnvelopePayload({
    required this.schemaVersion,
    required this.eventType,
    required this.createdAtClient,
    required this.authorDeviceId,
    required this.body,
  });

  final int schemaVersion;
  final String eventType;
  final DateTime createdAtClient;
  final String authorDeviceId;
  final Map<String, Object?> body;

  Map<String, Object?> toJson() => <String, Object?>{
    'schemaVersion': schemaVersion,
    'eventType': eventType,
    'createdAtClient': createdAtClient.toUtc().toIso8601String(),
    'authorDeviceId': authorDeviceId,
    'body': body,
  };

  factory DecryptedEnvelopePayload.fromJson(Map<String, Object?> json) {
    final Object? rawBody = json['body'];
    return DecryptedEnvelopePayload(
      schemaVersion: json['schemaVersion'] as int,
      eventType: json['eventType'] as String,
      createdAtClient: DateTime.parse(json['createdAtClient'] as String)
          .toUtc(),
      authorDeviceId: json['authorDeviceId'] as String,
      body: rawBody is Map<String, Object?>
          ? Map<String, Object?>.from(rawBody)
          : <String, Object?>{},
    );
  }
}

/// Opaque AEAD-encrypted envelope stored by the server (`SP02-01`, `S-01`).
class EncryptedEnvelope {
  const EncryptedEnvelope({
    required this.envelopeId,
    required this.coupleId,
    required this.senderDeviceId,
    required this.channel,
    required this.keyEpoch,
    required this.nonce,
    required this.ciphertextWithTag,
    this.seq,
    this.createdAtServer,
  });

  final String envelopeId;
  final String coupleId;
  final String senderDeviceId;
  final EnvelopeChannel channel;
  final int keyEpoch;
  final Uint8List nonce;
  final Uint8List ciphertextWithTag;
  final int? seq;
  final DateTime? createdAtServer;

  Map<String, Object?> toUploadJson() => <String, Object?>{
    'envelopeId': envelopeId,
    'channel': channel.wireValue,
    'keyEpoch': keyEpoch,
    'nonceB64': base64UrlEncode(nonce),
    'ciphertextB64': base64UrlEncode(ciphertextWithTag),
  };

  factory EncryptedEnvelope.fromJson(Map<String, Object?> json) {
    return EncryptedEnvelope(
      envelopeId: json['envelopeId'] as String,
      coupleId: json['coupleId'] as String,
      senderDeviceId: json['senderDeviceId'] as String,
      channel: EnvelopeChannel.fromWire(json['channel'] as String),
      keyEpoch: json['keyEpoch'] as int,
      nonce: Uint8List.fromList(
        base64Url.decode(_padB64(json['nonceB64'] as String)),
      ),
      ciphertextWithTag: Uint8List.fromList(
        base64Url.decode(_padB64(json['ciphertextB64'] as String)),
      ),
      seq: json['seq'] as int?,
      createdAtServer: json['createdAtServer'] == null
          ? null
          : DateTime.parse(json['createdAtServer'] as String).toUtc(),
    );
  }
}

/// X25519 + XChaCha20-Poly1305 wrapped key package delivered between partner devices.
class WrappedKeyPackage {
  const WrappedKeyPackage({
    required this.coupleId,
    required this.fromDeviceId,
    required this.toDeviceId,
    required this.nonce,
    required this.ciphertextWithTag,
    this.keyEpoch = 1,
    this.deliveryKind = 'PAIRING_SEED',
  });

  final String coupleId;
  final String fromDeviceId;
  final String toDeviceId;
  final Uint8List nonce;
  final Uint8List ciphertextWithTag;
  final int keyEpoch;
  final String deliveryKind;

  Map<String, Object?> toJson() => <String, Object?>{
    'toDeviceId': toDeviceId,
    'nonceB64': base64UrlEncode(nonce),
    'ciphertextB64': base64UrlEncode(ciphertextWithTag),
    if (keyEpoch > 1) 'keyEpoch': keyEpoch,
  };

  factory WrappedKeyPackage.fromJson(Map<String, Object?> json) {
    return WrappedKeyPackage(
      coupleId: json['coupleId'] as String,
      fromDeviceId: json['fromDeviceId'] as String,
      toDeviceId: json['toDeviceId'] as String,
      nonce: Uint8List.fromList(
        base64Url.decode(_padB64(json['nonceB64'] as String)),
      ),
      ciphertextWithTag: Uint8List.fromList(
        base64Url.decode(_padB64(json['ciphertextB64'] as String)),
      ),
      keyEpoch: json['keyEpoch'] as int? ?? 1,
      deliveryKind: json['deliveryKind'] as String? ?? 'PAIRING_SEED',
    );
  }
}

/// Versioned key bundle (`CA-02`, `ADR-0012`) carrying the active `recoverySeed`,
/// `currentKeyEpoch`, historical `epoch1` root key (key `1` when rotated), and `epoch >= 2` secrets.
class KeyBundle {
  const KeyBundle({
    required this.recoverySeed,
    required this.currentKeyEpoch,
    required this.epochSecrets,
  });

  final Uint8List recoverySeed;
  final int currentKeyEpoch;
  final Map<int, Uint8List> epochSecrets;

  Map<String, Object?> toJson() => <String, Object?>{
    'schemaVersion': 2,
    'recoverySeedB64': base64UrlEncode(recoverySeed),
    'currentKeyEpoch': currentKeyEpoch,
    'epochSecretsB64': <String, String>{
      for (final MapEntry<int, Uint8List> entry in epochSecrets.entries)
        entry.key.toString(): base64UrlEncode(entry.value),
    },
  };

  factory KeyBundle.fromJson(Map<String, Object?> json) {
    final int schema = json['schemaVersion'] as int? ?? 0;
    if (schema != 2) {
      throw FormatException('Unsupported KeyBundle schemaVersion=$schema');
    }
    final Map<int, Uint8List> epochs = <int, Uint8List>{};
    final Object? rawMap = json['epochSecretsB64'];
    if (rawMap is Map) {
      for (final MapEntry<Object?, Object?> entry in rawMap.entries) {
        final int epoch = int.parse(entry.key.toString());
        epochs[epoch] = Uint8List.fromList(
          base64Url.decode(_padB64(entry.value! as String)),
        );
      }
    }
    return KeyBundle(
      recoverySeed: Uint8List.fromList(
        base64Url.decode(_padB64(json['recoverySeedB64'] as String)),
      ),
      currentKeyEpoch: json['currentKeyEpoch'] as int,
      epochSecrets: Map<int, Uint8List>.unmodifiable(epochs),
    );
  }
}

/// Local persisted cryptographic identity and couple state for a single device.
class LocalDeviceIdentity {
  const LocalDeviceIdentity({
    required this.serverUrl,
    required this.coupleId,
    required this.deviceId,
    required this.deviceLabel,
    required this.authPrivateKeySeed,
    required this.authPublicKey,
    required this.kemPrivateKey,
    required this.kemPublicKey,
    this.recoverySeed,
    this.currentKeyEpoch = 1,
    this.epochSecrets = const <int, Uint8List>{},
    this.recoverySavedConfirmed = false,
    this.pairingCompleted = true,
    this.nameSetupCompleted = true,
  });

  final String serverUrl;
  final String coupleId;
  final String deviceId;
  final String deviceLabel;
  final Uint8List authPrivateKeySeed;
  final Uint8List authPublicKey;
  final Uint8List kemPrivateKey;
  final Uint8List kemPublicKey;
  final Uint8List? recoverySeed;
  final int currentKeyEpoch;
  final Map<int, Uint8List> epochSecrets;
  final bool recoverySavedConfirmed;
  final bool pairingCompleted;
  final bool nameSetupCompleted;

  bool get hasCoupleRoot => recoverySeed != null && recoverySeed!.length == 32;

  LocalDeviceIdentity copyWith({
    String? serverUrl,
    String? coupleId,
    String? deviceId,
    String? deviceLabel,
    Uint8List? authPrivateKeySeed,
    Uint8List? authPublicKey,
    Uint8List? kemPrivateKey,
    Uint8List? kemPublicKey,
    Uint8List? recoverySeed,
    int? currentKeyEpoch,
    Map<int, Uint8List>? epochSecrets,
    bool? recoverySavedConfirmed,
    bool? pairingCompleted,
    bool? nameSetupCompleted,
  }) {
    return LocalDeviceIdentity(
      serverUrl: serverUrl ?? this.serverUrl,
      coupleId: coupleId ?? this.coupleId,
      deviceId: deviceId ?? this.deviceId,
      deviceLabel: deviceLabel ?? this.deviceLabel,
      authPrivateKeySeed: authPrivateKeySeed ?? this.authPrivateKeySeed,
      authPublicKey: authPublicKey ?? this.authPublicKey,
      kemPrivateKey: kemPrivateKey ?? this.kemPrivateKey,
      kemPublicKey: kemPublicKey ?? this.kemPublicKey,
      recoverySeed: recoverySeed ?? this.recoverySeed,
      currentKeyEpoch: currentKeyEpoch ?? this.currentKeyEpoch,
      epochSecrets: epochSecrets ?? this.epochSecrets,
      recoverySavedConfirmed:
          recoverySavedConfirmed ?? this.recoverySavedConfirmed,
      pairingCompleted: pairingCompleted ?? this.pairingCompleted,
      nameSetupCompleted: nameSetupCompleted ?? this.nameSetupCompleted,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'serverUrl': serverUrl,
    'coupleId': coupleId,
    'deviceId': deviceId,
    'deviceLabel': deviceLabel,
    'authPrivateKeySeedB64': base64UrlEncode(authPrivateKeySeed),
    'authPublicKeyB64': base64UrlEncode(authPublicKey),
    'kemPrivateKeyB64': base64UrlEncode(kemPrivateKey),
    'kemPublicKeyB64': base64UrlEncode(kemPublicKey),
    'recoverySeedB64': recoverySeed == null
        ? null
        : base64UrlEncode(recoverySeed!),
    'currentKeyEpoch': currentKeyEpoch,
    if (epochSecrets.isNotEmpty)
      'epochSecretsB64': <String, String>{
        for (final MapEntry<int, Uint8List> entry in epochSecrets.entries)
          entry.key.toString(): base64UrlEncode(entry.value),
      },
    'recoverySavedConfirmed': recoverySavedConfirmed,
    'pairingCompleted': pairingCompleted,
    'nameSetupCompleted': nameSetupCompleted,
  };

  factory LocalDeviceIdentity.fromJson(Map<String, Object?> json) {
    final String? recoveryB64 = json['recoverySeedB64'] as String?;
    final Map<int, Uint8List> epochs = <int, Uint8List>{};
    final Object? rawEpochs = json['epochSecretsB64'];
    if (rawEpochs is Map) {
      for (final MapEntry<Object?, Object?> entry in rawEpochs.entries) {
        final int epoch = int.parse(entry.key.toString());
        epochs[epoch] = Uint8List.fromList(
          base64Url.decode(_padB64(entry.value! as String)),
        );
      }
    }
    return LocalDeviceIdentity(
      serverUrl: json['serverUrl'] as String,
      coupleId: json['coupleId'] as String,
      deviceId: json['deviceId'] as String,
      deviceLabel: json['deviceLabel'] as String,
      authPrivateKeySeed: Uint8List.fromList(
        base64Url.decode(_padB64(json['authPrivateKeySeedB64'] as String)),
      ),
      authPublicKey: Uint8List.fromList(
        base64Url.decode(_padB64(json['authPublicKeyB64'] as String)),
      ),
      kemPrivateKey: Uint8List.fromList(
        base64Url.decode(_padB64(json['kemPrivateKeyB64'] as String)),
      ),
      kemPublicKey: Uint8List.fromList(
        base64Url.decode(_padB64(json['kemPublicKeyB64'] as String)),
      ),
      recoverySeed: recoveryB64 == null
          ? null
          : Uint8List.fromList(base64Url.decode(_padB64(recoveryB64))),
      currentKeyEpoch: json['currentKeyEpoch'] as int? ?? 1,
      epochSecrets: Map<int, Uint8List>.unmodifiable(epochs),
      recoverySavedConfirmed: json['recoverySavedConfirmed'] as bool? ?? false,
      pairingCompleted: json['pairingCompleted'] as bool? ?? true,
      nameSetupCompleted: json['nameSetupCompleted'] as bool? ?? true,
    );
  }
}

String _padB64(String input) {
  final int rem = input.length % 4;
  if (rem == 0) {
    return input;
  }
  return input.padRight(input.length + (4 - rem), '=');
}
