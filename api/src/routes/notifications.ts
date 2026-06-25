// Notifications routes for ClipMind API
import { Hono } from 'hono';
import { Errors } from '../errors';
import { authMiddleware } from '../middleware/auth';
import { jsonResponse } from '../utils/db';
import type { Env, AuthContext, Notification } from '../types';

const notifications = new Hono<{ Bindings: Env; Variables: AuthContext }>();

// GET /api/notifications - Get user's notifications
notifications.get('/', authMiddleware, async (c) => {
  const userId = c.get('userId');
  const limit = parseInt(c.req.query('limit') || '50');
  const offset = parseInt(c.req.query('offset') || '0');
  const unreadOnly = c.req.query('unread') === 'true';

  let query = `
    SELECT * FROM notifications
    WHERE user_id = ?
  `;

  const params: any[] = [userId];

  if (unreadOnly) {
    query += ' AND is_read = 0';
  }

  query += ' ORDER BY created_at DESC LIMIT ? OFFSET ?';
  params.push(Math.min(limit, 100), offset);

  const results = await c.env.DB
    .prepare(query)
    .bind(...params)
    .all<Notification>();

  return jsonResponse({ notifications: results.results });
});

// GET /api/notifications/unread-count - Get unread notification count
notifications.get('/unread-count', authMiddleware, async (c) => {
  const userId = c.get('userId');

  const result = await c.env.DB
    .prepare('SELECT COUNT(*) as count FROM notifications WHERE user_id = ? AND is_read = 0')
    .bind(userId)
    .first<{ count: number }>();

  return jsonResponse({ count: result?.count || 0 });
});

// PUT /api/notifications/:id/read - Mark notification as read
notifications.put('/:id/read', authMiddleware, async (c) => {
  const userId = c.get('userId');
  const notificationId = c.req.param('id');

  // Get notification
  const notification = await c.env.DB
    .prepare('SELECT * FROM notifications WHERE id = ?')
    .bind(notificationId)
    .first<Notification>();

  if (!notification) {
    throw Errors.NOT_FOUND('Notification');
  }

  // Verify ownership
  if (notification.user_id !== userId) {
    throw Errors.PERMISSION_DENIED();
  }

  // Mark as read
  await c.env.DB
    .prepare('UPDATE notifications SET is_read = 1 WHERE id = ?')
    .bind(notificationId)
    .run();

  return jsonResponse({ success: true });
});

// PUT /api/notifications/read-all - Mark all notifications as read
notifications.put('/read-all', authMiddleware, async (c) => {
  const userId = c.get('userId');

  await c.env.DB
    .prepare('UPDATE notifications SET is_read = 1 WHERE user_id = ? AND is_read = 0')
    .bind(userId)
    .run();

  return jsonResponse({ success: true });
});

// DELETE /api/notifications/:id - Delete notification
notifications.delete('/:id', authMiddleware, async (c) => {
  const userId = c.get('userId');
  const notificationId = c.req.param('id');

  // Get notification
  const notification = await c.env.DB
    .prepare('SELECT * FROM notifications WHERE id = ?')
    .bind(notificationId)
    .first<Notification>();

  if (!notification) {
    throw Errors.NOT_FOUND('Notification');
  }

  // Verify ownership
  if (notification.user_id !== userId) {
    throw Errors.PERMISSION_DENIED();
  }

  // Delete notification
  await c.env.DB
    .prepare('DELETE FROM notifications WHERE id = ?')
    .bind(notificationId)
    .run();

  return jsonResponse({ success: true });
});

export default notifications;
