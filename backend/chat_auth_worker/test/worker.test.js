import assert from 'node:assert/strict';
import { test } from 'node:test';

import { generateUserSig, handleRequest } from '../src/index.js';
import { hashDemoPin } from '../scripts/hash_demo_users.mjs';

const TEST_PEPPER = Uint8Array.from(
  { length: 32 },
  (_, index) => index + 31,
);
const TEST_PEPPER_BASE64URL = Buffer.from(TEST_PEPPER).toString('base64url');

class MemoryKv {
  values = new Map();

  async get(key, type) {
    const value = this.values.get(key) ?? null;
    return type === 'json' && value ? JSON.parse(value) : value;
  }

  async put(key, value) {
    this.values.set(key, value);
  }

  async delete(key) {
    this.values.delete(key);
  }
}

function demoUser(pin, userId = 'driver_one') {
  const salt = Uint8Array.from({ length: 16 }, (_, index) => index + 1);
  return hashDemoPin(pin, userId, TEST_PEPPER, salt);
}

test('generates a Tencent-shaped UserSig without exposing the key', async () => {
  const result = await generateUserSig({
    sdkAppId: 12_345,
    secretKey: 'test-only-key',
    userId: 'demo_user',
    expiresInSeconds: 3600,
    issuedAtSeconds: 1_700_000_000,
  });

  assert.match(result, /^[A-Za-z0-9*_-]+$/);
  assert.ok(result.length > 80);
  assert.ok(!result.includes('test-only-key'));
});

test('health response reports configuration without returning values', async () => {
  const response = await handleRequest(
    new Request('https://example.test/health'),
    {
      TENCENT_IM_SDK_APP_ID: '12345',
      TENCENT_IM_SDK_SECRET_KEY: 'test-key',
      DEMO_PIN_PEPPER: TEST_PEPPER_BASE64URL,
      DEMO_USERS_JSON: '{}',
      CHAT_AUTH_KV: new MemoryKv(),
    },
  );
  const body = await response.json();

  assert.equal(response.status, 200);
  assert.equal(body.sdkAppIdConfigured, true);
  assert.equal(body.authenticationConfigured, true);
  assert.equal(JSON.stringify(body).includes('12345'), false);
});

test('invalid credentials return the same safe error', async () => {
  const response = await handleRequest(
    new Request('https://example.test/v1/auth/login', {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ userId: 'unknown', pin: 'wrong-pin' }),
    }),
    {
      TENCENT_IM_SDK_APP_ID: '12345',
      TENCENT_IM_SDK_SECRET_KEY: 'test-key',
      DEMO_PIN_PEPPER: TEST_PEPPER_BASE64URL,
      DEMO_USERS_JSON: '{}',
      CHAT_AUTH_KV: new MemoryKv(),
    },
  );
  const body = await response.json();

  assert.equal(response.status, 401);
  assert.equal(body.error.code, 'invalid_credentials');
  assert.equal(JSON.stringify(body).includes('unknown'), false);
});

test('login, refresh rotation, and logout form a revocable session', async () => {
  const kv = new MemoryKv();
  const pin = '2468';
  const env = {
    TENCENT_IM_SDK_APP_ID: '12345',
    TENCENT_IM_SDK_SECRET_KEY: 'test-only-secret-key',
    DEMO_PIN_PEPPER: TEST_PEPPER_BASE64URL,
    DEMO_USERS_JSON: JSON.stringify({ driver_one: demoUser(pin) }),
    CHAT_AUTH_KV: kv,
  };

  const loginResponse = await handleRequest(
    new Request('https://example.test/v1/auth/login', {
      method: 'POST',
      headers: {
        'content-type': 'application/json',
        'CF-Connecting-IP': '192.0.2.1',
      },
      body: JSON.stringify({ userId: 'driver_one', pin }),
    }),
    env,
  );
  const login = await loginResponse.json();
  assert.equal(loginResponse.status, 200);
  assert.equal(login.userId, 'driver_one');
  assert.ok(login.userSig.length > 80);
  assert.ok(login.refreshToken.length >= 40);
  assert.equal(JSON.stringify(login).includes(pin), false);
  assert.equal(JSON.stringify(login).includes('test-only-secret-key'), false);

  const refreshResponse = await handleRequest(
    new Request('https://example.test/v1/auth/refresh', {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ refreshToken: login.refreshToken }),
    }),
    env,
  );
  const refreshed = await refreshResponse.json();
  assert.equal(refreshResponse.status, 200);
  assert.notEqual(refreshed.refreshToken, login.refreshToken);

  const reusedResponse = await handleRequest(
    new Request('https://example.test/v1/auth/refresh', {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ refreshToken: login.refreshToken }),
    }),
    env,
  );
  assert.equal(reusedResponse.status, 401);

  const logoutResponse = await handleRequest(
    new Request('https://example.test/v1/auth/logout', {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ refreshToken: refreshed.refreshToken }),
    }),
    env,
  );
  assert.equal(logoutResponse.status, 200);

  const loggedOutResponse = await handleRequest(
    new Request('https://example.test/v1/auth/refresh', {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ refreshToken: refreshed.refreshToken }),
    }),
    env,
  );
  assert.equal(loggedOutResponse.status, 401);
});

test('rejects a body over the limit without trusting Content-Length', async () => {
  const response = await handleRequest(
    new Request('https://example.test/v1/auth/login', {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ userId: 'driver_one', pin: 'x'.repeat(5000) }),
    }),
    {
      TENCENT_IM_SDK_APP_ID: '12345',
      TENCENT_IM_SDK_SECRET_KEY: 'test-key',
      DEMO_PIN_PEPPER: TEST_PEPPER_BASE64URL,
      DEMO_USERS_JSON: '{}',
      CHAT_AUTH_KV: new MemoryKv(),
    },
  );
  const body = await response.json();

  assert.equal(response.status, 413);
  assert.equal(body.error.code, 'request_too_large');
});
