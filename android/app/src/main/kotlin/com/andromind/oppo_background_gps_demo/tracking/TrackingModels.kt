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
)

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
        )

    companion object {
        const val CSV_HEADER =
            "sequence,timestamp,latitude,longitude,accuracy_m,provider," +
                "speed_mps,bearing_deg,altitude_m,battery_percent,screen_state," +
                "app_process_state,event_type,message"

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
