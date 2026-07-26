package com.andromind.oppo_background_gps_demo.tracking

import android.Manifest
import android.app.ActivityManager
import android.app.KeyguardManager
import android.app.Service
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.location.Location
import android.location.LocationListener
import android.location.LocationManager
import android.os.BatteryManager
import android.os.Bundle
import android.os.IBinder
import android.os.PowerManager
import androidx.core.app.ActivityCompat
import androidx.core.app.ServiceCompat

class LocationTrackingService : Service(), LocationListener {
    private lateinit var locationManager: LocationManager
    private lateinit var logStore: TrackingLogStore
    private lateinit var notificationManager: TrackingNotificationManager
    private var listenersRegistered = false
    private var screenReceiverRegistered = false
    private var foregroundStarted = false
    private var explicitlyStopped = false
    private var lastLatitude: Double? = null
    private var lastLongitude: Double? = null

    private val screenStateReceiver =
        object : BroadcastReceiver() {
            override fun onReceive(
                context: Context?,
                intent: Intent?,
            ) {
                val eventType =
                    when (intent?.action) {
                        Intent.ACTION_SCREEN_OFF -> "SCREEN_OFF"
                        Intent.ACTION_SCREEN_ON -> "SCREEN_ON"
                        else -> return
                    }
                runCatching { logStore.append(eventType, message = currentScreenState()) }
                emitServiceStatus()
            }
        }

    override fun onCreate() {
        super.onCreate()
        isRunning = true
        locationManager = getSystemService(Context.LOCATION_SERVICE) as LocationManager
        logStore = TrackingLogStore(this)
        notificationManager = TrackingNotificationManager(this)
        try {
            notificationManager.promoteService(this)
            foregroundStarted = true
        } catch (error: SecurityException) {
            logStore.setTrackingActive(false)
            runCatching {
                logStore.append(
                    "ERROR",
                    message = "Android denied foreground-service promotion after permission changed",
                )
            }
            TrackingEventBridge.emit(
                mapOf(
                    "type" to "error",
                    "message" to "Android denied the foreground location service.",
                ),
            )
            isRunning = false
            stopSelf()
        }
        registerScreenReceiver()
        val previous = logStore.lastCoordinates()
        lastLatitude = previous.first
        lastLongitude = previous.second
    }

