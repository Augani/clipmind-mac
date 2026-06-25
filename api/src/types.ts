// Type definitions for ClipMind API

export interface User {
  id: string;
  username: string;
  email: string;
  password_hash: string;
  display_name: string | null;
  avatar_url: string | null;
  bio: string | null;
  created_at: number;
  updated_at: number;
}

export interface UserPublic {
  id: string;
  username: string;
  display_name: string | null;
  avatar_url: string | null;
  bio: string | null;
  created_at: number;
}

export interface SharedClip {
  id: string;
  sender_id: string;
  recipient_id: string;
  content_type: string;
  content: string | null;
  content_url: string | null;
  message: string | null;
  is_encrypted: number;
  encryption_metadata: string | null;
  is_read: number;
  created_at: number;
  expires_at: number | null;
}

export interface SharedClipWithSender extends SharedClip {
  sender: UserPublic;
}

export interface Contact {
  id: string;
  user_id: string;
  contact_id: string;
  status: 'active' | 'blocked';
  created_at: number;
}

export interface ContactWithUser extends Contact {
  user: UserPublic;
}

export interface Notification {
  id: string;
  user_id: string;
  type: 'clip_received' | 'contact_request' | 'system';
  title: string;
  message: string;
  metadata: string | null;
  is_read: number;
  created_at: number;
}

export interface UserSettings {
  user_id: string;
  sharing_permission: 'anyone' | 'contacts' | 'none';
  notification_enabled: number;
  auto_accept_contacts: number;
}

export interface JWTPayload {
  userId: string;
  username: string;
  iat: number;
  exp: number;
}

export interface RateLimit {
  key: string;
  count: number;
  window_start: number;
}

// Request/Response types

export interface RegisterRequest {
  username: string;
  email: string;
  password: string;
  display_name?: string;
}

export interface LoginRequest {
  email: string;
  password: string;
}

export interface AuthResponse {
  token: string;
  user: UserPublic;
}

export interface ShareClipRequest {
  recipient_username: string;
  content_type: string;
  content?: string;
  file?: File;
  is_encrypted?: boolean;
  encryption_metadata?: string;
  expires_in?: number; // seconds
}

export interface UpdateProfileRequest {
  display_name?: string;
  bio?: string;
  avatar?: File;
}

export interface AddContactRequest {
  username: string;
}

export interface UpdateSettingsRequest {
  sharing_permission?: 'anyone' | 'contacts' | 'none';
  notification_enabled?: boolean;
  auto_accept_contacts?: boolean;
}

// Environment bindings
export interface Env {
  DB: D1Database;
  STORAGE: R2Bucket;
  NOTIFICATION_MANAGER: DurableObjectNamespace;
  JWT_SECRET: string;
  ENVIRONMENT: string;
}

// Context types for Hono
export interface AuthContext {
  user: User;
  userId: string;
}
