# Phase 5 chat demo

## Credential-free demonstration

1. Build and install the debug APK without a Dart define.
2. Confirm Live GPS tracking starts and its foreground notification remains.
3. Open **Chat** and confirm
   **Local UI Demo — Not connected to Tencent Cloud** is visible.
4. Open a seeded Dispatch, Field Operations, or Technical Support conversation.
5. Send text and confirm **Local demonstration only** is shown.
6. Use **Simulate incoming message** explicitly.
7. After a GPS sample exists, choose **Share current tracking status**.
8. Review the privacy warning, confirm, and verify only the latest allowed
   fields appear. Confirm no action started GPS.
9. Switch between all five tabs while GPS continues.
10. Open Chat Settings, reset demo data, and verify seeded conversations return.
11. Copy Diagnostics and verify it contains no credentials or message content.

## Real Tencent demonstration

Use two different test users on two devices. Sign in once with each demo User
ID and PIN, then verify automatic sign-in, C2C send/receive, unread and read
changes, reconnect behavior, expired-session refresh, and kicked-offline
state. Keep GPS active during the test and confirm chat does not alter its
service or notification.

Cloud messaging is pending until this two-user test succeeds. Offline push is
not part of Phase 5.

## Phase 6

Phase 6 adds foreground one-to-one audio/video calls with TUICallKit. See
[phase-6-calling-demo.md](phase-6-calling-demo.md).

## Phase 7

Phase 7 is **Tencent IM offline push for OPPO/ColorOS**. It may require Tencent
Chat application push configuration, an OPPO developer application and vendor
credentials, Tencent push certificates, notification click routing, and
foreground, background, locked-screen, and killed-process tests.
