# Phase 3 physical-device test plan

Use a real Android phone and preserve the exported CSV from each test. Record
observed behavior rather than assuming the foreground service survived.

Before testing, record:

- App build/commit:
- Date and test location:
- Device manufacturer/model:
- Android version:
- ColorOS version (if applicable):
- Location accuracy mode:
- Notification permission:
- Battery mode/optimization setting:

## Test A — Foreground

1. Start tracking while the app is visible.
2. Wait for five valid samples.
3. Confirm the persistent notification is present.
4. Confirm the location count advances and the CSV log can be shared.
5. Inspect the CSV for `SERVICE_START_REQUESTED`, `SERVICE_STARTED`, and five
   `LOCATION_RECEIVED` rows.

Result:

- Pass/fail:
- Sample count:
- Notes:

## Test B — Minimized

1. Press Home.
2. Leave the app minimized for 10 minutes.
3. Return to the app.
4. Confirm missing UI events were restored from persistent storage.
5. Compare UI samples with `LOCATION_RECEIVED` rows in the exported CSV.

Result:

- Pass/fail:
- Expected samples:
- Actual samples:
- Longest update gap:
- Notes:

## Test C — Locked screen

1. Start tracking.
2. Lock the screen for 15 minutes.
3. Unlock and return to the app.
4. Confirm samples continued and were restored.
5. Inspect `SCREEN_OFF`, `SCREEN_ON`, and `screen_state=LOCKED` CSV rows.

Result:

- Pass/fail:
- Expected samples:
- Actual samples:
- Longest update gap:
- Notes:

## Test D — App removed from recent apps

1. Start tracking.
2. Remove the activity from recent apps.
3. Confirm whether the foreground service and notification remain active.
4. Reopen the app and inspect service state and restored records.
5. Record actual device behavior without fabricating success.

Result:

- Service survived: Yes/No
- Notification survived: Yes/No
- Session recovered: Yes/No
- Notes:

## Test E — GPS toggled

1. Disable GPS while tracking.
2. Confirm the provider change/error is visible and
   `PROVIDER_DISABLED` is logged.
3. Re-enable GPS.
4. Document whether tracking recovers and `PROVIDER_ENABLED` is logged.

Result:

- Recovered: Yes/No
- Recovery time:
- Notes:

## Test F — Stop action

1. Start tracking and wait for at least one sample.
2. Press Stop in the notification.
3. Reopen the app.
4. Confirm status is stopped and the previous log remains exportable.
5. Inspect the CSV for `SERVICE_STOP_REQUESTED`, `SERVICE_STOPPED`, and
   `SERVICE_DESTROYED`.

Result:

- Pass/fail:
- Notes:

## Test G — OPPO/ColorOS

Record:

- Device model:
- Android version:
- ColorOS version:
- Battery mode:
- App battery setting:
- Test duration:
- Expected samples:
- Actual samples:
- Longest update gap:
- Service/notification survived:
- Observed ColorOS prompts or restrictions:

Do not describe OPPO/ColorOS compatibility as verified unless this section was
completed on the target model.
