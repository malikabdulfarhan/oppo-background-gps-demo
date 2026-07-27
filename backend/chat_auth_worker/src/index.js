const encoder = new TextEncoder();
const USER_ID_PATTERN = /^[A-Za-z0-9_-]{1,32}$/;
const DEFAULT_USER_SIG_TTL_SECONDS = 86_400;
const DEFAULT_REFRESH_TTL_SECONDS = 2_592_000;
const MAX_BODY_BYTES = 4096;
const MAX_LOGIN_ATTEMPTS_PER_MINUTE = 10;

export default {
  fetch(request, env) {
    return handleRequest(request, env);
  },
};

export async function handleRequest(request, env) {
  const url = new URL(request.url);
  const headers = securityHeaders(request, env);

  if (request.method === 'OPTIONS') {
    return new Response(null, { status: 204, headers });
  }
  if (request.method === 'GET' && url.pathname === '/health') {
    return jsonResponse(
      {
        status: 'ok',
        service: 'oppo-gps-chat-auth',
        sdkAppIdConfigured: validSdkAppId(env.TENCENT_IM_SDK_APP_ID),
        authenticationConfigured: authenticationConfigured(env),
      },
      200,
      headers,
    );
  }
  if (request.method !== 'POST') {
    return jsonError('Not found.', 404, 'not_found', headers);
  }

  try {
    validateEnvironment(env);
    if (url.pathname === '/v1/auth/login') {
      await enforceLoginRateLimit(request, env);
      const body = await readJson(request);
      return await login(body, env, headers);
    }
    if (url.pathname === '/v1/auth/refresh') {
      const body = await readJson(request);
      return await refresh(body, env, headers);
    }
    if (url.pathname === '/v1/auth/logout') {
      const body = await readJson(request);
      return await logout(body, env, headers);
    }
    return jsonError('Not found.', 404, 'not_found', headers);
  } catch (error) {
    if (error instanceof SafeHttpError) {
      return jsonError(error.message, error.status, error.code, headers);
    }
    const diagnostic = internalDiagnostic(error);
    console.error('chat_auth_internal_failure', diagnostic);
    return jsonError(
      'Authentication service is temporarily unavailable.',
      500,
      'service_unavailable',
      headers,
    );
  }
}

async function login(body, env, headers) {
  const userId = cleanUserId(body.userId);
  const pin = typeof body.pin === 'string' ? body.pin : '';
  if (pin.length < 4 || pin.length > 64) {
    throw new SafeHttpError(
      401,
      'invalid_credentials',
      'Invalid User ID or PIN.',
    );
  }
  const users = parseDemoUsers(env.DEMO_USERS_JSON);
  const user = users[userId];
  let valid = false;
  try {
    valid =
      user != null &&
      (await verifyPin(pin, userId, user, env.DEMO_PIN_PEPPER));
  } catch (error) {
    throw new InternalStageError('pin_verification', error);
  }
  if (!valid) {
    throw new SafeHttpError(
      401,
      'invalid_credentials',
      'Invalid User ID or PIN.',
    );
  }
  let chatSession;
  try {
    chatSession = await issueChatSession(userId, env);
  } catch (error) {
    throw new InternalStageError('usersig_generation', error);
  }
  let refreshToken;
  try {
    refreshToken = await createRefreshSession(userId, env);
  } catch (error) {
    throw new InternalStageError('refresh_session_creation', error);
  }
  return jsonResponse({ ...chatSession, refreshToken }, 200, headers);
}

