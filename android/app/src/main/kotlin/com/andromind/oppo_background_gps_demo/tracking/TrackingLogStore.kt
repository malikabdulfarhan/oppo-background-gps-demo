package com.andromind.oppo_background_gps_demo.tracking

import android.content.Context
import java.io.File
import java.io.FileOutputStream
import java.io.OutputStreamWriter
import java.nio.charset.StandardCharsets

internal class TrackingLogStore(context: Context) {
    private val applicationContext = context.applicationContext
    private val sessionsDirectory =
        File(applicationContext.filesDir, "tracking_sessions").apply { mkdirs() }
    private val preferences =
        applicationContext.getSharedPreferences(PREFERENCES_NAME, Context.MODE_PRIVATE)

    @Synchronized
    fun createSession(): TrackingSessionFile {
        val timestamp = TrackingTime.sessionId()
        var sessionId = timestamp
        var file = File(sessionsDirectory, TrackingTime.sessionFilename(sessionId))
        var suffix = 1
        while (file.exists()) {
            sessionId = "${timestamp}_$suffix"
            file = File(sessionsDirectory, TrackingTime.sessionFilename(sessionId))
            suffix += 1
        }
        file.parentFile?.mkdirs()
        file.writeText("${TrackingCsvRecord.CSV_HEADER}\n", StandardCharsets.UTF_8)
        preferences.edit()
            .putString(KEY_SESSION_ID, sessionId)
            .putString(KEY_LOG_PATH, file.absolutePath)
            .putLong(KEY_SEQUENCE, 0)
            .remove(KEY_LAST_LOCATION_TIMESTAMP)
            .remove(KEY_CURRENT_PROVIDER)
            .remove(KEY_LAST_AMAP_LOCATION_TYPE)
            .remove(KEY_LAST_AMAP_ERROR_CODE)
            .remove(KEY_LAST_AMAP_ERROR_MESSAGE)
            .remove(KEY_SATELLITE_COUNT)
            .remove(KEY_GPS_ACCURACY_STATUS)
            .remove(KEY_COORDINATE_SYSTEM)
            .remove(KEY_SESSION_LOCATION_ENGINE)
            .apply()
        return TrackingSessionFile(sessionId, file)
    }

    @Synchronized
    fun currentSession(): TrackingSessionFile? {
        val sessionId = preferences.getString(KEY_SESSION_ID, null) ?: return null
        if (!isSafeSessionId(sessionId)) {
            return null
        }
        return sessionForId(sessionId)
    }

    @Synchronized
    fun currentOrCreateSession(): TrackingSessionFile = currentSession() ?: createSession()

    @Synchronized
    fun append(
        eventType: String,
        sample: TrackingSample? = null,
        message: String? = null,
    ): TrackingCsvRecord {
        val session = currentOrCreateSession()
        val sequence = preferences.getLong(KEY_SEQUENCE, 0) + 1
        val record =
            TrackingCsvRecord(
                sequence = sequence,
                timestamp = sample?.timestamp ?: TrackingTime.nowIso(),
                latitude = sample?.latitude,
                longitude = sample?.longitude,
                accuracy = sample?.accuracy,
                provider = sample?.provider,
                speed = sample?.speed,
                bearing = sample?.bearing,
                altitude = sample?.altitude,
                batteryPercent = sample?.batteryPercent,
                screenState = sample?.screenState,
                appProcessState = sample?.appProcessState,
                eventType = eventType,
                message = message,
                locationEngine =
                    sample?.locationEngine
                        ?: currentLocationEngine()
                        ?: LocationEngineType.ANDROID_LOCATION_MANAGER.wireValue,
                amapLocationType = sample?.amapLocationType,
                amapErrorCode = sample?.amapErrorCode,
                amapErrorInfo = sample?.amapErrorInfo,
                gpsAccuracyStatus = sample?.gpsAccuracyStatus,
                satelliteCount = sample?.satelliteCount,
                isMock = sample?.isMock,
                coordinateSystem = sample?.coordinateSystem,
                country = sample?.country,
                province = sample?.province,
                city = sample?.city,
                district = sample?.district,
                street = sample?.street,
                address = sample?.address,
            )
        FileOutputStream(session.file, true).use { output ->
            OutputStreamWriter(output, StandardCharsets.UTF_8).use { writer ->
                writer.append(record.toCsvRow()).append('\n')
                writer.flush()
                output.fd.sync()
            }
        }
        updateState(record, sample)
        return record
    }

