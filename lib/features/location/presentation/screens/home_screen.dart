import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import '../notifiers/location_notifier.dart';
import '../../../battery/presentation/notifiers/battery_notifier.dart';
import '../../domain/entities/location_entity.dart';
import '../../domain/entities/tracking_session.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/widgets/gradient_background.dart';
import '../../../../core/widgets/pulse_dot.dart';
import '../../../../services/location_permission_service.dart';
import '../widgets/location_tile.dart';
import 'location_list_screen.dart';
import '../../../../features/map/presentation/screens/map_screen.dart';

// ── Screen ────────────────────────────────────────────────────────────────────

/// ConsumerStatefulWidget = StatefulWidget + Riverpod ref.
/// Use when the widget needs both local animation state AND provider data.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

/// ConsumerState gives us:
///   ref  — the full Riverpod provider graph (read, watch, listen)
///   this — regular StatefulWidget state (AnimationController, Timer)
class _HomeScreenState extends ConsumerState<HomeScreen>
    with SingleTickerProviderStateMixin {

  // Single controller drives all staggered card entrances via Interval curves.
  // One controller is cheaper than N controllers and easy to explain in interviews.
  late final AnimationController _entryCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1000),
  );

  // ── Session timer (ValueNotifier pattern) ─────────────────────────────────
  //
  // WHY VALUENOTIFIER INSTEAD OF SETSTATE (performance optimization):
  // ─────────────────────────────────────────────────────────────────
  // The previous implementation called `setState(() => _sessionSeconds++)` every
  // second. setState() marks the ENTIRE HomeScreen element as dirty, so Flutter
  // rebuilds the full widget tree — all 9 cards, the stagger animation wrappers,
  // the recent locations list — just to update two digits on a timer display.
  //
  // With ValueNotifier + ValueListenableBuilder:
  //   • _sessionTick.value++ does NOT trigger a setState on HomeScreen.
  //   • Only the ValueListenableBuilder widgets that subscribe to _sessionTick
  //     rebuild — and those widgets contain only the timer Text node.
  //
  // Result: 58 fewer widget rebuilds per minute during an active session.
  final ValueNotifier<int> _sessionTick = ValueNotifier<int>(0);
  Timer? _sessionTimer;

  // Polls SQLite while a session is active so the points counter and recent-
  // locations list visibly update as the background isolate records new
  // fixes. Without this, loadLocations() only re-runs on init, stop(), or a
  // manual pull-to-refresh — the background service can be inserting rows
  // every 60 s while the dashboard keeps showing stale data until the user
  // stops tracking, which looks exactly like "recording isn't happening".
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _entryCtrl.forward();
  }

  @override
  void dispose() {
    _sessionTimer?.cancel();
    _refreshTimer?.cancel();
    _sessionTick.dispose();  // always dispose ValueNotifier to release listeners
    _entryCtrl.dispose();
    super.dispose();
  }

  // ── Session timer ─────────────────────────────────────────────────────────

  void _startSessionTimer() {
    _sessionTick.value = 0;
    _sessionTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _sessionTick.value++; // no setState — only subscribed ValueListenableBuilders rebuild
    });

    // 15 s is frequent enough to catch each 60 s GPS capture promptly (plus
    // the immediate first capture on start) without hammering SQLite.
    _refreshTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      ref.read(locationProvider.notifier).loadLocations();
    });
  }

  void _stopSessionTimer() {
    _sessionTimer?.cancel();
    _sessionTimer = null;
    _sessionTick.value = 0;
    _refreshTimer?.cancel();
    _refreshTimer = null;
  }

  // ── Actions ───────────────────────────────────────────────────────────────

  Future<void> _onStart() async {
    final result = await LocationPermissionService.requestAll();
    if (!mounted) return;

    switch (result) {
      case PermissionResult.granted:
        break;
      case PermissionResult.denied:
        _showErrorSnackBar('Location permission denied. Tap START again to retry.');
        return;
      case PermissionResult.deniedForever:
        _showPermissionSettingsDialog();
        return;
      case PermissionResult.gpsDisabled:
        _showGpsDialog();
        return;
    }

    await ref.read(locationProvider.notifier).startTracking();
    if (!mounted) return;

    final loc = ref.read(locationProvider);
    if (loc.isTracking) {
      _startSessionTimer();
    } else if (loc.error != null) {
      _showErrorSnackBar(loc.error!);
    }
  }

  Future<void> _onStop() async {
    _stopSessionTimer();
    await ref.read(locationProvider.notifier).stopTracking();
  }

  void _navigateToHistory() {
    Navigator.push(
      context,
      PageRouteBuilder<void>(
        pageBuilder: (_, anim, secondary) => const LocationHistoryScreen(),
        transitionsBuilder: (_, anim, secondary, child) => SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(1, 0),
            end:   Offset.zero,
          ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOut)),
          child: child,
        ),
      ),
    );
  }

  void _navigateToMap() {
    Navigator.push(
      context,
      PageRouteBuilder<void>(
        pageBuilder: (_, anim, secondary) => const MapScreen(),
        transitionsBuilder: (_, anim, secondary, child) => FadeTransition(
          opacity: CurvedAnimation(parent: anim, curve: Curves.easeOut),
          child:   child,
        ),
      ),
    );
  }

  // ── Dialog / snackbar helpers ─────────────────────────────────────────────

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content:         Text(message),
      behavior:        SnackBarBehavior.floating,
      backgroundColor: AppColors.error,
    ));
  }

  void _showPermissionSettingsDialog() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bgCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        ),
        title:   Text('Permission Required', style: AppTextStyles.h2),
        content: Text(
          'Background location is permanently denied.\n\n'
          'Go to Settings → Location → "Allow all the time".',
          style: AppTextStyles.body,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('CANCEL', style: AppTextStyles.label),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              LocationPermissionService.openSettings();
            },
            child: Text(
              'OPEN SETTINGS',
              style: AppTextStyles.label.copyWith(color: AppColors.brand),
            ),
          ),
        ],
      ),
    );
  }

  void _showGpsDialog() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bgCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        ),
        title:   Text('GPS Disabled', style: AppTextStyles.h2),
        content: Text(
          'Enable location services on your device to start tracking.',
          style: AppTextStyles.body,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('CANCEL', style: AppTextStyles.label),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await Geolocator.openLocationSettings();
            },
            child: Text(
              'ENABLE GPS',
              style: AppTextStyles.label.copyWith(color: AppColors.brand),
            ),
          ),
        ],
      ),
    );
  }

  // ── Stagger helper ────────────────────────────────────────────────────────

  /// Wraps [child] in a fade + upward slide keyed to [start] (0.0–1.0).
  ///
  /// How it works:
  ///   _entryCtrl runs 0→1 over 1 second.
  ///   Interval(start, start+0.5) maps the parent t to 0→1 ONLY within that
  ///   window — cards entered at different [start] values appear sequentially.
  ///   Using AnimatedBuilder's `child:` parameter caches the subtree so it
  ///   is built once and reused across every animation frame — zero extra builds.
  Widget _stagger({required Widget child, required double start}) {
    return AnimatedBuilder(
      animation: _entryCtrl,
      child: child,
      builder: (ctx, cached) {
        final t = Interval(
          start,
          (start + 0.5).clamp(0.0, 1.0),
          curve: Curves.easeOutCubic,
        ).transform(_entryCtrl.value);

        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, 16.0 * (1.0 - t)),
            child: cached,
          ),
        );
      },
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    // ref.watch() keeps this widget subscribed to state changes.
    // Any LocationState or BatteryState update triggers a rebuild automatically.
    final loc = ref.watch(locationProvider);
    final bat = ref.watch(batteryProvider);

    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      extendBodyBehindAppBar: true,
      appBar: _buildAppBar(),
      // Map FAB — appears only when there is data to visualise
      floatingActionButton: loc.locations.isNotEmpty
          ? FloatingActionButton.small(
              onPressed:       _navigateToMap,
              backgroundColor: AppColors.brand,
              tooltip:         'View on Map',
              child:           const Icon(Icons.map_rounded, color: Colors.white, size: 20),
            )
          : null,
      body: GradientBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.screenH,
              vertical:   AppSpacing.screenV,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── 1. App Header ───────────────────────────────────────────
                _stagger(child: _buildPageHeader(), start: 0.0),
                const SizedBox(height: AppSpacing.lg),

                // ── 2. Tracking Status Card ─────────────────────────────────
                _stagger(
                  child: _TrackingStatusCard(
                    isTracking:    loc.isTracking,
                    sessionTick:   _sessionTick,
                    locationCount: loc.locationCount,
                  ),
                  start: 0.05,
                ),
                const SizedBox(height: AppSpacing.sm + 4),

                // ── 3. Battery Card  +  7. Location Counter ─────────────────
                _stagger(
                  child: Row(
                    children: [
                      Expanded(
                        child: _BatteryCard(
                          level:      bat.level,
                          isCharging: bat.isCharging,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm + 2),
                      Expanded(
                        child: _PointsCard(count: loc.locationCount),
                      ),
                    ],
                  ),
                  start: 0.15,
                ),

                // ── 6. Active Session Information ───────────────────────────
                if (loc.isTracking && loc.currentSession != null) ...[
                  const SizedBox(height: AppSpacing.sm + 4),
                  _stagger(
                    child: _ActiveSessionCard(
                      session:     loc.currentSession!,
                      sessionTick: _sessionTick,
                    ),
                    start: 0.22,
                  ),
                ],

                // ── 8. Last Recorded Location ───────────────────────────────
                if (loc.locations.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.sm + 4),
                  _stagger(
                    child: _LastLocationCard(location: loc.locations.first),
                    start: 0.28,
                  ),
                ],

                // ── 4 & 5. Start / Stop Buttons ────────────────────────────
                const SizedBox(height: AppSpacing.xl),
                _stagger(
                  child: _CTASection(
                    isTracking: loc.isTracking,
                    isBusy:     loc.isBusy,
                    onStart:    _onStart,
                    onStop:     _onStop,
                  ),
                  start: 0.35,
                ),

                // ── 9. Recent Locations List ────────────────────────────────
                if (loc.locations.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.xl),
                  _stagger(
                    child: _RecentLocationsSection(
                      locations: loc.locations,
                      onViewAll: _navigateToHistory,
                    ),
                    start: 0.45,
                  ),
                ],

                // Error banner
                if (loc.error != null) ...[
                  const SizedBox(height: AppSpacing.md),
                  _stagger(
                    child: _ErrorBanner(message: loc.error!),
                    start: 0.5,
                  ),
                ],

                const SizedBox(height: AppSpacing.xl),
              ],
            ),
          ),
        ),
      ),
    );
  }

  AppBar _buildAppBar() => AppBar(
        backgroundColor: Colors.transparent,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 7,
              height: 7,
              decoration: const BoxDecoration(
                shape:    BoxShape.circle,
                gradient: AppColors.startGradient,
              ),
            ),
            const SizedBox(width: 7),
            Text('Location Tracker', style: AppTextStyles.h2),
          ],
        ),
      );

  Widget _buildPageHeader() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Dashboard', style: AppTextStyles.display),
          const SizedBox(height: 4),
          Text('GPS tracking · Battery monitoring', style: AppTextStyles.body),
        ],
      );
}

