package com.andromind.oppo_background_gps_demo.tracking

import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.TimeZone

internal data class TrackingSample(
    val timestamp: String,
    val latitude: Double,
    val longitude: Double,
    val accuracy: Float,
    val provider: String,
    val speed: Float?,
    val bearing: Float?,
    val altitude: Double?,
    val batteryPercent: Int?,
    val screenState: String,
    val appProcessState: String,
    val locationEngine: String = "AMAP",
    val amapLocationType: Int? = null,
    val amapErrorCode: Int? = null,
    val amapErrorInfo: String? = null,
    val gpsAccuracyStatus: Int? = null,
    val satelliteCount: Int? = null,
    val isMock: Boolean? = null,
    val coordinateSystem: String = "GCJ02",
    val country: String? = null,
    val province: String? = null,
    val city: String? = null,
    val district: String? = null,
    val street: String? = null,
    val address: String? = null,
)

internal data class AmapLocationSnapshot(
    val timestampMillis: Long,
    val latitude: Double,
    val longitude: Double,
    val accuracy: Float,
    val provider: String?,
    val speed: Float,
    val bearing: Float,
    val altitude: Double,
    val locationType: Int,
    val errorCode: Int,
    val errorInfo: String?,
    val gpsAccuracyStatus: Int,
    val satelliteCount: Int,
    val isMock: Boolean,
    val coordinateSystem: String?,
    val country: String?,
    val province: String?,
    val city: String?,
    val district: String?,
    val street: String?,
    val address: String?,
)

internal object AmapSampleMapper {
    fun map(
        snapshot: AmapLocationSnapshot,
        batteryPercent: Int?,
        screenState: String,
        appProcessState: String,
    ): TrackingSample =
        TrackingSample(
            timestamp = TrackingTime.format(Date(snapshot.timestampMillis)),
            latitude = snapshot.latitude,
            longitude = snapshot.longitude,
            accuracy = snapshot.accuracy,
            provider = snapshot.provider?.takeIf(String::isNotBlank) ?: "amap",
            speed = snapshot.speed.takeIf(Float::isFinite),
            bearing = snapshot.bearing.takeIf(Float::isFinite),
            altitude = snapshot.altitude.takeIf(Double::isFinite),
            batteryPercent = batteryPercent,
            screenState = screenState,
            appProcessState = appProcessState,
            amapLocationType = snapshot.locationType,
            amapErrorCode = snapshot.errorCode,
            amapErrorInfo = snapshot.errorInfo?.take(240),
            gpsAccuracyStatus = snapshot.gpsAccuracyStatus,
            satelliteCount = snapshot.satelliteCount,
            isMock = snapshot.isMock,
            coordinateSystem = snapshot.coordinateSystem?.uppercase(Locale.US) ?: "GCJ02",
            country = snapshot.country,
            province = snapshot.province,
            city = snapshot.city,
            district = snapshot.district,
            street = snapshot.street,
            address = snapshot.address,
        )
}

internal data class TrackingCsvRecord(
    val sequence: Long,
    val timestamp: String,
    val latitude: Double? = null,
    val longitude: Double? = null,
    val accuracy: Float? = null,
    val provider: String? = null,
    val speed: Float? = null,
    val bearing: Float? = null,
    val altitude: Double? = null,
    val batteryPercent: Int? = null,
    val screenState: String? = null,
    val appProcessState: String? = null,
    val eventType: String,
    val message: String? = null,
    val locationEngine: String? = null,
    val amapLocationType: Int? = null,
    val amapErrorCode: Int? = null,
    val amapErrorInfo: String? = null,
    val gpsAccuracyStatus: Int? = null,
    val satelliteCount: Int? = null,
    val isMock: Boolean? = null,
    val coordinateSystem: String? = null,
    val country: String? = null,
    val province: String? = null,
    val city: String? = null,
    val district: String? = null,
    val street: String? = null,
    val address: String? = null,
) {
    fun toCsvRow(): String =
        listOf(
            sequence,
            timestamp,
            latitude,
            longitude,
            accuracy,
            provider,
            speed,
            bearing,
            altitude,
            batteryPercent,
            screenState,
            appProcessState,
            eventType,
            message,
            locationEngine,
            amapLocationType,
            amapErrorCode,
            amapErrorInfo,
            gpsAccuracyStatus,
            satelliteCount,
            isMock,
            coordinateSystem,
            country,
            province,
            city,
            district,
            street,
            address,
        ).joinToString(",") { csvEscape(it?.toString().orEmpty()) }

    fun toLocationMap(): Map<String, Any?> =
        mapOf(
            "type" to "location",
            "sequence" to sequence,
            "timestamp" to timestamp,
            "latitude" to latitude,
            "longitude" to longitude,
            "accuracy" to accuracy?.toDouble(),
            "provider" to provider,
            "speed" to speed?.toDouble(),
            "bearing" to bearing?.toDouble(),
            "altitude" to altitude,
            "batteryPercent" to batteryPercent,
            "screenState" to screenState,
            "appProcessState" to appProcessState,
            "locationEngine" to locationEngine,
            "amapLocationType" to amapLocationType,
            "amapErrorCode" to amapErrorCode,
            "amapErrorInfo" to amapErrorInfo,
            "gpsAccuracyStatus" to gpsAccuracyStatus,
            "satelliteCount" to satelliteCount,
            "isMock" to isMock,
            "coordinateSystem" to coordinateSystem,
            "country" to country,
            "province" to province,
            "city" to city,
            "district" to district,
            "street" to street,
            "address" to address,
        )

    companion object {
        const val SCHEMA_VERSION = "4"
        const val CSV_HEADER =
            "sequence,timestamp,latitude,longitude,accuracy_m,provider," +
                "speed_mps,bearing_deg,altitude_m,battery_percent,screen_state," +
                "app_process_state,event_type,message,location_engine,amap_location_type," +
                "amap_error_code,amap_error_info,gps_accuracy_status,satellite_count,is_mock," +
                "coordinate_system,country,province,city,district,street,address"

        private fun csvEscape(value: String): String {
            if (value.none { it == ',' || it == '"' || it == '\n' || it == '\r' }) {
                return value
            }
            return "\"${value.replace("\"", "\"\"")}\""
        }
    }
}

