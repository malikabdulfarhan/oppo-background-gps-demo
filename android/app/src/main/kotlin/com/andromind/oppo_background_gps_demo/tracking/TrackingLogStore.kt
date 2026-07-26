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
        var sessionId = TrackingTime.sessionId()
        var file = File(sessionsDirectory, TrackingTime.sessionFilename(sessionId))
        var suffix = 1
        while (file.exists()) {
            sessionId = "${TrackingTime.sessionId()}_$suffix"
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
            .apply()
        return TrackingSessionFile(sessionId, file)
    }

    @Synchronized
    fun currentSession(): TrackingSessionFile? {
        val sessionId = preferences.getString(KEY_SESSION_ID, null) ?: return null
        val storedPath = preferences.getString(KEY_LOG_PATH, null)
        val file =
            storedPath?.let(::File)
                ?: File(sessionsDirectory, TrackingTime.sessionFilename(sessionId))
        if (!file.exists()) {
            return null
        }
        return TrackingSessionFile(sessionId, file)
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
            )
        FileOutputStream(session.file, true).use { output ->
            OutputStreamWriter(output, StandardCharsets.UTF_8).use { writer ->
                writer.append(record.toCsvRow()).append('\n')
                writer.flush()
                output.fd.sync()
            }
        }
        val editor = preferences.edit().putLong(KEY_SEQUENCE, sequence)
        if (eventType == "LOCATION_RECEIVED" && sample != null) {
            editor
                .putString(KEY_LAST_LOCATION_TIMESTAMP, sample.timestamp)
                .putString(KEY_CURRENT_PROVIDER, sample.provider)
                .putLong(KEY_LAST_LATITUDE_BITS, sample.latitude.toBits())
                .putLong(KEY_LAST_LONGITUDE_BITS, sample.longitude.toBits())
        }
        editor.apply()
        return record
    }

    fun currentLocationRecords(): List<Map<String, Any?>> =
        currentSession()?.file?.let(::readLocationRecords).orEmpty()

    fun listSessions(): List<Map<String, Any?>> =
        sessionsDirectory
            .listFiles { file -> file.isFile && file.name.startsWith("tracking_session_") && file.extension == "csv" }
            ?.sortedByDescending(File::lastModified)
            ?.map { file ->
                mapOf(
                    "sessionId" to
                        file.name.removePrefix("tracking_session_").removeSuffix(".csv"),
                    "fileName" to file.name,
                    "path" to file.absolutePath,
                    "lastModified" to file.lastModified(),
                    "sizeBytes" to file.length(),
                )
            }.orEmpty()

    fun setTrackingActive(value: Boolean) {
        preferences.edit().putBoolean(KEY_TRACKING_ACTIVE, value).apply()
    }

    fun isTrackingActive(): Boolean = preferences.getBoolean(KEY_TRACKING_ACTIVE, false)

    fun lastLocationTimestamp(): String? =
        preferences.getString(KEY_LAST_LOCATION_TIMESTAMP, null)

    fun currentProvider(): String? = preferences.getString(KEY_CURRENT_PROVIDER, null)

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

    private fun readLocationRecords(file: File): List<Map<String, Any?>> {
        if (!file.exists()) {
            return emptyList()
        }
        return file.useLines { lines ->
            lines
                .drop(1)
                .mapNotNull(::parseLocationRow)
                .toList()
        }
    }

    private fun parseLocationRow(line: String): Map<String, Any?>? {
        val fields = parseCsvLine(line)
        if (fields.size < 13 || fields[12] != "LOCATION_RECEIVED") {
            return null
        }
        val sequence = fields[0].toLongOrNull() ?: return null
        val latitude = fields[2].toDoubleOrNull() ?: return null
        val longitude = fields[3].toDoubleOrNull() ?: return null
        val accuracy = fields[4].toDoubleOrNull() ?: return null
        if (!TrackingValidator.isValid(latitude, longitude, accuracy.toFloat())) {
            return null
        }
        return mapOf(
            "type" to "location",
            "sequence" to sequence,
            "timestamp" to fields[1],
            "latitude" to latitude,
            "longitude" to longitude,
            "accuracy" to accuracy,
            "provider" to fields[5],
            "speed" to fields[6].toDoubleOrNull(),
            "bearing" to fields[7].toDoubleOrNull(),
            "altitude" to fields[8].toDoubleOrNull(),
            "batteryPercent" to fields[9].toIntOrNull(),
            "screenState" to fields[10],
            "appProcessState" to fields[11],
        )
    }

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
        private const val PREFERENCES_NAME = "tracking_service_state"
        private const val KEY_SESSION_ID = "session_id"
        private const val KEY_LOG_PATH = "log_path"
        private const val KEY_SEQUENCE = "sequence"
        private const val KEY_TRACKING_ACTIVE = "tracking_active"
        private const val KEY_LAST_LOCATION_TIMESTAMP = "last_location_timestamp"
        private const val KEY_CURRENT_PROVIDER = "current_provider"
        private const val KEY_LAST_LATITUDE_BITS = "last_latitude_bits"
        private const val KEY_LAST_LONGITUDE_BITS = "last_longitude_bits"
    }
}

internal data class TrackingSessionFile(
    val sessionId: String,
    val file: File,
)