// ── 2. Tracking Status Card ───────────────────────────────────────────────────

class _TrackingStatusCard extends StatelessWidget {
  final bool                 isTracking;
  final ValueListenable<int> sessionTick;
  final int                  locationCount;

  const _TrackingStatusCard({
    required this.isTracking,
    required this.sessionTick,
    required this.locationCount,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      gradient: isTracking
          ? LinearGradient(
              begin:  Alignment.topLeft,
              end:    Alignment.bottomRight,
              colors: [
                AppColors.active.withValues(alpha: 0.10),
                AppColors.accent.withValues(alpha: 0.04),
              ],
            )
          : null,
      borderColor:
          isTracking ? AppColors.active.withValues(alpha: 0.35) : null,
      child: Column(
        children: [
          Row(
            children: [
              PulseDot(isActive: isTracking, size: 9),
              const SizedBox(width: AppSpacing.sm),
              Text(
                isTracking ? 'TRACKING ACTIVE' : 'TRACKING INACTIVE',
                style: AppTextStyles.label.copyWith(
                  color: isTracking ? AppColors.active : AppColors.textMuted,
                ),
              ),
              const Spacer(),
              _LiveBadge(isTracking: isTracking),
            ],
          ),
          const SizedBox(height: AppSpacing.lg + 2),
          IntrinsicHeight(
            child: Row(
              children: [
                // ValueListenableBuilder rebuilds ONLY this column every second.
                // The two columns beside it (POINTS, INTERVAL) are untouched.
                ValueListenableBuilder<int>(
                  valueListenable: sessionTick,
                  builder: (_, ticks, _) {
                    final m     = ticks ~/ 60;
                    final s     = ticks  % 60;
                    final label = isTracking
                        ? '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}'
                        : '--:--';
                    return _StatCol(
                      icon:      Icons.timer_outlined,
                      iconColor: AppColors.accent,
                      value:     label,
                      label:     'SESSION',
                    );
                  },
                ),
                _VertDivider(),
                _StatCol(
                  icon:      Icons.location_on_outlined,
                  iconColor: AppColors.brand,
                  value:     '$locationCount',
                  label:     'POINTS',
                ),
                _VertDivider(),
                _StatCol(
                  icon:      Icons.access_time_rounded,
                  iconColor: AppColors.purple,
                  value:     '60s',
                  label:     'INTERVAL',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LiveBadge extends StatelessWidget {
  final bool isTracking;
  const _LiveBadge({required this.isTracking});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: isTracking
            ? AppColors.active.withValues(alpha: 0.15)
            : AppColors.glassWhite,
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm - 2),
        border: Border.all(
          color: isTracking
              ? AppColors.active.withValues(alpha: 0.4)
              : AppColors.glassBorder,
        ),
      ),
      child: Text(
        isTracking ? 'LIVE' : 'OFF',
        style: AppTextStyles.label.copyWith(
          color:         isTracking ? AppColors.active : AppColors.textMuted,
          fontSize:      9,
          letterSpacing: 1.8,
        ),
      ),
    );
  }
}

class _StatCol extends StatelessWidget {
  final IconData icon;
  final Color    iconColor;
  final String   value;
  final String   label;

  const _StatCol({
    required this.icon,
    required this.iconColor,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, size: 18, color: iconColor),
          const SizedBox(height: 6),
          Text(
            value,
            style: AppTextStyles.h2.copyWith(
              fontWeight: FontWeight.w700,
              fontSize:   18,
            ),
          ),
          const SizedBox(height: 2),
          Text(label, style: AppTextStyles.label),
        ],
      ),
    );
  }
}

class _VertDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
        width:  1,
        color:  AppColors.glassBorder,
        margin: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      );
}

