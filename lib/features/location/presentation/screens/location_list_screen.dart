import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../notifiers/location_notifier.dart';
import '../../domain/entities/location_entity.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/widgets/gradient_background.dart';
import '../../../../core/widgets/app_empty_state.dart';
import '../widgets/location_tile.dart';
import '../../../../features/map/presentation/screens/map_screen.dart';

// ── Domain model for a grouped session ────────────────────────────────────────

class _SessionGroup {
  final String               sessionId;
  final List<LocationEntity> locations; // sorted DESC (most recent first)

  const _SessionGroup({required this.sessionId, required this.locations});

  String get shortId => '${sessionId.substring(0, 8).toUpperCase()}···';
  int    get count   => locations.length;

  // Most recent and oldest timestamps within this session
  String? get latestTime   => locations.isEmpty ? null : locations.first.timestamp;
  String? get earliestTime => locations.isEmpty ? null : locations.last.timestamp;

  Duration? get timespan {
    if (locations.length < 2) return null;
    final a = DateTime.parse(latestTime!);
    final b = DateTime.parse(earliestTime!);
    return a.difference(b).abs();
  }

  String get timespanLabel {
    final d = timespan;
    if (d == null) return '';
    if (d.inHours   > 0) return '${d.inHours}h ${d.inMinutes.remainder(60)}m';
    if (d.inMinutes > 0) return '${d.inMinutes}m';
    return '< 1m';
  }
}

// ── Sealed display item types — exhaustive switch, no default needed ──────────

sealed class _ListItem {}

class _HeaderItem extends _ListItem {
  final _SessionGroup group;
  final int           sessionIndex;
  _HeaderItem({required this.group, required this.sessionIndex});
}

class _TileItem extends _ListItem {
  final LocationEntity location;
  final int            indexInSession;
  _TileItem({required this.location, required this.indexInSession});
}

// ── Screen ────────────────────────────────────────────────────────────────────

class LocationHistoryScreen extends ConsumerStatefulWidget {
  const LocationHistoryScreen({super.key});

  @override
  ConsumerState<LocationHistoryScreen> createState() =>
      _LocationHistoryState();
}

class _LocationHistoryState extends ConsumerState<LocationHistoryScreen> {

  // ── Local search / filter state ───────────────────────────────────────────

  final TextEditingController _searchCtrl = TextEditingController();
  String         _query      = '';
  bool           _isSearching = false;
  DateTimeRange? _dateFilter;

  // Sessions the user explicitly collapsed. All sessions start expanded.
  final Set<String> _collapsed = {};

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  // ── Data pipeline ─────────────────────────────────────────────────────────

  /// Applies search + date filters, groups by session, and flattens into a
  /// mixed list of header and tile items for SliverList.builder to render.
  List<_ListItem> _buildItems(List<LocationEntity> locations) {
    // ── 1. Text search ──────────────────────────────────────────────────────
    var src = locations;
    if (_query.isNotEmpty) {
      final q = _query.toLowerCase();
      src = src.where((loc) {
        return loc.latitude.toStringAsFixed(6).contains(q)
            || loc.longitude.toStringAsFixed(6).contains(q)
            || DateFormatter.timestampToDisplay(loc.timestamp)
                .toLowerCase()
                .contains(q)
            || loc.sessionId.substring(0, 8).toLowerCase().contains(q);
      }).toList();
    }

    // ── 2. Date range ────────────────────────────────────────────────────────
    if (_dateFilter != null) {
      final rangeStart = DateTime(
        _dateFilter!.start.year,
        _dateFilter!.start.month,
        _dateFilter!.start.day,
      );
      final rangeEnd = DateTime(
        _dateFilter!.end.year,
        _dateFilter!.end.month,
        _dateFilter!.end.day,
        23, 59, 59,
      );
      src = src.where((loc) {
        final dt = DateTime.parse(loc.timestamp).toLocal();
        return !dt.isBefore(rangeStart) && !dt.isAfter(rangeEnd);
      }).toList();
    }

    if (src.isEmpty) return [];

    // ── 3. Group by sessionId — Dart Map preserves insertion order ───────────
    final grouped = <String, List<LocationEntity>>{};
    for (final loc in src) {
      grouped.putIfAbsent(loc.sessionId, () => []).add(loc);
    }

    // ── 4. Flatten: header + (tiles if expanded) ─────────────────────────────
    final items = <_ListItem>[];
    var sessionIndex = 1;
    for (final entry in grouped.entries) {
      final group = _SessionGroup(
        sessionId: entry.key,
        locations: entry.value,
      );
      items.add(_HeaderItem(group: group, sessionIndex: sessionIndex++));

      if (!_collapsed.contains(entry.key)) {
        for (var i = 0; i < entry.value.length; i++) {
          items.add(_TileItem(
            location:       entry.value[i],
            indexInSession: i + 1,
          ));
        }
      }
    }

    return items;
  }

