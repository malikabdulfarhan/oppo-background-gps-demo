package com.andromind.oppo_background_gps_demo.tracking

import com.andromind.oppo_background_gps_demo.amap.AmapSdkConfiguration
import java.util.Date
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class TrackingModelsTest {
    @Test
    fun emptyAndPlaceholderAmapKeysAreNotConfigured() {
        assertFalse(AmapSdkConfiguration.isKeyValueConfigured(null))
        assertFalse(AmapSdkConfiguration.isKeyValueConfigured("  "))
        assertFalse(AmapSdkConfiguration.isKeyValueConfigured("YOUR_AMAP_ANDROID_KEY"))
        assertTrue(AmapSdkConfiguration.isKeyValueConfigured("configured-key"))
    }

    @Test
    fun automaticSelectionFallsBackWithoutAttemptingAmapWhenKeyIsMissing() {
        val selection =
            LocationEngineSelector.select(
                preference = LocationEnginePreference.AUTOMATIC,
                amapKeyConfigured = false,
                amapPrivacyAccepted = true,
                amapRuntimeFailed = false,
            )

        assertEquals(LocationEngineType.ANDROID_LOCATION_MANAGER, selection.engine)
        assertTrue(selection.fallbackReason!!.contains("not configured"))
    }

    @Test
    fun explicitAndroidSelectionNeverRequiresAmap() {
        val selection =
            LocationEngineSelector.select(
                preference = LocationEnginePreference.ANDROID_GPS_DEMO,
                amapKeyConfigured = true,
                amapPrivacyAccepted = true,
                amapRuntimeFailed = false,
            )

        assertEquals(LocationEngineType.ANDROID_LOCATION_MANAGER, selection.engine)
        assertEquals(null, selection.fallbackReason)
    }

    @Test
    fun amapRuntimeFailureFallsBackToAndroidLocationManager() {
        val selection =
            LocationEngineSelector.select(
                preference = LocationEnginePreference.AUTOMATIC,
                amapKeyConfigured = true,
                amapPrivacyAccepted = true,
                amapRuntimeFailed = true,
            )

        assertEquals(LocationEngineType.ANDROID_LOCATION_MANAGER, selection.engine)
        assertTrue(selection.fallbackReason!!.contains("initialization failed"))
    }

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
        assertTrue(row.contains("\"value, with \"\"quotes\"\"\""))
        assertEquals(28, TrackingCsvRecord.CSV_HEADER.split(",").size)
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
                amapApiKeyConfigured = true,
                amapPrivacyConsent = "ACCEPTED",
                amapSdkInitialized = true,
                locationEngine = "AMAP",
                lastAmapLocationType = 1,
                coordinateSystem = "GCJ02",
            ).toMap()

        assertEquals(true, map["isTracking"])
        assertEquals("session-1", map["sessionId"])
        assertEquals("gps", map["currentProvider"])
        assertEquals(false, map["notificationPermissionGranted"])
        assertEquals(true, map["amapApiKeyConfigured"])
        assertEquals("AMAP", map["locationEngine"])
        assertEquals("GCJ02", map["coordinateSystem"])
        assertEquals("AUTOMATIC", map["selectedLocationEngine"])
        assertEquals("4", map["csvSchemaVersion"])
        assertFalse(map.containsKey("apiKey"))
        assertFalse(map.containsKey("sha1"))
    }

    @Test
    fun amapCallbackMapsAllDiagnosticFields() {
        val sample =
            AmapSampleMapper.map(
                AmapLocationSnapshot(
                    timestampMillis = 0,
                    latitude = 24.861,
                    longitude = 67.002,
                    accuracy = 4.2f,
                    provider = "gps",
                    speed = 1.5f,
                    bearing = 30f,
                    altitude = 12.0,
                    locationType = 1,
                    errorCode = 0,
                    errorInfo = null,
                    gpsAccuracyStatus = 1,
                    satelliteCount = 8,
                    isMock = false,
                    coordinateSystem = "gcj02",
                    country = null,
                    province = null,
                    city = null,
                    district = null,
                    street = null,
                    address = null,
                ),
                batteryPercent = 80,
                screenState = "LOCKED",
                appProcessState = "BACKGROUND",
            )

        assertEquals("AMAP", sample.locationEngine)
        assertEquals(1, sample.amapLocationType)
        assertEquals(8, sample.satelliteCount)
        assertEquals("GCJ02", sample.coordinateSystem)
        assertEquals("LOCKED", sample.screenState)
    }

    @Test
    fun amapErrorCodeAndMessageRemainAvailableForLifecycleLogging() {
        val sample =
            AmapSampleMapper.map(
                AmapLocationSnapshot(
                    timestampMillis = 0,
                    latitude = 0.0,
                    longitude = 0.0,
                    accuracy = 0f,
                    provider = null,
                    speed = 0f,
                    bearing = 0f,
                    altitude = 0.0,
                    locationType = 0,
                    errorCode = 12,
                    errorInfo = "network unavailable",
                    gpsAccuracyStatus = 0,
                    satelliteCount = 0,
                    isMock = false,
                    coordinateSystem = null,
                    country = null,
                    province = null,
                    city = null,
                    district = null,
                    street = null,
                    address = null,
                ),
                batteryPercent = null,
                screenState = "UNKNOWN",
                appProcessState = "UNKNOWN",
            )

        assertEquals(12, sample.amapErrorCode)
        assertEquals("network unavailable", sample.amapErrorInfo)
    }

    @Test
    fun phaseFourCsvAppendsFieldsWithoutMovingLegacyColumns() {
        val columns = TrackingCsvRecord.CSV_HEADER.split(",")

        assertEquals("sequence", columns.first())
        assertEquals("message", columns[13])
        assertEquals("location_engine", columns[14])
        assertEquals("address", columns.last())
    }

    @Test
    fun androidCsvEngineMetadataDoesNotFabricateAmapFields() {
        val row =
            TrackingCsvRecord(
                sequence = 1,
                timestamp = "2026-07-26T12:00:00.000Z",
                latitude = 24.861,
                longitude = 67.002,
                accuracy = 4.2f,
                provider = "gps",
                eventType = "LOCATION_RECEIVED",
                locationEngine = "ANDROID_LOCATION_MANAGER",
                coordinateSystem = "WGS84",
            ).toCsvRow().split(",")

        assertEquals("ANDROID_LOCATION_MANAGER", row[14])
        assertEquals("", row[15])
        assertEquals("", row[16])
        assertEquals("", row[17])
        assertEquals("WGS84", row[21])
    }

    @Test
    fun safeSessionIdentifiersRejectTraversal() {
        assertTrue(TrackingLogStore.isSafeSessionId("20260726_120000_123"))
        assertFalse(TrackingLogStore.isSafeSessionId("../tracking_session"))
        assertFalse(TrackingLogStore.isSafeSessionId("C:\\private\\file"))
    }

    @Test
    fun activeSessionDeletionIsPreventedWithoutBlockingOtherSessions() {
        assertFalse(
            TrackingLogStore.canDeleteSession(
                requestedSessionId = "active",
                activeSessionId = "active",
                isTracking = true,
            ),
        )
        assertTrue(
            TrackingLogStore.canDeleteSession(
                requestedSessionId = "older",
                activeSessionId = "active",
                isTracking = true,
            ),
        )
    }
}