    fun currentLocationRecords(): List<Map<String, Any?>> =
        currentSession()?.let { readSession(it.sessionId).records }.orEmpty()

    fun readSession(sessionId: String): SessionReadResult {
        val session = sessionForId(sessionId) ?: return SessionReadResult()
        return parseSession(session.file)
    }

    fun listSessions(): List<Map<String, Any?>> =
        sessionFiles()
            .sortedByDescending(File::lastModified)
            .map(::sessionSummary)

    fun deleteSession(sessionId: String): SessionOperationResult {
        val session = sessionForId(sessionId)
            ?: return SessionOperationResult(false, "Session was not found.")
        if (
            !canDeleteSession(
                requestedSessionId = sessionId,
                activeSessionId = currentSession()?.sessionId,
                isTracking = isTrackingActive(),
            )
        ) {
            return SessionOperationResult(
                false,
                "The active tracking session cannot be deleted.",
            )
        }
        return if (session.file.delete()) {
            SessionOperationResult(true, "Session deleted.")
        } else {
            SessionOperationResult(false, "Android could not delete this session.")
        }
    }

    fun sessionForId(sessionId: String): TrackingSessionFile? {
        if (!isSafeSessionId(sessionId)) {
            return null
        }
        val file = File(sessionsDirectory, TrackingTime.sessionFilename(sessionId))
        val rootPath = sessionsDirectory.canonicalFile.toPath()
        val candidatePath = file.canonicalFile.toPath()
        if (!candidatePath.startsWith(rootPath) || !file.isFile) {
            return null
        }
        return TrackingSessionFile(sessionId, file)
    }

    fun setTrackingActive(value: Boolean) {
        preferences.edit().putBoolean(KEY_TRACKING_ACTIVE, value).apply()
    }

    fun isTrackingActive(): Boolean = preferences.getBoolean(KEY_TRACKING_ACTIVE, false)

    fun lastLocationTimestamp(): String? =
        preferences.getString(KEY_LAST_LOCATION_TIMESTAMP, null)

    fun currentProvider(): String? = preferences.getString(KEY_CURRENT_PROVIDER, null)

    fun setSessionLocationEngine(engine: LocationEngineType) {
        preferences.edit().putString(KEY_SESSION_LOCATION_ENGINE, engine.wireValue).apply()
    }

    fun currentLocationEngine(): String? =
        preferences.getString(KEY_SESSION_LOCATION_ENGINE, null)

    fun lastAmapLocationType(): Int? =
        preferences.optionalInt(KEY_LAST_AMAP_LOCATION_TYPE)

    fun lastAmapErrorCode(): Int? = preferences.optionalInt(KEY_LAST_AMAP_ERROR_CODE)

    fun lastAmapErrorMessage(): String? =
        preferences.getString(KEY_LAST_AMAP_ERROR_MESSAGE, null)

    fun satelliteCount(): Int? = preferences.optionalInt(KEY_SATELLITE_COUNT)

    fun gpsAccuracyStatus(): Int? = preferences.optionalInt(KEY_GPS_ACCURACY_STATUS)

    fun coordinateSystem(): String? = preferences.getString(KEY_COORDINATE_SYSTEM, null)

    fun lastCoordinates(): Pair<Double?, Double?> {
        val latitude =
            if (preferences.contains(KEY_LAST_LATITUDE_BITS)) {
                Double.fromBits(preferences.getLong(KEY_LAST_LATITUDE_BITS, 0))
            } else {
                null
            }
        val longitude =
            if (preferences.contains(KEY_LAST_LONGITUDE_BITS)) {
                Double.fromBits(preferences.getLong(KEY_LAST_LONGITUDE_BITS, 0))
            } else {
                null
            }
        return latitude to longitude
    }

