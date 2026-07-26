package com.andromind.oppo_background_gps_demo.tracking

import android.content.Context
import com.andromind.oppo_background_gps_demo.amap.AmapPrivacyConsent
import com.andromind.oppo_background_gps_demo.amap.AmapRuntimeState
import com.andromind.oppo_background_gps_demo.amap.AmapSdkConfiguration

internal enum class LocationEngineType(val wireValue: String) {
    ANDROID_LOCATION_MANAGER("ANDROID_LOCATION_MANAGER"),
    AMAP("AMAP"),
}

internal enum class LocationEnginePreference(val wireValue: String) {
    AUTOMATIC("AUTOMATIC"),
    ANDROID_GPS_DEMO("ANDROID_GPS_DEMO"),
    AMAP("AMAP"),
}

internal data class LocationEngineSelection(
    val selected: LocationEnginePreference,
    val engine: LocationEngineType,
    val fallbackReason: String? = null,
)

internal object LocationEngineSelector {
    fun select(
        preference: LocationEnginePreference,
        amapKeyConfigured: Boolean,
        amapPrivacyAccepted: Boolean,
        amapRuntimeFailed: Boolean,
    ): LocationEngineSelection {
        if (preference == LocationEnginePreference.ANDROID_GPS_DEMO) {
            return LocationEngineSelection(preference, LocationEngineType.ANDROID_LOCATION_MANAGER)
        }
        val reason =
            when {
                !amapKeyConfigured ->
                    "AMap API key is not configured. Android GPS Demo Mode is active."
                !amapPrivacyAccepted ->
                    "AMap privacy consent is not accepted. Android GPS Demo Mode is active."
                amapRuntimeFailed ->
                    "AMap initialization failed. Android GPS Demo Mode is active."
                else -> null
            }
        return if (reason == null) {
            LocationEngineSelection(preference, LocationEngineType.AMAP)
        } else {
            LocationEngineSelection(
                preference,
                LocationEngineType.ANDROID_LOCATION_MANAGER,
                reason,
            )
        }
    }
}

internal object LocationEngineConfiguration {
    private const val PREFERENCES = "location_engine_configuration"
    private const val KEY_SELECTED_ENGINE = "selected_engine"
    private const val KEY_FALLBACK_REASON = "fallback_reason"

    fun selectedPreference(context: Context): LocationEnginePreference {
        val stored =
            preferences(context).getString(
                KEY_SELECTED_ENGINE,
                LocationEnginePreference.AUTOMATIC.wireValue,
            )
        return LocationEnginePreference.entries.firstOrNull { it.wireValue == stored }
            ?: LocationEnginePreference.AUTOMATIC
    }

    fun setSelectedPreference(
        context: Context,
        preference: LocationEnginePreference,
    ) {
        preferences(context).edit().putString(KEY_SELECTED_ENGINE, preference.wireValue).apply()
    }

    fun resolve(context: Context): LocationEngineSelection =
        LocationEngineSelector.select(
            preference = selectedPreference(context),
            amapKeyConfigured = AmapSdkConfiguration.isKeyConfigured(context),
            amapPrivacyAccepted =
                AmapSdkConfiguration.privacyConsent(context) == AmapPrivacyConsent.ACCEPTED,
            amapRuntimeFailed =
                AmapSdkConfiguration.runtimeState() == AmapRuntimeState.FAILED,
        )

    fun setFallbackReason(
        context: Context,
        reason: String?,
    ) {
        val editor = preferences(context).edit()
        if (reason.isNullOrBlank()) {
            editor.remove(KEY_FALLBACK_REASON)
        } else {
            editor.putString(KEY_FALLBACK_REASON, reason.take(240))
        }
        editor.apply()
    }

    fun fallbackReason(context: Context): String? =
        preferences(context).getString(KEY_FALLBACK_REASON, null)

    fun configurationMap(context: Context): Map<String, Any?> {
        val selection = resolve(context)
        val keyConfigured = AmapSdkConfiguration.isKeyConfigured(context)
        val privacyAccepted =
            AmapSdkConfiguration.privacyConsent(context) == AmapPrivacyConsent.ACCEPTED
        return AmapSdkConfiguration.configurationMap(context) +
            mapOf(
                "selectedLocationEngine" to selection.selected.wireValue,
                "resolvedLocationEngine" to selection.engine.wireValue,
                "fallbackReason" to
                    if (selection.engine == LocationEngineType.AMAP) {
                        null
                    } else {
                        fallbackReason(context) ?: selection.fallbackReason
                    },
                "amapOptionAvailable" to keyConfigured,
                "amapUnavailableReason" to
                    when {
                        !keyConfigured -> "A valid AMap Android SDK key is required."
                        !privacyAccepted -> "AMap privacy consent must be accepted."
                        AmapSdkConfiguration.runtimeState() == AmapRuntimeState.FAILED ->
                            AmapSdkConfiguration.runtimeFailureReason()
                                ?: "AMap initialization failed."
                        else -> null
                    },
                "csvSchemaVersion" to TrackingCsvRecord.SCHEMA_VERSION,
            )
    }

    private fun preferences(context: Context) =
        context.applicationContext.getSharedPreferences(PREFERENCES, Context.MODE_PRIVATE)
}