async function refresh(body, env, headers) {
  const oldToken = cleanRefreshToken(body.refreshToken);
  const sessionKey = await refreshSessionKey(oldToken);
  const stored = await env.CHAT_AUTH_KV.get(sessionKey, 'json');
  if (!stored || !USER_ID_PATTERN.test(stored.userId ?? '')) {
    throw new SafeHttpError(
      401,
      'session_expired',
      'This saved login has expired. Sign in again.',
    );
  }

  let chatSession;
  try {
    chatSession = await issueChatSession(stored.userId, env);
  } catch (error) {
    throw new InternalStageError('usersig_refresh', error);
  }
  let newToken;
  try {
    newToken = await createRefreshSession(stored.userId, env);
    await env.CHAT_AUTH_KV.delete(sessionKey);
  } catch (error) {
    throw new InternalStageError('refresh_session_rotation', error);
  }
  return jsonResponse({ ...chatSession, refreshToken: newToken }, 200, headers);
}

async function logout(body, env, headers) {
  const token = cleanRefreshToken(body.refreshToken);
  await env.CHAT_AUTH_KV.delete(await refreshSessionKey(token));
  return jsonResponse({ success: true }, 200, headers);
}

async function issueChatSession(userId, env) {
  const sdkAppId = Number(env.TENCENT_IM_SDK_APP_ID);
  const ttl = boundedInteger(
    env.USER_SIG_TTL_SECONDS,
    DEFAULT_USER_SIG_TTL_SECONDS,
    3600,
    5_184_000,
  );
  const issuedAtSeconds = Math.floor(Date.now() / 1000);
  const userSig = await generateUserSig({
    sdkAppId,
    secretKey: env.TENCENT_IM_SDK_SECRET_KEY,
    userId,
    expiresInSeconds: ttl,
    issuedAtSeconds,
  });
  return {
    userId,
    userSig,
    expiresAt: new Date((issuedAtSeconds + ttl) * 1000).toISOString(),
  };
}

export async function generateUserSig({
  sdkAppId,
  secretKey,
  userId,
  expiresInSeconds,
  issuedAtSeconds = Math.floor(Date.now() / 1000),
}) {
  if (!Number.isSafeInteger(sdkAppId) || sdkAppId <= 0) {
    throw new Error('Invalid SDKAppID.');
  }
  if (!secretKey || !USER_ID_PATTERN.test(userId)) {
    throw new Error('Invalid UserSig input.');
  }

  const content =
    `TLS.identifier:${userId}\n` +
    `TLS.sdkappid:${sdkAppId}\n` +
    `TLS.time:${issuedAtSeconds}\n` +
    `TLS.expire:${expiresInSeconds}\n`;
  const cryptoKey = await crypto.subtle.importKey(
    'raw',
    encoder.encode(secretKey),
    { name: 'HMAC', hash: 'SHA-256' },
    false,
    ['sign'],
  );
  const signature = await crypto.subtle.sign(
    'HMAC',
    cryptoKey,
    encoder.encode(content),
  );
  const document = {
    'TLS.ver': '2.0',
    'TLS.identifier': userId,
    'TLS.sdkappid': sdkAppId,
    'TLS.time': issuedAtSeconds,
    'TLS.expire': expiresInSeconds,
    'TLS.sig': bytesToBase64(new Uint8Array(signature)),
  };
  const compressed = await deflate(encoder.encode(JSON.stringify(document)));
  return tencentBase64Url(compressed);
}

async function createRefreshSession(userId, env) {
  const tokenBytes = crypto.getRandomValues(new Uint8Array(32));
  const token = standardBase64Url(tokenBytes);
  const ttl = boundedInteger(
    env.REFRESH_TOKEN_TTL_SECONDS,
    DEFAULT_REFRESH_TTL_SECONDS,
    3600,
    7_776_000,
  );
  await env.CHAT_AUTH_KV.put(
    await refreshSessionKey(token),
    JSON.stringify({ userId, createdAt: new Date().toISOString() }),
    { expirationTtl: ttl },
  );
  return token;
}

async function refreshSessionKey(token) {
  const digest = await crypto.subtle.digest('SHA-256', encoder.encode(token));
  return `session:${standardBase64Url(new Uint8Array(digest))}`;
}

