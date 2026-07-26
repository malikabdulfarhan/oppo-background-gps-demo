package com.andromind.oppo_background_gps_demo.tracking

import android.Manifest
import android.app.Activity
import android.app.KeyguardManager
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import androidx.core.content.FileProvider
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

internal class TrackingServiceController(
    private val activity: Activity,
) : MethodChannel.MethodCallHandler {
    private val context = activity.applicationContext
    private val logStore = TrackingLogStore(context)
    private var permissionResult: MethodChannel.Result? = null

    override fun onMethodCall(
        call: MethodCall,
        result: MethodChannel.Result,
    ) {
        when (call.method) {
            "ensurePermissions" -> ensurePermissions(result)
            "startTracking" -> startTracking(result)
            "stopTracking" -> stopTracking(result)
            "getTrackingStatus" -> result.success(buildStatus(context, logStore).toMap())
            "getCurrentSession" -> result.success(currentSessionMap())
            "getCurrentSessionRecords" -> result.success(logStore.currentLocationRecords())
            "listTrackingSessions" -> result.success(logStore.listSessions())
            "getBatteryOptimizationStatus" -> result.success(batteryOptimizationStatus())
            "openBatteryOptimizationSettings" ->
                result.success(openIntent(Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS)))
            "openAppSettings" ->
                result.success(
                    openIntent(
                        Intent(
                            Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                            Uri.parse("package:${context.packageName}"),
                        ),
                    ),
                )
            "openLocationSettings" ->
                result.success(openIntent(Intent(Settings.ACTION_LOCATION_SOURCE_SETTINGS)))
            "shareCurrentLog" -> result.success(shareCurrentLog())
            else -> result.notImplemented()
        }
    }

    fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ): Boolean {
        if (requestCode != PERMISSION_REQUEST_CODE) {
            return false
        }
        val pendingResult = permissionResult ?: return true
        permissionResult = null
        pendingResult.success(permissionStatusMap(requestCompleted = true))
        return true
    }

    private fun ensurePermissions(result: MethodChannel.Result) {
        if (permissionResult != null) {
            result.error(
                "PERMISSION_REQUEST_ACTIVE",
                "A permission request is already in progress.",
                null,
            )
            return
        }
        if (!hasAnyLocationPermission()) {
            requestPermissions(result, includeLocation = true)
            return
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU && !hasNotificationPermission()) {
            requestPermissions(result, includeLocation = false)
            return
        }
        result.success(permissionStatusMap(requestCompleted = false))
    }

    private fun requestPermissions(
        result: MethodChannel.Result,
        includeLocation: Boolean,
    ) {
        val permissions = mutableListOf<String>()
        if (includeLocation) {
            permissions += Manifest.permission.ACCESS_FINE_LOCATION
            permissions += Manifest.permission.ACCESS_COARSE_LOCATION
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU && !hasNotificationPermission()) {
            permissions += Manifest.permission.POST_NOTIFICATIONS
        }
        permissionResult = result
        context
            .getSharedPreferences(PERMISSION_PREFERENCES, Context.MODE_PRIVATE)
            .edit()
            .putBoolean(KEY_LOCATION_PERMISSION_REQUESTED, includeLocation)
            .apply()
        ActivityCompat.requestPermissions(
            activity,
            permissions.distinct().toTypedArray(),
            PERMISSION_REQUEST_CODE,
        )
    }

    private fun permissionStatusMap(requestCompleted: Boolean): Map<String, Any?> {
        val fineGranted = hasPermission(Manifest.permission.ACCESS_FINE_LOCATION)
        val coarseGranted = hasPermission(Manifest.permission.ACCESS_COARSE_LOCATION)
        val locationGranted = fineGranted || coarseGranted
        val notificationGranted = hasNotificationPermission()
        val requestedBefore =
            context
                .getSharedPreferences(PERMISSION_PREFERENCES, Context.MODE_PRIVATE)
                .getBoolean(KEY_LOCATION_PERMISSION_REQUESTED, false)
        val permanentlyDenied =
            !locationGranted &&
                requestedBefore &&
                !ActivityCompat.shouldShowRequestPermissionRationale(
                    activity,
                    Manifest.permission.ACCESS_FINE_LOCATION,
                ) &&
                !ActivityCompat.shouldShowRequestPermissionRationale(
                    activity,
                    Manifest.permission.ACCESS_COARSE_LOCATION,
                )
        val message =
            when {
                !locationGranted && permanentlyDenied ->
                    "Location permission is permanently denied. Open app settings to allow it."
                !locationGranted -> "Location permission was denied. Allow access and try again."
                !fineGranted ->
                    "Approximate location is enabled. Precise location is recommended for route tracking."
                !notificationGranted ->
                    "Notification permission is denied. Android may hide the tracking notification."
                else -> "Permissions granted"
            }
        return mapOf(
            "success" to locationGranted,
            "locationGranted" to locationGranted,
            "preciseLocationGranted" to fineGranted,
            "locationPermanentlyDenied" to permanentlyDenied,
            "notificationPermissionGranted" to notificationGranted,
            "requestCompleted" to requestCompleted,
            "message" to message,
        )
    }

    private fun startTracking(result: MethodChannel.Result) {
        if (!hasAnyLocationPermission()) {
            result.success(
                mapOf(
                    "success" to false,
                    "isTracking" to false,
                    "errorCode" to "PERMISSION_DENIED",
                    "message" to "Location permission is required.",
                ),
            )
            return
        }
        if (!isAnyLocationProviderEnabled(context)) {
            result.success(
                mapOf(
                    "success" to false,
                    "isTracking" to false,
                    "errorCode" to "GPS_DISABLED",
                    "message" to "Location services are turned off. Enable GPS to continue.",
                ),
            )
            return
        }
        if (logStore.isTrackingActive()) {
            val session = logStore.currentOrCreateSession()
            if (!LocationTrackingService.isRunning) {
                startForegroundService()
            }
            result.success(startResultMap(session, "Tracking service reconnected"))
            return
        }

        val session = logStore.createSession()
        logStore.setTrackingActive(true)
        logStore.append("SERVICE_START_REQUESTED")
        try {
            startForegroundService()
            result.success(startResultMap(session, "Tracking started"))
        } catch (error: SecurityException) {
            logStore.append("ERROR", message = "Foreground location service permission denied")
            logStore.setTrackingActive(false)
            result.success(
                mapOf(
                    "success" to false,
                    "isTracking" to false,
                    "sessionId" to session.sessionId,
                    "errorCode" to "SECURITY_EXCEPTION",
                    "message" to "Android denied the foreground location service.",
                ),
            )
        } catch (error: Exception) {
            logStore.append("ERROR", message = "Foreground service start failed")
            logStore.setTrackingActive(false)
            result.success(
                mapOf(
                    "success" to false,
                    "isTracking" to false,
                    "sessionId" to session.sessionId,
                    "errorCode" to "SERVICE_START_FAILED",
                    "message" to "Unable to start the native tracking service.",
                ),
            )
        }
    }

    private fun stopTracking(result: MethodChannel.Result) {
        if (!logStore.isTrackingActive() && !LocationTrackingService.isRunning) {
            result.success(null)
            return
        }
        if (LocationTrackingService.isRunning) {
            context.startService(
                Intent(context, LocationTrackingService::class.java).apply {
                    action = LocationTrackingService.ACTION_STOP
                },
            )
        } else {
            logStore.append("SERVICE_STOP_REQUESTED", message = "Service was not running")
            logStore.setTrackingActive(false)
            logStore.append("SERVICE_STOPPED")
        }
        result.success(null)
    }

    private fun startForegroundService() {
        ContextCompat.startForegroundService(
            context,
            Intent(context, LocationTrackingService::class.java).apply {
                action = LocationTrackingService.ACTION_START
            },
        )
    }

    private fun startResultMap(
        session: TrackingSessionFile,
        message: String,
    ): Map<String, Any?> =
        mapOf(
            "success" to true,
            "isTracking" to true,
            "sessionId" to session.sessionId,
            "message" to message,
            "notificationPermissionGranted" to hasNotificationPermission(),
        )

    private fun currentSessionMap(): Map<String, Any?>? =
        logStore.currentSession()?.let { session ->
            mapOf(
                "sessionId" to session.sessionId,
                "fileName" to session.file.name,
                "path" to session.file.absolutePath,
                "lastModified" to session.file.lastModified(),
                "sizeBytes" to session.file.length(),
            )
        }

    private fun batteryOptimizationStatus(): Map<String, Any?> {
        val powerManager = context.getSystemService(Context.POWER_SERVICE) as PowerManager
        val ignoring =
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                powerManager.isIgnoringBatteryOptimizations(context.packageName)
            } else {
                true
            }
        return mapOf(
            "isIgnoringBatteryOptimizations" to ignoring,
            "isOptimized" to !ignoring,
            "manufacturer" to Build.MANUFACTURER,
            "model" to Build.MODEL,
            "androidVersion" to Build.VERSION.RELEASE,
            "sdkInt" to Build.VERSION.SDK_INT,
            "isOppo" to Build.MANUFACTURER.equals("oppo", ignoreCase = true),
        )
    }

    private fun shareCurrentLog(): Boolean {
        val session = logStore.currentSession() ?: return false
        if (!session.file.exists()) {
            return false
        }
        val uri =
            FileProvider.getUriForFile(
                context,
                "${context.packageName}.tracking_files",
                session.file,
            )
        val shareIntent =
            Intent(Intent.ACTION_SEND).apply {
                type = "text/csv"
                putExtra(Intent.EXTRA_STREAM, uri)
                putExtra(Intent.EXTRA_SUBJECT, session.file.name)
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            }
        activity.startActivity(Intent.createChooser(shareIntent, "Share tracking log"))
        return true
    }

    private fun openIntent(intent: Intent): Boolean =
        try {
            activity.startActivity(intent)
            true
        } catch (error: Exception) {
            false
        }

    private fun hasAnyLocationPermission(): Boolean =
        hasPermission(Manifest.permission.ACCESS_FINE_LOCATION) ||
            hasPermission(Manifest.permission.ACCESS_COARSE_LOCATION)

    private fun hasNotificationPermission(): Boolean =
        Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU ||
            hasPermission(Manifest.permission.POST_NOTIFICATIONS)

    private fun hasPermission(permission: String): Boolean =
        ContextCompat.checkSelfPermission(context, permission) == PackageManager.PERMISSION_GRANTED

    companion object {
        const val METHOD_CHANNEL =
            "com.andromind.oppo_background_gps_demo/tracking_control"
        const val EVENT_CHANNEL =
            "com.andromind.oppo_background_gps_demo/tracking_events"
        private const val PERMISSION_REQUEST_CODE = 7401
        private const val PERMISSION_PREFERENCES = "tracking_permission_state"
        private const val KEY_LOCATION_PERMISSION_REQUESTED = "location_requested"

        internal fun buildStatus(
            context: Context,
            logStore: TrackingLogStore = TrackingLogStore(context),
        ): TrackingStatus {
            val session = logStore.currentSession()
            val notificationGranted =
                Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU ||
                    ContextCompat.checkSelfPermission(
                        context,
                        Manifest.permission.POST_NOTIFICATIONS,
                    ) == PackageManager.PERMISSION_GRANTED
            val keyguardManager =
                context.getSystemService(Context.KEYGUARD_SERVICE) as KeyguardManager
            return TrackingStatus(
                isTracking = logStore.isTrackingActive(),
                serviceRunning = LocationTrackingService.isRunning,
                sessionId = session?.sessionId,
                lastLocationTimestamp = logStore.lastLocationTimestamp(),
                currentLogPath = session?.file?.absolutePath,
                currentProvider = logStore.currentProvider(),
                screenState = if (keyguardManager.isKeyguardLocked) "LOCKED" else "UNLOCKED",
                notificationPermissionGranted = notificationGranted,
            )
        }

        private fun isAnyLocationProviderEnabled(context: Context): Boolean {
            val manager =
                context.getSystemService(Context.LOCATION_SERVICE) as android.location.LocationManager
            return listOf(
                android.location.LocationManager.GPS_PROVIDER,
                android.location.LocationManager.NETWORK_PROVIDER,
            ).any { provider ->
                runCatching {
                    manager.getProvider(provider) != null && manager.isProviderEnabled(provider)
                }.getOrDefault(false)
            }
        }
    }
}
