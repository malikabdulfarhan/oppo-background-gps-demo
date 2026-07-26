package com.andromind.oppo_background_gps_demo.amap

import android.content.Context
import android.content.pm.PackageManager
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import com.amap.api.location.AMapLocationClient
import com.amap.api.maps.MapsInitializer

internal enum class AmapPrivacyConsent(val wireValue: String) {
    ACCEPTED("ACCEPTED"),
    DECLINED("DECLINED"),
    NOT_SELECTED("NOT_SELECTED"),
}

internal enum class AmapRuntimeState(val wireValue: String) {
    NOT_ATTEMPTED("NOT_ATTEMPTED"),
    VERIFIED("VERIFIED"),
    FAILED("FAILED"),
}

internal object AmapSdkConfiguration {
    private const val PREFERENCES = "amap_configuration"
    private const val KEY_PRIVACY_CONSENT = "privacy_consent"
    private const val KEY_MAP_TYPE = "map_type"
    private const val KEY_TRAFFIC = "traffic"
    private const val KEY_COMPASS = "compass"
    private const val KEY_SCALE = "scale"
    @Volatile
    private var locationSdkInitialized = false
    private var mapSdkInstanceCount = 0
    @Volatile
    private var runtimeState = AmapRuntimeState.NOT_ATTEMPTED
    @Volatile
    private var runtimeFailureReason: String? = null

    fun isKeyConfigured(context: Context): Boolean {
        val applicationInfo =
            context.packageManager.getApplicationInfo(
                context.packageName,
                PackageManager.GET_META_DATA,
            )
        return isKeyValueConfigured(
            applicationInfo.metaData?.getString("com.amap.api.v2.apikey"),
        )
    }

    fun isKeyValueConfigured(value: String?): Boolean {
        val key = value?.trim().orEmpty()
        return key.isNotEmpty() &&
            key != "YOUR_AMAP_ANDROID_KEY" &&
            !key.startsWith("\${")
    }

    fun privacyConsent(context: Context): AmapPrivacyConsent {
        val value =
            preferences(context).getString(
                KEY_PRIVACY_CONSENT,
                AmapPrivacyConsent.NOT_SELECTED.wireValue,
            )
        return AmapPrivacyConsent.entries.firstOrNull { it.wireValue == value }
            ?: AmapPrivacyConsent.NOT_SELECTED
    }

    fun setPrivacyConsent(
        context: Context,
        consent: AmapPrivacyConsent,
    ) {
        preferences(context).edit()
            .putString(KEY_PRIVACY_CONSENT, consent.wireValue)
            .apply()
        locationSdkInitialized = false
        mapSdkInstanceCount = 0
        runtimeState = AmapRuntimeState.NOT_ATTEMPTED
        runtimeFailureReason = null
        if (isKeyConfigured(context) && consent != AmapPrivacyConsent.NOT_SELECTED) {
            applyPrivacy(context, consent == AmapPrivacyConsent.ACCEPTED)
        }
    }

    fun applyAcceptedPrivacy(context: Context) {
        check(privacyConsent(context) == AmapPrivacyConsent.ACCEPTED) {
            "AMap privacy consent has not been accepted"
        }
        applyPrivacy(context, true)
    }

    fun setLocationSdkInitialized(
        context: Context,
        initialized: Boolean,
    ) {
        locationSdkInitialized = initialized
        if (initialized) {
            markRuntimeVerified()
        }
    }

    @Synchronized
    fun setMapSdkInitialized(
        context: Context,
        initialized: Boolean,
    ) {
        mapSdkInstanceCount =
            if (initialized) {
                mapSdkInstanceCount + 1
            } else {
                (mapSdkInstanceCount - 1).coerceAtLeast(0)
            }
        if (initialized) {
            markRuntimeVerified()
        }
    }

    fun isSdkInitialized(context: Context): Boolean =
        locationSdkInitialized || mapSdkInstanceCount > 0

