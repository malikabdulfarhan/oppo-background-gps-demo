# Tencent UserSig security

UserSig is a temporary Tencent authentication credential. The Cloudflare Worker
generates it and returns it to the app only after login or refresh. The app uses
it from memory and does not persist it. It is not printed, copied into
diagnostics, placed in assets, or committed. A manual UserSig field exists only
in debug builds for troubleshooting.

The Tencent SDKSecretKey must never be shipped in Dart, Kotlin, Gradle,
manifests, assets, documentation, or mobile configuration. A client-side
UserSig generator would expose that key and allow account impersonation.

This repository implements the following demo architecture:

```text
Mobile app
  -> Cloudflare Worker verifies an allowlisted demo user and PIN verifier
  -> backend generates a short-lived UserSig using SDKSecretKey
  -> backend returns temporary UserSig and a revocable opaque refresh token
  -> app stores only the refresh token in Android secure storage
  -> mobile app logs in to Tencent Cloud Chat
```

The Worker rate-limits login attempts, rotates refresh tokens, stores only
hashed refresh-token keys, and never logs credentials. Demo PIN verifiers use
HMAC-SHA256 with random per-user salts and a random server-only pepper. For
production, replace demo PIN authentication with the application's real
identity provider and add monitoring, abuse controls, audit policy, and secret
rotation. Do not log a PIN, UserSig, refresh token, PIN pepper, or SDKSecretKey
on either side.