  // ── Actions ───────────────────────────────────────────────────────────────

  Future<void> _refresh() async {
    await ref.read(locationProvider.notifier).loadLocations();
  }

  void _startSearch() => setState(() => _isSearching = true);

  void _stopSearch() {
    _searchCtrl.clear();
    setState(() {
      _isSearching = false;
      _query       = '';
    });
  }

  void _toggleSession(String sessionId) {
    setState(() {
      if (_collapsed.contains(sessionId)) {
        _collapsed.remove(sessionId);
      } else {
        _collapsed.add(sessionId);
      }
    });
  }

  Future<void> _pickDateRange() async {
    final range = await showDateRangePicker(
      context: context,
      firstDate:          DateTime(2020),
      lastDate:           DateTime.now(),
      initialDateRange:   _dateFilter,
      builder: (ctx, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(
            primary:   AppColors.brand,
            onPrimary: Colors.white,
            surface:   AppColors.bgCard,
            onSurface: AppColors.textPrimary,
          ),
          dialogTheme: const DialogThemeData(backgroundColor: AppColors.bgCard),
        ),
        child: child!,
      ),
    );
    if (!mounted) return;
    setState(() => _dateFilter = range);
  }

  void _clearDateFilter() => setState(() => _dateFilter = null);

  Future<void> _deleteSession(String sessionId, int count) async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierColor: AppColors.overlay,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bgCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
          side: const BorderSide(color: AppColors.glassBorder),
        ),
        title:   Text('Delete Session?', style: AppTextStyles.h2),
        content: Text(
          'This permanently removes $count recorded '
          '${count == 1 ? 'point' : 'points'}.',
          style: AppTextStyles.body,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('CANCEL', style: AppTextStyles.label),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'DELETE',
              style: AppTextStyles.label.copyWith(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(locationProvider.notifier).deleteSession(sessionId);
    }
  }

  Future<void> _confirmClearAll(int totalCount) async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierColor: AppColors.overlay,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bgCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
          side: const BorderSide(color: AppColors.glassBorder),
        ),
        title:   Text('Clear All Locations?', style: AppTextStyles.h2),
        content: Text(
          'This permanently deletes all $totalCount recorded points.',
          style: AppTextStyles.body,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('CANCEL', style: AppTextStyles.label),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'DELETE ALL',
              style: AppTextStyles.label.copyWith(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(locationProvider.notifier).clearLocations();
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  /// Builds a compact "dd Mmm" string from a DateTime for filter chips.
  String _formatDate(DateTime dt) {
    const months = [
      'Jan','Feb','Mar','Apr','May','Jun',
      'Jul','Aug','Sep','Oct','Nov','Dec',
    ];
    return '${dt.day} ${months[dt.month - 1]}';
  }

  Widget _buildListItem(_ListItem item) => switch (item) {
    _HeaderItem(:final group, :final sessionIndex) => Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenH, 12, AppSpacing.screenH, 4,
      ),
      child: _SessionHeader(
        group:        group,
        sessionIndex: sessionIndex,
        isExpanded:   !_collapsed.contains(group.sessionId),
        onToggle:     () => _toggleSession(group.sessionId),
        onDelete:     () => _deleteSession(group.sessionId, group.count),
      ),
    ),
    _TileItem(:final location, :final indexInSession) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenH),
      child: LocationTile(
        key:      ValueKey(location.id ?? '${location.sessionId}-$indexInSession'),
        location: location,
        index:    indexInSession,
      ),
    ),
  };

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final loc = ref.watch(locationProvider);

    // Derive display list — pure transformation, fast enough for rebuild
    final displayItems   = _buildItems(loc.locations);
    final filteredCount  = displayItems.whereType<_TileItem>().length;
    final sessionCount   = displayItems.whereType<_HeaderItem>().length;
    final isFiltered     = _query.isNotEmpty || _dateFilter != null;

    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      extendBodyBehindAppBar: true,
      appBar: _buildAppBar(loc.locationCount, isFiltered),
      body: GradientBackground(
        child: SafeArea(
          child: RefreshIndicator(
            onRefresh:       _refresh,
            color:           AppColors.brand,
            backgroundColor: AppColors.bgCard,
            displacement:    60,
            child: CustomScrollView(
              // Always scrollable so RefreshIndicator can trigger even on short lists
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                // ── Summary banner ──────────────────────────────────────────
                if (loc.locations.isNotEmpty || isFiltered)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.screenH, AppSpacing.md,
                        AppSpacing.screenH, 0,
                      ),
                      child: _SummaryBanner(
                        totalCount:    loc.locationCount,
                        totalSessions: loc.sessionIds.length,
                        filteredCount: filteredCount,
                        sessionCount:  sessionCount,
                        isFiltered:    isFiltered,
                        latestTime:    loc.locations.isNotEmpty
                            ? loc.locations.first.timestamp
                            : null,
                      ),
                    ),
                  ),

                // ── Active filters row ──────────────────────────────────────
                if (_dateFilter != null)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.screenH, AppSpacing.sm,
                        AppSpacing.screenH, 0,
                      ),
                      child: _ActiveFiltersRow(
                        dateFilter: _dateFilter!,
                        dateLabel:
                            '${_formatDate(_dateFilter!.start)}'
                            ' → '
                            '${_formatDate(_dateFilter!.end)}',
                        onClearDate: _clearDateFilter,
                      ),
                    ),
                  ),

                // ── Main list or empty state ────────────────────────────────
                if (loc.locations.isEmpty && !isFiltered)
                  // Case 1: Nothing recorded yet
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: AppEmptyState(
                      icon:     Icons.location_off_rounded,
                      title:    'No Locations Yet',
                      subtitle: 'Start tracking on the home screen\n'
                                'to record GPS coordinates.',
                      action:   TextButton.icon(
                        onPressed: () => Navigator.pop(context),
                        icon:  const Icon(Icons.arrow_back_rounded, size: 16),
                        label: const Text('Go Back'),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.brand,
                        ),
                      ),
                    ),
                  )
                else if (displayItems.isEmpty)
                  // Case 2: Filter / search returned nothing
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: AppEmptyState(
                      icon:     _query.isNotEmpty
                          ? Icons.search_off_rounded
                          : Icons.event_busy_rounded,
                      title:    _query.isNotEmpty
                          ? 'No results for "$_query"'
                          : 'No locations in range',
                      subtitle: _query.isNotEmpty
                          ? 'Try searching by coordinates,\n'
                            'date, or session ID.'
                          : 'Try a different date range.',
                      action:   TextButton(
                        onPressed: () {
                          if (_query.isNotEmpty) _stopSearch();
                          if (_dateFilter != null) _clearDateFilter();
                        },
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.brand,
                        ),
                        child: const Text('Clear Filters'),
                      ),
                    ),
                  )
                else ...[
                  // Case 3: Grouped session list
                  SliverList.builder(
                    itemCount: displayItems.length,
                    itemBuilder: (ctx, i) => _buildListItem(displayItems[i]),
                  ),
                  const SliverToBoxAdapter(
                    child: SizedBox(height: AppSpacing.xxl),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── AppBar ────────────────────────────────────────────────────────────────

  AppBar _buildAppBar(int totalCount, bool isFiltered) {
    return AppBar(
      backgroundColor: AppColors.bgPrimary.withValues(alpha: 0.95),
      surfaceTintColor: Colors.transparent,
      elevation:        0,

      // Leading: back OR close-search
      leading: _isSearching
          ? IconButton(
              icon:     const Icon(Icons.close_rounded, size: 20),
              color:    AppColors.textSecondary,
              onPressed: _stopSearch,
              tooltip:  'Close search',
            )
          : GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                margin: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color:  AppColors.glassWhite,
                  shape:  BoxShape.circle,
                  border: Border.all(color: AppColors.glassBorder),
                ),
                child: const Icon(
                  Icons.arrow_back_ios_new_rounded,
                  size:  15,
                  color: AppColors.textPrimary,
                ),
              ),
            ),

      // Title: animated switch between text and search field
      title: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        transitionBuilder: (child, anim) => FadeTransition(
          opacity: anim,
          child: child,
        ),
        child: _isSearching
            ? TextField(
                key:        const ValueKey('search-field'),
                controller: _searchCtrl,
                autofocus:  true,
                style:      AppTextStyles.h3,
                cursorColor: AppColors.brand,
                onChanged: (v) => setState(() => _query = v),
                decoration: InputDecoration(
                  hintText:        'Coordinates, date, session ID…',
                  hintStyle:       AppTextStyles.body.copyWith(fontSize: 13),
                  border:          InputBorder.none,
                  isDense:         true,
                  contentPadding:  EdgeInsets.zero,
                ),
              )
            : Text(
                'Location History',
                key:   const ValueKey('history-title'),
                style: AppTextStyles.h2,
              ),
      ),

      // Actions
      actions: [
        if (_isSearching) ...[
          // Clear search text
          if (_query.isNotEmpty)
            IconButton(
              icon:     const Icon(Icons.clear_rounded, size: 18),
              color:    AppColors.textSecondary,
              onPressed: () {
                _searchCtrl.clear();
                setState(() => _query = '');
              },
            ),
        ] else ...[
          // Map view
          if (totalCount > 0)
            IconButton(
              icon:    const Icon(Icons.map_rounded, size: 20),
              color:   AppColors.textSecondary,
              tooltip: 'View on Map',
              onPressed: () => Navigator.push(
                context,
                PageRouteBuilder<void>(
                  pageBuilder: (_, anim, _) => const MapScreen(),
                  transitionsBuilder: (_, anim, _, child) => FadeTransition(
                    opacity: CurvedAnimation(parent: anim, curve: Curves.easeOut),
                    child:   child,
                  ),
                ),
              ),
            ),
          // Search toggle
          IconButton(
            icon:     const Icon(Icons.search_rounded, size: 20),
            color:    AppColors.textSecondary,
            onPressed: _startSearch,
            tooltip:  'Search',
          ),
          // Date filter toggle — coloured when active
          IconButton(
            icon: Icon(
              Icons.date_range_rounded,
              size:  20,
              color: _dateFilter != null
                  ? AppColors.brand
                  : AppColors.textSecondary,
            ),
            onPressed: _pickDateRange,
            tooltip:   'Filter by date',
          ),
          // Clear all (shown only if there is data)
          if (totalCount > 0)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: GestureDetector(
                onTap: () => _confirmClearAll(totalCount),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm + 4,
                    vertical:   AppSpacing.xs + 1,
                  ),
                  decoration: BoxDecoration(
                    color:        AppColors.errorGlow,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                    border: Border.all(
                      color: AppColors.error.withValues(alpha: 0.35),
                    ),
                  ),
                  child: Text(
                    'Clear',
                    style: AppTextStyles.label.copyWith(color: AppColors.error),
                  ),
                ),
              ),
            ),
        ],
      ],
    );
  }
}