    override fun onStartCommand(
        intent: Intent?,
        flags: Int,
        startId: Int,
    ): Int {
        if (!foregroundStarted) {
            return START_NOT_STICKY
        }
        if (intent?.action == ACTION_STOP) {
            stopTrackingExplicitly("Notification or app stop action")
            return START_NOT_STICKY
        }

        val isStickyRestart = intent == null
        if (isStickyRestart && !logStore.isTrackingActive()) {
            stopSelf()
            return START_NOT_STICKY
        }

        try {
            if (!logStore.isTrackingActive()) {
                logStore.createSession()
                logStore.setTrackingActive(true)
                logStore.append("SERVICE_START_REQUESTED")
            } else if (isStickyRestart) {
                logStore.append("SERVICE_RESTARTED")
            }
            val wasRegistered = listenersRegistered
            startLocationUpdates()
            if (!wasRegistered) {
                logStore.append("SERVICE_STARTED")
                TrackingEventBridge.emit(
                    mapOf(
                        "type" to "trackingStarted",
                        "sessionId" to logStore.currentSession()?.sessionId,
                        "message" to
                            if (isStickyRestart) {
                                "Tracking service restarted"
                            } else {
                                "Tracking started"
                            },
                    ),
                )
            }
            emitServiceStatus()
        } catch (error: SecurityException) {
            reportError("Location permission is missing or was revoked.")
            logStore.setTrackingActive(false)
            stopForegroundAndSelf()
            return START_NOT_STICKY
        } catch (error: IllegalStateException) {
            reportError(error.message ?: "Location providers are disabled.")
            logStore.setTrackingActive(false)
            stopForegroundAndSelf()
            return START_NOT_STICKY
        } catch (error: Exception) {
            reportError("Native tracking service failed to start.")
            logStore.setTrackingActive(false)
            stopForegroundAndSelf()
            return START_NOT_STICKY
        }
        return START_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onLocationChanged(location: Location) {
        val sample =
            TrackingSample(
                timestamp = TrackingTime.format(java.util.Date(location.time)),
                latitude = location.latitude,
                longitude = location.longitude,
                accuracy = location.accuracy,
                provider = location.provider ?: "unknown",
                speed = if (location.hasSpeed()) location.speed else null,
                bearing = if (location.hasBearing()) location.bearing else null,
                altitude = if (location.hasAltitude()) location.altitude else null,
                batteryPercent = currentBatteryPercent(),
                screenState = currentScreenState(),
                appProcessState = currentAppProcessState(),
            )

        if (!TrackingValidator.isValid(sample.latitude, sample.longitude, sample.accuracy)) {
            logStore.append(
                "LOCATION_REJECTED_INVALID",
                sample,
                "Coordinate or accuracy failed validation",
            )
            return
        }
        if (
            TrackingValidator.isDuplicate(
                sample.latitude,
                sample.longitude,
                lastLatitude,
                lastLongitude,
            )
        ) {
            logStore.append(
                "LOCATION_REJECTED_DUPLICATE",
                sample,
                "Exactly duplicated consecutive coordinate",
            )
            return
        }

        val record = logStore.append("LOCATION_RECEIVED", sample)
        lastLatitude = sample.latitude
        lastLongitude = sample.longitude
        notificationManager.update(
            "%.6f, %.6f".format(java.util.Locale.US, sample.latitude, sample.longitude),
        )
        TrackingEventBridge.emit(record.toLocationMap())
        emitServiceStatus()
    }

    @Deprecated("Deprecated by Android but required by LocationListener")
    override fun onStatusChanged(
        provider: String?,
        status: Int,
        extras: Bundle?,
    ) = Unit

    override fun onProviderEnabled(provider: String) {
        logStore.append("PROVIDER_ENABLED", message = provider)
        TrackingEventBridge.emit(
            mapOf(
                "type" to "providerStatus",
                "provider" to provider,
                "enabled" to true,
                "message" to "$provider provider enabled",
            ),
        )
    }

    override fun onProviderDisabled(provider: String) {
        logStore.append("PROVIDER_DISABLED", message = provider)
        TrackingEventBridge.emit(
            mapOf(
                "type" to "providerStatus",
                "provider" to provider,
                "enabled" to false,
                "message" to "$provider provider disabled",
            ),
        )
    }

    override fun onDestroy() {
        removeLocationUpdates()
        unregisterScreenReceiver()
        runCatching { logStore.append("SERVICE_DESTROYED") }
        if (explicitlyStopped) {
            logStore.setTrackingActive(false)
        }
        isRunning = false
        TrackingEventBridge.emit(
            mapOf(
                "type" to "serviceStatus",
                "isTracking" to logStore.isTrackingActive(),
                "serviceRunning" to false,
            ),
        )
        super.onDestroy()
    }

    private fun startLocationUpdates() {
        if (listenersRegistered) {
            return
        }
        if (
            ActivityCompat.checkSelfPermission(this, Manifest.permission.ACCESS_FINE_LOCATION) !=
                PackageManager.PERMISSION_GRANTED &&
            ActivityCompat.checkSelfPermission(this, Manifest.permission.ACCESS_COARSE_LOCATION) !=
                PackageManager.PERMISSION_GRANTED
        ) {
            throw SecurityException("Location permission is not granted")
        }

        val enabledProviders =
            listOf(LocationManager.GPS_PROVIDER, LocationManager.NETWORK_PROVIDER)
                .filter { provider ->
                    runCatching {
                        locationManager.getProvider(provider) != null &&
                            locationManager.isProviderEnabled(provider)
                    }.getOrDefault(false)
                }
        if (enabledProviders.isEmpty()) {
            throw IllegalStateException("Location services are turned off. Enable GPS to continue.")
        }
        enabledProviders.forEach { provider ->
            locationManager.requestLocationUpdates(
                provider,
                UPDATE_INTERVAL_MS,
                MINIMUM_DISTANCE_METERS,
                this,
            )
        }
        listenersRegistered = true
    }

    private fun removeLocationUpdates() {
        if (!listenersRegistered) {
            return
        }
        runCatching { locationManager.removeUpdates(this) }
        listenersRegistered = false
    }

    private fun stopTrackingExplicitly(message: String) {
        if (explicitlyStopped) {
            return
        }
        explicitlyStopped = true
        runCatching { logStore.append("SERVICE_STOP_REQUESTED", message = message) }
        logStore.setTrackingActive(false)
        removeLocationUpdates()
        runCatching { logStore.append("SERVICE_STOPPED") }
        TrackingEventBridge.emit(
            mapOf(
                "type" to "trackingStopped",
                "message" to "Tracking stopped",
            ),
        )
        emitServiceStatus()
        stopForegroundAndSelf()
    }

    private fun stopForegroundAndSelf() {
        ServiceCompat.stopForeground(this, ServiceCompat.STOP_FOREGROUND_REMOVE)
        stopSelf()
    }

    private fun reportError(message: String) {
        runCatching { logStore.append("ERROR", message = message) }
        TrackingEventBridge.emit(mapOf("type" to "error", "message" to message))
    }

    private fun emitServiceStatus() {
        TrackingEventBridge.emit(
            TrackingServiceController.buildStatus(this, logStore).toMap() +
                mapOf("type" to "serviceStatus"),
        )
    }

    private fun registerScreenReceiver() {
        if (screenReceiverRegistered) {
            return
        }
        val filter =
            IntentFilter().apply {
                addAction(Intent.ACTION_SCREEN_ON)
                addAction(Intent.ACTION_SCREEN_OFF)
            }
        registerReceiver(screenStateReceiver, filter)
        screenReceiverRegistered = true
    }

    private fun unregisterScreenReceiver() {
        if (!screenReceiverRegistered) {
            return
        }
        runCatching { unregisterReceiver(screenStateReceiver) }
        screenReceiverRegistered = false
    }

    private fun currentScreenState(): String {
        val keyguardManager = getSystemService(Context.KEYGUARD_SERVICE) as KeyguardManager
        val powerManager = getSystemService(Context.POWER_SERVICE) as PowerManager
        return if (keyguardManager.isKeyguardLocked || !powerManager.isInteractive) {
            "LOCKED"
        } else {
            "UNLOCKED"
        }
    }

    private fun currentBatteryPercent(): Int? {
        val intent = registerReceiver(null, IntentFilter(Intent.ACTION_BATTERY_CHANGED)) ?: return null
        val level = intent.getIntExtra(BatteryManager.EXTRA_LEVEL, -1)
        val scale = intent.getIntExtra(BatteryManager.EXTRA_SCALE, -1)
        if (level < 0 || scale <= 0) {
            return null
        }
        return ((level * 100f) / scale).toInt()
    }

    private fun currentAppProcessState(): String {
        val manager = getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
        val process =
            manager.runningAppProcesses?.firstOrNull {
                it.pid == android.os.Process.myPid()
            } ?: return "UNKNOWN"
        return when {
            process.importance <= ActivityManager.RunningAppProcessInfo.IMPORTANCE_FOREGROUND ->
                "FOREGROUND"
            process.importance <= ActivityManager.RunningAppProcessInfo.IMPORTANCE_VISIBLE ->
                "VISIBLE"
            process.importance <= ActivityManager.RunningAppProcessInfo.IMPORTANCE_SERVICE ->
                "SERVICE"
            else -> "BACKGROUND"
        }
    }

    companion object {
        const val ACTION_START =
            "com.andromind.oppo_background_gps_demo.action.START_TRACKING"
        const val ACTION_STOP =
            "com.andromind.oppo_background_gps_demo.action.STOP_TRACKING"
        const val UPDATE_INTERVAL_MS = 5_000L
        const val MINIMUM_DISTANCE_METERS = 0f

        @Volatile
        var isRunning: Boolean = false
            private set
    }
}
