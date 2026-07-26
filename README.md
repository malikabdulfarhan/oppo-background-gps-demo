# OPPO Background GPS Demo

A phased Flutter demonstration of Android route tracking. Phase 2 replaces the
simulated Phase 1 coordinates with live foreground GPS updates while preserving
the Material 3 tracking interface and custom-painted route preview.

## Phase 2 functionality

- Requests location access when the user starts tracking.
- Detects disabled Android location services.
- Handles denied and permanently denied permissions with recovery actions.
- Receives live high-accuracy GPS positions approximately every five seconds.
- Displays the latest coordinate, accuracy, route point count, and sample count.
- Adds valid positions to a scrollable log and custom-painted route preview.
- Skips consecutive route points with exactly identical coordinates.
- Stops the location stream when tracking stops or the controller is disposed.
- Supports clearing route points or visible logs while tracking continues.

State is managed with `ChangeNotifier`. Location platform access is isolated in
`LocationService` so controller tests can use an in-memory fake service.

## Android permissions

Phase 2 declares only foreground location permissions in
`android/app/src/main/AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
```

`ACCESS_BACKGROUND_LOCATION` is intentionally not included.

## Run on a physical Android device

1. Enable Developer options and USB debugging on the phone.
2. Connect the phone over USB and accept its debugging authorization prompt.
3. Confirm that Flutter can see it:

   ```bash
   flutter devices
   ```

4. Resolve packages and run the app:

   ```bash
   flutter pub get
   flutter run -d <device-id>
   ```

5. Tap **Start Tracking**, enable GPS if prompted, and grant precise location
   access while using the app.

For the best first fix, test outdoors or near a window.

## Current limitation

Tracking is foreground-only. It is expected to stop when the app is no longer
active, the process is suspended, or the phone is locked. Phase 2 does not
include background permission, a persistent notification, an Android foreground
service, or locked-screen tracking.

## Next phase

Phase 3 will introduce an Android foreground service for active background
tracking and replace the custom route preview with AMap integration.

## Verification

```bash
dart format .
flutter pub get
flutter analyze
flutter test
```
