// Authentication routes for ClipMind API
import { Hono } from 'hono';
import { Errors } from '../errors';
import { authMiddleware } from '../middleware/auth';
import { rateLimitMiddleware } from '../middleware/rateLimit';
import { registerSchema, loginSchema, updateProfileSchema, safeValidate } from '../utils/validation';
import { hashPassword, verifyPassword, generateId, getCurrentTimestamp } from '../utils/crypto';
import { createToken } from '../utils/jwt';
import { toPublicUser, jsonResponse } from '../utils/db';
import type { Env, User, AuthContext, RegisterRequest, LoginRequest } from '../types';

const auth = new Hono<{ Bindings: Env; Variables: AuthContext }>();

// POST /api/auth/register - Register new user
auth.post('/register', rateLimitMiddleware('auth:register'), async (c) => {
  const body = await c.req.json();
  const validation = safeValidate(registerSchema, body);

  if (!validation.success) {
    throw Errors.VALIDATION_ERROR(validation.errors.format());
  }

  const data = validation.data as RegisterRequest;

  // Check if username exists
  const existingUsername = await c.env.DB
    .prepare('SELECT id FROM users WHERE username = ?')
    .bind(data.username)
    .first();

  if (existingUsername) {
    throw Errors.USERNAME_EXISTS();
  }

  // Check if email exists
  const existingEmail = await c.env.DB
    .prepare('SELECT id FROM users WHERE email = ?')
    .bind(data.email)
    .first();

  if (existingEmail) {
    throw Errors.EMAIL_EXISTS();
  }

  // Hash password
  const passwordHash = await hashPassword(data.password);

  // Create user
  const userId = generateId();
  const timestamp = getCurrentTimestamp();

  await c.env.DB
    .prepare(`
      INSERT INTO users (id, username, email, password_hash, display_name, created_at, updated_at)
      VALUES (?, ?, ?, ?, ?, ?, ?)
    `)
    .bind(
      userId,
      data.username,
      data.email,
      passwordHash,
      data.display_name || null,
      timestamp,
      timestamp
    )
    .run();

  // Create default settings
  await c.env.DB
    .prepare(`
      INSERT INTO user_settings (user_id, sharing_permission, notification_enabled, auto_accept_contacts)
      VALUES (?, 'contacts', 1, 0)
    `)
    .bind(userId)
    .run();

  // Get created user
  const user = await c.env.DB
    .prepare('SELECT * FROM users WHERE id = ?')
    .bind(userId)
    .first<User>();

  if (!user) {
    throw Errors.DATABASE_ERROR();
  }

  // Generate JWT
  const token = await createToken(user.id, user.username, c.env.JWT_SECRET);

  return jsonResponse({
    token,
    user: toPublicUser(user)
  }, 201);
});

// POST /api/auth/login - Login user
auth.post('/login', rateLimitMiddleware('auth:login'), async (c) => {
  const body = await c.req.json();
  const validation = safeValidate(loginSchema, body);

  if (!validation.success) {
    throw Errors.VALIDATION_ERROR(validation.errors.format());
  }

  const data = validation.data;

  // Get user by email
  const user = await c.env.DB
    .prepare('SELECT * FROM users WHERE email = ?')
    .bind(data.email)
    .first<User>();

  if (!user) {
    throw Errors.INVALID_CREDENTIALS();
  }

  // Verify password
  const isValid = await verifyPassword(data.password, user.password_hash);

  if (!isValid) {
    throw Errors.INVALID_CREDENTIALS();
  }

  // Generate JWT
  const token = await createToken(user.id, user.username, c.env.JWT_SECRET);

  return jsonResponse({
    token,
    user: toPublicUser(user)
  });
});

// GET /api/users/me - Get current user profile
auth.get('/me', authMiddleware, async (c) => {
  const user = c.get('user');
  return jsonResponse({ user: toPublicUser(user) });
});

// PUT /api/users/me - Update current user profile
auth.put('/me', authMiddleware, async (c) => {
  const user = c.get('user');
  const body = await c.req.json();
  const validation = safeValidate(updateProfileSchema, body);

  if (!validation.success) {
    throw Errors.VALIDATION_ERROR(validation.errors.format());
  }

  const data = validation.data;
  const timestamp = getCurrentTimestamp();

  // Build update query dynamically
  const updates: string[] = [];
  const values: any[] = [];

  if (data.display_name !== undefined) {
    updates.push('display_name = ?');
    values.push(data.display_name);
  }

  if (data.bio !== undefined) {
    updates.push('bio = ?');
    values.push(data.bio);
  }

  if (updates.length === 0) {
    return jsonResponse({ user: toPublicUser(user) });
  }

  updates.push('updated_at = ?');
  values.push(timestamp);
  values.push(user.id);

  await c.env.DB
    .prepare(`UPDATE users SET ${updates.join(', ')} WHERE id = ?`)
    .bind(...values)
    .run();

  // Get updated user
  const updatedUser = await c.env.DB
    .prepare('SELECT * FROM users WHERE id = ?')
    .bind(user.id)
    .first<User>();

  if (!updatedUser) {
    throw Errors.DATABASE_ERROR();
  }

  return jsonResponse({ user: toPublicUser(updatedUser) });
});

// GET /api/users/search - Search users by username
auth.get('/search', authMiddleware, rateLimitMiddleware('search:users'), async (c) => {
  const query = c.req.query('q');
  const limit = parseInt(c.req.query('limit') || '10');

  if (!query || query.length < 1) {
    throw Errors.INVALID_INPUT('Search query must be at least 1 character');
  }

  const results = await c.env.DB
    .prepare(`
      SELECT * FROM users
      WHERE username LIKE ?
      ORDER BY username
      LIMIT ?
    `)
    .bind(`%${query}%`, Math.min(limit, 50))
    .all<User>();

  return jsonResponse({
    users: results.results.map(toPublicUser)
  });
});

export default auth;