async function verifyPin(pin, userId, configuredUser, encodedPepper) {
  if (configuredUser.algorithm !== 'hmac-sha256-v1') {
    return false;
  }
  let pepper;
  let salt;
  let expected;
  try {
    pepper = standardBase64UrlDecode(encodedPepper);
    salt = standardBase64UrlDecode(configuredUser.salt);
    expected = standardBase64UrlDecode(configuredUser.pinHash);
  } catch {
    return false;
  }
  if (pepper.length < 32 || salt.length < 16 || expected.length !== 32) {
    return false;
  }
  const key = await crypto.subtle.importKey(
    'raw',
    pepper,
    { name: 'HMAC', hash: 'SHA-256' },
    false,
    ['sign'],
  );
  const derived = new Uint8Array(
    await crypto.subtle.sign(
      'HMAC',
      key,
      pinVerifierPayload(userId, configuredUser.salt, pin),
    ),
  );
  return timingSafeEqual(derived, expected);
}

async function enforceLoginRateLimit(request, env) {
  const clientIp = request.headers.get('CF-Connecting-IP') ?? 'local';
  const minute = Math.floor(Date.now() / 60_000);
  const digest = await crypto.subtle.digest(
    'SHA-256',
    encoder.encode(clientIp),
  );
  const key = `rate:${minute}:${standardBase64Url(new Uint8Array(digest))}`;
  const attempts = Number(await env.CHAT_AUTH_KV.get(key)) || 0;
  if (attempts >= MAX_LOGIN_ATTEMPTS_PER_MINUTE) {
    throw new SafeHttpError(
      429,
      'rate_limited',
      'Too many login attempts. Try again shortly.',
    );
  }
  await env.CHAT_AUTH_KV.put(key, String(attempts + 1), {
    expirationTtl: 120,
  });
}

async function readJson(request) {
  const length = Number(request.headers.get('content-length') ?? 0);
  if (length > MAX_BODY_BYTES) {
    throw new SafeHttpError(413, 'request_too_large', 'Request is too large.');
  }
  const contentType = request.headers.get('content-type') ?? '';
  if (!contentType.toLowerCase().startsWith('application/json')) {
    throw new SafeHttpError(
      415,
      'unsupported_media_type',
      'Content-Type must be application/json.',
    );
  }
  let text;
  try {
    text = await request.text();
  } catch {
    throw new SafeHttpError(400, 'invalid_json', 'Invalid JSON request.');
  }
  if (encoder.encode(text).byteLength > MAX_BODY_BYTES) {
    throw new SafeHttpError(413, 'request_too_large', 'Request is too large.');
  }
  try {
    return JSON.parse(text);
  } catch {
    throw new SafeHttpError(400, 'invalid_json', 'Invalid JSON request.');
  }
}

function validateEnvironment(env) {
  if (!authenticationConfigured(env)) {
    throw new SafeHttpError(
      503,
      'configuration_missing',
      'Authentication service is not configured.',
    );
  }
}

function authenticationConfigured(env) {
  return Boolean(
    validSdkAppId(env.TENCENT_IM_SDK_APP_ID) &&
      env.TENCENT_IM_SDK_SECRET_KEY &&
      env.DEMO_PIN_PEPPER &&
      env.DEMO_USERS_JSON &&
      env.CHAT_AUTH_KV,
  );
}

function parseDemoUsers(value) {
  try {
    const users = JSON.parse(value);
    return users && typeof users === 'object' && !Array.isArray(users)
      ? users
      : {};
  } catch {
    return {};
  }
}

function cleanUserId(value) {
  const clean = typeof value === 'string' ? value.trim() : '';
  if (!USER_ID_PATTERN.test(clean)) {
    throw new SafeHttpError(
      401,
      'invalid_credentials',
      'Invalid User ID or PIN.',
    );
  }
  return clean;
}

