# OPPO Background GPS Demo

An Android-focused Flutter demonstration with two native location engines:
keyless Android LocationManager GPS and optional AMap. It includes foreground
collection, app-private CSV logging, session history, analytics, and route
replay.

## Phase 5 Tencent Cloud Chat

Phase 5 adds a fifth **Chat** destination without changing ownership of GPS
tracking. The Kotlin foreground service remains fully independent from chat.

Two provider modes are available:

- **Local Chat Demo Mode** works with no credentials. It includes seeded
  one-to-one conversations, app-private JSON persistence, local-only text
  delivery labels, an explicit incoming-message simulator, and local data
  reset.
- **Tencent Cloud Chat Mode** uses the official
  `tencent_cloud_chat_sdk` package for C2C text conversations, history,
  sending, advanced incoming-message callbacks, unread state, and connection
  events. It activates only after an explicit login with a configured SDKAppID,
  User ID, and temporary UserSig.

Configure only the public SDKAppID at build time:

```powershell
flutter run --dart-define=TENCENT_IM_SDK_APP_ID=1234567890
```

The number above is a placeholder. Enter the User ID and temporary UserSig at
runtime. UserSig remains in memory only and is cleared after the login attempt
or logout. Never put the Tencent SDKSecretKey in this repository or generate a
production UserSig in the app. The production flow is:

```text
Mobile app -> authenticated application backend
           -> backend generates temporary UserSig
           -> mobile app logs in to Tencent Cloud Chat
```

Inside a conversation, the user may explicitly share the latest already
available GPS status after confirming a privacy warning. Chat never starts
tracking and never sends locations automatically or uploads a CSV session.

Scope is one-to-one text only. Images, files, audio, calls, group chat, and
Tencent vendor offline push are intentionally excluded. OPPO/ColorOS
locked-screen and killed-process chat notifications are not configured.
Cloud verification still requires a real Tencent application and two test
users. See [Tencent setup](docs/tencent-im-setup.md),
[Phase 5 demo](docs/phase-5-chat-demo.md), and
[UserSig security](docs/tencent-usersig-security.md).

## Phase 4 architecture

```text
Flutter Material 3 UI
  ├─ Live / Sessions / Chat / Diagnostics / Settings
  ├─ AMap PlatformView or custom fallback route canvas
  └─ MethodChannel + EventChannel
          ↓
Kotlin LocationTrackingService (START_STICKY)
  ├─ one selected engine (LocationManager or AMapLocationClient)
  ├─ one persistent foreground notification
  └─ append-only app-private CSV sessions
```

The Kotlin foreground service remains the owner of tracking and continues
logging while Flutter is detached. Flutter restores persisted samples when it
reconnects. The service starts only after an explicit user action and does not
start at boot.

Phase 4 uses the official native AMap Android SDK through a PlatformView. The
published Flutter plugin was not selected because its available release was
not compatible enough with this project's current Flutter/AGP toolchain.

Pinned dependency:

```kotlin
implementation("com.amap.api:3dmap-location-search:10.1.200_loc6.4.9_sea9.7.4")
```

This official bundle supplies AMap 3D Map 10.1.200, Location 6.4.9, and Search
9.7.4. Search/reverse geocoding is not used. Builds include `arm64-v8a` and
`armeabi-v7a`; x86/x86_64 emulator ABIs are intentionally excluded.

## AMap key setup

The application ID is:

```text
com.andromind.oppo_background_gps_demo
```

1. Create an Android SDK key in the AMap developer console for that package.
2. Obtain the signing fingerprint:

   ```powershell
   cd android
   .\gradlew.bat signingReport
   ```

3. Add the key only to ignored `android/local.properties`:

   ```properties
   AMAP_API_KEY=replace_with_your_amap_android_key
   ```

4. Rebuild the application.

Debug and release certificates usually have different SHA-1 fingerprints and
may need separate AMap key configuration. Gradle injects the local property
through the `com.amap.api.v2.apikey` manifest placeholder and never prints it.
When no key is configured, the app builds without crashing and automatically
uses Android GPS Demo Mode. Tracking, CSV sessions, statistics, diagnostics,
and custom-canvas live/replay route views remain available.

See [docs/amap-setup.md](docs/amap-setup.md) for the complete setup and
troubleshooting guide. `android/local.properties.example` contains only a safe
placeholder.

## Privacy consent

No AMap object is created until the user genuinely accepts the in-app AMap
privacy notice. The native layer applies the required AMap Location and Map
privacy APIs before constructing `AMapLocationClient` or `MapView`.

Declining keeps AMap SDK features disabled but does not disable Android GPS
Demo Mode. Settings lets the user review the disclosure, accept later, or
revoke consent when AMap tracking is not active.
Consent is stored in app-private Android preferences. This demo does not claim
to have a public privacy-policy URL.

## Development without an AMap key

Android GPS Demo Mode remains fully functional without `AMAP_API_KEY`. It uses
the native Android LocationManager in the existing foreground service and
retains the persistent notification, CSV logging, session history, route
statistics, diagnostics, and fallback-canvas live/replay routes.

