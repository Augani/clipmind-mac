// Settings routes for ClipMind API
import { Hono } from 'hono';
import { Errors } from '../errors';
import { authMiddleware } from '../middleware/auth';
import { updateSettingsSchema, safeValidate } from '../utils/validation';
import { jsonResponse } from '../utils/db';
import type { Env, AuthContext, UserSettings } from '../types';

const settings = new Hono<{ Bindings: Env; Variables: AuthContext }>();

// GET /api/settings - Get user settings
settings.get('/', authMiddleware, async (c) => {
  const userId = c.get('userId');

  const userSettings = await c.env.DB
    .prepare('SELECT * FROM user_settings WHERE user_id = ?')
    .bind(userId)
    .first<UserSettings>();

  if (!userSettings) {
    // Return default settings if not found
    return jsonResponse({
      settings: {
        user_id: userId,
        sharing_permission: 'contacts',
        notification_enabled: 1,
        auto_accept_contacts: 0
      }
    });
  }

  return jsonResponse({ settings: userSettings });
});

// PUT /api/settings - Update user settings
settings.put('/', authMiddleware, async (c) => {
  const userId = c.get('userId');
  const body = await c.req.json();
  const validation = safeValidate(updateSettingsSchema, body);

  if (!validation.success) {
    throw Errors.VALIDATION_ERROR(validation.errors.format());
  }

  const data = validation.data;

  // Check if settings exist
  const existing = await c.env.DB
    .prepare('SELECT * FROM user_settings WHERE user_id = ?')
    .bind(userId)
    .first<UserSettings>();

  if (!existing) {
    // Create settings if not exist
    await c.env.DB
      .prepare(`
        INSERT INTO user_settings (user_id, sharing_permission, notification_enabled, auto_accept_contacts)
        VALUES (?, ?, ?, ?)
      `)
      .bind(
        userId,
        data.sharing_permission || 'contacts',
        data.notification_enabled !== undefined ? (data.notification_enabled ? 1 : 0) : 1,
        data.auto_accept_contacts !== undefined ? (data.auto_accept_contacts ? 1 : 0) : 0
      )
      .run();
  } else {
    // Build update query dynamically
    const updates: string[] = [];
    const values: any[] = [];

    if (data.sharing_permission !== undefined) {
      updates.push('sharing_permission = ?');
      values.push(data.sharing_permission);
    }

    if (data.notification_enabled !== undefined) {
      updates.push('notification_enabled = ?');
      values.push(data.notification_enabled ? 1 : 0);
    }

    if (data.auto_accept_contacts !== undefined) {
      updates.push('auto_accept_contacts = ?');
      values.push(data.auto_accept_contacts ? 1 : 0);
    }

    if (updates.length > 0) {
      values.push(userId);
      await c.env.DB
        .prepare(`UPDATE user_settings SET ${updates.join(', ')} WHERE user_id = ?`)
        .bind(...values)
        .run();
    }
  }

  // Get updated settings
  const updatedSettings = await c.env.DB
    .prepare('SELECT * FROM user_settings WHERE user_id = ?')
    .bind(userId)
    .first<UserSettings>();

  return jsonResponse({ settings: updatedSettings });
});

export default settings;
