// Clip sharing routes for ClipMind API
import { Hono } from 'hono';
import { Errors } from '../errors';
import { authMiddleware } from '../middleware/auth';
import { rateLimitMiddleware } from '../middleware/rateLimit';
import { shareClipSchema, paginationSchema, safeValidate } from '../utils/validation';
import { generateId, getCurrentTimestamp } from '../utils/crypto';
import { toPublicUser, jsonResponse } from '../utils/db';
import type { Env, User, AuthContext, SharedClip, SharedClipWithSender, UserSettings } from '../types';

const clips = new Hono<{ Bindings: Env; Variables: AuthContext }>();

const MAX_FILE_SIZE = 5 * 1024 * 1024; // 5MB
const INLINE_CONTENT_LIMIT = 100 * 1024; // 100KB

// POST /api/clips/share - Share a clip with another user
clips.post('/share', authMiddleware, rateLimitMiddleware('clip:share'), async (c) => {
  const userId = c.get('userId');
  const user = c.get('user');
  const contentType = c.req.header('Content-Type') || '';

  let data: any;
  let fileData: ArrayBuffer | null = null;

  if (contentType.includes('multipart/form-data')) {
    const formData = await c.req.formData();
    const file = formData.get('file') as File | null;

    if (file) {
      if (file.size > MAX_FILE_SIZE) {
        throw Errors.FILE_TOO_LARGE('5MB');
      }
      fileData = await file.arrayBuffer();
    }

    const jsonFields = formData.get('data') as string;
    data = jsonFields ? JSON.parse(jsonFields) : {};
  } else {
    data = await c.req.json();
  }

  const validation = safeValidate(shareClipSchema, data);

  if (!validation.success) {
    throw Errors.VALIDATION_ERROR(validation.errors.format());
  }

  const clipData = validation.data;

  const recipient = await c.env.DB
    .prepare('SELECT * FROM users WHERE username = ?')
    .bind(clipData.recipient_username)
    .first<User>();

  if (!recipient) {
    throw Errors.USER_NOT_FOUND();
  }

  // Can't share with yourself
  if (recipient.id === userId) {
    throw Errors.INVALID_INPUT('Cannot share clips with yourself');
  }

  // Check if recipient has blocked sender
  const isBlocked = await c.env.DB
    .prepare('SELECT id FROM contacts WHERE user_id = ? AND contact_id = ? AND status = ?')
    .bind(recipient.id, userId, 'blocked')
    .first();

  if (isBlocked) {
    throw Errors.PERMISSION_DENIED();
  }

  // Check recipient's sharing permissions
  const recipientSettings = await c.env.DB
    .prepare('SELECT * FROM user_settings WHERE user_id = ?')
    .bind(recipient.id)
    .first<UserSettings>();

  if (recipientSettings?.sharing_permission === 'none') {
    throw Errors.PERMISSION_DENIED();
  }

  if (recipientSettings?.sharing_permission === 'contacts') {
    // Check if sender is in recipient's contacts
    const isContact = await c.env.DB
      .prepare('SELECT id FROM contacts WHERE user_id = ? AND contact_id = ? AND status = ?')
      .bind(recipient.id, userId, 'active')
      .first();

    if (!isContact) {
      throw Errors.PERMISSION_DENIED();
    }
  }

  // Prepare clip data
  const clipId = generateId();
  const timestamp = getCurrentTimestamp();
  let content = clipData.content || null;
  let contentUrl = null;

  // Handle file upload to R2
  if (fileData) {
    const fileName = `${clipId}-${Date.now()}`;
    await c.env.STORAGE.put(fileName, fileData);
    contentUrl = fileName;
    content = null; // Don't store inline if using R2
  } else if (content && content.length > INLINE_CONTENT_LIMIT) {
    // Store large inline content in R2
    const fileName = `${clipId}-${Date.now()}.txt`;
    await c.env.STORAGE.put(fileName, content);
    contentUrl = fileName;
    content = null;
  }

  // Calculate expiration
  let expiresAt = null;
  if (clipData.expires_in) {
    expiresAt = timestamp + clipData.expires_in;
  }

  await c.env.DB
    .prepare(`
      INSERT INTO shared_clips (
        id, sender_id, recipient_id, content_type, content, content_url, message,
        is_encrypted, encryption_metadata, is_read, created_at, expires_at
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, 0, ?, ?)
    `)
    .bind(
      clipId,
      userId,
      recipient.id,
      clipData.content_type,
      content,
      contentUrl,
      clipData.message || null,
      clipData.is_encrypted ? 1 : 0,
      clipData.encryption_metadata || null,
      timestamp,
      expiresAt
    )
    .run();

  const notificationId = generateId();
  await c.env.DB
    .prepare(`
      INSERT INTO notifications (id, user_id, type, title, message, metadata, is_read, created_at)
      VALUES (?, ?, ?, ?, ?, ?, 0, ?)
    `)
    .bind(
      notificationId,
      recipient.id,
      'clip_received',
      'New clip received',
      `You received a ${clipData.content_type} from @${user.username}`,
      JSON.stringify({ clip_id: clipId }),
      timestamp
    )
    .run();

  // Send real-time notification via Durable Object
  try {
    const notificationManager = c.env.NOTIFICATION_MANAGER.idFromName(recipient.id);
    const stub = c.env.NOTIFICATION_MANAGER.get(notificationManager);
    await stub.fetch(new Request('https://notification/notify', {
      method: 'POST',
      body: JSON.stringify({
        type: 'clip_received',
        clipId,
        senderId: userId
      })
    }));
  } catch (error) {
    console.error('Failed to send real-time notification:', error);
    // Don't fail the request if notification fails
  }

  const clip = await c.env.DB
    .prepare('SELECT * FROM shared_clips WHERE id = ?')
    .bind(clipId)
    .first<SharedClip>();

  return jsonResponse({ clip }, 201);
});

