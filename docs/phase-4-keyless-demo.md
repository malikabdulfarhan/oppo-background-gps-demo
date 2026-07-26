# Phase 4 keyless demo

Phase 4 supports a complete Android GPS demonstration without an AMap Android
SDK key. It preserves the official AMap integration behind runtime guards for
activation when the client supplies a valid key.

## Audit and implementation matrix

| Area | Status | Keyless evidence or remaining risk |
|---|---|---|
| Android foreground location service | Implemented and testable without a key | Uses one `AndroidLocationManagerEngine`, persistent notification, and existing `START_STICKY` service |
| CSV sessions and engine metadata | Implemented and testable without a key | Schema 4 stores `ANDROID_LOCATION_MANAGER`; optional AMap fields remain empty |
| Session history, statistics, sharing, deletion safeguards | Implemented and testable without a key | Operates on app-private CSV files and does not depend on a map provider |
| Live map and route replay | Implemented and testable without a key | Reusable custom-painted fallback adapter; no AMap PlatformView is created |
| Engine selection | Implemented and testable without a key | Automatic, Android GPS Demo, and guarded AMap preferences are persisted |
| AMap privacy | Implemented and testable without a key | Applies only to AMap; no AMap privacy API call is made when the key is empty |
| Diagnostics | Implemented and testable without a key | Separates compile integration from runtime verification and omits secrets |
| AMap Map SDK | Implemented but blocked from runtime verification | Official PlatformView code compiles; tiles and authentication require a valid key |
| AMap Location SDK | Implemented but blocked from runtime verification | Official client is guarded; callbacks and AMap error codes require a valid key |
| AMap initialization failure recovery | Implemented; hardware/runtime verification blocked | Caught failures mark runtime state and select Android fallback |
| Locked-screen continuity | Ready for physical-device testing | Architecture is present, but duration and vendor power-policy behavior require recorded phone evidence |
| OPPO/ColorOS acceptance | Not verified | Must not be inferred from builds or automated tests |

Compilation risks are contained at the AMap boundary: the SDK dependency and
ARM ABI restriction remain, while all object construction is guarded by key,
consent, and runtime state. The application must still be tested with the
client's eventual package/SHA-1-bound key.

## Demonstrable now without AMap

- Native Android LocationManager foreground collection
- Minimized-app and locked-screen foreground-service test flow
- Persistent tracking notification
- Continuous app-private CSV logging
- Route statistics
- Session history, sharing, and protected deletion
- Live custom route preview
- Route replay with timeline, playback speed, previous/next, and fit route
- Diagnostics and safe copied reports
- AMap prepared state reported as `Pending API key`

These items describe implemented demo paths. Actual locked-screen duration and
vendor power-saving behavior still require physical-device evidence.

## Blocked until a valid AMap key is supplied

- AMap tile rendering
- AMap native location callback verification
- AMap authentication verification
- AMap-specific error-code validation
- AMap coordinate-system runtime validation

The fallback canvas does not imitate AMap tiles or branding and the project
does not fake AMap results.

## Keyless demo procedure

1. Leave `AMAP_API_KEY` absent or empty in `android/local.properties`.
2. Build and install on an ARM Android phone.
3. In Settings, choose Automatic or Android GPS Demo.
4. Grant precise location and notification permission and enable device GPS.
5. Start tracking and confirm the persistent notification.
6. Record foreground, minimized, and locked-screen samples.
7. Stop tracking, inspect statistics and session history, share the CSV, and
   replay the route on the fallback canvas.
8. Copy Diagnostics and confirm `Pending API key` and
   `ANDROID_LOCATION_MANAGER`.

Do not report locked-screen or OPPO power-policy acceptance until the device
test has been performed and recorded.
