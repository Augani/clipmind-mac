// JWT utilities for ClipMind API
import { SignJWT, jwtVerify } from 'jose';
import type { JWTPayload } from '../types';
import { Errors } from '../errors';

const JWT_EXPIRY = 30 * 24 * 60 * 60; // 30 days in seconds

export async function createToken(
  userId: string,
  username: string,
  secret: string
): Promise<string> {
  const encoder = new TextEncoder();
  const secretKey = encoder.encode(secret);

  const token = await new SignJWT({
    userId,
    username
  })
    .setProtectedHeader({ alg: 'HS256' })
    .setIssuedAt()
    .setExpirationTime(`${JWT_EXPIRY}s`)
    .sign(secretKey);

  return token;
}

export async function verifyToken(
  token: string,
  secret: string
): Promise<JWTPayload> {
  try {
    const encoder = new TextEncoder();
    const secretKey = encoder.encode(secret);

    const { payload } = await jwtVerify(token, secretKey);

    return {
      userId: payload.userId as string,
      username: payload.username as string,
      iat: payload.iat as number,
      exp: payload.exp as number
    };
  } catch (error) {
    throw Errors.INVALID_TOKEN();
  }
}

export function extractBearerToken(authHeader: string | null): string | null {
  if (!authHeader) {
    return null;
  }

  const match = authHeader.match(/^Bearer\s+(.+)$/i);
  return match ? match[1] : null;
}