    private fun updateState(
        record: TrackingCsvRecord,
        sample: TrackingSample?,
    ) {
        val editor = preferences.edit().putLong(KEY_SEQUENCE, record.sequence)
        if (record.eventType == "LOCATION_RECEIVED" && sample != null) {
            editor
                .putString(KEY_LAST_LOCATION_TIMESTAMP, sample.timestamp)
                .putString(KEY_CURRENT_PROVIDER, sample.provider)
                .putLong(KEY_LAST_LATITUDE_BITS, sample.latitude.toBits())
                .putLong(KEY_LAST_LONGITUDE_BITS, sample.longitude.toBits())
                .putString(KEY_COORDINATE_SYSTEM, sample.coordinateSystem)
            sample.amapLocationType?.let { editor.putInt(KEY_LAST_AMAP_LOCATION_TYPE, it) }
            sample.satelliteCount?.let { editor.putInt(KEY_SATELLITE_COUNT, it) }
            sample.gpsAccuracyStatus?.let { editor.putInt(KEY_GPS_ACCURACY_STATUS, it) }
        }
        if (record.eventType == "AMAP_LOCATION_ERROR" && sample != null) {
            sample.amapErrorCode?.let { editor.putInt(KEY_LAST_AMAP_ERROR_CODE, it) }
            sample.amapErrorInfo?.let { editor.putString(KEY_LAST_AMAP_ERROR_MESSAGE, it) }
        }
        editor.apply()
    }

    private fun parseSession(file: File): SessionReadResult {
        if (!file.exists()) {
            return SessionReadResult()
        }
        val lines = file.readLines(StandardCharsets.UTF_8)
        if (lines.isEmpty()) {
            return SessionReadResult()
        }
        val headers = parseCsvLine(lines.first())
        val indexes = headers.withIndex().associate { it.value to it.index }
        val records = mutableListOf<Map<String, Any?>>()
        var skippedRows = 0
        var lifecycleRows = 0
        var amapErrors = 0
        var firstTimestamp: String? = null
        var lastTimestamp: String? = null
        var engine = if ("location_engine" in indexes) "UNKNOWN" else "LEGACY"

        lines.drop(1).forEach { line ->
            if (line.isBlank()) {
                return@forEach
            }
            val fields = parseCsvLine(line)
            if (fields.size < headers.size || fields.value(indexes, "event_type") == null) {
                skippedRows += 1
                return@forEach
            }
            val eventType = fields.value(indexes, "event_type").orEmpty()
            fields.value(indexes, "location_engine")
                ?.takeIf(String::isNotBlank)
                ?.let { rowEngine ->
                    if (engine == "UNKNOWN") {
                        engine = rowEngine
                    }
                }
            val timestamp = fields.value(indexes, "timestamp")
            if (timestamp != null) {
                if (firstTimestamp == null) firstTimestamp = timestamp
                lastTimestamp = timestamp
            }
            if (eventType == "AMAP_LOCATION_ERROR") {
                amapErrors += 1
            }
            if (eventType != "LOCATION_RECEIVED") {
                lifecycleRows += 1
                return@forEach
            }
            val location = parseLocation(fields, indexes)
            if (location == null) {
                skippedRows += 1
            } else {
                records += location
                engine = (location["locationEngine"] as? String) ?: engine
            }
        }
        return SessionReadResult(
            records = records,
            skippedRows = skippedRows,
            lifecycleRows = lifecycleRows,
            amapErrorCount = amapErrors,
            startTimestamp = firstTimestamp,
            endTimestamp = lastTimestamp,
            locationEngine = engine,
        )
    }

