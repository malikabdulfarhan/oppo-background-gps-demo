package com.andromind.oppo_background_gps_demo.tracking

import java.util.Date
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class TrackingModelsTest {
    @Test
    fun csvSerializationEscapesMessagesAndPreservesColumns() {
        val record =
            TrackingCsvRecord(
                sequence = 4,
                timestamp = "2026-07-26T12:00:00.000Z",
                latitude = 24.861,
                longitude = 67.002,
                accuracy = 4.2f,
                provider = "gps",
                eventType = "LOCATION_RECEIVED",
                message = "value, with \"quotes\"",
            )

        val row = record.toCsvRow()

        assertTrue(row.startsWith("4,2026-07-26T12:00:00.000Z,24.861,67.002,4.2,gps"))
        assertTrue(row.endsWith("\"value, with \"\"quotes\"\"\""))
        assertEquals(14, TrackingCsvRecord.CSV_HEADER.split(",").size)
    }

    @Test
    fun sessionFilenameUsesExpectedStablePattern() {
        assertEquals(
            "tracking_session_19700101_000000_000.csv",
            TrackingTime.sessionFilename(TrackingTime.sessionId(Date(0))),
        )
    }

    @Test
    fun invalidCoordinatesAndAccuracyAreRejected() {
        assertTrue(TrackingValidator.isValid(24.861, 67.002, 3.5f))
        assertFalse(TrackingValidator.isValid(91.0, 67.002, 3.5f))
        assertFalse(TrackingValidator.isValid(24.861, -181.0, 3.5f))
        assertFalse(TrackingValidator.isValid(24.861, 67.002, -1f))
        assertFalse(TrackingValidator.isValid(Double.NaN, 67.002, 3.5f))
    }

    @Test
    fun exactConsecutiveCoordinatesAreDuplicates() {
        assertTrue(TrackingValidator.isDuplicate(24.861, 67.002, 24.861, 67.002))
        assertFalse(TrackingValidator.isDuplicate(24.862, 67.002, 24.861, 67.002))
        assertFalse(TrackingValidator.isDuplicate(24.861, 67.002, null, null))
    }

    @Test
    fun trackingStatusSerializesExpectedFields() {
        val map =
            TrackingStatus(
                isTracking = true,
                serviceRunning = true,
                sessionId = "session-1",
                lastLocationTimestamp = "2026-07-26T12:00:00.000Z",
                currentLogPath = "/private/tracking.csv",
                currentProvider = "gps",
                screenState = "LOCKED",
                notificationPermissionGranted = false,
            ).toMap()

        assertEquals(true, map["isTracking"])
        assertEquals("session-1", map["sessionId"])
        assertEquals("gps", map["currentProvider"])
        assertEquals(false, map["notificationPermissionGranted"])
    }
}
