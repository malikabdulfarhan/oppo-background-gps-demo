# Chat authentication backend setup

The demo backend is a Cloudflare Worker in
`backend/chat_auth_worker`. It can run within Cloudflare's free Worker and KV
allowances for a small two-user demonstration. It is intentionally a demo
identity system, not a production replacement for a full user-authentication
service.

## Security boundary

The Worker owns:

- `TENCENT_IM_SDK_SECRET_KEY`
- a random PIN pepper and salted HMAC verifiers for the two demo PINs
- hashed, expiring refresh-token records in KV

The Android app owns only an opaque refresh token in platform secure storage.
The SDKAppID and Worker URL are public configuration. Never send the secret,
PINs, UserSigs, or refresh tokens through chat, commit them, place them in
`--dart-define`, or save them in screenshots.

This Flutter version has an Android 7.0 (API 24) baseline, which satisfies the
Keystore-backed secure storage requirement. Android cloud backup is disabled
for the demo app so encrypted storage is not restored without its device-bound
key.

## Prerequisites

- A Cloudflare account
- Node.js 20 or newer and npm
- The numeric Tencent SDKAppID
- The Tencent SDKSecretKey
- The exact two Tencent User IDs

Tencent creates a user automatically on their first valid SDK login, so the
same User IDs can be used for the Worker allowlist and the app.

## Provision and deploy

Run these commands from `backend/chat_auth_worker`:

```bash
npm install
npx wrangler login
npx wrangler kv namespace create CHAT_AUTH_KV
```

Copy the returned namespace ID into the existing `CHAT_AUTH_KV` entry in
`wrangler.toml`. Do not change the binding name.

Generate the allowlist and random server-only pepper. The script asks for each
PIN without echoing it and prints a Wrangler secret-bulk JSON document:

```bash
node scripts/hash_demo_users.mjs USER_ID_ONE USER_ID_TWO > demo-secrets.json
npx wrangler secret bulk demo-secrets.json
```

Delete `demo-secrets.json` immediately after Wrangler confirms the upload. It
contains sensitive verifier material and must never be committed. Then enter
the remaining values through Wrangler's interactive secret prompt:

```bash
npx wrangler secret put TENCENT_IM_SDK_APP_ID
npx wrangler secret put TENCENT_IM_SDK_SECRET_KEY
npm run deploy
```

For `TENCENT_IM_SDK_APP_ID`, enter the numeric public ID. For
`TENCENT_IM_SDK_SECRET_KEY`, enter the secret only in the hidden Wrangler
prompt. Clear the terminal clipboard after provisioning if it contained a
sensitive value.

The deploy output returns an HTTPS `workers.dev` URL. Verify only the safe
health response:

```bash
curl https://your-worker.workers.dev/health
```

It reports whether the SDKAppID is configured but never returns its value.

## Build and run Android

From the repository root:

```bash
flutter run \
  --dart-define=TENCENT_IM_SDK_APP_ID=1234567890 \
  --dart-define=TENCENT_CHAT_AUTH_BASE_URL=https://your-worker.workers.dev/
```

Replace the placeholders locally. The backend URL must use HTTPS. Sign in once
from the Chat tab using one exact User ID and its demo PIN. On the next launch,
the app rotates the saved refresh token and logs into Tencent automatically.

Use different User IDs on the two phones. Tencent may kick off a duplicate
login of the same user; the app deliberately does not auto-retry that condition.

## Local Worker development

Copy `.dev.vars.example` to `.dev.vars` and replace its placeholders only on
your machine. `.dev.vars` is ignored by Git.

```bash
npm run dev
npm test
```

Do not use real production credentials for local tests. The committed Worker
tests use fake values.

## Production follow-up

Before using this beyond a controlled demo, replace PIN authentication with the
application's real login system. Add centrally enforced authorization,
monitoring, stronger rate limiting, incident response, secret rotation, and
account-management flows.
