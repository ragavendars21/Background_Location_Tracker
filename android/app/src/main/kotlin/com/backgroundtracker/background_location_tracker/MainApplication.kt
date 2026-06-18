package com.backgroundtracker.background_location_tracker

import android.app.Application
import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.os.Build
import android.util.Log

class MainApplication : Application() {

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
        resetForegroundFlag()
    }

    /**
     * Creates the foreground-service notification channel up front.
     *
     * WHY THIS IS NECESSARY:
     * ────────────────────────────────────────────────────────────────────────
     * BackgroundLocationService configures AndroidConfiguration with an explicit
     * notificationChannelId ("location_tracker_channel" — see AppConstants in
     * background_location_service.dart). flutter_background_service_android's
     * BackgroundService.onCreate() only calls its OWN createNotificationChannel()
     * when notificationChannelId is null; when we supply our own ID, the plugin
     * assumes WE already created that channel. We never did — so on Android 8+
     * (API 26+), posting a notification on a non-existent channel fails Android's
     * validation and the OS throws
     * RemoteServiceException$CannotPostForegroundServiceNotificationException:
     * "Bad notification for startForeground" — killing the process immediately
     * whenever startForeground() is actually invoked (i.e. the moment the user
     * taps Start Tracking, since is_foreground only flips to true then).
     *
     * Creating the channel here — before resetForegroundFlag() and before any
     * Service/BroadcastReceiver callback — guarantees it exists for the lifetime
     * of every process, so the very first startForeground() call succeeds.
     *
     * NOTE: id/name here must stay in sync with AppConstants.notificationChannelId
     * / notificationChannelName in lib/core/constants/app_constants.dart.
     */
    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                "location_tracker_channel",
                "Location Tracking",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Shows ongoing GPS tracking status"
            }
            getSystemService(NotificationManager::class.java)
                .createNotificationChannel(channel)
            Log.d(TAG, "Notification channel 'location_tracker_channel' ensured")
        }
    }

    /**
     * Always resets flutter_background_service's `is_foreground` flag to false
     * at the very start of every process.
     *
     * WHY THIS IS NECESSARY:
     * ────────────────────────────────────────────────────────────────────────
     * BackgroundLocationService.start() calls configure(isForegroundMode=true)
     * just before startService(), which writes is_foreground=true to
     * SharedPreferences. That flag survives process death.
     *
     * flutter_background_service's WatchdogReceiver schedules an AlarmManager
     * alarm 5 seconds after every onStartCommand. If the process is killed
     * between the is_foreground=true write and the alarm firing, the alarm
     * fires in a fresh process. Application.onCreate runs first (this method),
     * then WatchdogReceiver.onReceive reads is_foreground and calls
     * startForegroundService() if true. On Android 14+ that crashes with
     * CannotPostForegroundServiceNotificationException if POST_NOTIFICATIONS
     * is not granted OR if the notification channel is blocked.
     *
     * During debug hot-restarts the same race can occur: the Dart VM resets
     * faster than the 5-second alarm window, so the alarm fires while
     * BackgroundLocationService.initialize() is still awaiting its first
     * method-channel call. is_foreground=true is still in SharedPreferences
     * at that moment → crash.
     *
     * By always writing false here — the very first thing in the process,
     * before any BroadcastReceiver or Service callback — the watchdog always
     * uses startService() (background mode, no notification) instead of
     * startForegroundService(). Foreground mode is re-enabled explicitly by
     * BackgroundLocationService.start() only after the user has deliberately
     * initiated a tracking session and permissions are confirmed.
     */
    private fun resetForegroundFlag() {
        // "id.flutter.background_service" is the SharedPreferences name used by
        // flutter_background_service's Config.java.
        // "is_foreground" is the key read by WatchdogReceiver and BackgroundService.
        getSharedPreferences("id.flutter.background_service", Context.MODE_PRIVATE)
            .edit()
            .putBoolean("is_foreground", false)
            .apply()
        Log.d(TAG, "is_foreground reset to false — re-enabled only by BackgroundLocationService.start()")
    }

    companion object {
        private const val TAG = "MainApplication"
    }
}
