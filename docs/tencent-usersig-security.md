# Tencent UserSig security

UserSig is a temporary Tencent authentication credential. The mobile app accepts
it only through the runtime login form and does not persist it. It is not
printed, copied into diagnostics, placed in assets, or committed.

The Tencent SDKSecretKey must never be shipped in Dart, Kotlin, Gradle,
manifests, assets, documentation, or mobile configuration. A client-side
UserSig generator would expose that key and allow account impersonation.

Use this production architecture:

```text
Mobile app
  -> authenticated application backend
  -> backend authorizes the requested Tencent user
  -> backend generates a short-lived UserSig using SDKSecretKey
  -> backend returns only the temporary UserSig
  -> mobile app logs in to Tencent Cloud Chat
```

Protect the backend with application authentication, authorization, short
credential lifetime, rate limits, audit logging, key rotation, and secure secret
storage. Do not log the returned UserSig on either side.
