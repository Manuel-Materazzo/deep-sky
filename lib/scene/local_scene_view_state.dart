import 'dart:convert';

import 'package:deep_sky/data/secure_key_store.dart';

/// Fixed local time-of-day sky bands computed strictly from device clock (`S-05`, `S2-CTR-02`).
enum SkyPeriod {
  day,
  twilight,
  night;

  /// Resolves the local sky band without GPS or weather APIs (`S-05`).
  ///
  /// - `06:00–17:59` -> [SkyPeriod.day]
  /// - `18:00–20:59` -> [SkyPeriod.twilight]
  /// - `21:00–05:59` -> [SkyPeriod.night]
  static SkyPeriod fromLocalTime(DateTime localTime) {
    final int hour = localTime.hour;
    if (hour >= 6 && hour < 18) {
      return SkyPeriod.day;
    }
    if (hour >= 18 && hour < 21) {
      return SkyPeriod.twilight;
    }
    return SkyPeriod.night;
  }

  String get manifestState => name;

  String localizedLabel(String languageCode) {
    final bool isIt = languageCode == 'it';
    switch (this) {
      case SkyPeriod.day:
        return isIt ? 'Giorno' : 'Day';
      case SkyPeriod.twilight:
        return isIt ? 'Crepuscolo' : 'Twilight';
      case SkyPeriod.night:
        return isIt ? 'Notte' : 'Night';
    }
  }
}

/// Device-local sky / theme preference (`Auto`, `Giorno`, `Notte`, `S2-CTR-02`).
enum SkyTimePreference {
  auto,
  day,
  night;

  String get storageValue => name;

  static SkyTimePreference fromStorage(String? raw) {
    switch (raw) {
      case 'day':
        return SkyTimePreference.day;
      case 'night':
        return SkyTimePreference.night;
      default:
        return SkyTimePreference.auto;
    }
  }

  SkyPeriod resolvePeriod(DateTime localTime) {
    switch (this) {
      case SkyTimePreference.day:
        return SkyPeriod.day;
      case SkyTimePreference.night:
        return SkyPeriod.night;
      case SkyTimePreference.auto:
        return SkyPeriod.fromLocalTime(localTime);
    }
  }

  String localizedLabel(String languageCode) {
    final bool isIt = languageCode == 'it';
    switch (this) {
      case SkyTimePreference.auto:
        return isIt ? 'Automatico (ora locale)' : 'Automatic (local time)';
      case SkyTimePreference.day:
        return isIt ? 'Giorno' : 'Day';
      case SkyTimePreference.night:
        return isIt ? 'Notte' : 'Night';
    }
  }
}

/// Strictly device-local Home view state that NEVER leaves the phone or enters
/// `CoupleRoomSnapshot` / server sync (`P-07`, `S-05`, `S2-CTR-02`).
class LocalSceneViewState {
  const LocalSceneViewState({
    this.lastSeenEventSeq = 0,
    this.lastSeenThoughtEnvelopeId,
    this.lastOpenedAtLocal,
    this.skyPreference = SkyTimePreference.auto,
  });

  /// Minimum elapsed local gap before showing the warm welcome-back note (`S2-D07`).
  static const Duration welcomeBackAbsenceThreshold = Duration(days: 3);

  final int lastSeenEventSeq;
  final String? lastSeenThoughtEnvelopeId;
  final DateTime? lastOpenedAtLocal;
  final SkyTimePreference skyPreference;

  bool shouldShowWelcomeBack(DateTime nowUtc) {
    final DateTime? prev = lastOpenedAtLocal;
    if (prev == null) {
      return false;
    }
    return nowUtc.toUtc().difference(prev.toUtc()) >=
        welcomeBackAbsenceThreshold;
  }

  LocalSceneViewState copyWith({
    int? lastSeenEventSeq,
    String? lastSeenThoughtEnvelopeId,
    DateTime? lastOpenedAtLocal,
    SkyTimePreference? skyPreference,
  }) {
    return LocalSceneViewState(
      lastSeenEventSeq: lastSeenEventSeq ?? this.lastSeenEventSeq,
      lastSeenThoughtEnvelopeId:
          lastSeenThoughtEnvelopeId ?? this.lastSeenThoughtEnvelopeId,
      lastOpenedAtLocal: lastOpenedAtLocal ?? this.lastOpenedAtLocal,
      skyPreference: skyPreference ?? this.skyPreference,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'lastSeenEventSeq': lastSeenEventSeq,
    'lastSeenThoughtEnvelopeId': lastSeenThoughtEnvelopeId,
    'lastOpenedAtLocal': lastOpenedAtLocal?.toUtc().toIso8601String(),
    'skyPreference': skyPreference.storageValue,
  };

  factory LocalSceneViewState.fromJson(Map<String, Object?> json) {
    final String? rawOpened = json['lastOpenedAtLocal'] as String?;
    return LocalSceneViewState(
      lastSeenEventSeq: json['lastSeenEventSeq'] as int? ?? 0,
      lastSeenThoughtEnvelopeId: json['lastSeenThoughtEnvelopeId'] as String?,
      lastOpenedAtLocal: rawOpened == null || rawOpened.isEmpty
          ? null
          : DateTime.tryParse(rawOpened)?.toUtc(),
      skyPreference: SkyTimePreference.fromStorage(
        json['skyPreference'] as String?,
      ),
    );
  }
}

/// Persists [LocalSceneViewState] exclusively inside device-local [SecureKeyStore] (`P-07`, `S-05`).
class LocalSceneViewStateStore {
  const LocalSceneViewStateStore(this._keyStore);

  static const String storageKey = 'deepsky.local_scene_view_state.v1';

  final SecureKeyStore _keyStore;

  Future<LocalSceneViewState> load() async {
    try {
      final String? raw = await _keyStore.read(storageKey);
      if (raw == null || raw.isEmpty) {
        return const LocalSceneViewState();
      }
      final Object? decoded = jsonDecode(raw);
      if (decoded is Map<String, Object?>) {
        return LocalSceneViewState.fromJson(decoded);
      }
    } catch (_) {}
    return const LocalSceneViewState();
  }

  Future<void> save(LocalSceneViewState state) {
    return _keyStore.write(storageKey, jsonEncode(state.toJson()));
  }

  Future<void> clear() => _keyStore.delete(storageKey);
}
