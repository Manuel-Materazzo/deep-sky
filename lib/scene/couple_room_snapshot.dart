/// Shared, E2EE-syncable couple room snapshot (`schemaVersion = 1`, `S2-CTR-02`, `AR-03`).
///
/// By contract (`P-02`, `P-07`, `S-05`), this model contains **only** objective shared
/// couple artifacts and NEVER includes read receipts (`lastSeenEventSeq`), open timestamps
/// (`lastOpenedAtLocal`), online presence, or inactivity counters.
class SharedThoughtArtifact {
  const SharedThoughtArtifact({
    required this.envelopeId,
    required this.authorDeviceId,
    required this.createdAtUtc,
    this.seq,
    this.note,
  });

  final String envelopeId;
  final int? seq;
  final String authorDeviceId;
  final DateTime createdAtUtc;
  final String? note;

  Map<String, Object?> toJson() => <String, Object?>{
    'envelopeId': envelopeId,
    'seq': seq,
    'authorDeviceId': authorDeviceId,
    'createdAtUtc': createdAtUtc.toUtc().toIso8601String(),
    if (note != null && note!.isNotEmpty) 'note': note,
  };

  factory SharedThoughtArtifact.fromJson(Map<String, Object?> json) {
    return SharedThoughtArtifact(
      envelopeId: json['envelopeId'] as String,
      seq: json['seq'] as int?,
      authorDeviceId: json['authorDeviceId'] as String,
      createdAtUtc: DateTime.parse(json['createdAtUtc'] as String).toUtc(),
      note: json['note'] as String?,
    );
  }
}

class CoupleRoomSnapshot {
  const CoupleRoomSnapshot({
    this.schemaVersion = currentSchemaVersion,
    required this.coupleId,
    required this.lastEventSeq,
    this.latestThought,
  });

  static const int currentSchemaVersion = 1;

  final int schemaVersion;
  final String coupleId;
  final int lastEventSeq;
  final SharedThoughtArtifact? latestThought;

  Map<String, Object?> toJson() => <String, Object?>{
    'schemaVersion': schemaVersion,
    'coupleId': coupleId,
    'lastEventSeq': lastEventSeq,
    if (latestThought != null) 'latestThought': latestThought!.toJson(),
  };

  factory CoupleRoomSnapshot.fromJson(Map<String, Object?> json) {
    final Object? rawThought = json['latestThought'];
    return CoupleRoomSnapshot(
      schemaVersion: json['schemaVersion'] as int? ?? currentSchemaVersion,
      coupleId: json['coupleId'] as String? ?? '',
      lastEventSeq: json['lastEventSeq'] as int? ?? 0,
      latestThought: rawThought is Map<String, Object?>
          ? SharedThoughtArtifact.fromJson(rawThought)
          : null,
    );
  }
}
