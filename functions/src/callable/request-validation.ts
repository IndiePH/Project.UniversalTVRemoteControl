import { HttpsError } from 'firebase-functions/v2/https';

export function requireString(
  value: unknown,
  name: string,
  maxLen: number,
): string {
  if (typeof value !== 'string') {
    throw new HttpsError('invalid-argument', `${name} must be a string`);
  }
  const trimmed = value.trim();
  if (!trimmed) {
    throw new HttpsError('invalid-argument', `${name} is required`);
  }
  if (trimmed.length > maxLen) {
    throw new HttpsError('invalid-argument', `${name} is too long`);
  }
  return trimmed;
}

export function requireAuthedUid(uid: string | undefined): string {
  if (!uid) {
    throw new HttpsError('unauthenticated', 'Authentication required.');
  }
  return uid;
}

export function env(name: string): string {
  const v = process.env[name];
  if (!v || !v.trim()) {
    throw new HttpsError(
      'failed-precondition',
      `Missing required env var: ${name}`,
    );
  }
  return v.trim();
}
