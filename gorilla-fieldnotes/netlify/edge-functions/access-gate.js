const COOKIE_BASE = 'gorilla_session';
const COOKIE_HOST = '__Host-gorilla_session';
const SESSION_TTL_SECONDS = 12 * 60 * 60;
const LOGIN_PATH = '/__auth/login';
const LOGOUT_PATH = '/__auth/logout';
const STATUS_PATH = '/__auth/status';
const PUBLIC_EXACT = new Set([
  '/login.html',
  '/robots.txt',
  '/site.webmanifest',
  '/favicon.ico',
]);
const encoder = new TextEncoder();

function getEnv(name) {
  try { return Netlify.env.get(name) || ''; } catch { return ''; }
}

function getConfig() {
  const accessKeyHash = getEnv('ACCESS_KEY_SHA256').toLowerCase();
  const sessionSecret = getEnv('SESSION_SECRET');
  // Store only the SHA-256 digest of a high-entropy access key in Netlify.
  // Fail closed if the digest or independent signing secret is absent or malformed.
  const configured = /^[a-f0-9]{64}$/.test(accessKeyHash) && sessionSecret.length >= 32;
  return { accessKeyHash, sessionSecret, configured };
}

function jsonResponse(status, body, extraHeaders = {}) {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      'Content-Type': 'application/json; charset=utf-8',
      'Cache-Control': 'no-store, max-age=0',
      'Pragma': 'no-cache',
      'X-Content-Type-Options': 'nosniff',
      ...extraHeaders,
    },
  });
}