    private fun parseLocation(
        fields: List<String>,
        indexes: Map<String, Int>,
    ): Map<String, Any?>? {
        val sequence = fields.value(indexes, "sequence")?.toLongOrNull() ?: return null
        val timestamp = fields.value(indexes, "timestamp") ?: return null
        val latitude = fields.value(indexes, "latitude")?.toDoubleOrNull() ?: return null
        val longitude = fields.value(indexes, "longitude")?.toDoubleOrNull() ?: return null
        val accuracy = fields.value(indexes, "accuracy_m")?.toDoubleOrNull() ?: return null
        if (!TrackingValidator.isValid(latitude, longitude, accuracy.toFloat())) {
            return null
        }
        val legacy = "location_engine" !in indexes
        return mapOf(
            "type" to "location",
            "sequence" to sequence,
            "timestamp" to timestamp,
            "latitude" to latitude,
            "longitude" to longitude,
            "accuracy" to accuracy,
            "provider" to fields.value(indexes, "provider"),
            "speed" to fields.value(indexes, "speed_mps")?.toDoubleOrNull(),
            "bearing" to fields.value(indexes, "bearing_deg")?.toDoubleOrNull(),
            "altitude" to fields.value(indexes, "altitude_m")?.toDoubleOrNull(),
            "batteryPercent" to fields.value(indexes, "battery_percent")?.toIntOrNull(),
            "screenState" to fields.value(indexes, "screen_state"),
            "appProcessState" to fields.value(indexes, "app_process_state"),
            "locationEngine" to (
                fields.value(indexes, "location_engine")?.ifBlank { null }
                    ?: if (legacy) "LEGACY" else "AMAP"
            ),
            "amapLocationType" to
                fields.value(indexes, "amap_location_type")?.toIntOrNull(),
            "amapErrorCode" to fields.value(indexes, "amap_error_code")?.toIntOrNull(),
            "amapErrorInfo" to fields.value(indexes, "amap_error_info"),
            "gpsAccuracyStatus" to
                fields.value(indexes, "gps_accuracy_status")?.toIntOrNull(),
            "satelliteCount" to
                fields.value(indexes, "satellite_count")?.toIntOrNull(),
            "isMock" to fields.value(indexes, "is_mock")?.toBooleanStrictOrNull(),
            "coordinateSystem" to (
                fields.value(indexes, "coordinate_system")?.ifBlank { null }
                    ?: if (legacy) "WGS84_LEGACY" else "GCJ02"
            ),
            "country" to fields.value(indexes, "country"),
            "province" to fields.value(indexes, "province"),
            "city" to fields.value(indexes, "city"),
            "district" to fields.value(indexes, "district"),
            "street" to fields.value(indexes, "street"),
            "address" to fields.value(indexes, "address"),
        )
    }

    private fun sessionSummary(file: File): Map<String, Any?> {
        val sessionId = file.name.removePrefix(FILE_PREFIX).removeSuffix(FILE_SUFFIX)
        val parsed = parseSession(file)
        var routePointCount = 0
        var previousLatitude: Double? = null
        var previousLongitude: Double? = null
        parsed.records.forEach { record ->
            val latitude = record["latitude"] as? Double
            val longitude = record["longitude"] as? Double
            if (
                latitude != null &&
                longitude != null &&
                !TrackingValidator.isDuplicate(
                    latitude,
                    longitude,
                    previousLatitude,
                    previousLongitude,
                )
            ) {
                routePointCount += 1
                previousLatitude = latitude
                previousLongitude = longitude
            }
        }
        return mapOf(
            "sessionId" to sessionId,
            "fileName" to file.name,
            "lastModified" to file.lastModified(),
            "sizeBytes" to file.length(),
            "startTimestamp" to parsed.startTimestamp,
            "endTimestamp" to parsed.endTimestamp,
            "isActive" to (isTrackingActive() && currentSession()?.sessionId == sessionId),
            "locationEngine" to parsed.locationEngine,
            "sampleCount" to parsed.records.size,
            "routePointCount" to routePointCount,
            "skippedRows" to parsed.skippedRows,
            "amapErrorCount" to parsed.amapErrorCount,
        )
    }

