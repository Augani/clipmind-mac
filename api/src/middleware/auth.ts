// Authentication middleware for ClipMind API
import { Context, Next } from 'hono';
import { verifyToken, extractBearerToken } from '../utils/jwt';
import { Errors } from '../errors';
import type { Env, AuthContext, User } from '../types';

export async function authMiddleware(
  c: Context<{ Bindings: Env; Variables: AuthContext }>,
  next: Next
) {
  const authHeader = c.req.header('Authorization') ?? null;
  const token = extractBearerToken(authHeader);

  if (!token) {
    throw Errors.UNAUTHORIZED('No token provided');
  }

  // Verify token
  const payload = await verifyToken(token, c.env.JWT_SECRET);

  // Get user from database
  const user = await c.env.DB
    .prepare('SELECT * FROM users WHERE id = ?')
    .bind(payload.userId)
    .first<User>();

  if (!user) {
    throw Errors.USER_NOT_FOUND();
  }

  // Set user in context
  c.set('user', user);
  c.set('userId', user.id);

  await next();
}

export async function optionalAuthMiddleware(
  c: Context<{ Bindings: Env; Variables: Partial<AuthContext> }>,
  next: Next
) {
  const authHeader = c.req.header('Authorization') ?? null;
  const token = extractBearerToken(authHeader);

  if (token) {
    try {
      const payload = await verifyToken(token, c.env.JWT_SECRET);

      const user = await c.env.DB
        .prepare('SELECT * FROM users WHERE id = ?')
        .bind(payload.userId)
        .first<User>();

      if (user) {
        c.set('user', user);
        c.set('userId', user.id);
      }
    } catch (error) {
      // Ignore auth errors for optional auth
    }
  }

  await next();
}
