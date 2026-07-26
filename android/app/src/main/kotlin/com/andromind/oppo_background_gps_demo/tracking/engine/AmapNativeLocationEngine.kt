package com.andromind.oppo_background_gps_demo.tracking.engine

import android.content.Context
import com.amap.api.location.AMapLocation
import com.amap.api.location.AMapLocationClient
import com.amap.api.location.AMapLocationClientOption
import com.amap.api.location.AMapLocationListener
import com.andromind.oppo_background_gps_demo.amap.AmapPrivacyConsent
import com.andromind.oppo_background_gps_demo.amap.AmapSdkConfiguration
import com.andromind.oppo_background_gps_demo.tracking.AmapLocationSnapshot
import com.andromind.oppo_background_gps_demo.tracking.AmapSampleMapper
import com.andromind.oppo_background_gps_demo.tracking.LocationEngineType

internal class AmapNativeLocationEngine(
    context: Context,
    private val updateIntervalMillis: Long,
    private val onEvent: (NativeLocationEvent) -> Unit,
) : NativeLocationEngine,
    AMapLocationListener {
    private val applicationContext = context.applicationContext
    private var client: AMapLocationClient? = null
    private var started = false

    override val type = LocationEngineType.AMAP

    override val isAvailable: Boolean
        get() =
            AmapSdkConfiguration.isKeyConfigured(applicationContext) &&
                AmapSdkConfiguration.privacyConsent(applicationContext) ==
                AmapPrivacyConsent.ACCEPTED

    override val unavailableReason: String?
        get() =
            when {
                !AmapSdkConfiguration.isKeyConfigured(applicationContext) ->
                    "AMap API key is not configured."
                AmapSdkConfiguration.privacyConsent(applicationContext) !=
                    AmapPrivacyConsent.ACCEPTED ->
                    "AMap privacy consent is not accepted."
                else -> null
            }

    override fun initialize() {
        if (client != null) {
            return
        }
        check(isAvailable) { unavailableReason ?: "AMap is unavailable." }
        try {
            AmapSdkConfiguration.applyAcceptedPrivacy(applicationContext)
            client =
                AMapLocationClient(applicationContext).also {
                    it.setLocationListener(this)
                }
            AmapSdkConfiguration.setLocationSdkInitialized(applicationContext, true)
        } catch (error: Throwable) {
            AmapSdkConfiguration.markRuntimeFailed(
                error.message ?: "AMap location initialization failed.",
            )
            throw error
        }
    }

    override fun start() {
        if (started) {
            return
        }
        initialize()
        val option =
            AMapLocationClientOption().apply {
                setLocationMode(AMapLocationClientOption.AMapLocationMode.Hight_Accuracy)
                setInterval(updateIntervalMillis)
                setOnceLocation(false)
                setGpsFirst(true)
                setNeedAddress(false)
                setMockEnable(true)
                setLocationCacheEnable(false)
                setSensorEnable(true)
                setWifiScan(true)
            }
        checkNotNull(client).apply {
            setLocationOption(option)
            startLocation()
        }
        started = true
    }

    override fun stop() {
        if (!started) {
            return
        }
        runCatching { client?.stopLocation() }
        started = false
    }

    override fun dispose() {
        stop()
        runCatching { client?.onDestroy() }
        client = null
        AmapSdkConfiguration.setLocationSdkInitialized(applicationContext, false)
    }

    override fun onLocationChanged(location: AMapLocation?) {
        if (location == null) {
            onEvent(
                NativeLocationEvent.Error(
                    code = -1,
                    message = "AMap returned an empty location callback.",
                ),
            )
            return
        }
        val snapshot =
            AmapLocationSnapshot(
                timestampMillis =
                    location.time.takeIf { it > 0 } ?: System.currentTimeMillis(),
                latitude = location.latitude,
                longitude = location.longitude,
                accuracy = location.accuracy,
                provider = location.provider,
                speed = location.speed,
                bearing = location.bearing,
                altitude = location.altitude,
                locationType = location.locationType,
                errorCode = location.errorCode,
                errorInfo = sanitize(location.errorInfo),
                gpsAccuracyStatus = location.gpsAccuracyStatus,
                satelliteCount = location.satellites,
                isMock = location.isMock,
                coordinateSystem = location.coordType,
                country = location.country,
                province = location.province,
                city = location.city,
                district = location.district,
                street = location.street,
                address = location.address,
            )
        val sample =
            AmapSampleMapper.map(
                snapshot,
                batteryPercent = null,
                screenState = "UNKNOWN",
                appProcessState = "UNKNOWN",
            )
        if (location.errorCode == 0) {
            onEvent(NativeLocationEvent.LocationSample(sample))
        } else {
            onEvent(
                NativeLocationEvent.Error(
                    code = location.errorCode,
                    message =
                        "AMap location failed (${location.errorCode}): " +
                            (sample.amapErrorInfo ?: "Unknown location error"),
                    sample = sample,
                ),
            )
        }
    }

    private fun sanitize(value: String?): String? =
        value?.replace(Regex("[\\r\\n\\t]+"), " ")?.trim()?.take(240)
}
