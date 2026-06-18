import 'package:flutter/foundation.dart';
import '../../domain/entities/location_entity.dart';
import '../../domain/entities/tracking_session.dart';
import '../../domain/repositories/location_repository.dart';
import '../../domain/usecases/start_tracking_usecase.dart';
import '../../domain/usecases/stop_tracking_usecase.dart';
import '../../domain/usecases/get_current_session_usecase.dart';
import '../../domain/usecases/save_location_usecase.dart';
import '../../domain/usecases/get_locations_usecase.dart';
import '../../domain/usecases/get_locations_by_session_usecase.dart';
import '../../domain/usecases/get_session_ids_usecase.dart';
import '../../domain/usecases/delete_session_usecase.dart';
import '../../domain/usecases/clear_all_locations_usecase.dart';

class LocationProvider extends ChangeNotifier {
  // Use cases — each owns one piece of business logic
  final StartTrackingUsecase       _startTracking;
  final StopTrackingUsecase        _stopTracking;
  final GetCurrentSessionUsecase   _getCurrentSession;
  final SaveLocationUsecase        _saveLocation;
  final GetLocationsUsecase        _getLocations;
  final GetLocationsBySessionUsecase _getLocationsBySession;
  final GetSessionIdsUsecase       _getSessionIds;
  final DeleteSessionUsecase       _deleteSession;
  final ClearAllLocationsUsecase   _clearAllLocations;

  LocationProvider({
    required LocationRepository            locationRepository,
    required StartTrackingUsecase          startTracking,
    required StopTrackingUsecase           stopTracking,
    required GetCurrentSessionUsecase      getCurrentSession,
  })  : _startTracking       = startTracking,
        _stopTracking        = stopTracking,
        _getCurrentSession   = getCurrentSession,
        _saveLocation        = SaveLocationUsecase(locationRepository),
        _getLocations        = GetLocationsUsecase(locationRepository),
        _getLocationsBySession = GetLocationsBySessionUsecase(locationRepository),
        _getSessionIds       = GetSessionIdsUsecase(locationRepository),
        _deleteSession       = DeleteSessionUsecase(locationRepository),
        _clearAllLocations   = ClearAllLocationsUsecase(locationRepository);

  // ── State ──────────────────────────────────────────────────────────────────

  TrackingSession? _currentSession;
  List<LocationEntity> _locations  = [];
  List<String>         _sessionIds = [];
  int    _locationCount = 0;
  String? _error;
  bool   _isBusy = false; // prevents double-tap races on start/stop

  // ── Getters ────────────────────────────────────────────────────────────────

  TrackingSession? get currentSession  => _currentSession;
  bool   get isTracking                => _currentSession?.isActive ?? false;
  String? get currentSessionId         => _currentSession?.id;
  List<LocationEntity> get locations   => List.unmodifiable(_locations);
  List<String>         get sessionIds  => List.unmodifiable(_sessionIds);
  int    get locationCount             => _locationCount;
  String? get error                    => _error;
  bool   get isBusy                    => _isBusy;

  // ── Tracking ───────────────────────────────────────────────────────────────

  Future<void> startTracking() async {
    if (_isBusy || isTracking) return;
    _isBusy = true;
    _error  = null;
    notifyListeners();

    try {
      _currentSession = await _startTracking();
    } catch (e) {
      _error = 'Could not start tracking: $e';
    } finally {
      _isBusy = false;
      notifyListeners();
    }
  }

  Future<void> stopTracking() async {
    if (_isBusy || !isTracking) return;
    _isBusy = true;
    _error  = null;
    notifyListeners();

    try {
      _currentSession = await _stopTracking(_currentSession);
      // Refresh data so the just-ended session appears in history
      await loadLocations();
      await loadSessionIds();
    } catch (e) {
      _error = 'Could not stop tracking: $e';
    } finally {
      _isBusy = false;
      notifyListeners();
    }
  }

  /// Called on app resume to re-attach to a service that survived a kill+reopen.
  Future<void> reattachSession() async {
    try {
      _currentSession = await _getCurrentSession();
    } catch (_) {
      // Non-fatal: if reattach fails, the user just starts a new session
    }
    notifyListeners();
  }

  // ── Data loading ───────────────────────────────────────────────────────────

  Future<void> loadLocations() async {
    try {
      _locations     = await _getLocations();
      _locationCount = _locations.length;
      _error         = null;
    } catch (e) {
      _error = 'Failed to load locations: $e';
    }
    notifyListeners();
  }

  Future<void> loadSessionIds() async {
    try {
      _sessionIds = await _getSessionIds();
      _error      = null;
    } catch (e) {
      _error = 'Failed to load sessions: $e';
    }
    notifyListeners();
  }

  Future<List<LocationEntity>> getLocationsBySession(String sessionId) async {
    try {
      return await _getLocationsBySession(sessionId);
    } catch (e) {
      _error = 'Failed to load session: $e';
      notifyListeners();
      return [];
    }
  }

  // ── Write ──────────────────────────────────────────────────────────────────

  Future<void> saveLocation(LocationEntity location) async {
    try {
      await _saveLocation(location);
    } catch (e) {
      _error = 'Failed to save location: $e';
      notifyListeners();
    }
  }

  // ── Delete ─────────────────────────────────────────────────────────────────

  Future<void> deleteSession(String sessionId) async {
    try {
      await _deleteSession(sessionId);
      await loadLocations();
      await loadSessionIds();
    } catch (e) {
      _error = 'Failed to delete session: $e';
      notifyListeners();
    }
  }

  Future<void> clearLocations() async {
    try {
      await _clearAllLocations();
      _locations     = [];
      _sessionIds    = [];
      _locationCount = 0;
      _error         = null;
    } catch (e) {
      _error = 'Failed to clear locations: $e';
    }
    notifyListeners();
  }
}