The project does not fake AMap behavior. Without a valid Android SDK key, AMap
tile rendering, authentication, native location callbacks, error codes, and
coordinate-system behavior cannot be runtime verified. The integration remains
compiled and guarded, so a client-provided key can activate it without an
architectural change.

Add the future key only to ignored `android/local.properties`:

```properties
AMAP_API_KEY=replace_with_your_amap_android_key
```

Then perform a clean rebuild:

```powershell
flutter clean
flutter pub get
flutter run
```

See [docs/phase-4-keyless-demo.md](docs/phase-4-keyless-demo.md) for the audit
matrix, demo procedure, and the exact boundary between demonstrable and
key-blocked behavior.

## Live tracking and map

- AMap or fallback-canvas current-location marker and accuracy circle
- start, latest, and selected replay markers
- blue route polyline
- recenter, fit route, and follow-location controls
- standard, satellite, and night map modes
- traffic, compass, and scale toggles
- current coordinates, accuracy, engine metadata, and optional AMap type
- live route statistics and location log

All samples remain in CSV. For rendering only, a deterministic stride limits a
very large polyline to approximately 2,000 display points. Exact consecutive
duplicates are omitted from the displayed polyline but stationary callbacks
remain persisted and count as samples.

## Sessions and replay

The Sessions tab lists app-private CSV sessions newest first and shows summary
metrics, engine metadata, corruption counts, and device information. A session
can be opened, summarized, shared, or deleted. The active session cannot be
deleted. Native identifier validation prevents path traversal and all
operations remain inside `tracking_sessions`.

Replay uses AMap when selected and available, otherwise the fallback route
canvas. It never starts or changes live tracking. It supports a timeline,
previous/next, play/pause, 1x/2x/4x speed, fit-route, point details, and
independent CSV sharing.

## CSV compatibility and coordinates

The original Phase 3 columns retain their order. Phase 4 appends:

```text
location_engine, amap_location_type, amap_error_code, amap_error_info,
gps_accuracy_status, satellite_count, is_mock, coordinate_system,
country, province, city, district, street, address
```

Malformed rows are skipped and counted without failing the session. Phase 3
files are read without rewriting and marked `LEGACY` / `WGS84_LEGACY`. New
Android GPS sessions use `ANDROID_LOCATION_MANAGER` with WGS84 coordinates and
leave optional AMap columns empty. New AMap points are recorded as `AMAP` /
`GCJ02`. Legacy coordinates are converted
only in the map-display copy using AMap's official coordinate converter; the
CSV remains unchanged. A warning remains visible because legacy mainland-China
routes can still be offset if their historical coordinate metadata is wrong.

## Android permissions

The manifest includes fine/coarse location, foreground-location service,
notification, internet, network-state, and Wi-Fi-state permissions.
`ACCESS_BACKGROUND_LOCATION` is intentionally not requested. The foreground
service is started from the visible activity.

## Run on a physical Android phone

```powershell
flutter pub get
flutter devices
flutter run -d <device-id>
```

For keyless testing, select Automatic or Android GPS Demo, grant precise
location and notification permission, enable GPS, then press **Start
Tracking**. AMap-specific testing additionally requires a valid key and
accepted AMap privacy consent.
Outdoor testing generally produces a faster and more accurate first fix.

Follow [docs/phase-4-test-plan.md](docs/phase-4-test-plan.md) and preserve
exported CSV evidence for client acceptance.

## Diagnostics

Diagnostics reports key presence (never the key value), compile/runtime AMap
state, selected and active engines, fallback reason, permissions, session and
CSV state, location timing, map preferences, service and battery state, OPPO
detection, Android version, and the safe system build display (which may
contain ColorOS version information). Copying a report excludes secrets,
signing data, and absolute app-private paths.

## Known Android, ColorOS, and AMap limitations

- AMap tiles and AMap location require a valid key, matching package/SHA-1,
  accepted consent, connectivity, enabled providers, and permissions.
- Reverse geocoding is off, so address fields are normally empty.
- This build targets ARM Android phones and does not support x86 Android
  emulators.
- Approximate positioning, indoor conditions, radio availability, and mock
  providers affect accuracy and AMap location type.
- Android or ColorOS may restrict or stop background work under memory,
  battery, thermal, force-stop, permission, or vendor policy conditions.
  `START_STICKY` requests recreation; it is not a survival guarantee.
- No undocumented OPPO/ColorOS intent or boot auto-start is included. Tencent
  OPPO offline push is deferred to Phase 6.
- Hardware behavior must be recorded on the target phone; a successful build
  is not proof of locked-screen callback continuity.

## Validation

```powershell
dart format .
flutter pub get
flutter analyze
flutter test
flutter build apk --debug
cd android
.\gradlew.bat test
.\gradlew.bat assembleDebug
```

Official references: [AMap Android Studio setup](https://lbs.amap.com/api/android-sdk/guide/create-project/android-studio-create-project),
[AMap SDK downloads](https://lbs.amap.com/api/maps-sdk-for-android/download),
[AMap Location integration notes](https://lbs.amap.com/api/android-location-sdk/guide/create-project/dev-attention),
and [AMap Android key setup](https://lbs.amap.com/api/maps-sdk-for-android/guide/create-project/get-key).
