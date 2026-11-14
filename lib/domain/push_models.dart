/// Runtime Firebase parameters delivered by the server without embedded credentials (SP-01, TC-04).
class RuntimeFirebaseConfig {
  const RuntimeFirebaseConfig({
    required this.enabled,
    required this.projectId,
    required this.apiKey,
    required this.appId,
    required this.senderId,
  });

  factory RuntimeFirebaseConfig.fromJson(Map<String, dynamic> json) {
    return RuntimeFirebaseConfig(
      enabled: json['enabled'] == true,
      projectId: (json['projectId'] as String?) ?? '',
      apiKey: (json['apiKey'] as String?) ?? '',
      appId: (json['appId'] as String?) ?? '',
      senderId: (json['senderId'] as String?) ?? '',
    );
  }

  final bool enabled;
  final String projectId;
  final String apiKey;
  final String appId;
  final String senderId;

  bool get isComplete =>
      projectId.trim().isNotEmpty &&
      apiKey.trim().isNotEmpty &&
      appId.trim().isNotEmpty &&
      senderId.trim().isNotEmpty;

  Map<String, String> toChannelArgs() => <String, String>{
    'projectId': projectId.trim(),
    'apiKey': apiKey.trim(),
    'appId': appId.trim(),
    'senderId': senderId.trim(),
  };
}

/// Snapshot of Android native push initialization and received wakeups (SP-01).
class NativePushStatus {
  const NativePushStatus({
    required this.configured,
    required this.firebaseInitialized,
    required this.projectId,
    required this.appId,
    required this.lastKnownToken,
    required this.pendingToken,
    required this.lastWakeupKey,
    required this.lastWakeupEpochMs,
    required this.receivedCount,
    required this.hasNotificationPermission,
  });

  factory NativePushStatus.fromMap(Map<Object?, Object?> map) {
    return NativePushStatus(
      configured: map['configured'] == true,
      firebaseInitialized: map['firebaseInitialized'] == true,
      projectId: (map['projectId'] as String?) ?? '',
      appId: (map['appId'] as String?) ?? '',
      lastKnownToken: (map['lastKnownToken'] as String?) ?? '',
      pendingToken: (map['pendingToken'] as String?) ?? '',
      lastWakeupKey: (map['lastWakeupKey'] as String?) ?? '',
      lastWakeupEpochMs: (map['lastWakeupEpochMs'] as int?) ?? 0,
      receivedCount: (map['receivedCount'] as int?) ?? 0,
      hasNotificationPermission: map['hasNotificationPermission'] == true,
    );
  }

  final bool configured;
  final bool firebaseInitialized;
  final String projectId;
  final String appId;
  final String lastKnownToken;
  final String pendingToken;
  final String lastWakeupKey;
  final int lastWakeupEpochMs;
  final int receivedCount;
  final bool hasNotificationPermission;
}

/// Server summary returned by `/api/v1/push/test-wakeup`.
class PushWakeupOutcome {
  const PushWakeupOutcome({
    required this.localizationKey,
    required this.attempted,
    required this.delivered,
    required this.unregisteredRemoved,
  });

  factory PushWakeupOutcome.fromJson(Map<String, dynamic> json) {
    return PushWakeupOutcome(
      localizationKey: (json['localizationKey'] as String?) ?? 'wakeup.generic',
      attempted: (json['attempted'] as int?) ?? 0,
      delivered: (json['delivered'] as int?) ?? 0,
      unregisteredRemoved: (json['unregisteredRemoved'] as int?) ?? 0,
    );
  }

  final String localizationKey;
  final int attempted;
  final int delivered;
  final int unregisteredRemoved;
}
