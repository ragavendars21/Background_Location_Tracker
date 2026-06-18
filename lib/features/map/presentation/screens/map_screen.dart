import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../notifiers/map_notifier.dart';
import '../state/map_state.dart';
import '../../../location/presentation/notifiers/location_notifier.dart';
import '../../../location/domain/entities/location_entity.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../core/widgets/app_empty_state.dart';

// ── Architecture overview ─────────────────────────────────────────────────────
//
//   locationProvider  ──► location data (existing)
//   mapProvider       ──► which session is selected (new, minimal)
//
//   MapScreen reads both, derives markers + polylines, and renders.
//   Zero business logic lives here — it's a pure view.
//
//   Data flow (what to say in an interview):
//     SQLite → LocationNotifier → MapScreen.build()
//       → _filterLocations() → _groupBySession()
//       → _buildMarkers()    → GoogleMap(markers: ...)
//       → _buildPolylines()  → GoogleMap(polylines: ...)

// ── Session colour palette ────────────────────────────────────────────────────
//
// Parallel arrays: index N in _kHues corresponds to index N in _kLineColors.
// Each session gets a consistent colour regardless of which sessions are visible.

const _kHues = [
  BitmapDescriptor.hueBlue,     // session 1  → matches brand colour
  BitmapDescriptor.hueGreen,    // session 2
  BitmapDescriptor.hueViolet,   // session 3
  BitmapDescriptor.hueCyan,     // session 4
  BitmapDescriptor.hueYellow,   // session 5
  BitmapDescriptor.hueOrange,   // session 6
  BitmapDescriptor.hueMagenta,  // session 7+
];

const _kLineColors = [
  Color(0xFF4F8EF7), // blue   — AppColors.brand
  Color(0xFF00E5A0), // green  — AppColors.active
  Color(0xFF7B61FF), // violet — AppColors.purple
  Color(0xFF00D4FF), // cyan   — AppColors.accent
  Color(0xFFFFE44D), // yellow
  Color(0xFFFF8C00), // orange
  Color(0xFFFF47C7), // magenta
];

// ── Dark map JSON style ───────────────────────────────────────────────────────
//
// Colours mirror the app palette: bgPrimary (#090e1a) for land,
// bgCard (#131929) for roads, textSecondary (#8892b0) for labels.

const _kMapStyle = '''[
  {"elementType":"geometry","stylers":[{"color":"#090e1a"}]},
  {"elementType":"labels.text.fill","stylers":[{"color":"#8892b0"}]},
  {"elementType":"labels.text.stroke","stylers":[{"color":"#090e1a"}]},
  {"featureType":"administrative","elementType":"geometry",
   "stylers":[{"color":"#1a2744"}]},
  {"featureType":"poi","elementType":"geometry",
   "stylers":[{"color":"#0d1624"}]},
  {"featureType":"poi.park","elementType":"geometry",
   "stylers":[{"color":"#0a1f14"}]},
  {"featureType":"road","elementType":"geometry",
   "stylers":[{"color":"#131929"}]},
  {"featureType":"road","elementType":"geometry.stroke",
   "stylers":[{"color":"#090e1a"}]},
  {"featureType":"road.highway","elementType":"geometry",
   "stylers":[{"color":"#1e2d45"}]},
  {"featureType":"road.highway","elementType":"geometry.stroke",
   "stylers":[{"color":"#0e1929"}]},
  {"featureType":"transit","elementType":"geometry",
   "stylers":[{"color":"#0d1624"}]},
  {"featureType":"water","elementType":"geometry",
   "stylers":[{"color":"#050b14"}]},
  {"featureType":"water","elementType":"labels.text.fill",
   "stylers":[{"color":"#1e3a5f"}]}
]''';

// ── Default camera (world view — shown before data loads / fit runs) ──────────

const _kDefaultCamera = CameraPosition(target: LatLng(0, 0), zoom: 2);

// ── Screen ────────────────────────────────────────────────────────────────────

class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

