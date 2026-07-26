# AMap Android setup

## 1. Create the AMap application

Sign in to the AMap developer console, create an application, and create an
Android SDK key. Use:

- Package name: `com.andromind.oppo_background_gps_demo`
- SHA-1: the fingerprint of the certificate that signs the installed APK

Follow the official [AMap key guide](https://lbs.amap.com/api/maps-sdk-for-android/guide/create-project/get-key).

## 2. Obtain debug and release SHA-1 fingerprints

From the repository:

```powershell
cd android
.\gradlew.bat signingReport
```

Find the SHA-1 under the intended variant. Debug builds normally use the local
debug keystore. Production/release builds use the project's release
certificate. Because their fingerprints differ, configure the matching AMap
key for each signing certificate as required by the AMap console.

Do not paste certificate data into source files or diagnostic reports.

## 3. Configure the local key

Copy the placeholder concept from `android/local.properties.example` and add
this line to the existing ignored `android/local.properties`:

```properties
AMAP_API_KEY=replace_with_your_amap_android_key
```

Do not add quotation marks. Do not commit `local.properties`.

The Android Gradle file reads the property, uses an empty string when missing,
and injects it into:

```xml
<meta-data
    android:name="com.amap.api.v2.apikey"
    android:value="${AMAP_API_KEY}" />
```

To verify placeholder processing without exposing the value, build the debug
APK and confirm the app reports **AMap API key configured: Yes**. Do not print
or copy the merged-manifest value into logs or tickets.

## 4. Privacy initialization

The first-run Material dialog describes use of both AMap SDKs, location
collection, app-private CSV storage, the foreground notification, and the Stop
control. On genuine acceptance, Kotlin invokes:

- `AMapLocationClient.updatePrivacyShow`
- `AMapLocationClient.updatePrivacyAgree`
- `MapsInitializer.updatePrivacyShow`
- `MapsInitializer.updatePrivacyAgree`

These run before `AMapLocationClient` or `MapView` is constructed. Declining
does not initialize either SDK. Consent can be reviewed or revoked from
Settings after tracking stops.

## 5. Common invalid-key symptoms

- AMap key is shown as missing: property absent, misspelled, empty, or the app
  was not rebuilt after editing `local.properties`.
- Map surface opens but tiles fail: connectivity, key product selection,
  package binding, SHA-1 binding, or AMap service availability.
- AMap location callbacks return an error: inspect the sanitized error code and
  message in Diagnostics and the session lifecycle rows.
- Debug works but release fails: release APK uses a different signing SHA-1.
- A newly configured key is rejected: verify the Android SDK service and wait
  for AMap console configuration propagation if applicable.

The project contains no real AMap key or credential.

## Working without a key

An empty or missing `AMAP_API_KEY` is a supported development state. Automatic
mode resolves to Android GPS Demo Mode and does not construct
`AMapLocationClient`, `MapView`, or call AMap privacy APIs. The custom route
canvas is used for both live tracking and replay.

Diagnostics should report:

```text
AMap API key configured: No
AMap SDK compile integration: Yes
AMap runtime verification: Pending API key
Active location engine: Android GPS Demo
```

This confirms only that the guarded integration is compiled. It is not proof
that AMap authentication, map tiles, location callbacks, GCJ-02 behavior, or
AMap error codes work at runtime.

After receiving a valid key, add it to `android/local.properties`, accept the
AMap privacy notice in the app, select Automatic or AMap, and run:

```powershell
flutter clean
flutter pub get
flutter run
```
