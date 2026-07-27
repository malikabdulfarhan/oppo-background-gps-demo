# Chat authentication Worker

This Cloudflare Worker keeps the Tencent SDKSecretKey off the Android device.
It exchanges a demo User ID and PIN for a revocable refresh token and a
short-lived Tencent UserSig. On later launches the refresh token obtains a new
UserSig without asking the user to enter Tencent credentials.

No secret belongs in this directory, Git, Flutter assets, Dart defines, or APKs.
The demo PIN verifier uses random per-user salts and a server-only random
pepper stored as a Worker secret.
Follow `docs/chat-auth-backend-setup.md` for provisioning and deployment.