// ── 3. Battery Card ───────────────────────────────────────────────────────────

class _BatteryCard extends StatelessWidget {
  final int?  level;
  final bool  isCharging;

  const _BatteryCard({this.level, this.isCharging = false});

  Color get _color {
    if (level == null) return AppColors.textMuted;
    if (isCharging)    return AppColors.accent;
    if (level! >= 50)  return AppColors.active;
    if (level! >= 20)  return AppColors.warning;
    return AppColors.error;
  }

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isCharging
                    ? Icons.battery_charging_full_rounded
                    : Icons.bolt_rounded,
                size:  12,
                color: _color,
              ),
              const SizedBox(width: 4),
              Text(isCharging ? 'CHARGING' : 'BATTERY', style: AppTextStyles.label),
            ],
          ),
          const SizedBox(height: AppSpacing.sm + 2),
          Text(
            level != null ? '$level%' : '--',
            style: AppTextStyles.display.copyWith(
              fontSize:   28,
              color:      _color,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value:           level != null ? level! / 100.0 : 0,
              backgroundColor: AppColors.glassWhite,
              valueColor:      AlwaysStoppedAnimation<Color>(_color),
              minHeight:       4,
            ),
          ),
        ],
      ),
    );
  }
}

// ── 7. Points Card ────────────────────────────────────────────────────────────