    fun markRuntimeFailed(reason: String) {
        runtimeState = AmapRuntimeState.FAILED
        runtimeFailureReason = sanitizeReason(reason)
    }

    fun resetRuntimeAttempt() {
        if (!locationSdkInitialized && mapSdkInstanceCount == 0) {
            runtimeState = AmapRuntimeState.NOT_ATTEMPTED
            runtimeFailureReason = null
        }
    }

    fun runtimeState(): AmapRuntimeState = runtimeState

    fun runtimeFailureReason(): String? = runtimeFailureReason

    fun runtimeVerification(context: Context): String =
        when {
            !isKeyConfigured(context) -> "PENDING_API_KEY"
            runtimeState == AmapRuntimeState.FAILED -> "FAILED"
            runtimeState == AmapRuntimeState.VERIFIED -> "VERIFIED"
            else -> "NOT_ATTEMPTED"
        }

    fun configurationMap(context: Context): Map<String, Any?> =
        mapOf(
            "apiKeyConfigured" to isKeyConfigured(context),
            "privacyConsent" to privacyConsent(context).wireValue,
            "sdkInitialized" to isSdkInitialized(context),
            "sdkCompileIntegration" to true,
            "runtimeState" to runtimeState.wireValue,
            "runtimeVerification" to runtimeVerification(context),
            "runtimeFailureReason" to runtimeFailureReason,
            "locationEngine" to
                if (isKeyConfigured(context)) {
                    "AMAP"
                } else {
                    "UNAVAILABLE"
                },
            "networkAvailable" to isNetworkAvailable(context),
        )

    fun mapPreferences(context: Context): Map<String, Any?> =
        mapOf(
            "mapType" to preferences(context).getString(KEY_MAP_TYPE, "STANDARD"),
            "trafficEnabled" to preferences(context).getBoolean(KEY_TRAFFIC, false),
            "compassEnabled" to preferences(context).getBoolean(KEY_COMPASS, true),
            "scaleEnabled" to preferences(context).getBoolean(KEY_SCALE, true),
        )

    fun updateMapPreferences(
        context: Context,
        values: Map<*, *>,
    ): Map<String, Any?> {
        val editor = preferences(context).edit()
        (values["mapType"] as? String)
            ?.takeIf { it in setOf("STANDARD", "SATELLITE", "NIGHT") }
            ?.let { editor.putString(KEY_MAP_TYPE, it) }
        (values["trafficEnabled"] as? Boolean)?.let { editor.putBoolean(KEY_TRAFFIC, it) }
        (values["compassEnabled"] as? Boolean)?.let { editor.putBoolean(KEY_COMPASS, it) }
        (values["scaleEnabled"] as? Boolean)?.let { editor.putBoolean(KEY_SCALE, it) }
        editor.apply()
        return mapPreferences(context)
    }

    private fun applyPrivacy(
        context: Context,
        accepted: Boolean,
    ) {
        AMapLocationClient.updatePrivacyShow(context, true, true)
        AMapLocationClient.updatePrivacyAgree(context, accepted)
        MapsInitializer.updatePrivacyShow(context, true, true)
        MapsInitializer.updatePrivacyAgree(context, accepted)
    }

    private fun markRuntimeVerified() {
        runtimeState = AmapRuntimeState.VERIFIED
        runtimeFailureReason = null
    }

    private fun sanitizeReason(value: String): String =
        value.replace(Regex("[\\r\\n\\t]+"), " ").trim().take(240)

    private fun preferences(context: Context) =
        context.applicationContext.getSharedPreferences(PREFERENCES, Context.MODE_PRIVATE)

    private fun isNetworkAvailable(context: Context): Boolean {
        val manager =
            context.getSystemService(Context.CONNECTIVITY_SERVICE) as? ConnectivityManager
                ?: return false
        val network = manager.activeNetwork ?: return false
        val capabilities = manager.getNetworkCapabilities(network) ?: return false
        return capabilities.hasCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)
    }
}
