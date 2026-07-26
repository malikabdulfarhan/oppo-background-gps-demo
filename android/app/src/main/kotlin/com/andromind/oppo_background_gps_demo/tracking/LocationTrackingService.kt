package com.andromind.oppo_background_gps_demo.tracking

import android.app.ActivityManager
import android.app.KeyguardManager
import android.app.Service
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.BatteryManager
import android.os.IBinder
import android.os.PowerManager
import androidx.core.app.ServiceCompat
import com.andromind.oppo_background_gps_demo.amap.AmapSdkConfiguration
import com.andromind.oppo_background_gps_demo.tracking.engine.AmapNativeLocationEngine
import com.andromind.oppo_background_gps_demo.tracking.engine.AndroidLocationManagerEngine
import com.andromind.oppo_background_gps_demo.tracking.engine.NativeLocationEngine
import com.andromind.oppo_background_gps_demo.tracking.engine.NativeLocationEvent
import java.util.Locale

class LocationTrackingService : Service() {
    private lateinit var logStore: TrackingLogStore
    private lateinit var notificationManager: TrackingNotificationManager
    private var locationEngine: NativeLocationEngine? = null
    private var screenReceiverRegistered = false
    private var foregroundStarted = false
    private var engineStarted = false
    private var explicitlyStopped = false

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
            if (!engineStarted) {
                startConfiguredEngine()
                logStore.append("SERVICE_STARTED")
                TrackingEventBridge.emit(
                    mapOf(
                        "type" to "trackingStarted",
                        "sessionId" to logStore.currentSession()?.sessionId,
                        "message" to
                            if (isStickyRestart) {
                                "Tracking service restarted with ${activeEngineType?.wireValue}"
                            } else {
                                "Tracking started with ${activeEngineType?.wireValue}"
                            },
                    ),
                )
            }
            emitServiceStatus()
        } catch (error: SecurityException) {
            failServiceStart("Location permission is missing or was revoked.")
            return START_NOT_STICKY
        } catch (error: IllegalStateException) {
            failServiceStart(error.message ?: "Location providers are disabled.")
            return START_NOT_STICKY
        } catch (error: Exception) {
            failServiceStart("Native tracking service failed to start.")
            return START_NOT_STICKY
        }
        return START_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onDestroy() {
        disposeLocationEngine()
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

    private fun startConfiguredEngine() {
        val selection = LocationEngineConfiguration.resolve(this)
        if (selection.engine == LocationEngineType.AMAP) {
            try {
                startEngine(LocationEngineType.AMAP)
                LocationEngineConfiguration.setFallbackReason(this, null)
                return
            } catch (error: Throwable) {
                val reason =
                    "AMap initialization failed. Android GPS Demo Mode is active."
                AmapSdkConfiguration.markRuntimeFailed(
                    error.message ?: "AMap location initialization failed.",
                )
                LocationEngineConfiguration.setFallbackReason(this, reason)
                runCatching {
                    logStore.append(
                        "AMAP_LOCATION_ERROR",
                        message = sanitizeMessage(error.message ?: reason),
                    )
                }
                disposeLocationEngine()
                TrackingEventBridge.emit(
                    mapOf(
                        "type" to "providerStatus",
                        "provider" to "AMap",
                        "enabled" to false,
                        "message" to reason,
                    ),
                )
            }
        } else {
            LocationEngineConfiguration.setFallbackReason(
                this,
                selection.fallbackReason,
            )
        }
        startEngine(LocationEngineType.ANDROID_LOCATION_MANAGER)
    }

    private fun startEngine(type: LocationEngineType) {
        check(locationEngine == null) {
            "A location engine is already active."
        }
        logStore.setSessionLocationEngine(type)
        val engine =
            when (type) {
                LocationEngineType.AMAP ->
                    AmapNativeLocationEngine(
                        context = this,
                        updateIntervalMillis = UPDATE_INTERVAL_MS,
                        onEvent = ::handleEngineEvent,
                    )
                LocationEngineType.ANDROID_LOCATION_MANAGER ->
                    AndroidLocationManagerEngine(
                        context = this,
                        updateIntervalMillis = UPDATE_INTERVAL_MS,
                        onEvent = ::handleEngineEvent,
                    )
            }
        locationEngine = engine
        activeEngineType = type
        logStore.append(
            if (type == LocationEngineType.AMAP) {
                "AMAP_INITIALIZING"
            } else {
                "ANDROID_LOCATION_MANAGER_INITIALIZING"
            },
        )
        try {
            engine.initialize()
            logStore.append(
                if (type == LocationEngineType.AMAP) {
                    "AMAP_INITIALIZED"
                } else {
                    "ANDROID_LOCATION_MANAGER_INITIALIZED"
                },
            )
            engine.start()
            engineStarted = true
            logStore.append(
                if (type == LocationEngineType.AMAP) {
                    "AMAP_LOCATION_STARTED"
                } else {
                    "ANDROID_LOCATION_MANAGER_STARTED"
                },
            )
        } catch (error: Throwable) {
            engine.dispose()
            locationEngine = null
            activeEngineType = null
            engineStarted = false
            throw error
        }
    }

    private fun handleEngineEvent(event: NativeLocationEvent) {
        when (event) {
            is NativeLocationEvent.LocationSample -> handleLocationSample(event.sample)
            is NativeLocationEvent.Error -> handleLocationError(event)
            is NativeLocationEvent.ProviderStatus -> {
                logStore.append(
                    if (event.enabled) "PROVIDER_ENABLED" else "PROVIDER_DISABLED",
                    message = event.provider,
                )
                TrackingEventBridge.emit(
                    mapOf(
                        "type" to "providerStatus",
                        "provider" to event.provider,
                        "enabled" to event.enabled,
                        "message" to
                            "${event.provider} provider " +
                                if (event.enabled) "enabled" else "disabled",
                    ),
                )
            }
        }
    }

    private fun handleLocationSample(engineSample: TrackingSample) {
        val sample =
            engineSample.copy(
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

        // Stationary callbacks remain in the CSV. Flutter independently removes
        // exact consecutive duplicate points from the displayed polyline.
        val record = logStore.append("LOCATION_RECEIVED", sample)
        notificationManager.update(
            "%.6f, %.6f".format(Locale.US, sample.latitude, sample.longitude),
        )
        TrackingEventBridge.emit(record.toLocationMap())
        emitServiceStatus()
    }

    private fun handleLocationError(error: NativeLocationEvent.Error) {
        val sample =
            error.sample?.copy(
                batteryPercent = currentBatteryPercent(),
                screenState = currentScreenState(),
                appProcessState = currentAppProcessState(),
            )
        logStore.append(
            if (activeEngineType == LocationEngineType.AMAP) {
                "AMAP_LOCATION_ERROR"
            } else {
                "ANDROID_LOCATION_ERROR"
            },
            sample,
            sanitizeMessage(error.message),
        )
        TrackingEventBridge.emit(
            mapOf(
                "type" to "error",
                "code" to error.code?.let { "AMAP_$it" },
                "message" to sanitizeMessage(error.message),
            ),
        )
        emitServiceStatus()
    }

    private fun disposeLocationEngine() {
        val engine = locationEngine ?: return
        if (engineStarted) {
            runCatching { engine.stop() }
            runCatching {
                logStore.append(
                    if (engine.type == LocationEngineType.AMAP) {
                        "AMAP_LOCATION_STOPPED"
                    } else {
                        "ANDROID_LOCATION_MANAGER_STOPPED"
                    },
                )
            }
        }
        runCatching { engine.dispose() }
        runCatching {
            logStore.append(
                if (engine.type == LocationEngineType.AMAP) {
                    "AMAP_CLIENT_DESTROYED"
                } else {
                    "ANDROID_LOCATION_MANAGER_DESTROYED"
                },
            )
        }
        locationEngine = null
        engineStarted = false
        activeEngineType = null
    }

    private fun stopTrackingExplicitly(message: String) {
        if (explicitlyStopped) {
            return
        }
        explicitlyStopped = true
        runCatching { logStore.append("SERVICE_STOP_REQUESTED", message = message) }
        logStore.setTrackingActive(false)
        disposeLocationEngine()
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

    private fun failServiceStart(message: String) {
        reportError(message)
        logStore.setTrackingActive(false)
        disposeLocationEngine()
        stopForegroundAndSelf()
    }

    private fun stopForegroundAndSelf() {
        ServiceCompat.stopForeground(this, ServiceCompat.STOP_FOREGROUND_REMOVE)
        stopSelf()
    }

    private fun reportError(message: String) {
        runCatching { logStore.append("ERROR", message = sanitizeMessage(message)) }
        TrackingEventBridge.emit(
            mapOf(
                "type" to "error",
                "message" to sanitizeMessage(message),
            ),
        )
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
        registerReceiver(
            screenStateReceiver,
            IntentFilter().apply {
                addAction(Intent.ACTION_SCREEN_ON)
                addAction(Intent.ACTION_SCREEN_OFF)
            },
        )
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

    private fun sanitizeMessage(value: String): String =
        value.replace(Regex("[\\r\\n\\t]+"), " ").trim().take(240)

    companion object {
        const val ACTION_START =
            "com.andromind.oppo_background_gps_demo.action.START_TRACKING"
        const val ACTION_STOP =
            "com.andromind.oppo_background_gps_demo.action.STOP_TRACKING"
        const val UPDATE_INTERVAL_MS = 5_000L

        @Volatile
        var isRunning: Boolean = false
            private set

        @Volatile
        internal var activeEngineType: LocationEngineType? = null
            private set
    }
}
