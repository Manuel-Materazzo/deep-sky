import 'package:deep_sky/data/encrypted_local_cache.dart';
import 'package:deep_sky/scene/couple_room_snapshot.dart';
import 'package:deep_sky/scene/local_scene_view_state.dart';

/// Combined derived view state for the Home scene (`F-02`, `F-03`, `S2-CTR-02`).
///
/// Keeps [sharedSnapshot] (objective shared artifacts) strictly separated from
/// device-local unseen/lamp visibility and local sky period (`P-07`, `S-05`).
class SceneStateSnapshot {
  const SceneStateSnapshot({
    required this.slotStates,
    this.sharedSnapshot,
    this.skyPeriod = SkyPeriod.night,
    this.latestThought,
    this.unseenPartnerThought,
    this.fromPartner = false,
  });

  final Map<String, String> slotStates;
  final CoupleRoomSnapshot? sharedSnapshot;
  final SkyPeriod skyPeriod;
  final CachedEventEntry? latestThought;
  final CachedEventEntry? unseenPartnerThought;
  final bool fromPartner;

  /// Whether the "light left on" (`floor_lamp: lit`) is currently glowing (`F-03`).
  bool get floorLampLit => slotStates['floor_lamp'] == 'lit';

  /// Whether there is an unseen partner thought received within 6 hours (`S2-CTR-02`).
  bool get hasUnseenRecentPartnerThought => unseenPartnerThought != null;

  /// Legacy compatibility alias for M2 pilot tests.
  bool get windowLit => floorLampLit || slotStates['window'] == 'lit';
}

class SceneStateMapper {
  const SceneStateMapper();

  /// Active window for displaying the `"<Partner> ti ha pensato"` + `"Ricambia"` banner
  /// and illuminating `floor_lamp: lit` (`S2-CTR-02`, `S2-APP-03`).
  static const Duration thoughtGlowWindow = Duration(hours: 6);

  SceneStateSnapshot derive({
    required List<CachedEventEntry> events,
    required String localDeviceId,
    String coupleId = '',
    LocalSceneViewState localViewState = const LocalSceneViewState(),
    DateTime? nowUtc,
    DateTime? nowLocal,
  }) {
    final DateTime resolvedNowUtc = (nowUtc ?? DateTime.now().toUtc()).toUtc();
    final DateTime resolvedNowLocal = nowLocal ?? DateTime.now();
    final SkyPeriod activeSky = localViewState.skyPreference.resolvePeriod(
      resolvedNowLocal,
    );

    int maxSeq = 0;
    CachedEventEntry? latestThought;
    CachedEventEntry? latestPartnerThought;

    for (final CachedEventEntry entry in events) {
      if (entry.seq != null && entry.seq! > maxSeq) {
        maxSeq = entry.seq!;
      }
      if (entry.payload.eventType == 'thinking_of_you') {
        if (latestThought == null ||
            entry.payload.createdAtClient.isAfter(
              latestThought.payload.createdAtClient,
            )) {
          latestThought = entry;
        }
        if (entry.payload.authorDeviceId != localDeviceId) {
          if (latestPartnerThought == null ||
              entry.payload.createdAtClient.isAfter(
                latestPartnerThought.payload.createdAtClient,
              )) {
            latestPartnerThought = entry;
          }
        }
      }
    }

    final CachedEventEntry? activeUnseenPartnerThought =
        _isUnseenAndWithinWindow(
          entry: latestPartnerThought,
          localViewState: localViewState,
          nowUtc: resolvedNowUtc,
        )
        ? latestPartnerThought
        : null;

    final bool fromPartner =
        latestThought != null &&
        latestThought.payload.authorDeviceId != localDeviceId;

    final Object? rawNote = latestThought?.payload.body['note'];
    final CoupleRoomSnapshot sharedSnapshot = CoupleRoomSnapshot(
      coupleId: coupleId,
      lastEventSeq: maxSeq,
      latestThought: latestThought == null
          ? null
          : SharedThoughtArtifact(
              envelopeId: latestThought.envelopeId,
              seq: latestThought.seq,
              authorDeviceId: latestThought.payload.authorDeviceId,
              createdAtUtc: latestThought.payload.createdAtClient,
              note: rawNote is String && rawNote.isNotEmpty ? rawNote : null,
            ),
    );

    return SceneStateSnapshot(
      slotStates: <String, String>{
        'window': activeSky.manifestState,
        'floor_lamp': activeUnseenPartnerThought != null ? 'lit' : 'calm',
      },
      sharedSnapshot: sharedSnapshot,
      skyPeriod: activeSky,
      latestThought: latestThought,
      unseenPartnerThought: activeUnseenPartnerThought,
      fromPartner: fromPartner,
    );
  }

  static bool _isUnseenAndWithinWindow({
    required CachedEventEntry? entry,
    required LocalSceneViewState localViewState,
    required DateTime nowUtc,
  }) {
    if (entry == null) {
      return false;
    }
    final Duration age = nowUtc.difference(
      entry.payload.createdAtClient.toUtc(),
    );
    if (age >= thoughtGlowWindow || age < const Duration(minutes: -5)) {
      return false;
    }
    if (entry.seq != null) {
      return entry.seq! > localViewState.lastSeenEventSeq;
    }
    return entry.envelopeId != localViewState.lastSeenThoughtEnvelopeId;
  }
}