class _PointsCard extends StatelessWidget {
  final int count;
  const _PointsCard({required this.count});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ShaderMask(
                shaderCallback: (b) => AppColors.brandGradient.createShader(b),
                child: const Icon(Icons.location_on_rounded, size: 12, color: Colors.white),
              ),
              const SizedBox(width: 4),
              Text('RECORDED', style: AppTextStyles.label),
            ],
          ),
          const SizedBox(height: AppSpacing.sm + 2),
          ShaderMask(
            shaderCallback: (b) => AppColors.brandGradient.createShader(b),
            child: Text(
              '$count',
              style: AppTextStyles.display.copyWith(
                fontSize:   28,
                color:      Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            count == 1 ? 'GPS point' : 'GPS points',
            style: AppTextStyles.bodySmall,
          ),
        ],
      ),
    );
  }
}

// ── 6. Active Session Card ────────────────────────────────────────────────────

/// Shown only while tracking is active — displays session identity and elapsed time.
class _ActiveSessionCard extends StatelessWidget {
  final TrackingSession      session;
  final ValueListenable<int> sessionTick;

  const _ActiveSessionCard({
    required this.session,
    required this.sessionTick,
  });

  @override
  Widget build(BuildContext context) {
    // Show first 8 chars of UUID in uppercase for a clean terminal-style look.
    final shortId = '${session.id.substring(0, 8).toUpperCase()}···';
    final startedAt = DateFormatter.timestampToShort(
      session.startedAt.toIso8601String(),
    );

    return GlassCard(
      borderColor: AppColors.active.withValues(alpha: 0.28),
      gradient: LinearGradient(
        begin:  Alignment.topLeft,
        end:    Alignment.bottomRight,
        colors: [
          AppColors.active.withValues(alpha: 0.06),
          AppColors.accent.withValues(alpha: 0.02),
        ],
      ),
      child: Column(
        children: [
          // ── Header ───────────────────────────────────────────────────────
          Row(
            children: [
              Container(
                width: 6, height: 6,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.active,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                'ACTIVE SESSION',
                style: AppTextStyles.label.copyWith(color: AppColors.active),
              ),
              const Spacer(),
              // Only this Text rebuilds every second — not the whole card.
              ValueListenableBuilder<int>(
                valueListenable: sessionTick,
                builder: (_, ticks, _) {
                  final m = ticks ~/ 60;
                  final s = ticks  % 60;
                  return Text(
                    '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}',
                    style: AppTextStyles.mono.copyWith(
                      color:    AppColors.accent,
                      fontSize: 12,
                    ),
                  );
                },
              ),
            ],
          ),
          const Divider(color: AppColors.glassBorder, height: 20),

          // ── Session ID row ────────────────────────────────────────────────
          _InfoRow(label: 'SESSION ID', value: shortId),
          const SizedBox(height: 6),

          // ── Start time row ────────────────────────────────────────────────
          _InfoRow(label: 'STARTED', value: startedAt),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(label, style: AppTextStyles.label),
        const Spacer(),
        Text(
          value,
          style: AppTextStyles.mono.copyWith(
            color:    AppColors.textPrimary,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}

// ── 8. Last Recorded Location ─────────────────────────────────────────────────

class _LastLocationCard extends StatelessWidget {
  final LocationEntity location;
  const _LastLocationCard({required this.location});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical:   AppSpacing.md - 2,
      ),
      child: Row(
        children: [
          Container(
            width:  40,
            height: 40,
            decoration: BoxDecoration(
              gradient:     AppColors.brandGradient,
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            ),
            child: const Icon(Icons.my_location_rounded, size: 18, color: Colors.white),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('LAST RECORDED', style: AppTextStyles.label),
                const SizedBox(height: 3),
                Text(
                  '${location.latitude.toStringAsFixed(6)}°N  '
                  '${location.longitude.toStringAsFixed(6)}°E',
                  style: AppTextStyles.mono.copyWith(color: AppColors.textPrimary),
                ),
                Text(
                  'Accuracy ±${location.accuracy.toStringAsFixed(1)} m  ·  '
                  '${DateFormatter.timestampToShort(location.timestamp)}',
                  style: AppTextStyles.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── 4 & 5. CTA Buttons (Start + Stop) ────────────────────────────────────────

/// Two separate full-width buttons.
///
/// Why two buttons instead of one toggle?
///   • Users can see both options at once — no mental model required.
///   • Disabled state makes it immediately obvious which action is available.
///   • Easier to explain in interviews: each button has a single responsibility.
class _CTASection extends StatelessWidget {
  final bool         isTracking;
  final bool         isBusy;
  final VoidCallback onStart;
  final VoidCallback onStop;

  const _CTASection({
    required this.isTracking,
    required this.isBusy,
    required this.onStart,
    required this.onStop,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 4. START TRACKING
        _TrackingButton(
          label:     'START TRACKING',
          icon:      Icons.play_arrow_rounded,
          gradient:  AppColors.startGradient,
          glowColor: AppColors.active,
          enabled:   !isTracking && !isBusy,
          loading:   isBusy && !isTracking,
          onTap:     onStart,
        ),
        const SizedBox(height: 10),
        // 5. STOP TRACKING
        _TrackingButton(
          label:     'STOP TRACKING',
          icon:      Icons.stop_rounded,
          gradient:  AppColors.stopGradient,
          glowColor: AppColors.error,
          enabled:   isTracking && !isBusy,
          loading:   isBusy && isTracking,
          onTap:     onStop,
        ),
      ],
    );
  }
}

class _TrackingButton extends StatelessWidget {
  final String     label;
  final IconData   icon;
  final Gradient   gradient;
  final Color      glowColor;
  final bool       enabled;
  final bool       loading;
  final VoidCallback onTap;

  const _TrackingButton({
    required this.label,
    required this.icon,
    required this.gradient,
    required this.glowColor,
    required this.enabled,
    required this.loading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // AnimatedOpacity dims the button (including its glow shadow) when disabled.
    // The transition is smooth (300ms) so the state change feels intentional.
    return AnimatedOpacity(
      opacity:  enabled ? 1.0 : 0.28,
      duration: const Duration(milliseconds: 300),
      child: GestureDetector(
        onTap: enabled ? onTap : null,
        child: Container(
          width:  double.infinity,
          height: 60,
          decoration: BoxDecoration(
            gradient:     gradient,
            borderRadius: BorderRadius.circular(AppSpacing.radiusXxl),
            boxShadow: [
              BoxShadow(
                color:      glowColor.withValues(alpha: 0.32),
                blurRadius: 20,
                offset:     const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Swap icon for a spinner when this specific button triggered the load
              if (loading)
                const SizedBox(
                  width:  20,
                  height: 20,
                  child:  CircularProgressIndicator(
                    strokeWidth: 2,
                    color:       Colors.white,
                  ),
                )
              else
                Icon(icon, color: Colors.white, size: 22),
              const SizedBox(width: 10),
              Text(label, style: AppTextStyles.button),
            ],
          ),
        ),
      ),
    );
  }
}

// ── 9. Recent Locations List ──────────────────────────────────────────────────

/// Inline preview of the 5 most recent GPS points.
/// "View All →" navigates to the full LocationHistoryScreen.
class _RecentLocationsSection extends StatelessWidget {
  final List<LocationEntity> locations;
  final VoidCallback         onViewAll;

  const _RecentLocationsSection({
    required this.locations,
    required this.onViewAll,
  });

  @override
  Widget build(BuildContext context) {
    final recent = locations.take(5).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Section header ────────────────────────────────────────────────
        Row(
          children: [
            Text('Recent Locations', style: AppTextStyles.h2),
            const Spacer(),
            GestureDetector(
              onTap: onViewAll,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'View All',
                    style: AppTextStyles.body.copyWith(color: AppColors.brand),
                  ),
                  const Icon(
                    Icons.chevron_right_rounded,
                    size:  15,
                    color: AppColors.brand,
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),

        // ── Location tiles (last 5) ───────────────────────────────────────
        // LocationTile adds its own bottom padding (AppSpacing.sm + 4),
        // so no additional spacing is needed between tiles.
        ...recent.asMap().entries.map(
          (entry) => LocationTile(
            key:      ValueKey(entry.value.id ?? entry.key),
            location: entry.value,
            index:    entry.key + 1,
          ),
        ),
      ],
    );
  }
}

// ── Error Banner ──────────────────────────────────────────────────────────────

class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      borderColor: AppColors.error.withValues(alpha: 0.4),
      gradient: LinearGradient(
        colors: [
          AppColors.errorGlow,
          Colors.transparent,
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 18),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              message,
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
  }
}
