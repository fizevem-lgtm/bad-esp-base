import test from 'node:test';
import assert from 'node:assert/strict';

const { createHash } = await import('node:crypto');
const TEST_KEY = 'test-access-key-with-more-than-20-characters';
const testHash = (value) => createHash('sha256').update(value).digest('hex');
const environment = { ACCESS_KEY_SHA256: testHash(TEST_KEY), SESSION_SECRET: 'test-session-secret-that-is-longer-than-32-chars' };
globalThis.Netlify = { env: { get: (name) => environment[name] ?? '' } };
const { default: accessGate } = await import('../netlify/edge-functions/access-gate.js');
const origin = 'https://gorilla.test';
const context = { next: async () => new Response('protected page content', { status: 200, headers: { 'Content-Type': 'text/html' } }) };
const req = (path, init = {}) => new Request(new URL(path, origin), init);

function resetEnvironment() {
  environment.ACCESS_KEY_SHA256 = testHash(TEST_KEY);
  environment.SESSION_SECRET = 'test-session-secret-that-is-longer-than-32-chars';
}

test('fails closed when access secrets are missing', async () => {
  environment.ACCESS_KEY_SHA256 = '';
  environment.SESSION_SECRET = '';
  const response = await accessGate(req('/pages/linux.html'), context);
  assert.equal(response.status, 503);
  assert.match(await response.text(), /Archive verrouillée/);
  resetEnvironment();
});

test('redirects anonymous page requests to the login form', async () => {
  const response = await accessGate(req('/pages/linux.html?q=debian'), context);
  assert.equal(response.status, 302);
  assert.match(response.headers.get('location'), /\/login\.html\?next=/);
  assert.equal(response.headers.get('cache-control'), 'no-store, max-age=0');
});

test('allows the login shell and public non-sensitive assets', async () => {
  assert.equal((await accessGate(req('/login.html'), context)).status, 200);
  assert.equal((await accessGate(req('/assets/auth.js'), context)).status, 200);
});

test('rejects cross-origin login submissions', async () => {
  const response = await accessGate(req('/__auth/login', {
    method: 'POST', headers: { 'Origin': 'https://attacker.test', 'Content-Type': 'application/json' },
    body: JSON.stringify({ key: TEST_KEY }),
  }), context);
  assert.equal(response.status, 403);
});

test('rejects an incorrect access key', async () => {
  const response = await accessGate(req('/__auth/login', {
    method: 'POST', headers: { 'Origin': origin, 'Content-Type': 'application/json' },
    body: JSON.stringify({ key: 'wrong-key' }),
  }), context);
  assert.equal(response.status, 401);
});

test('valid key creates a signed HttpOnly session that unlocks protected HTML', async () => {
  const loginResponse = await accessGate(req('/__auth/login', {
    method: 'POST', headers: { 'Origin': origin, 'Content-Type': 'application/json' },
    body: JSON.stringify({ key: TEST_KEY }),
  }), context);
  assert.equal(loginResponse.status, 200);
  assert.equal((await loginResponse.json()).ok, true);
  const cookieHeader = loginResponse.headers.get('set-cookie');
  assert.match(cookieHeader, /HttpOnly/);
  assert.match(cookieHeader, /SameSite=Strict/);
  const cookiePair = cookieHeader.split(';')[0];
  const pageResponse = await accessGate(req('/pages/linux.html', { headers: { Cookie: cookiePair } }), context);
  assert.equal(pageResponse.status, 200);
  assert.equal(await pageResponse.text(), 'protected page content');
  assert.equal(pageResponse.headers.get('cache-control'), 'private, no-store, max-age=0');
  assert.match(pageResponse.headers.get('x-robots-tag'), /noindex/);
});

test('logout expires the session cookies', async () => {
  const response = await accessGate(req('/__auth/logout', {
    method: 'POST', headers: { 'Origin': origin },
  }), context);
  assert.equal(response.status, 200);
  const body = await response.json();
  assert.equal(body.ok, true);
  assert.match(response.headers.get('set-cookie'), /Max-Age=0/);
});

test('rejects tampered and expired session cookies', async () => {
  const { createHmac } = await import('node:crypto');
  const secret = environment.SESSION_SECRET;
  const expires = Math.floor(Date.now() / 1000) + 60 * 60;
  const signature = createHmac('sha256', secret).update(`gorilla-fieldnotes:v1:${expires}`).digest('base64url');
  const validToken = `${expires}.${signature}`;
  const tamperedToken = `${expires}.${'A'.repeat(43)}`;
  const expired = Math.floor(Date.now() / 1000) - 10;
  const expiredSignature = createHmac('sha256', secret).update(`gorilla-fieldnotes:v1:${expired}`).digest('base64url');
  for (const token of [tamperedToken, `${expired}.${expiredSignature}`]) {
    const response = await accessGate(req('/pages/opsec.html', { headers: { Cookie: `__Host-gorilla_session=${token}` } }), context);
    assert.equal(response.status, 302);
    assert.match(response.headers.get('location'), /\/login\.html/);
  }
  // A legitimately signed token is accepted, proving the failure cases above are meaningful.
  const validResponse = await accessGate(req('/pages/opsec.html', { headers: { Cookie: `__Host-gorilla_session=${validToken}` } }), context);
  assert.equal(validResponse.status, 200);
});

test('all core HTML routes are protected before their content can be read', async () => {
  for (const path of ['/', '/index.html', '/pages/linux.html', '/pages/pentest.html', '/pages/opsec.html', '/pages/geoint.html', '/pages/osint.html']) {
    const response = await accessGate(req(path), context);
    assert.equal(response.status, 302, `Expected auth redirect for ${path}`);
    assert.equal(await response.text(), '');
  }
});

test('the signed cookie is Secure and host-scoped for HTTPS deployments', async () => {
  const response = await accessGate(req('/__auth/login', {
    method: 'POST', headers: { 'Origin': origin, 'Content-Type': 'application/json' },
    body: JSON.stringify({ key: TEST_KEY }),
  }), context);
  const cookie = response.headers.get('set-cookie') || '';
  assert.match(cookie, /__Host-gorilla_session=/);
  assert.match(cookie, /Secure/);
  assert.match(cookie, /HttpOnly/);
  assert.match(cookie, /SameSite=Strict/);
  assert.match(cookie, /Path=\//);
  assert.doesNotMatch(cookie, /Domain=/i);
});