// ── Summary Banner ────────────────────────────────────────────────────────────

class _SummaryBanner extends StatelessWidget {
  final int     totalCount;
  final int     totalSessions;
  final int     filteredCount;
  final int     sessionCount;
  final bool    isFiltered;
  final String? latestTime;

  const _SummaryBanner({
    required this.totalCount,
    required this.totalSessions,
    required this.filteredCount,
    required this.sessionCount,
    required this.isFiltered,
    this.latestTime,
  });

  @override
  Widget build(BuildContext context) {
    final countLabel = isFiltered
        ? '$filteredCount of $totalCount'
        : '$totalCount';
    final sessionLabel = isFiltered
        ? '$sessionCount of $totalSessions'
        : '$totalSessions';

    return GlassCard(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical:   AppSpacing.sm + 4,
      ),
      child: Row(
        children: [
          // Icon badge
          Container(
            width:  36,
            height: 36,
            decoration: BoxDecoration(
              gradient:     AppColors.brandGradient,
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            ),
            child: const Icon(Icons.pin_drop_rounded, size: 18, color: Colors.white),
          ),
          const SizedBox(width: AppSpacing.md),
          // Stats
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _Chip(label: '$countLabel pts', color: AppColors.brand),
                    const SizedBox(width: 6),
                    _Chip(label: '$sessionLabel sessions', color: AppColors.purple),
                    if (isFiltered) ...[
                      const SizedBox(width: 6),
                      _Chip(label: 'filtered', color: AppColors.accent),
                    ],
                  ],
                ),
                if (!isFiltered && latestTime != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    'Last: ${DateFormatter.timestampToShort(latestTime!)}',
                    style: AppTextStyles.bodySmall,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final Color  color;
  const _Chip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color:        color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm - 2),
        border:       Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: AppTextStyles.label.copyWith(color: color, fontSize: 9),
      ),
    );
  }
}

