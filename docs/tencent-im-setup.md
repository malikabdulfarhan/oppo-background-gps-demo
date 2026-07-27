# Tencent IM setup

Phase 5 integrates the official `tencent_cloud_chat_sdk` package, and Phase 6
adds `tencent_calls_uikit` for foreground one-to-one audio/video calls. Local
Chat Demo Mode requires no account or network. Real cloud features require the
configured Tencent application.

## Cloud verification

1. Create or select a Tencent Cloud Chat application.
2. Obtain its numeric SDKAppID.
3. Create two test users.
4. Deploy the demo authentication Worker as described in
   [chat-auth-backend-setup.md](chat-auth-backend-setup.md).
5. Configure the two exact test User IDs in the Worker's hashed demo-user
   allowlist.
6. Run two devices or installations with different User IDs.
7. Sign in once on each device with its User ID and demo PIN.
8. Restart the app and verify automatic sign-in without entering a PIN.
9. Send C2C text messages between the users.
10. Verify incoming advanced-message callbacks and unread updates.
11. Export safe diagnostics and confirm that they contain no credentials or
    backend endpoint.
12. Activate Call for the same SDKAppID only when the calling APK is ready.
13. Open a cloud conversation and test its phone and camera actions.

Run with a placeholder-shaped command, replacing the value only in your local
terminal:

```powershell
flutter run `
  --dart-define=TENCENT_IM_SDK_APP_ID=1234567890 `
  --dart-define=TENCENT_CHAT_AUTH_BASE_URL=https://your-worker.workers.dev/
```

Do not save real credentials in source files. In the Chat tab, sign in once
with the demo User ID and PIN. The refresh token is stored securely and rotated
on later launches. If no saved login exists, the app stays in Local Demo Mode.
Tencent SDK network reconnection remains enabled after login.

## Boundaries

Cloud mode supports C2C text and foreground one-to-one audio/video calls.
Tencent OPPO offline push is not configured, so no killed-process or
locked-screen Chat/Call notification claim is made. The existing
foreground-location notification and channel are unchanged.
