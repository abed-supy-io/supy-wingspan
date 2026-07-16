/**
 * Runtime auth guards for supy-firebase-functions.
 *
 * The repo annotates triggers with `@unauthenticated` / `@internal` / `@admin` / `@apiKey`,
 * but those markers are currently SEMANTIC ONLY — nothing enforces them at runtime, so an
 * `@admin` handler that never checks the admin claim is an open endpoint
 * (architecture.md#rules rule 4). These guards make the markers real. Call the matching guard
 * at the top of every handler that carries the corresponding marker, before any business logic.
 *
 * NEVER hardcode a secret here. API keys and service-account audiences come from Secret Manager
 * / injected env (secrets-and-config.md#rules rule 1). This file reads them from `process.env`,
 * which the deploy wires from Secret Manager — it never embeds a literal.
 */
import { HttpsError, type CallableRequest } from 'firebase-functions/v2/https';
import type { Request } from 'firebase-functions/v2/https';
import { OAuth2Client } from 'google-auth-library';

/** Shape of the verified custom claims we care about. Extend as roles grow. */
export interface AuthClaims {
  uid: string;
  admin?: boolean;
  [claim: string]: unknown;
}

/**
 * `@admin` — require an authenticated caller whose token carries the `admin` custom claim.
 * Throws `permission-denied` otherwise. Use for callables that mutate tenant-wide state.
 */
export function requireAdmin(request: CallableRequest): AuthClaims {
  const auth = request.auth;
  if (!auth) {
    throw new HttpsError('unauthenticated', 'Sign-in required.');
  }
  if (auth.token.admin !== true) {
    // Do not leak which check failed beyond "not permitted".
    throw new HttpsError('permission-denied', 'Admin privileges required.');
  }
  return { uid: auth.uid, admin: true, ...auth.token };
}

/**
 * `@unauthenticated`-excluded paths — require any authenticated caller (no role check).
 */
export function requireAuth(request: CallableRequest): AuthClaims {
  const auth = request.auth;
  if (!auth) {
    throw new HttpsError('unauthenticated', 'Sign-in required.');
  }
  return { uid: auth.uid, ...auth.token };
}

/**
 * `@apiKey` — require a caller presenting the shared API key in the `x-api-key` header.
 * The expected key is read from injected env (Secret Manager), NEVER a literal in source.
 * Uses a length-checked constant-time-ish comparison to avoid trivially timing the prefix.
 */
export function requireApiKey(req: Request, expectedEnvVar = 'INTERNAL_API_KEY'): void {
  const expected = process.env[expectedEnvVar];
  if (!expected) {
    // Fail closed: a missing server-side key is a misconfiguration, not an open door.
    throw new HttpsError('failed-precondition', 'API key not configured on the server.');
  }
  const presented = req.get('x-api-key') ?? '';
  if (presented.length !== expected.length || !timingSafeEqual(presented, expected)) {
    throw new HttpsError('permission-denied', 'Invalid API key.');
  }
}

/**
 * `@internal` — require a caller that proves a Google-issued OIDC identity token minted for
 * one of the allowed service accounts (e.g. the Cloud Tasks / Scheduler invoker). This replaces
 * an open `onRequest`; an internal endpoint must verify the caller, not just its network origin
 * (architecture.md#rules rule 5). Allowed service-account emails come from injected env.
 */
export async function requireInternalOidc(
  req: Request,
  opts: { audience: string; allowedServiceAccountsEnvVar?: string } = {
    audience: process.env.FUNCTION_URL ?? '',
  },
): Promise<void> {
  const header = req.get('authorization') ?? '';
  const match = /^Bearer (.+)$/.exec(header);
  if (!match) {
    throw new HttpsError('unauthenticated', 'Missing bearer token.');
  }
  const allowed = (process.env[opts.allowedServiceAccountsEnvVar ?? 'ALLOWED_INVOKERS'] ?? '')
    .split(',')
    .map((s) => s.trim())
    .filter(Boolean);
  const client = new OAuth2Client();
  let ticket;
  try {
    ticket = await client.verifyIdToken({ idToken: match[1], audience: opts.audience });
  } catch {
    // Do not echo the token or the verification error detail.
    throw new HttpsError('permission-denied', 'OIDC verification failed.');
  }
  const payload = ticket.getPayload();
  const email = payload?.email;
  if (!email || payload?.email_verified !== true || !allowed.includes(email)) {
    throw new HttpsError('permission-denied', 'Caller is not an allowed invoker.');
  }
}

/** Length-prefixed constant-time string compare (both operands already length-checked). */
function timingSafeEqual(a: string, b: string): boolean {
  let mismatch = 0;
  for (let i = 0; i < a.length; i++) {
    mismatch |= a.charCodeAt(i) ^ b.charCodeAt(i);
  }
  return mismatch === 0;
}
