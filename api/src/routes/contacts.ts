// Contacts routes for ClipMind API
import { Hono } from 'hono';
import { Errors } from '../errors';
import { authMiddleware } from '../middleware/auth';
import { rateLimitMiddleware } from '../middleware/rateLimit';
import { addContactSchema, safeValidate } from '../utils/validation';
import { generateId, getCurrentTimestamp } from '../utils/crypto';
import { toPublicUser, jsonResponse } from '../utils/db';
import type { Env, User, AuthContext, Contact, ContactWithUser } from '../types';

const contacts = new Hono<{ Bindings: Env; Variables: AuthContext }>();

// GET /api/contacts - Get user's contacts
contacts.get('/', authMiddleware, async (c) => {
  const userId = c.get('userId');

  const results = await c.env.DB
    .prepare(`
      SELECT c.*, u.id as contact_user_id, u.username as contact_username,
             u.display_name as contact_display_name, u.avatar_url as contact_avatar_url,
             u.bio as contact_bio, u.created_at as contact_created_at
      FROM contacts c
      JOIN users u ON c.contact_id = u.id
      WHERE c.user_id = ? AND c.status = 'active'
      ORDER BY u.username
    `)
    .bind(userId)
    .all();

  const contactList = results.results.map((row: any) => ({
    id: row.id,
    user_id: row.user_id,
    contact_id: row.contact_id,
    status: row.status,
    created_at: row.created_at,
    user: {
      id: row.contact_user_id,
      username: row.contact_username,
      display_name: row.contact_display_name,
      avatar_url: row.contact_avatar_url,
      bio: row.contact_bio,
      created_at: row.contact_created_at
    }
  }));

  return jsonResponse({ contacts: contactList });
});

// POST /api/contacts - Add a contact
contacts.post('/', authMiddleware, rateLimitMiddleware('contact:add'), async (c) => {
  const userId = c.get('userId');
  const body = await c.req.json();
  const validation = safeValidate(addContactSchema, body);

  if (!validation.success) {
    throw Errors.VALIDATION_ERROR(validation.errors.format());
  }

  const data = validation.data;

  // Get contact user
  const contactUser = await c.env.DB
    .prepare('SELECT * FROM users WHERE username = ?')
    .bind(data.username)
    .first<User>();

  if (!contactUser) {
    throw Errors.USER_NOT_FOUND();
  }

  // Can't add yourself
  if (contactUser.id === userId) {
    throw Errors.INVALID_INPUT('Cannot add yourself as a contact');
  }

  // Check if already exists
  const existing = await c.env.DB
    .prepare('SELECT * FROM contacts WHERE user_id = ? AND contact_id = ?')
    .bind(userId, contactUser.id)
    .first<Contact>();

  if (existing) {
    if (existing.status === 'blocked') {
      throw Errors.CONFLICT('User is blocked');
    }
    throw Errors.CONFLICT('Contact already exists');
  }

  // Create contact
  const contactId = generateId();
  const timestamp = getCurrentTimestamp();

  await c.env.DB
    .prepare(`
      INSERT INTO contacts (id, user_id, contact_id, status, created_at)
      VALUES (?, ?, ?, 'active', ?)
    `)
    .bind(contactId, userId, contactUser.id, timestamp)
    .run();

  return jsonResponse({
    contact: {
      id: contactId,
      user_id: userId,
      contact_id: contactUser.id,
      status: 'active',
      created_at: timestamp,
      user: toPublicUser(contactUser)
    }
  }, 201);
});

// DELETE /api/contacts/:id - Remove a contact
contacts.delete('/:id', authMiddleware, async (c) => {
  const userId = c.get('userId');
  const contactId = c.req.param('id');

  // Get contact
  const contact = await c.env.DB
    .prepare('SELECT * FROM contacts WHERE id = ?')
    .bind(contactId)
    .first<Contact>();

  if (!contact) {
    throw Errors.NOT_FOUND('Contact');
  }

  // Verify ownership
  if (contact.user_id !== userId) {
    throw Errors.PERMISSION_DENIED();
  }

  // Delete contact
  await c.env.DB
    .prepare('DELETE FROM contacts WHERE id = ?')
    .bind(contactId)
    .run();

  return jsonResponse({ success: true });
});