function cleanRefreshToken(value) {
  const clean = typeof value === 'string' ? value.trim() : '';
  if (!/^[A-Za-z0-9_-]{40,64}$/.test(clean)) {
    throw new SafeHttpError(
      401,
      'session_expired',
      'This saved login has expired. Sign in again.',
    );
  }
  return clean;
}

function validSdkAppId(value) {
  const parsed = Number(value);
  return Number.isSafeInteger(parsed) && parsed > 0;
}

function boundedInteger(value, fallback, minimum, maximum) {
  const parsed = Number(value ?? fallback);
  return Number.isSafeInteger(parsed) && parsed >= minimum && parsed <= maximum
    ? parsed
    : fallback;
}

function securityHeaders(request, env) {
  const headers = new Headers({
    'content-type': 'application/json; charset=utf-8',
    'cache-control': 'no-store',
    pragma: 'no-cache',
    'x-content-type-options': 'nosniff',
    'referrer-policy': 'no-referrer',
  });
  const origin = request.headers.get('origin');
  const allowed = String(env.ALLOWED_ORIGINS ?? '')
    .split(',')
    .map((item) => item.trim())
    .filter(Boolean);
  if (origin && allowed.includes(origin)) {
    headers.set('access-control-allow-origin', origin);
    headers.set('vary', 'Origin');
    headers.set('access-control-allow-methods', 'POST, OPTIONS');
    headers.set('access-control-allow-headers', 'Content-Type');
  }
  return headers;
}

function jsonResponse(body, status, headers) {
  return new Response(JSON.stringify(body), { status, headers });
}

function jsonError(message, status, code, headers) {
  return jsonResponse({ error: { code, message } }, status, headers);
}

async function deflate(bytes) {
  const stream = new Blob([bytes])
    .stream()
    .pipeThrough(new CompressionStream('deflate'));
  return new Uint8Array(await new Response(stream).arrayBuffer());
}

function bytesToBase64(bytes) {
  let binary = '';
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return btoa(binary);
}

function standardBase64Url(bytes) {
  return bytesToBase64(bytes)
    .replace(/\+/g, '-')
    .replace(/\//g, '_')
    .replace(/=+$/g, '');
}

function standardBase64UrlDecode(value) {
  const padded = value.replace(/-/g, '+').replace(/_/g, '/');
  const binary = atob(padded + '='.repeat((4 - (padded.length % 4)) % 4));
  return Uint8Array.from(binary, (character) => character.charCodeAt(0));
}

function tencentBase64Url(bytes) {
  return bytesToBase64(bytes)
    .replace(/\+/g, '*')
    .replace(/\//g, '-')
    .replace(/=/g, '_');
}

function pinVerifierPayload(userId, encodedSalt, pin) {
  return encoder.encode(
    `oppo-gps-demo-pin-v1\u0000${userId}\u0000${encodedSalt}\u0000${pin}`,
  );
}

function timingSafeEqual(left, right) {
  if (left.length !== right.length) return false;
  if (typeof crypto.subtle.timingSafeEqual === 'function') {
    return crypto.subtle.timingSafeEqual(left, right);
  }
  let difference = 0;
  for (let index = 0; index < left.length; index += 1) {
    difference |= left[index] ^ right[index];
  }
  return difference === 0;
}

function internalDiagnostic(error) {
  if (error instanceof InternalStageError) {
    return {
      stage: error.stage,
      errorName:
        error.cause && typeof error.cause.name === 'string'
          ? error.cause.name
          : 'Error',
    };
  }
  return {
    stage: 'request_handling',
    errorName:
      error && typeof error.name === 'string' ? error.name : 'UnknownError',
  };
}

class SafeHttpError extends Error {
  constructor(status, code, message) {
    super(message);
    this.status = status;
    this.code = code;
  }
}

class InternalStageError extends Error {
  constructor(stage, cause) {
    super('Internal authentication stage failed.');
    this.name = 'InternalStageError';
    this.stage = stage;
    this.cause = cause;
  }
}
