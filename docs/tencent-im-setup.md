# Tencent IM setup

Phase 5 integrates the official `tencent_cloud_chat_sdk` package. Local Chat
Demo Mode requires no account or network. Real cloud messaging requires
temporary development credentials.

## Cloud verification

1. Create or select a Tencent Cloud Chat application.
2. Obtain its numeric SDKAppID.
3. Create two test users.
4. Generate temporary test UserSigs through the Tencent console.
5. Run two devices or installations with different User IDs.
6. Send C2C text messages between the users.
7. Verify incoming advanced-message callbacks.
8. Verify conversation and unread updates.
9. Export safe diagnostics and confirm that they contain no UserSig.

Run with a placeholder-shaped command, replacing the value only in your local
terminal:

```powershell
flutter run --dart-define=TENCENT_IM_SDK_APP_ID=1234567890
```

Do not save the real value in source files. In the Chat tab, open Tencent
login and enter the User ID and temporary UserSig. Real credentials are still
required before cloud behavior can be verified.

The application deliberately does not initialize Tencent when Local Demo is
selected and does not automatically log in. Normal Tencent SDK network
reconnection is allowed after login; the app does not repeatedly call login.

## Boundaries

This phase supports C2C text messaging only. Tencent OPPO offline push is not
configured, so no killed-process or locked-screen chat notification claim is
made. The existing foreground-location notification and channel are unchanged.
