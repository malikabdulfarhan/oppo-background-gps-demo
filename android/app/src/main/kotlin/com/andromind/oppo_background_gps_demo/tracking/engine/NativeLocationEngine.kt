package com.andromind.oppo_background_gps_demo.tracking.engine

import com.andromind.oppo_background_gps_demo.tracking.LocationEngineType
import com.andromind.oppo_background_gps_demo.tracking.TrackingSample

internal sealed interface NativeLocationEvent {
    data class LocationSample(val sample: TrackingSample) : NativeLocationEvent

    data class Error(
        val code: Int? = null,
        val message: String,
        val sample: TrackingSample? = null,
    ) : NativeLocationEvent

    data class ProviderStatus(
        val provider: String,
        val enabled: Boolean,
    ) : NativeLocationEvent
}

internal interface NativeLocationEngine {
    val type: LocationEngineType
    val isAvailable: Boolean
    val unavailableReason: String?

    fun initialize()

    fun start()

    fun stop()

    fun dispose()
}
