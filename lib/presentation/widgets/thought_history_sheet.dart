import 'package:deep_sky/data/encrypted_local_cache.dart';
import 'package:deep_sky/presentation/l10n/deep_sky_strings.dart';
import 'package:deep_sky/presentation/theme/deep_sky_theme.dart';
import 'package:material_ui/material_ui.dart';

/// Opens the "Ti Penso" chronological history modal bottom sheet
/// (`docs/design/S3-3/thinking of you histoty/`, `F-03`, `P-02`, `V-06`, `V-07`).
Future<void> showThoughtHistorySheet({
  required BuildContext context,
  required List<CachedEventEntry> events,
  required String? myDeviceId,
  required String? myDisplayName,
  required String? partnerDisplayName,
  required DateTime nowLocal,
  required DeepSkyStrings strings,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (BuildContext sheetContext) {
      return ThoughtHistorySheet(
        events: events,
        myDeviceId: myDeviceId,
        myDisplayName: myDisplayName,
        partnerDisplayName: partnerDisplayName,
        nowLocal: nowLocal,
        strings: strings,
      );
    },
  );
}

class ThoughtHistorySheet extends StatelessWidget {
  const ThoughtHistorySheet({
    super.key,
    required this.events,
    required this.myDeviceId,
    required this.myDisplayName,
    required this.partnerDisplayName,
    required this.nowLocal,
    required this.strings,
  });

  final List<CachedEventEntry> events;
  final String? myDeviceId;
  final String? myDisplayName;
  final String? partnerDisplayName;
  final DateTime nowLocal;
  final DeepSkyStrings strings;