// GET /api/clips/received - Get clips received by current user
clips.get('/received', authMiddleware, async (c) => {
  const userId = c.get('userId');
  const limit = parseInt(c.req.query('limit') || '20');
  const offset = parseInt(c.req.query('offset') || '0');

  const results = await c.env.DB
    .prepare(`
      SELECT sc.*, u.id as sender_id, u.username as sender_username,
             u.display_name as sender_display_name, u.avatar_url as sender_avatar_url,
             u.bio as sender_bio, u.created_at as sender_created_at
      FROM shared_clips sc
      JOIN users u ON sc.sender_id = u.id
      WHERE sc.recipient_id = ?
        AND (sc.expires_at IS NULL OR sc.expires_at > ?)
      ORDER BY sc.created_at DESC
      LIMIT ? OFFSET ?
    `)
    .bind(userId, getCurrentTimestamp(), Math.min(limit, 100), offset)
    .all();

  const clips = results.results.map((row: any) => ({
    id: row.id,
    sender_id: row.sender_id,
    recipient_id: row.recipient_id,
    content_type: row.content_type,
    content: row.content,
    content_url: row.content_url,
    message: row.message,
    is_encrypted: row.is_encrypted,
    encryption_metadata: row.encryption_metadata,
    is_read: row.is_read,
    created_at: row.created_at,
    expires_at: row.expires_at,
    sender: {
      id: row.sender_id,
      username: row.sender_username,
      display_name: row.sender_display_name,
      avatar_url: row.sender_avatar_url,
      bio: row.sender_bio,
      created_at: row.sender_created_at
    }
  }));

  return jsonResponse({ clips });
});

