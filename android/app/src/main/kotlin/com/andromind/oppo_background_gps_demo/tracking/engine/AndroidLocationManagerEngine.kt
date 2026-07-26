package com.andromind.oppo_background_gps_demo.tracking.engine

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.location.Location
import android.location.LocationListener
import android.location.LocationManager
import android.os.Bundle
import androidx.core.app.ActivityCompat
import com.andromind.oppo_background_gps_demo.tracking.LocationEngineType
import com.andromind.oppo_background_gps_demo.tracking.TrackingSample
import com.andromind.oppo_background_gps_demo.tracking.TrackingTime
import java.util.Date

internal class AndroidLocationManagerEngine(
    context: Context,
    private val updateIntervalMillis: Long,
    private val onEvent: (NativeLocationEvent) -> Unit,
) : NativeLocationEngine,
    LocationListener {
    private val applicationContext = context.applicationContext
    private var locationManager: LocationManager? = null
    private var listenersRegistered = false

    override val type = LocationEngineType.ANDROID_LOCATION_MANAGER

    override val isAvailable: Boolean
        get() = hasLocationPermission() && enabledProviders().isNotEmpty()

    override val unavailableReason: String?
        get() =
            when {
                !hasLocationPermission() -> "Location permission is not granted."
                enabledProviders().isEmpty() ->
                    "Location services are turned off. Enable GPS to continue."
                else -> null
            }

    override fun initialize() {
        if (locationManager == null) {
            locationManager =
                applicationContext.getSystemService(Context.LOCATION_SERVICE) as LocationManager
        }
    }

    override fun start() {
        if (listenersRegistered) {
            return
        }
        initialize()
        if (!hasLocationPermission()) {
            throw SecurityException("Location permission is not granted.")
        }
        val providers = enabledProviders()
        if (providers.isEmpty()) {
            throw IllegalStateException(
                "Location services are turned off. Enable GPS to continue.",
            )
        }
        val manager = checkNotNull(locationManager)
        providers.forEach { provider ->
            manager.requestLocationUpdates(
                provider,
                updateIntervalMillis,
                0f,
                this,
            )
        }
        listenersRegistered = true
    }

    override fun stop() {
        if (!listenersRegistered) {
            return
        }
        locationManager?.let { manager ->
            runCatching { manager.removeUpdates(this) }
        }
        listenersRegistered = false
    }

    override fun dispose() {
        stop()
        locationManager = null
    }

    override fun onLocationChanged(location: Location) {
        onEvent(
            NativeLocationEvent.LocationSample(
                TrackingSample(
                    timestamp =
                        TrackingTime.format(
                            Date(location.time.takeIf { it > 0 } ?: System.currentTimeMillis()),
                        ),
                    latitude = location.latitude,
                    longitude = location.longitude,
                    accuracy = location.accuracy,
                    provider = location.provider ?: "android",
                    speed = if (location.hasSpeed()) location.speed else null,
                    bearing = if (location.hasBearing()) location.bearing else null,
                    altitude = if (location.hasAltitude()) location.altitude else null,
                    batteryPercent = null,
                    screenState = "UNKNOWN",
                    appProcessState = "UNKNOWN",
                    locationEngine = LocationEngineType.ANDROID_LOCATION_MANAGER.wireValue,
                    coordinateSystem = "WGS84",
                ),
            ),
        )
    }

    @Deprecated("Deprecated by Android but required by LocationListener")
    override fun onStatusChanged(
        provider: String?,
        status: Int,
        extras: Bundle?,
    ) = Unit

    override fun onProviderEnabled(provider: String) {
        onEvent(NativeLocationEvent.ProviderStatus(provider, true))
    }

    override fun onProviderDisabled(provider: String) {
        onEvent(NativeLocationEvent.ProviderStatus(provider, false))
    }

    private fun hasLocationPermission(): Boolean =
        ActivityCompat.checkSelfPermission(
            applicationContext,
            Manifest.permission.ACCESS_FINE_LOCATION,
        ) == PackageManager.PERMISSION_GRANTED ||
            ActivityCompat.checkSelfPermission(
                applicationContext,
                Manifest.permission.ACCESS_COARSE_LOCATION,
            ) == PackageManager.PERMISSION_GRANTED

    private fun enabledProviders(): List<String> {
        val manager =
            locationManager
                ?: (
                    applicationContext.getSystemService(Context.LOCATION_SERVICE)
                        as LocationManager
                ).also { locationManager = it }
        return listOf(LocationManager.GPS_PROVIDER, LocationManager.NETWORK_PROVIDER)
            .filter { provider ->
                runCatching {
                    provider in manager.allProviders && manager.isProviderEnabled(provider)
                }.getOrDefault(false)
            }
    }
}