  @override
  Widget build(BuildContext context) {
    final DeepSkyTokens tokens = DeepSkyTheme.tokensOf(context);
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final List<CachedEventEntry> thoughts =
        events
            .where((CachedEventEntry e) => e.payload.eventType == 'thinking_of_you')
            .toList()
          ..sort((CachedEventEntry a, CachedEventEntry b) {
            final int timeCmp = b.payload.createdAtClient.compareTo(
              a.payload.createdAtClient,
            );
            if (timeCmp != 0) {
              return timeCmp;
            }
            return (b.seq ?? 0).compareTo(a.seq ?? 0);
          });

    final List<_DateGroup> groups = _groupByLocalDate(thoughts);
    final double maxHeight = MediaQuery.sizeOf(context).height * 0.88;

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: Material(
        key: const Key('thought-history-sheet'),
        color: tokens.elevatedSurface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Center(
              child: Padding(
                padding: const EdgeInsets.only(top: 10, bottom: 4),
                child: Container(
                  width: 40,
                  height: 5,
                  decoration: BoxDecoration(
                    color: tokens.cardBorder.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 8, 8),
              child: Row(
                children: <Widget>[
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: scheme.primaryContainer,
                      boxShadow: <BoxShadow>[
                        BoxShadow(
                          color: scheme.primaryContainer.withValues(alpha: 0.45),
                          blurRadius: 10,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      strings.thoughtHistorySheetTitle,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    key: const Key('close-thought-history-button'),
                    tooltip: strings.thoughtHistoryCloseTooltip,
                    constraints: const BoxConstraints(
                      minWidth: 48,
                      minHeight: 48,
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(Icons.close_rounded, color: tokens.mutedInk),
                  ),
                ],
              ),
            ),
            Flexible(
              child: ListView(
                key: const Key('thought-history-list'),
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
                children: <Widget>[
                  _buildSummaryCard(context, tokens, scheme, thoughts.length),
                  const SizedBox(height: 20),
                  if (thoughts.isEmpty)
                    _buildEmptyState(context, tokens)
                  else
                    for (final _DateGroup group in groups) ...<Widget>[
                      _buildGroupHeader(context, tokens, group),
                      const SizedBox(height: 10),
                      for (final CachedEventEntry entry
                          in group.entries) ...<Widget>[
                        _buildThoughtItem(
                          context: context,
                          tokens: tokens,
                          scheme: scheme,
                          entry: entry,
                        ),
                        const SizedBox(height: 10),
                      ],
                      const SizedBox(height: 10),
                    ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard(
    BuildContext context,
    DeepSkyTokens tokens,
    ColorScheme scheme,
    int totalCount,
  ) {
    return Container(
      key: const Key('thought-history-summary-card'),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(DeepSkyTheme.radiusXl),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            tokens.cardSurface,
            tokens.surfaceLow,
          ],
        ),
        border: Border.all(
          color: tokens.cardBorder.withValues(alpha: 0.35),
        ),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(Icons.auto_awesome, color: tokens.amberGlow, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  strings.thoughtHistoryEyebrow,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: tokens.blushPetal,
                    letterSpacing: 0.9,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text.rich(
            TextSpan(
              children: <InlineSpan>[
                TextSpan(
                  text: strings.thoughtHistoryCount(totalCount),
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const TextSpan(text: '  '),
                TextSpan(
                  text: strings.thoughtHistoryCountSuffix,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: tokens.accentText.withValues(alpha: 0.85),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            strings.thoughtHistorySubtitle,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: tokens.mutedInk,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, DeepSkyTokens tokens) {
    return Container(
      key: const Key('thought-history-empty'),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: tokens.cardSurface.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(DeepSkyTheme.radiusXl),
        border: Border.all(color: tokens.cardBorder.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: <Widget>[
          Icon(
            Icons.nights_stay_outlined,
            size: 28,
            color: tokens.blushPetal,
          ),
          const SizedBox(height: 10),
          Text(
            strings.thoughtHistoryEmptyTitle,
            style: Theme.of(context).textTheme.titleSmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            strings.thoughtHistoryEmptyBody,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: tokens.mutedInk,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildGroupHeader(
    BuildContext context,
    DeepSkyTokens tokens,
    _DateGroup group,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: <Widget>[
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: group.isToday ? tokens.blushPetal : tokens.cardBorder,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            group.label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: tokens.mutedInk,
              letterSpacing: 0.8,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThoughtItem({
    required BuildContext context,
    required DeepSkyTokens tokens,
    required ColorScheme scheme,
    required CachedEventEntry entry,
  }) {
    final bool isMe =
        myDeviceId != null &&
        (entry.senderDeviceId == myDeviceId ||
            entry.payload.authorDeviceId == myDeviceId);

    final String partnerName =
        (partnerDisplayName != null && partnerDisplayName!.trim().isNotEmpty)
        ? partnerDisplayName!.trim()
        : strings.partnerFallbackName;
    final String myName =
        (myDisplayName != null && myDisplayName!.trim().isNotEmpty)
        ? myDisplayName!.trim()
        : strings.thoughtHistorySelfFallbackName;

    final String authorTitle = isMe
        ? strings.thoughtHistorySelfLabel(myName)
        : partnerName;
    final String rawNameForInitial = isMe ? myName : partnerName;
    final String initial = rawNameForInitial.isNotEmpty
        ? rawNameForInitial.substring(0, 1).toUpperCase()
        : '?';

    final Object? rawNote = entry.payload.body['note'];
    final String? note = rawNote is String && rawNote.trim().isNotEmpty
        ? rawNote.trim()
        : null;

    final DateTime localTime = entry.payload.createdAtClient.toLocal();
    final String hh = localTime.hour.toString().padLeft(2, '0');
    final String mm = localTime.minute.toString().padLeft(2, '0');
    final String timeLabel = '$hh:$mm';

    final IconData badgeIcon = note == null
        ? Icons.touch_app_rounded
        : (isMe ? Icons.auto_awesome : Icons.favorite_rounded);
    final Color badgeColor = note == null
        ? tokens.blushPetal
        : (isMe ? tokens.amberGlow : tokens.blushPetal);

    return Container(
      decoration: BoxDecoration(
        color: isMe ? tokens.surfaceLow : tokens.cardSurface,
        borderRadius: BorderRadius.circular(DeepSkyTheme.radiusXl),
        border: Border.all(
          color: tokens.cardBorder.withValues(alpha: 0.28),
        ),
      ),
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 42,
            height: 42,
            child: Stack(
              clipBehavior: Clip.none,
              children: <Widget>[
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isMe
                        ? tokens.elevatedSurface
                        : scheme.primaryContainer,
                    boxShadow: isMe
                        ? null
                        : <BoxShadow>[
                            BoxShadow(
                              color: scheme.primaryContainer.withValues(
                                alpha: 0.3,
                              ),
                              blurRadius: 12,
                              spreadRadius: 1,
                            ),
                          ],
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    initial,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: isMe
                          ? tokens.blushPetal
                          : scheme.onPrimaryContainer,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Positioned(
                  right: -1,
                  bottom: -1,
                  child: Container(
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: tokens.skyBackdrop,
                    ),
                    alignment: Alignment.center,
                    child: Icon(badgeIcon, size: 11, color: badgeColor),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Expanded(
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: <Widget>[
                          Text(
                            authorTitle,
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                          if (note == null)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: tokens.elevatedSurface,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                strings.thoughtHistorySilentBadge,
                                style: Theme.of(context).textTheme.labelSmall
                                    ?.copyWith(color: tokens.accentText),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      timeLabel,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: tokens.mutedInk,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                if (note != null)
                  Text(
                    '“$note”',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: isMe ? tokens.mutedInk : null,
                    ),
                  )
                else
                  Text(
                    strings.thoughtHistorySilentCaption,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: tokens.mutedInk,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<_DateGroup> _groupByLocalDate(List<CachedEventEntry> sorted) {
    final DateTime today = DateTime(nowLocal.year, nowLocal.month, nowLocal.day);
    final DateTime yesterday = today.subtract(const Duration(days: 1));
    final Map<DateTime, List<CachedEventEntry>> buckets =
        <DateTime, List<CachedEventEntry>>{};

    for (final CachedEventEntry entry in sorted) {
      final DateTime local = entry.payload.createdAtClient.toLocal();
      final DateTime day = DateTime(local.year, local.month, local.day);
      buckets.putIfAbsent(day, () => <CachedEventEntry>[]).add(entry);
    }

    final List<_DateGroup> groups = <_DateGroup>[];
    for (final MapEntry<DateTime, List<CachedEventEntry>> bucket
        in buckets.entries) {
      final DateTime day = bucket.key;
      final bool isToday = day == today;
      final String label;
      if (isToday) {
        label = strings.thoughtHistoryToday;
      } else if (day == yesterday) {
        label = strings.thoughtHistoryYesterday;
      } else {
        label = strings.thoughtHistoryDateLabel(day, nowLocal);
      }
      groups.add(_DateGroup(label: label, isToday: isToday, entries: bucket.value));
    }
    return groups;
  }
}

class _DateGroup {
  const _DateGroup({
    required this.label,
    required this.isToday,
    required this.entries,
  });

  final String label;
  final bool isToday;
  final List<CachedEventEntry> entries;
}