// POST /api/contacts/block - Block a user
contacts.post('/block', authMiddleware, async (c) => {
  const userId = c.get('userId');
  const body = await c.req.json();
  const validation = safeValidate(addContactSchema, body);

  if (!validation.success) {
    throw Errors.VALIDATION_ERROR(validation.errors.format());
  }

  const data = validation.data;

  // Get user to block
  const userToBlock = await c.env.DB
    .prepare('SELECT * FROM users WHERE username = ?')
    .bind(data.username)
    .first<User>();

  if (!userToBlock) {
    throw Errors.USER_NOT_FOUND();
  }

  // Can't block yourself
  if (userToBlock.id === userId) {
    throw Errors.INVALID_INPUT('Cannot block yourself');
  }

  // Check if already exists
  const existing = await c.env.DB
    .prepare('SELECT * FROM contacts WHERE user_id = ? AND contact_id = ?')
    .bind(userId, userToBlock.id)
    .first<Contact>();

  if (existing) {
    if (existing.status === 'blocked') {
      throw Errors.ALREADY_BLOCKED();
    }

    // Update existing contact to blocked
    await c.env.DB
      .prepare('UPDATE contacts SET status = ? WHERE id = ?')
      .bind('blocked', existing.id)
      .run();

    return jsonResponse({ success: true });
  }

  // Create new blocked contact
  const contactId = generateId();
  const timestamp = getCurrentTimestamp();

  await c.env.DB
    .prepare(`
      INSERT INTO contacts (id, user_id, contact_id, status, created_at)
      VALUES (?, ?, ?, 'blocked', ?)
    `)
    .bind(contactId, userId, userToBlock.id, timestamp)
    .run();

  return jsonResponse({ success: true }, 201);
});

// DELETE /api/contacts/unblock/:username - Unblock a user
contacts.delete('/unblock/:username', authMiddleware, async (c) => {
  const userId = c.get('userId');
  const username = c.req.param('username');

  // Get user to unblock
  const userToUnblock = await c.env.DB
    .prepare('SELECT * FROM users WHERE username = ?')
    .bind(username)
    .first<User>();

  if (!userToUnblock) {
    throw Errors.USER_NOT_FOUND();
  }

  // Get blocked contact
  const contact = await c.env.DB
    .prepare('SELECT * FROM contacts WHERE user_id = ? AND contact_id = ? AND status = ?')
    .bind(userId, userToUnblock.id, 'blocked')
    .first<Contact>();

  if (!contact) {
    throw Errors.NOT_FOUND('Blocked contact');
  }

  // Delete block
  await c.env.DB
    .prepare('DELETE FROM contacts WHERE id = ?')
    .bind(contact.id)
    .run();

  return jsonResponse({ success: true });
});

// GET /api/contacts/blocked - Get blocked users
contacts.get('/blocked', authMiddleware, async (c) => {
  const userId = c.get('userId');

  const results = await c.env.DB
    .prepare(`
      SELECT c.*, u.id as blocked_user_id, u.username as blocked_username,
             u.display_name as blocked_display_name, u.avatar_url as blocked_avatar_url,
             u.bio as blocked_bio, u.created_at as blocked_created_at
      FROM contacts c
      JOIN users u ON c.contact_id = u.id
      WHERE c.user_id = ? AND c.status = 'blocked'
      ORDER BY u.username
    `)
    .bind(userId)
    .all();

  const blockedList = results.results.map((row: any) => ({
    id: row.id,
    user_id: row.user_id,
    contact_id: row.contact_id,
    status: row.status,
    created_at: row.created_at,
    user: {
      id: row.blocked_user_id,
      username: row.blocked_username,
      display_name: row.blocked_display_name,
      avatar_url: row.blocked_avatar_url,
      bio: row.blocked_bio,
      created_at: row.blocked_created_at
    }
  }));

  return jsonResponse({ blocked: blockedList });
});

export default contacts;