// GET /api/clips/sent - Get clips sent by current user
clips.get('/sent', authMiddleware, async (c) => {
  const userId = c.get('userId');
  const limit = parseInt(c.req.query('limit') || '20');
  const offset = parseInt(c.req.query('offset') || '0');

  const results = await c.env.DB
    .prepare(`
      SELECT sc.*, u.id as recipient_id, u.username as recipient_username,
             u.display_name as recipient_display_name, u.avatar_url as recipient_avatar_url,
             u.bio as recipient_bio, u.created_at as recipient_created_at
      FROM shared_clips sc
      JOIN users u ON sc.recipient_id = u.id
      WHERE sc.sender_id = ?
      ORDER BY sc.created_at DESC
      LIMIT ? OFFSET ?
    `)
    .bind(userId, Math.min(limit, 100), offset)
    .all();

  const clips = results.results.map((row: any) => ({
    id: row.id,
    sender_id: row.sender_id,
    recipient_id: row.recipient_id,
    content_type: row.content_type,
    content: row.content,
    content_url: row.content_url,
    message: row.message,
    is_encrypted: row.is_encrypted,
    encryption_metadata: row.encryption_metadata,
    is_read: row.is_read,
    created_at: row.created_at,
    expires_at: row.expires_at,
    recipient: {
      id: row.recipient_id,
      username: row.recipient_username,
      display_name: row.recipient_display_name,
      avatar_url: row.recipient_avatar_url,
      bio: row.recipient_bio,
      created_at: row.recipient_created_at
    }
  }));

  return jsonResponse({ clips });
});

// PUT /api/clips/:id/read - Mark clip as read
clips.put('/:id/read', authMiddleware, async (c) => {
  const userId = c.get('userId');
  const clipId = c.req.param('id');

  // Get clip
  const clip = await c.env.DB
    .prepare('SELECT * FROM shared_clips WHERE id = ?')
    .bind(clipId)
    .first<SharedClip>();

  if (!clip) {
    throw Errors.CLIP_NOT_FOUND();
  }

  // Verify user is the recipient
  if (clip.recipient_id !== userId) {
    throw Errors.PERMISSION_DENIED();
  }

  // Update read status
  await c.env.DB
    .prepare('UPDATE shared_clips SET is_read = 1 WHERE id = ?')
    .bind(clipId)
    .run();

  return jsonResponse({ success: true });
});

// DELETE /api/clips/:id - Delete clip
clips.delete('/:id', authMiddleware, async (c) => {
  const userId = c.get('userId');
  const clipId = c.req.param('id');

  // Get clip
  const clip = await c.env.DB
    .prepare('SELECT * FROM shared_clips WHERE id = ?')
    .bind(clipId)
    .first<SharedClip>();

  if (!clip) {
    throw Errors.CLIP_NOT_FOUND();
  }

  // Verify user is sender or recipient
  if (clip.sender_id !== userId && clip.recipient_id !== userId) {
    throw Errors.PERMISSION_DENIED();
  }

  // Delete from R2 if exists
  if (clip.content_url) {
    try {
      await c.env.STORAGE.delete(clip.content_url);
    } catch (error) {
      console.error('Failed to delete from R2:', error);
    }
  }

  // Delete clip
  await c.env.DB
    .prepare('DELETE FROM shared_clips WHERE id = ?')
    .bind(clipId)
    .run();

  return jsonResponse({ success: true });
});

// GET /api/clips/:id/content - Get clip content from R2
clips.get('/:id/content', authMiddleware, async (c) => {
  const userId = c.get('userId');
  const clipId = c.req.param('id');

  // Get clip
  const clip = await c.env.DB
    .prepare('SELECT * FROM shared_clips WHERE id = ?')
    .bind(clipId)
    .first<SharedClip>();

  if (!clip) {
    throw Errors.CLIP_NOT_FOUND();
  }

  // Verify user is sender or recipient
  if (clip.sender_id !== userId && clip.recipient_id !== userId) {
    throw Errors.PERMISSION_DENIED();
  }

  // Check if expired
  if (clip.expires_at && clip.expires_at < getCurrentTimestamp()) {
    throw Errors.NOT_FOUND('Clip has expired');
  }

  // Get content from R2
  if (!clip.content_url) {
    throw Errors.NOT_FOUND('No external content');
  }

  const object = await c.env.STORAGE.get(clip.content_url);

  if (!object) {
    throw Errors.NOT_FOUND('Content not found');
  }

  return new Response(object.body, {
    headers: {
      'Content-Type': object.httpMetadata?.contentType || 'application/octet-stream',
      'Content-Length': object.size.toString()
    }
  });
});

export default clips;