    private fun sessionFiles(): List<File> =
        sessionsDirectory
            .listFiles { file ->
                file.isFile && file.name.startsWith(FILE_PREFIX) && file.name.endsWith(FILE_SUFFIX)
            }?.toList()
            .orEmpty()

    private fun parseCsvLine(line: String): List<String> {
        val fields = mutableListOf<String>()
        val value = StringBuilder()
        var quoted = false
        var index = 0
        while (index < line.length) {
            val character = line[index]
            when {
                character == '"' && quoted && index + 1 < line.length && line[index + 1] == '"' -> {
                    value.append('"')
                    index += 1
                }
                character == '"' -> quoted = !quoted
                character == ',' && !quoted -> {
                    fields += value.toString()
                    value.clear()
                }
                else -> value.append(character)
            }
            index += 1
        }
        fields += value.toString()
        return fields
    }

    companion object {
        private const val FILE_PREFIX = "tracking_session_"
        private const val FILE_SUFFIX = ".csv"
        private val SAFE_SESSION_ID = Regex("^[A-Za-z0-9_-]{1,96}$")
        private const val PREFERENCES_NAME = "tracking_service_state"
        private const val KEY_SESSION_ID = "session_id"
        private const val KEY_LOG_PATH = "log_path"
        private const val KEY_SEQUENCE = "sequence"
        private const val KEY_TRACKING_ACTIVE = "tracking_active"
        private const val KEY_LAST_LOCATION_TIMESTAMP = "last_location_timestamp"
        private const val KEY_CURRENT_PROVIDER = "current_provider"
        private const val KEY_LAST_LATITUDE_BITS = "last_latitude_bits"
        private const val KEY_LAST_LONGITUDE_BITS = "last_longitude_bits"
        private const val KEY_LAST_AMAP_LOCATION_TYPE = "last_amap_location_type"
        private const val KEY_LAST_AMAP_ERROR_CODE = "last_amap_error_code"
        private const val KEY_LAST_AMAP_ERROR_MESSAGE = "last_amap_error_message"
        private const val KEY_SATELLITE_COUNT = "satellite_count"
        private const val KEY_GPS_ACCURACY_STATUS = "gps_accuracy_status"
        private const val KEY_COORDINATE_SYSTEM = "coordinate_system"
        private const val KEY_SESSION_LOCATION_ENGINE = "session_location_engine"

        fun isSafeSessionId(sessionId: String): Boolean = SAFE_SESSION_ID.matches(sessionId)

        fun canDeleteSession(
            requestedSessionId: String,
            activeSessionId: String?,
            isTracking: Boolean,
        ): Boolean = !isTracking || requestedSessionId != activeSessionId
    }
}

private fun List<String>.value(
    indexes: Map<String, Int>,
    key: String,
): String? {
    val index = indexes[key] ?: return null
    return getOrNull(index)
}

private fun android.content.SharedPreferences.optionalInt(key: String): Int? =
    if (contains(key)) getInt(key, 0) else null

internal data class TrackingSessionFile(
    val sessionId: String,
    val file: File,
)

internal data class SessionReadResult(
    val records: List<Map<String, Any?>> = emptyList(),
    val skippedRows: Int = 0,
    val lifecycleRows: Int = 0,
    val amapErrorCount: Int = 0,
    val startTimestamp: String? = null,
    val endTimestamp: String? = null,
    val locationEngine: String = "LEGACY",
) {
    fun toMap(): Map<String, Any?> =
        mapOf(
            "records" to records,
            "skippedRows" to skippedRows,
            "lifecycleRows" to lifecycleRows,
            "amapErrorCount" to amapErrorCount,
            "startTimestamp" to startTimestamp,
            "endTimestamp" to endTimestamp,
            "locationEngine" to locationEngine,
        )
}

internal data class SessionOperationResult(
    val success: Boolean,
    val message: String,
) {
    fun toMap(): Map<String, Any?> = mapOf("success" to success, "message" to message)
}