internal data class TrackingStatus(
    val isTracking: Boolean,
    val serviceRunning: Boolean,
    val sessionId: String?,
    val lastLocationTimestamp: String?,
    val currentLogPath: String?,
    val currentProvider: String?,
    val screenState: String?,
    val notificationPermissionGranted: Boolean,
    val amapApiKeyConfigured: Boolean = false,
    val amapPrivacyConsent: String = "NOT_SELECTED",
    val amapSdkInitialized: Boolean = false,
    val locationEngine: String = "UNAVAILABLE",
    val lastAmapLocationType: Int? = null,
    val lastAmapErrorCode: Int? = null,
    val lastAmapErrorMessage: String? = null,
    val satelliteCount: Int? = null,
    val gpsAccuracyStatus: Int? = null,
    val coordinateSystem: String? = null,
    val selectedLocationEngine: String = "AUTOMATIC",
    val activeLocationEngine: String? = null,
    val fallbackReason: String? = null,
    val amapSdkCompileIntegration: Boolean = true,
    val amapRuntimeState: String = "NOT_ATTEMPTED",
    val amapRuntimeVerification: String = "PENDING_API_KEY",
    val locationPermissionGranted: Boolean = false,
    val csvSchemaVersion: String = TrackingCsvRecord.SCHEMA_VERSION,
) {
    fun toMap(): Map<String, Any?> =
        mapOf(
            "isTracking" to isTracking,
            "serviceRunning" to serviceRunning,
            "sessionId" to sessionId,
            "lastLocationTimestamp" to lastLocationTimestamp,
            "currentLogPath" to currentLogPath,
            "currentProvider" to currentProvider,
            "screenState" to screenState,
            "notificationPermissionGranted" to notificationPermissionGranted,
            "amapApiKeyConfigured" to amapApiKeyConfigured,
            "amapPrivacyConsent" to amapPrivacyConsent,
            "amapSdkInitialized" to amapSdkInitialized,
            "locationEngine" to locationEngine,
            "lastAmapLocationType" to lastAmapLocationType,
            "lastAmapErrorCode" to lastAmapErrorCode,
            "lastAmapErrorMessage" to lastAmapErrorMessage,
            "satelliteCount" to satelliteCount,
            "gpsAccuracyStatus" to gpsAccuracyStatus,
            "coordinateSystem" to coordinateSystem,
            "selectedLocationEngine" to selectedLocationEngine,
            "activeLocationEngine" to activeLocationEngine,
            "fallbackReason" to fallbackReason,
            "amapSdkCompileIntegration" to amapSdkCompileIntegration,
            "amapRuntimeState" to amapRuntimeState,
            "amapRuntimeVerification" to amapRuntimeVerification,
            "locationPermissionGranted" to locationPermissionGranted,
            "csvSchemaVersion" to csvSchemaVersion,
        )
}

internal object TrackingValidator {
    fun isValid(
        latitude: Double,
        longitude: Double,
        accuracy: Float,
    ): Boolean =
        latitude.isFinite() &&
            longitude.isFinite() &&
            accuracy.isFinite() &&
            latitude in -90.0..90.0 &&
            longitude in -180.0..180.0 &&
            accuracy >= 0f

    fun isDuplicate(
        latitude: Double,
        longitude: Double,
        previousLatitude: Double?,
        previousLongitude: Double?,
    ): Boolean = previousLatitude == latitude && previousLongitude == longitude
}

internal object TrackingTime {
    fun nowIso(): String = format(Date())

    fun format(date: Date): String =
        SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'", Locale.US)
            .apply { timeZone = TimeZone.getTimeZone("UTC") }
            .format(date)

    fun sessionId(date: Date = Date()): String =
        SimpleDateFormat("yyyyMMdd_HHmmss_SSS", Locale.US)
            .apply { timeZone = TimeZone.getTimeZone("UTC") }
            .format(date)

    fun sessionFilename(sessionId: String): String = "tracking_session_$sessionId.csv"
}
