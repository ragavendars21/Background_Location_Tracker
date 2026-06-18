package com.backgroundtracker.background_location_tracker

import android.content.Context
import android.os.BatteryManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * How Platform Channels work (recruiter-ready explanation):
 * ──────────────────────────────────────────────────────────
 * Flutter and native code live in separate worlds — Dart on one side,
 * Kotlin/Swift on the other. A MethodChannel is the named pipe connecting them.
 *
 * Flutter calls:   channel.invokeMethod("getBatteryLevel")
 * Android hears it via setMethodCallHandler and runs Kotlin code.
 * Android replies: result.success(mapOf("level" to 78, "isCharging" to true))
 * Flutter receives the Map and shows the number.
 *
 * Three rules:
 *   1. Channel name must match exactly on both sides.
 *   2. Only primitive types (Int, Double, Boolean, String, List, Map) cross the boundary.
 *   3. Always call exactly ONE of result.success / result.error / result.notImplemented.
 */
class MainActivity : FlutterActivity() {

    // This string must match AppConstants.batteryChannelName in Dart exactly —
    // one character off and the channel silently fails.
    private val batteryChannel = "com.backgroundtracker.app/battery"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, batteryChannel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getBatteryLevel" -> handleGetBatteryLevel(result)
                    else              -> result.notImplemented()
                }
            }
    }

    // ── Handler ───────────────────────────────────────────────────────────────

    private fun handleGetBatteryLevel(result: MethodChannel.Result) {
        val manager = getSystemService(Context.BATTERY_SERVICE) as BatteryManager

        // BATTERY_PROPERTY_CAPACITY returns 0–100 on real devices.
        // Returns Int.MIN_VALUE when the property is unsupported (some emulators).
        val level = manager.getIntProperty(BatteryManager.BATTERY_PROPERTY_CAPACITY)

        if (level == Int.MIN_VALUE) {
            // result.error maps to PlatformException on the Dart side.
            // Code, message, and details are all forwarded to Flutter.
            result.error(
                "UNAVAILABLE",
                "Battery level is not available on this device or emulator",
                null
            )
            return
        }

        // isCharging is true when plugged in regardless of whether the battery
        // is at 100% (full) or still charging.
        val isCharging = manager.isCharging

        // We return a Map so Flutter can read both values in one round-trip.
        // StandardMessageCodec (the default codec) serialises Kotlin Maps to
        // Dart Map<Object?, Object?> automatically — no JSON, no manual encoding.
        result.success(
            mapOf(
                "level"      to level,
                "isCharging" to isCharging
            )
        )
    }
}