// ── Active Filters Row ────────────────────────────────────────────────────────

class _ActiveFiltersRow extends StatelessWidget {
  final DateTimeRange dateFilter;
  final String       dateLabel;
  final VoidCallback onClearDate;

  const _ActiveFiltersRow({
    required this.dateFilter,
    required this.dateLabel,
    required this.onClearDate,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Date range chip
        GestureDetector(
          onTap: onClearDate,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color:        AppColors.brand.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: AppColors.brand.withValues(alpha: 0.35),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.date_range_rounded,
                  size:  11,
                  color: AppColors.brand,
                ),
                const SizedBox(width: 5),
                Text(
                  dateLabel,
                  style: AppTextStyles.label.copyWith(
                    color:     AppColors.brand,
                    fontSize:  10,
                  ),
                ),
                const SizedBox(width: 6),
                const Icon(
                  Icons.close_rounded,
                  size:  11,
                  color: AppColors.brand,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ── Session Header ────────────────────────────────────────────────────────────

class _SessionHeader extends StatelessWidget {
  final _SessionGroup group;
  final int           sessionIndex;
  final bool          isExpanded;
  final VoidCallback  onToggle;
  final VoidCallback  onDelete;

  const _SessionHeader({
    required this.group,
    required this.sessionIndex,
    required this.isExpanded,
    required this.onToggle,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onToggle,
      child: GlassCard(
        gradient: LinearGradient(
          begin:  Alignment.topLeft,
          end:    Alignment.bottomRight,
          colors: [
            AppColors.brand.withValues(alpha: 0.07),
            AppColors.purple.withValues(alpha: 0.04),
          ],
        ),
        borderColor: AppColors.brand.withValues(alpha: 0.22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Title row ─────────────────────────────────────────────────
            Row(
              children: [
                // Session badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm + 2,
                    vertical:   AppSpacing.xs - 1,
                  ),
                  decoration: BoxDecoration(
                    gradient:     AppColors.brandGradient,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusSm - 2),
                  ),
                  child: Text(
                    'SESSION $sessionIndex',
                    style: AppTextStyles.label.copyWith(
                      color:     Colors.white,
                      fontSize:  9,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                // Short session ID
                Expanded(
                  child: Text(
                    group.shortId,
                    style: AppTextStyles.mono.copyWith(
                      color:    AppColors.textMuted,
                      fontSize: 11,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                // Delete button
                GestureDetector(
                  onTap: onDelete,
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: const EdgeInsets.only(left: AppSpacing.md),
                    child: Icon(
                      Icons.delete_outline_rounded,
                      size:  16,
                      color: AppColors.error.withValues(alpha: 0.75),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                // Expand / collapse chevron
                AnimatedRotation(
                  turns:    isExpanded ? 0.5 : 0.0,
                  duration: const Duration(milliseconds: 220),
                  child: const Icon(
                    Icons.expand_more_rounded,
                    size:  18,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),

            // ── Stats row ─────────────────────────────────────────────────
            Row(
              children: [
                _SessionStat(
                  icon:  Icons.location_on_rounded,
                  label: '${group.count} pts',
                  color: AppColors.brand,
                ),
                if (group.timespan != null) ...[
                  const SizedBox(width: AppSpacing.md),
                  _SessionStat(
                    icon:  Icons.timelapse_rounded,
                    label: group.timespanLabel,
                    color: AppColors.accent,
                  ),
                ],
                const Spacer(),
                // Most recent timestamp in this session
                if (group.latestTime != null)
                  Text(
                    DateFormatter.timestampToShort(group.latestTime!),
                    style: AppTextStyles.bodySmall,
                  ),
              ],
            ),

            // ── Collapsed preview ─────────────────────────────────────────
            if (!isExpanded && group.count > 0) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                '${group.count} location ${group.count == 1 ? 'point' : 'points'} — '
                'tap to expand',
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SessionStat extends StatelessWidget {
  final IconData icon;
  final String   label;
  final Color    color;
  const _SessionStat({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 11, color: color),
        const SizedBox(width: 3),
        Text(label, style: AppTextStyles.bodySmall.copyWith(color: color)),
      ],
    );
  }
}
