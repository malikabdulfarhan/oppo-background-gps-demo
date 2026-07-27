# Phase 6 audio/video calling demo

Phase 6 uses Tencent's official `tencent_calls_uikit` Flutter package. It
shares the existing SDKAppID, User ID, and short-lived backend-issued UserSig.
No SDKSecretKey or new credential is stored in the app.

## Implemented behavior

- Foreground one-to-one audio calls
- Foreground one-to-one video calls
- Official incoming and outgoing call UI
- Accept, reject, hang-up, microphone, speaker, and camera controls
- Automatic Call login during secure Chat login and refresh
- Call logout and cleanup when the Chat account signs out or is kicked offline
- Safe messages for inactive packages, permissions, expired sessions, and
  invitation failures
- Text Chat remains available when Call is not activated

Offline push and killed-process incoming calls are not configured in this
phase.

## Activate the trial

Wait until the APK is installed on both test phones, then:

1. Open the Tencent RTC console.
2. Select SDKAppID `20045530`.
3. Open **Call** and choose **Try now** or **Activate now**.
4. Confirm that Call appears under the application's activated products.
5. Check **View details** for the exact expiration time and remaining quota.

Tencent's current trial rules are documented at
<https://trtc.io/document/54512>. Console eligibility and expiration are the
source of truth.

## Two-phone happy path

1. Install the same new APK on both Android phones.
2. Sign in as `malikabdulfarhan` on one phone.
3. Sign in as `malikabdulsalam` on the other phone.
4. Keep both apps open and open the conversation with the other user.
5. Tap the phone icon, grant microphone permission, answer, speak both ways,
   and hang up from each phone.
6. Tap the camera icon, grant camera permission, answer, switch cameras, mute,
   and hang up.
7. Repeat with the other phone as caller.
8. Reject one call and leave one unanswered to verify those states.
9. Force-close and reopen both apps, verify automatic Chat/Call login, and
   repeat one audio call.

Do not use the same User ID on both phones. Background, locked-screen, and
killed-process delivery require a later vendor-push phase.

## Build

```powershell
flutter build apk --debug `
  --dart-define=TENCENT_IM_SDK_APP_ID=20045530 `
  --dart-define=TENCENT_CHAT_AUTH_BASE_URL=https://your-worker.workers.dev/
```

The project aligns Tencent's older Android wrapper modules to compileSdk 36
and Java/Kotlin 1.8 bytecode where required. This does not raise the app's
minimum Android version.