function base64url(bytes) {
  let binary = '';
  for (let i = 0; i < bytes.length; i++) binary += String.fromCharCode(bytes[i]);
  return btoa(binary).replace(/=/g, '').replace(/\+/g, '-').replace(/\//g, '_');
}

function decodeBase64url(value) {
  const base64 = value.replace(/-/g, '+').replace(/_/g, '/');
  const padded = base64 + '='.repeat((4 - (base64.length % 4)) % 4);
  const binary = atob(padded);
  return Uint8Array.from(binary, char => char.charCodeAt(0));
}

async function hmac(secret, message) {
  const key = await crypto.subtle.importKey(
    'raw', encoder.encode(secret), { name: 'HMAC', hash: 'SHA-256' }, false, ['sign']
  );
  return new Uint8Array(await crypto.subtle.sign('HMAC', key, encoder.encode(message)));
}

async function sha256Hex(value) {
  const digest = new Uint8Array(await crypto.subtle.digest('SHA-256', encoder.encode(value)));
  return Array.from(digest, byte => byte.toString(16).padStart(2, '0')).join('');
}

async function readJsonWithLimit(request, limitBytes = 4096) {
  if (!request.body) throw new Error('invalid-body');
  const reader = request.body.getReader();
  const chunks = [];
  let total = 0;
  try {
    while (true) {
      const { done, value } = await reader.read();
      if (done) break;
      total += value.byteLength;
      if (total > limitBytes) {
        try { await reader.cancel(); } catch { /* Ignore a cancelled body stream. */ }
        throw new Error('body-too-large');
      }
      chunks.push(value);
    }
  } finally {
    try { reader.releaseLock(); } catch { /* Reader may already be released. */ }
  }
  const merged = new Uint8Array(total);
  let offset = 0;
  for (const chunk of chunks) { merged.set(chunk, offset); offset += chunk.byteLength; }
  const text = new TextDecoder('utf-8', { fatal: true }).decode(merged);
  return JSON.parse(text);
}

function constantTimeEqual(a, b) {
  const left = encoder.encode(a);
  const right = encoder.encode(b);
  const maxLength = Math.max(left.length, right.length);
  let difference = left.length ^ right.length;
  for (let i = 0; i < maxLength; i++) {
    difference |= (left[i] || 0) ^ (right[i] || 0);
  }
  return difference === 0;
}

function cookieName(url) {
  return url.protocol === 'https:' ? COOKIE_HOST : COOKIE_BASE;
}

function readCookie(request, name) {
  const header = request.headers.get('cookie') || '';
  for (const item of header.split(';')) {
    const separator = item.indexOf('=');
    if (separator < 0) continue;
    if (item.slice(0, separator).trim() === name) return item.slice(separator + 1).trim();
  }
  return '';
}

function cookieHeader(url, value, maxAge) {
  const secure = url.protocol === 'https:' ? '; Secure' : '';
  const name = cookieName(url);
  return `${name}=${value}; Path=/; Max-Age=${maxAge}; HttpOnly; SameSite=Strict${secure}`;
}

async function createSession(secret, expiresAt) {
  const payload = `gorilla-fieldnotes:v1:${expiresAt}`;
  return `${expiresAt}.${base64url(await hmac(secret, payload))}`;
}

async function validSession(request, url, secret) {
  const token = readCookie(request, cookieName(url));
  if (!token || token.length > 512) return false;
  const separator = token.indexOf('.');
  if (separator < 1) return false;
  const expiresText = token.slice(0, separator);
  if (!/^\d{10,}$/.test(expiresText)) return false;
  const expiresAt = Number(expiresText);
  const now = Math.floor(Date.now() / 1000);
  if (!Number.isSafeInteger(expiresAt) || expiresAt <= now || expiresAt > now + SESSION_TTL_SECONDS + 60) return false;
  let suppliedSignature;
  try { suppliedSignature = decodeBase64url(token.slice(separator + 1)); } catch { return false; }
  if (suppliedSignature.length !== 32) return false;
  const expected = await hmac(secret, `gorilla-fieldnotes:v1:${expiresAt}`);
  let difference = 0;
  for (let i = 0; i < expected.length; i++) difference |= expected[i] ^ suppliedSignature[i];
  return difference === 0;
}

function sameOrigin(request, url) {
  // Browser-originated auth actions must be same-origin. Requiring Origin also
  // prevents accidental cross-site form submissions from reaching the handler.
  return request.headers.get('origin') === url.origin;
}

async function handleAuthEndpoint(request, url, config) {
  if (url.pathname === STATUS_PATH && request.method === 'GET') {
    if (!config.configured) return jsonResponse(503, { configured: false, authenticated: false, message: 'L’accès n’est pas configuré. L’administrateur doit définir ACCESS_KEY_SHA256 et SESSION_SECRET dans Netlify.' });
    const authenticated = await validSession(request, url, config.sessionSecret);
    return jsonResponse(200, { configured: true, authenticated });
  }

  if (url.pathname === LOGOUT_PATH && request.method === 'POST') {
    if (!sameOrigin(request, url)) return jsonResponse(403, { ok: false, message: 'Origine refusée.' });
    const expireBase = `${COOKIE_BASE}=; Path=/; Max-Age=0; HttpOnly; SameSite=Strict${url.protocol === 'https:' ? '; Secure' : ''}`;
    const expireHost = `${COOKIE_HOST}=; Path=/; Max-Age=0; HttpOnly; Secure; SameSite=Strict`;
    const headers = new Headers({
      'Content-Type': 'application/json; charset=utf-8',
      'Cache-Control': 'no-store, max-age=0',
      'Pragma': 'no-cache',
      'X-Content-Type-Options': 'nosniff',
    });
    headers.append('Set-Cookie', expireBase);
    headers.append('Set-Cookie', expireHost);
    return new Response(JSON.stringify({ ok: true }), { status: 200, headers });
  }

  if (url.pathname === LOGIN_PATH && request.method === 'POST') {
    if (!sameOrigin(request, url)) return jsonResponse(403, { ok: false, message: 'Origine refusée.' });
    if (!config.configured) return jsonResponse(503, { ok: false, message: 'L’accès n’est pas configuré. L’administrateur doit définir ACCESS_KEY_SHA256 et SESSION_SECRET dans Netlify.' });
    const type = request.headers.get('content-type') || '';
    const lengthHeader = request.headers.get('content-length');
    const length = lengthHeader === null ? 0 : Number(lengthHeader);
    if (!type.toLowerCase().includes('application/json')) {
      return jsonResponse(415, { ok: false, message: 'Requête invalide.' });
    }
    if (!Number.isFinite(length) || length > 4096) {
      return jsonResponse(413, { ok: false, message: 'Requête trop volumineuse.' });
    }
    let body;
    try { body = await readJsonWithLimit(request, 4096); }
    catch (error) { return jsonResponse(error?.message === 'body-too-large' ? 413 : 400, { ok: false, message: 'Requête invalide.' }); }
    const candidate = typeof body?.key === 'string' ? body.key : '';
    const candidateHash = candidate && candidate.length <= 512 ? await sha256Hex(candidate) : '';
    if (!candidate || candidate.length > 512 || !constantTimeEqual(candidateHash, config.accessKeyHash)) {
      // Keep failure details generic; never echo input or secrets.
      return jsonResponse(401, { ok: false, message: 'Clé invalide. Vérifie la clé et réessaie.' });
    }
    const expiresAt = Math.floor(Date.now() / 1000) + SESSION_TTL_SECONDS;
    const token = await createSession(config.sessionSecret, expiresAt);
    return jsonResponse(200, { ok: true, expiresAt }, {
      'Set-Cookie': cookieHeader(url, token, SESSION_TTL_SECONDS),
      'Cache-Control': 'no-store, max-age=0',
    });
  }

  return jsonResponse(405, { ok: false, message: 'Méthode non autorisée.' }, { Allow: url.pathname === STATUS_PATH ? 'GET' : 'POST' });
}

function unavailableResponse() {
  return new Response(`<!doctype html><html lang="fr"><meta charset="utf-8"><meta name="robots" content="noindex,nofollow"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Accès non configuré</title><body style="margin:0;background:#0b0c0e;color:#e9ebef;font:16px system-ui;padding:12vh 8vw"><h1>Archive verrouillée</h1><p>La protection n’est pas configurée. L’administrateur doit définir <code>ACCESS_KEY_SHA256</code> et <code>SESSION_SECRET</code> dans les variables d’environnement Netlify, puis redéployer.</p></body></html>`, {
    status: 503,
    headers: { 'Content-Type': 'text/html; charset=utf-8', 'Cache-Control': 'no-store', 'X-Robots-Tag': 'noindex, nofollow, noarchive', 'X-Content-Type-Options': 'nosniff', 'X-Frame-Options': 'DENY', 'Content-Security-Policy': "default-src 'none'; style-src 'unsafe-inline'; base-uri 'none'; frame-ancestors 'none'; object-src 'none'" },
  });
}

export default async function accessGate(request, context) {
  const url = new URL(request.url);
  const path = url.pathname;

  if ([LOGIN_PATH, LOGOUT_PATH, STATUS_PATH].includes(path)) {
    const config = getConfig();
    return handleAuthEndpoint(request, url, config);
  }

  // Only the login form and non-content assets are public. Resource HTML is never
  // delivered to an anonymous visitor; client-side-only gates are not sufficient.
  if (PUBLIC_EXACT.has(path) || path.startsWith('/assets/')) return context.next();

  const config = getConfig();
  if (!config.configured) return unavailableResponse(); // Fail closed if secrets are absent.
  if (await validSession(request, url, config.sessionSecret)) {
    const response = await context.next();
    const headers = new Headers(response.headers);
    headers.set('Cache-Control', 'private, no-store, max-age=0');
    headers.set('Pragma', 'no-cache');
    headers.set('X-Robots-Tag', 'noindex, nofollow, noarchive');
    return new Response(response.body, { status: response.status, statusText: response.statusText, headers });
  }

  if (request.method !== 'GET' && request.method !== 'HEAD') {
    return new Response('Authentification requise.', { status: 401, headers: { 'Cache-Control': 'no-store', 'X-Content-Type-Options': 'nosniff' } });
  }

  const requested = `${url.pathname}${url.search}`;
  const login = new URL('/login.html', url.origin);
  login.searchParams.set('next', requested);
  return new Response(null, {
    status: 302,
    headers: {
      Location: login.toString(),
      'Cache-Control': 'no-store, max-age=0',
      'Referrer-Policy': 'no-referrer',
      'X-Content-Type-Options': 'nosniff',
    },
  });
}