/// Why ConsumerStatefulWidget?
///   • We need a GoogleMapController — that's local, mutable, non-serialisable.
///   • We also need ref.watch() for provider data.
///   • ConsumerStatefulWidget gives us BOTH.
class _MapScreenState extends ConsumerState<MapScreen> {

  GoogleMapController? _controller;

  // Guards the initial auto-fit so it only runs once when the map is first ready.
  bool _initialFitDone = false;

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  // ── Camera animation ──────────────────────────────────────────────────────

  /// Animates the camera to tightly frame [points].
  ///
  /// Why LatLngBounds?
  ///   Google Maps doesn't accept a list of points for camera fitting — we must
  ///   compute the bounding box manually and pass it as LatLngBounds.
  ///   The padding (80 logical pixels) ensures markers aren't cut off at edges.
  Future<void> _fitPoints(List<LatLng> points) async {
    if (_controller == null || points.isEmpty) return;

    if (points.length == 1) {
      // A single point — just zoom to it at street level.
      await _controller!.animateCamera(
        CameraUpdate.newLatLngZoom(points.first, 15),
      );
      return;
    }

    // Scan all points to find the bounding box.
    var minLat = points.first.latitude;
    var maxLat = points.first.latitude;
    var minLng = points.first.longitude;
    var maxLng = points.first.longitude;

    for (final p in points) {
      if (p.latitude  < minLat) minLat = p.latitude;
      if (p.latitude  > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }

    // Prevent a zero-area bounds when all points are at the same location
    // (e.g., phone didn't move between fixes).
    const eps = 0.001; // ~111m at the equator
    if (maxLat - minLat < eps) { minLat -= eps; maxLat += eps; }
    if (maxLng - minLng < eps) { minLng -= eps; maxLng += eps; }

    await _controller!.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(minLat, minLng),
          northeast: LatLng(maxLat, maxLng),
        ),
        80.0, // padding in logical pixels
      ),
    );
  }

  // ── Map creation callback ─────────────────────────────────────────────────

  void _onMapCreated(GoogleMapController controller, List<LatLng> initialPoints) {
    _controller = controller;

    // Auto-fit on first load only — we don't want the camera to jump every
    // time the widget rebuilds (e.g., when battery state changes).
    if (!_initialFitDone && initialPoints.isNotEmpty) {
      _initialFitDone = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _fitPoints(initialPoints);
      });
    }
  }

  // ── Data helpers ──────────────────────────────────────────────────────────

  /// Applies the session filter from [MapState].
  List<LocationEntity> _filterLocations(
    List<LocationEntity> all,
    String?              sessionId,
  ) {
    if (sessionId == null) return all;
    return all.where((l) => l.sessionId == sessionId).toList();
  }

  /// Groups [locations] by sessionId.
  /// Map preserves insertion order — most-recent session appears first
  /// because [locations] is sorted DESC from SQLite.
  Map<String, List<LocationEntity>> _groupBySession(
    List<LocationEntity> locations,
  ) {
    final groups = <String, List<LocationEntity>>{};
    for (final loc in locations) {
      groups.putIfAbsent(loc.sessionId, () => []).add(loc);
    }
    return groups;
  }

  // ── Marker builder ────────────────────────────────────────────────────────
  //
  // Each session gets a consistent colour (from _kHues).
  // The chronologically OLDEST point (last in the DESC list) = ● Start (green).
  // The chronologically NEWEST point (first in the DESC list) = ● End   (red).
  // All other points = session colour.

  Set<Marker> _buildMarkers(
    Map<String, List<LocationEntity>> groups,
    List<String>                      sessionIds,
  ) {
    final markers = <Marker>{};

    for (final entry in groups.entries) {
      final sessionId = entry.key;
      final locs      = entry.value; // sorted DESC (most-recent first)
      final idx       = sessionIds.indexOf(sessionId);
      final hue       = _kHues[idx.clamp(0, _kHues.length - 1) % _kHues.length];

      for (var i = 0; i < locs.length; i++) {
        final loc     = locs[i];
        final isEnd   = i == 0;                    // most recent = journey end
        final isStart = i == locs.length - 1;      // oldest      = journey start

        final markerHue = isStart
            ? BitmapDescriptor.hueGreen
            : isEnd
                ? BitmapDescriptor.hueRed
                : hue;

        markers.add(Marker(
          markerId: MarkerId('${sessionId}_${loc.id ?? i}'),
          position: LatLng(loc.latitude, loc.longitude),
          icon:     BitmapDescriptor.defaultMarkerWithHue(markerHue),
          infoWindow: InfoWindow(
            title: isStart
                ? '▶  Journey Start'
                : isEnd
                    ? '⏹  Journey End'
                    : '${loc.latitude.toStringAsFixed(5)}, '
                      '${loc.longitude.toStringAsFixed(5)}',
            snippet:
                '${DateFormatter.timestampToShort(loc.timestamp)}'
                '  ·  ±${loc.accuracy.toStringAsFixed(1)} m',
          ),
        ));
      }
    }

    return markers;
  }

  // ── Polyline builder ──────────────────────────────────────────────────────
  //
  // One Polyline per session, reversed so the line runs oldest → newest.
  // A session with only one point has no line (needs ≥ 2 points for a path).

  Set<Polyline> _buildPolylines(
    Map<String, List<LocationEntity>> groups,
    List<String>                      sessionIds,
  ) {
    final polylines = <Polyline>{};

    for (final entry in groups.entries) {
      final sessionId = entry.key;
      final locs      = entry.value;
      if (locs.length < 2) continue; // can't draw a path from a single point

      final idx   = sessionIds.indexOf(sessionId);
      final color = _kLineColors[idx.clamp(0, _kLineColors.length - 1) % _kLineColors.length];

      polylines.add(Polyline(
        polylineId: PolylineId(sessionId),
        // Reverse DESC list → chronological order (oldest first) for correct direction
        points: locs.reversed.map((l) => LatLng(l.latitude, l.longitude)).toList(),
        color:     color,
        width:     4,
        startCap:  Cap.roundCap,
        endCap:    Cap.roundCap,
        jointType: JointType.round,
      ));
    }

    return polylines;
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final loc      = ref.watch(locationProvider);
    final mapState = ref.watch(mapProvider);

    // ── Derive all display data (pure transformation) ──────────────────────
    final filtered  = _filterLocations(loc.locations, mapState.selectedSessionId);
    final groups    = _groupBySession(filtered);
    final markers   = _buildMarkers(groups, loc.sessionIds);
    final polylines = _buildPolylines(groups, loc.sessionIds);
    final points    = filtered.map((l) => LatLng(l.latitude, l.longitude)).toList();

    // ── React to session selection changes ─────────────────────────────────
    // ref.listen() fires AFTER the provider updates — correct for side effects.
    ref.listen<MapState>(mapProvider, (prev, next) {
      if (prev?.selectedSessionId == next.selectedSessionId) return;
      // Read fresh locations so the camera fits the current data.
      final fresh = _filterLocations(
        ref.read(locationProvider).locations,
        next.selectedSessionId,
      );
      final newPoints = fresh.map((l) => LatLng(l.latitude, l.longitude)).toList();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _fitPoints(newPoints);
      });
    });

    return Scaffold(
      backgroundColor: const Color(0xFF050b14), // matches water colour in map style
      body: loc.locations.isEmpty
          // ── Empty state (no data to show on the map) ─────────────────────
          ? _buildEmptyState()
          // ── Map view ──────────────────────────────────────────────────────
          : Stack(
              fit: StackFit.expand,
              children: [
                // ── 1. Google Map ──────────────────────────────────────────
                GoogleMap(
                  initialCameraPosition: _kDefaultCamera,
                  style: _kMapStyle,

                  // Data
                  markers:   markers,
                  polylines: polylines,

                  // Current location blue dot — only when GPS is live
                  myLocationEnabled:       loc.isTracking,
                  myLocationButtonEnabled: false, // we provide our own recenter

                  // UI controls
                  zoomControlsEnabled: false,
                  compassEnabled:      true,
                  mapToolbarEnabled:   false, // hides "open in Maps" chip
                  buildingsEnabled:    true,

                  onMapCreated: (c) => _onMapCreated(c, points),
                ),

                // ── 2. Top overlay: back + title + recenter ────────────────
                Positioned(
                  top: 0, left: 0, right: 0,
                  child: _MapOverlayHeader(
                    filteredCount:  points.length,
                    sessionCount:   groups.length,
                    isFiltered:     mapState.selectedSessionId != null,
                    isTracking:     loc.isTracking,
                    onBack:         () => Navigator.pop(context),
                    onRecenter:     () => _fitPoints(points),
                  ),
                ),

                // ── 3. Bottom overlay: session selector ────────────────────
                Positioned(
                  bottom: 0, left: 0, right: 0,
                  child: _SessionSelectorBar(
                    sessionIds:        loc.sessionIds,
                    groups:            groups,
                    selectedSessionId: mapState.selectedSessionId,
                    onSelect: (id) =>
                        ref.read(mapProvider.notifier).selectSession(id),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildEmptyState() => GradientSafeArea(
        child: AppEmptyState(
          icon:     Icons.map_outlined,
          title:    'No Locations to Map',
          subtitle: 'Start tracking on the home screen to\n'
                    'record GPS coordinates and view them here.',
          action: TextButton.icon(
            onPressed: () => Navigator.pop(context),
            icon:  const Icon(Icons.arrow_back_rounded, size: 16),
            label: const Text('Go Back'),
            style: TextButton.styleFrom(foregroundColor: AppColors.brand),
          ),
        ),
      );
}

// ── Thin gradient safe-area wrapper for the empty state ───────────────────────

class GradientSafeArea extends StatelessWidget {
  final Widget child;
  const GradientSafeArea({super.key, required this.child});

  @override
  Widget build(BuildContext context) => Container(
        decoration: const BoxDecoration(gradient: AppColors.bgGradient),
        child: SafeArea(child: child),
      );
}

// ── 2. Top Overlay Header ─────────────────────────────────────────────────────

class _MapOverlayHeader extends StatelessWidget {
  final int          filteredCount;
  final int          sessionCount;
  final bool         isFiltered;
  final bool         isTracking;
  final VoidCallback onBack;
  final VoidCallback onRecenter;

  const _MapOverlayHeader({
    required this.filteredCount,
    required this.sessionCount,
    required this.isFiltered,
    required this.isTracking,
    required this.onBack,
    required this.onRecenter,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md, AppSpacing.sm, AppSpacing.md, 0,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical:   AppSpacing.sm + 4,
              ),
              decoration: BoxDecoration(
                color:        AppColors.bgPrimary.withValues(alpha: 0.82),
                borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
                border:       Border.all(color: AppColors.glassBorder),
              ),
              child: Row(
                children: [
                  // Back button
                  _CircleIconButton(
                    icon:    Icons.arrow_back_ios_new_rounded,
                    onTap:   onBack,
                    size:    13,
                  ),
                  const SizedBox(width: AppSpacing.md - 4),

                  // Title + subtitle
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Text('Route Map', style: AppTextStyles.h2),
                            if (isTracking) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.active.withValues(alpha: 0.18),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(
                                    color: AppColors.active.withValues(alpha: 0.4),
                                  ),
                                ),
                                child: Text(
                                  'LIVE',
                                  style: AppTextStyles.label.copyWith(
                                    color: AppColors.active, fontSize: 8,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        Text(
                          isFiltered
                              ? '$filteredCount pts · 1 session'
                              : '$filteredCount pts · $sessionCount sessions',
                          style: AppTextStyles.bodySmall,
                        ),
                      ],
                    ),
                  ),

                  // Recenter button
                  _CircleIconButton(
                    icon:     Icons.my_location_rounded,
                    onTap:    onRecenter,
                    iconColor: AppColors.brand,
                    bgColor:   AppColors.brand.withValues(alpha: 0.15),
                    border:    AppColors.brand.withValues(alpha: 0.4),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final double size;
  final Color  iconColor;
  final Color  bgColor;
  final Color  border;

  const _CircleIconButton({
    required this.icon,
    required this.onTap,
    this.size      = 15,
    this.iconColor = AppColors.textPrimary,
    this.bgColor   = AppColors.glassWhite,
    this.border    = AppColors.glassBorder,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          width:  36,
          height: 36,
          decoration: BoxDecoration(
            color:  bgColor,
            shape:  BoxShape.circle,
            border: Border.all(color: border),
          ),
          child: Icon(icon, size: size, color: iconColor),
        ),
      );
}

// ── 3. Session Selector Bar ───────────────────────────────────────────────────
//
// Horizontal scroll strip at the bottom.
// Shows "ALL" chip + one chip per session that has visible locations.

class _SessionSelectorBar extends StatelessWidget {
  final List<String>                      sessionIds;
  final Map<String, List<LocationEntity>> groups;
  final String?                           selectedSessionId;
  final void Function(String?)            onSelect;

  const _SessionSelectorBar({
    required this.sessionIds,
    required this.groups,
    required this.selectedSessionId,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    // Only show sessions that have data (important when a filter is active)
    final visible = sessionIds
        .where((id) => groups.containsKey(id))
        .toList();

    if (visible.isEmpty) return const SizedBox.shrink();

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.md),
        child: SizedBox(
          height: 60,
          child: ListView.separated(
            scrollDirection:    Axis.horizontal,
            padding:            const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            itemCount:          visible.length + 1, // +1 for the "ALL" chip
            separatorBuilder:   (_, _) => const SizedBox(width: AppSpacing.sm),
            itemBuilder: (ctx, i) {
              if (i == 0) {
                // "ALL" chip
                final totalCount = groups.values.fold<int>(
                  0, (sum, locs) => sum + locs.length,
                );
                return _SessionChip(
                  label:      'All',
                  count:      totalCount,
                  isSelected: selectedSessionId == null,
                  color:      AppColors.brand,
                  onTap:      () => onSelect(null),
                );
              }

              final sessionId = visible[i - 1];
              final count     = groups[sessionId]?.length ?? 0;
              final colorIdx  = sessionIds.indexOf(sessionId);
              final color     = _kLineColors[colorIdx.clamp(0, _kLineColors.length - 1) % _kLineColors.length];

              return _SessionChip(
                label:      'Session $i',
                count:      count,
                isSelected: selectedSessionId == sessionId,
                color:      color,
                onTap:      () => onSelect(sessionId),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _SessionChip extends StatelessWidget {
  final String       label;
  final int          count;
  final bool         isSelected;
  final Color        color;
  final VoidCallback onTap;

  const _SessionChip({
    required this.label,
    required this.count,
    required this.isSelected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve:    Curves.easeOut,
        padding:  const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          // Selected: solid colour fill. Unselected: dark glass.
          color: isSelected
              ? color
              : AppColors.bgCard.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
            color: isSelected ? color : color.withValues(alpha: 0.45),
            width: 1.5,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color:      color.withValues(alpha: 0.35),
                    blurRadius: 12,
                    offset:     const Offset(0, 4),
                  )
                ]
              : [],
        ),
        child: Column(
          mainAxisSize:        MainAxisSize.min,
          crossAxisAlignment:  CrossAxisAlignment.center,
          children: [
            Text(
              label,
              style: AppTextStyles.label.copyWith(
                color: isSelected ? Colors.white : AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '$count pts',
              style: AppTextStyles.bodySmall.copyWith(
                color:    isSelected
                    ? Colors.white.withValues(alpha: 0.75)
                    : AppColors.textMuted,
                fontSize: 9,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
