import 'package:deep_sky/data/encrypted_local_cache.dart';

/// Derives DS-2 hybrid scene slot states from decrypted couple events (PR-M2-06, F-03).
class SceneStateSnapshot {
  const SceneStateSnapshot({
    required this.slotStates,
    this.latestThought,
    this.fromPartner = false,
  });

  final Map<String, String> slotStates;
  final CachedEventEntry? latestThought;
  final bool fromPartner;

  bool get windowLit => slotStates['window'] == 'lit';
}

class SceneStateMapper {
  const SceneStateMapper();

  static const Duration thoughtGlowWindow = Duration(hours: 12);

  SceneStateSnapshot derive({
    required List<CachedEventEntry> events,
    required String localDeviceId,
    DateTime? nowUtc,
  }) {
    final DateTime now = (nowUtc ?? DateTime.now().toUtc()).toUtc();
    CachedEventEntry? latestThought;

    for (final CachedEventEntry entry in events) {
      if (entry.payload.eventType == 'thinking_of_you') {
        if (latestThought == null ||
            entry.payload.createdAtClient.isAfter(
              latestThought.payload.createdAtClient,
            )) {
          latestThought = entry;
        }
      }
    }

    final bool hasRecentThought =
        latestThought != null &&
        now.difference(latestThought.payload.createdAtClient) <=
            thoughtGlowWindow;
    final bool fromPartner =
        latestThought != null &&
        latestThought.payload.authorDeviceId != localDeviceId;

    return SceneStateSnapshot(
      slotStates: <String, String>{'window': hasRecentThought ? 'lit' : 'calm'},
      latestThought: latestThought,
      fromPartner: fromPartner,
    );
  }
}
