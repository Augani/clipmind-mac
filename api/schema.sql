-- ClipMind Database Schema
-- Cloudflare D1 (SQLite)

-- Users table
CREATE TABLE IF NOT EXISTS users (
  id TEXT PRIMARY KEY,
  username TEXT UNIQUE NOT NULL,
  email TEXT UNIQUE NOT NULL,
  password_hash TEXT NOT NULL,
  display_name TEXT,
  avatar_url TEXT,
  bio TEXT,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL,
  CHECK (length(username) >= 3 AND length(username) <= 20),
  CHECK (username GLOB '[a-z0-9_]*')
);

-- Shared clips table
CREATE TABLE IF NOT EXISTS shared_clips (
  id TEXT PRIMARY KEY,
  sender_id TEXT NOT NULL,
  recipient_id TEXT NOT NULL,
  content_type TEXT NOT NULL,
  content TEXT,
  content_url TEXT,
  message TEXT,
  is_encrypted INTEGER DEFAULT 0,
  encryption_metadata TEXT,
  is_read INTEGER DEFAULT 0,
  created_at INTEGER NOT NULL,
  expires_at INTEGER,
  FOREIGN KEY (sender_id) REFERENCES users(id) ON DELETE CASCADE,
  FOREIGN KEY (recipient_id) REFERENCES users(id) ON DELETE CASCADE
);

-- Contacts table
CREATE TABLE IF NOT EXISTS contacts (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL,
  contact_id TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'active',
  created_at INTEGER NOT NULL,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  FOREIGN KEY (contact_id) REFERENCES users(id) ON DELETE CASCADE,
  UNIQUE(user_id, contact_id),
  CHECK (status IN ('active', 'blocked'))
);

-- Notifications table
CREATE TABLE IF NOT EXISTS notifications (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL,
  type TEXT NOT NULL,
  title TEXT NOT NULL,
  message TEXT NOT NULL,
  metadata TEXT,
  is_read INTEGER DEFAULT 0,
  created_at INTEGER NOT NULL,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  CHECK (type IN ('clip_received', 'contact_request', 'system'))
);

-- Rate limits table
CREATE TABLE IF NOT EXISTS rate_limits (
  key TEXT PRIMARY KEY,
  count INTEGER NOT NULL DEFAULT 0,
  window_start INTEGER NOT NULL
);

-- User settings table
CREATE TABLE IF NOT EXISTS user_settings (
  user_id TEXT PRIMARY KEY,
  sharing_permission TEXT NOT NULL DEFAULT 'contacts',
  notification_enabled INTEGER DEFAULT 1,
  auto_accept_contacts INTEGER DEFAULT 0,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  CHECK (sharing_permission IN ('anyone', 'contacts', 'none'))
);

-- Indexes for performance

-- Users
CREATE INDEX IF NOT EXISTS idx_users_username ON users(username);
CREATE INDEX IF NOT EXISTS idx_users_email ON users(email);

-- Shared clips
CREATE INDEX IF NOT EXISTS idx_shared_clips_recipient ON shared_clips(recipient_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_shared_clips_sender ON shared_clips(sender_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_shared_clips_unread ON shared_clips(recipient_id, is_read, created_at DESC);

-- Contacts
CREATE INDEX IF NOT EXISTS idx_contacts_user ON contacts(user_id, status);
CREATE INDEX IF NOT EXISTS idx_contacts_contact ON contacts(contact_id, status);

-- Notifications
CREATE INDEX IF NOT EXISTS idx_notifications_user ON notifications(user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_notifications_unread ON notifications(user_id, is_read, created_at DESC);

-- Rate limits
CREATE INDEX IF NOT EXISTS idx_rate_limits_window ON rate_limits(window_start);
