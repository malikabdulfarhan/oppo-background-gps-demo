# OPPO Background GPS Demo

An Android-focused Flutter demonstration of route tracking. Phase 3 moves
location collection out of the Flutter activity and into a native Kotlin
foreground service, while preserving the Material 3 tracking UI and route
preview.

## Phase 3 architecture

```text
Flutter tracking UI
  -> MethodChannel commands
Kotlin tracking controller
  -> Android foreground service
  -> Android LocationManager (GPS + network)
  -> app-private CSV session log
  -> EventChannel updates while Flutter is attached
```

The Kotlin service owns the location listeners. It requests updates around
every 5000 ms, persists each accepted sample immediately, uses `START_STICKY`,
and remains active when the Flutter activity is minimized, locked, or
recreated. EventChannel delivery is only a live UI optimization; the CSV file
is the source used to restore samples missed while Flutter was detached.

The service starts only after the user presses **Start Tracking**. It does not
start at boot.

## What Phase 3 includes

- Native Android foreground location service using `LocationManager`.
- GPS and network-provider updates with coordinate validation and exact
  consecutive-coordinate deduplication.
- Persistent low-priority notification with a Stop action.
- App-private CSV sessions containing location, provider, motion, battery,
  screen, process-state, and service lifecycle data.
- Reconnection after activity recreation or Flutter hot restart without
  creating a second session.
- Restoration of persisted current-session locations.
- Diagnostic display for manufacturer, model, Android version, battery
  optimization, provider, screen state, service state, session, and log file.
- Export/share of the current CSV using an Android `FileProvider`.
- Clear Route and Clear Logs affect only the current Flutter UI. They do not
  delete historical CSV files.

## Android permissions

The main manifest declares:

```xml
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE_LOCATION" />
<uses-permission android:name="android.permission.POST_NOTIFICATIONS" />
```

`ACCESS_BACKGROUND_LOCATION` is intentionally not requested. The location
foreground service is started from the visible activity after the user grants
foreground location access. Android 13 and newer also prompt for notification
permission. Precise location is recommended; approximate access is accepted
with a warning.

The persistent notification communicates that location tracking is active.
If notification permission is denied, Android may hide it from the notification
drawer even though foreground-service behavior remains subject to the Android
version and device policy.

## Run on a physical Android device

1. Enable Developer options and USB debugging.
2. Connect the phone and accept its debugging prompt.
3. Confirm Flutter sees it:

   ```bash
   flutter devices
   ```

4. Resolve packages and run:

   ```bash
   flutter pub get
   flutter run -d <device-id>
   ```

5. Press **Start Tracking** while the app is visible.
6. Grant precise location and notification access.
7. Confirm the ongoing **GPS tracking is active** notification.

For a faster first GPS fix, test outdoors or near a window.

## CSV logs and export

Each session creates a non-overwriting file named similar to:

```text
tracking_session_20260726_120000_123.csv
```

Files are stored in the app-private Android files directory under
`tracking_sessions/`. The exact private path varies by installation and is not
shown prominently in the UI. Use **Export / Share Current Log** to send a
read-only copy through the Android share sheet.

Uninstalling the app or clearing its storage removes these app-private files.

## Locked-screen test

1. Start tracking and confirm a GPS sample and ongoing notification.
2. Lock the phone for 15 minutes.
3. Unlock it and reopen the app.
4. Confirm the current session is restored and inspect the CSV for
   `SCREEN_OFF`, locked-screen location samples, and `SCREEN_ON`.

The complete manual matrix is in
[`docs/phase-3-test-plan.md`](docs/phase-3-test-plan.md).

## ColorOS and Android limitations

ColorOS may apply additional background restrictions. Open **Battery Settings**
from the app and record the actual target-device behavior using the Phase 3
test plan. This demo does not use undocumented OPPO intents and does not
automatically request unrestricted battery usage.

No Android application can guarantee that the operating system or an OEM
power manager will never kill it. `START_STICKY` requests service recreation,
but callback cadence and recovery remain subject to Android, ColorOS, radio
conditions, permissions, and user actions. Do not claim OPPO power-saving
compatibility until the target model has completed a recorded hardware test.

## Out of scope

Phase 3 does not include:

- AMap or AMap Location SDK
- Tencent or NetEase IM
- boot-completed auto-start
- undocumented ColorOS settings intents

The next phase adds AMap map rendering and AMap Location SDK integration.

## Validation

```bash
dart format .
flutter pub get
flutter analyze
flutter test
flutter build apk --debug
cd android
gradlew.bat test
```
