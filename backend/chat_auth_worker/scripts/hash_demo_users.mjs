import { createHmac, randomBytes } from 'node:crypto';
import { pathToFileURL } from 'node:url';

const USER_ID_PATTERN = /^[A-Za-z0-9_-]{1,32}$/;
const ALGORITHM = 'hmac-sha256-v1';

export function hashDemoPin(
  pin,
  userId,
  pepper,
  salt = randomBytes(16),
) {
  if (
    typeof pin !== 'string' ||
    pin.length < 4 ||
    pin.length > 64 ||
    !USER_ID_PATTERN.test(userId) ||
    !(pepper instanceof Uint8Array) ||
    pepper.byteLength < 32 ||
    !(salt instanceof Uint8Array) ||
    salt.byteLength < 16
  ) {
    throw new Error('Invalid demo PIN hashing input.');
  }
  const encodedSalt = base64Url(salt);
  const payload =
    `oppo-gps-demo-pin-v1\u0000${userId}\u0000${encodedSalt}\u0000${pin}`;
  const pinHash = createHmac('sha256', Buffer.from(pepper))
    .update(payload, 'utf8')
    .digest();
  return {
    algorithm: ALGORITHM,
    salt: encodedSalt,
    pinHash: base64Url(pinHash),
  };
}

async function main() {
  const userIds = process.argv.slice(2);
  if (
    userIds.length === 0 ||
    new Set(userIds).size !== userIds.length ||
    userIds.some((userId) => !USER_ID_PATTERN.test(userId))
  ) {
    process.stderr.write(
      'Usage: node scripts/hash_demo_users.mjs USER_ID_ONE USER_ID_TWO\n',
    );
    process.exitCode = 2;
    return;
  }
  if (!process.stdin.isTTY || !process.stdin.setRawMode) {
    process.stderr.write('Run this command in an interactive terminal.\n');
    process.exitCode = 2;
    return;
  }

  const pepper = randomBytes(32);
  const users = {};
  for (const userId of userIds) {
    const pin = await hiddenPrompt(`Demo PIN for ${userId}: `);
    const confirmation = await hiddenPrompt('Confirm PIN: ');
    if (pin !== confirmation || pin.length < 4 || pin.length > 64) {
      process.stderr.write('PINs did not match or were outside 4-64 characters.\n');
      process.exitCode = 2;
      return;
    }
    users[userId] = hashDemoPin(pin, userId, pepper);
  }
  process.stdout.write(
    `${JSON.stringify({
      DEMO_PIN_PEPPER: base64Url(pepper),
      DEMO_USERS_JSON: JSON.stringify(users),
    })}\n`,
  );
}

function hiddenPrompt(label) {
  process.stderr.write(label);
  process.stdin.setRawMode(true);
  process.stdin.resume();
  process.stdin.setEncoding('utf8');
  return new Promise((resolve, reject) => {
    let value = '';
    function finish() {
      process.stdin.off('data', onData);
      process.stdin.setRawMode(false);
      process.stdin.pause();
      process.stderr.write('\n');
      resolve(value);
    }
    function onData(chunk) {
      for (const character of chunk) {
        if (character === '\u0003') {
          process.stdin.off('data', onData);
          process.stdin.setRawMode(false);
          process.stdin.pause();
          process.stderr.write('\n');
          reject(new Error('Cancelled.'));
          return;
        }
        if (character === '\r' || character === '\n') {
          finish();
          return;
        }
        if (character === '\u007f' || character === '\b') {
          value = value.slice(0, -1);
          continue;
        }
        value += character;
      }
    }
    process.stdin.on('data', onData);
  });
}

function base64Url(value) {
  return Buffer.from(value)
    .toString('base64')
    .replace(/\+/g, '-')
    .replace(/\//g, '_')
    .replace(/=+$/g, '');
}

if (
  process.argv[1] &&
  import.meta.url === pathToFileURL(process.argv[1]).href
) {
  main().catch(() => {
    process.stderr.write('Unable to generate the demo-user configuration.\n');
    process.exitCode = 1;
  });
}
