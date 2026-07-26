# Phase 4 physical-device test plan

Record evidence from a real phone. Do not infer background success from a
successful build.

Before testing, record:

- App commit/build:
- Date and location:
- Device manufacturer/model:
- Android version:
- ColorOS/build display:
- Battery mode and optimization:
- Network:
- AMap key/certificate variant:

## Test A — Keyless configuration and fallback

1. Build without `AMAP_API_KEY`.
2. Confirm the configuration-required card and Pending API key status.
3. Confirm Start remains enabled in Android GPS Demo Mode.
4. Confirm the fallback canvas updates during live tracking and replay.
5. Confirm no endless AMap loading surface is displayed.
6. When a valid key becomes available, configure it locally and rebuild.
7. Accept privacy and confirm map tiles load.

Result:

- Missing-key state:
- Valid-key map:
- Notes:

## Test B — Privacy

1. Clear app data or revoke consent.
2. Decline the AMap dialog.
3. Confirm AMap is disabled while Android GPS Demo Mode remains available.
4. Review the decision in Settings and accept.
5. Confirm AMap initializes.
6. Start AMap tracking and verify consent cannot be revoked until it stops.
7. Start Android GPS tracking and verify the AMap consent setting does not
   disable or stop it.

Result:

- Decline behavior:
- Accept behavior:
- Active revoke prevented:

## Test C — Live tracking

1. Start outdoors and grant precise location and notification access.
2. Confirm current marker, accuracy circle, start/latest markers, and route.
3. Confirm AMap location type and statistics update.
4. Share CSV and confirm appended AMap fields.

Result:

- First-fix time:
- Sample count:
- AMap location types:
- Errors:

## Test D — Camera controls

Test Follow, manual pan, Recenter, Fit Route, standard/satellite/night types,
traffic, compass, and scale. Confirm a gesture pauses automatic following and
Recenter enables it.

Result:

- Controls:
- Preference persistence after restart:
- Notes:

## Test E — Background

1. Start AMap tracking.
2. Minimize for 10 minutes.
3. Lock for 15 minutes.
4. Return and confirm persisted samples restore.
5. Compare expected callbacks with CSV rows and record the longest gap.

Result:

- Expected callbacks:
- Actual callbacks:
- Locked-screen samples:
- Longest gap:
- Service/notification observations:

## Test F — Session history

1. Complete two tracking sessions.
2. Confirm both appear newest first with summary data.
3. Open both summaries and share each CSV independently.
4. Confirm active deletion is refused.
5. Confirm a selected inactive session alone can be deleted.

Result:

- Session list:
- Sharing:
- Deletion safeguards:

## Test G — Route replay

1. Open a completed route.
2. Test slider, previous/next, play/pause, 2x, and 4x.
3. Fit the route and inspect point details.
4. Confirm replay does not start or alter native tracking or CSV.

Result:

- Replay controls:
- Live-state independence:
- Notes:

## Test H — Legacy session

Upgrade an installation containing a Phase 3 CSV. Confirm it remains readable,
is labeled `LEGACY` / `WGS84_LEGACY`, shows the coordinate warning, and is not
rewritten. If testing in mainland China, assess display offset.

Result:

- Readable:
- Original checksum/mtime unchanged:
- Display:
- Skipped rows:

## Test I — OPPO/ColorOS record

- OPPO model:
- Android version:
- ColorOS/build display:
- Battery mode:
- Test duration:
- Expected callbacks:
- Actual callbacks:
- Longest callback gap:
- Locked-screen samples:
- AMap error codes/messages:
- Was process/service stopped by OS or user:
- Notes:

Android and ColorOS can stop the process under device policies. Record observed
behavior; do not report a guarantee.
