# ClipMind Cloudflare Worker API Specification

## Overview

**Purpose:** REST API backend for Phase 16 Clip Sharing & Social Features
**Technology:** Cloudflare Workers + Durable Objects
**Database:** Cloudflare D1 (SQLite)
**Storage:** Cloudflare R2 for large attachments (images, files)
**Authentication:** JWT tokens stored in client Keychain
**API Version:** 1.0
**Base URL:** `https://api.clipmind.workers.dev`

---

## Authentication & Security

### JWT Token Structure
```typescript
interface JWTPayload {
  userId: string;           // UUID
  username: string;         // clippy username
  issuedAt: number;        // Unix timestamp
  expiresAt: number;       // Unix timestamp (30 days)
}
```

### Authentication Headers
```
Authorization: Bearer <jwt_token>
X-API-Version: 1.0
Content-Type: application/json
```

### Rate Limiting
- **Share endpoint:** 50 requests/hour per user
- **Search endpoint:** 100 requests/hour per user
- **Auth endpoints:** 10 requests/15min per IP
- **Headers returned:** `X-RateLimit-Remaining`, `X-RateLimit-Reset`

### Encryption Support
- Optional E2E encryption for sensitive clips
- Client generates ephemeral key pair
- Public key sent with share request
- Encrypted content blob stored, decryption client-side

---

## Data Models (DTOs)

### User
```typescript
interface User {
  id: string;                    // UUID
  username: string;              // 3-20 chars, alphanumeric, unique
  email?: string;                // Optional, for notifications
  displayName: string;           // Display name
  avatarUrl?: string;            // R2 URL or gravatar
  isPublic: boolean;             // Profile visibility
  createdAt: string;             // ISO 8601
  lastActiveAt: string;          // ISO 8601

  // Privacy settings
  sharingPermissions: 'anyone' | 'contacts' | 'none';
  allowSensitiveShares: boolean; // Whether to accept sensitive content
}
```

### SharedClip
```typescript
interface SharedClip {
  id: string;                    // UUID
  senderId: string;              // UUID
  senderUsername: string;        // For display
  recipientId: string;           // UUID
  recipientUsername: string;     // For display

  // Content
  contentType: 'text' | 'image' | 'url' | 'file';
  content: string | null;        // Actual content or null if encrypted
  contentUrl?: string;           // R2 URL for large files/images

  // Metadata
  message?: string;              // Optional sender message
  sourceApp?: string;            // Original source app
  windowTitle?: string;          // Original window title

  // Security
  isEncrypted: boolean;          // E2E encrypted flag
  encryptedBlob?: string;        // Base64 encrypted content
  encryptionPublicKey?: string;  // Recipient's public key used

  // Status
  isRead: boolean;
  readAt?: string;               // ISO 8601
  createdAt: string;             // ISO 8601
  expiresAt?: string;            // Optional auto-delete (ISO 8601)
}
```

### Contact
```typescript
interface Contact {
  id: string;                    // UUID
  userId: string;                // Owner's UUID
  contactUserId: string;         // Contact's UUID
  contactUsername: string;       // Contact's username
  displayName?: string;          // Custom display name
  isBlocked: boolean;            // Blocked status
  addedAt: string;               // ISO 8601
}
```

### ShareRequest (POST body)
```typescript
interface ShareRequest {
  recipientUsername: string;     // Target user
  contentType: 'text' | 'image' | 'url' | 'file';
  content?: string;              // Plain text/url content
  fileData?: string;             // Base64 encoded image/file (<5MB)
  message?: string;              // Optional message (max 500 chars)
  sourceApp?: string;
  windowTitle?: string;
  isEncrypted?: boolean;
  encryptedBlob?: string;        // If encrypted
  encryptionPublicKey?: string;
  expiresInHours?: number;       // Auto-delete after N hours
}
```

### Notification
```typescript
interface Notification {
  id: string;
  userId: string;
  type: 'clip_received' | 'clip_read' | 'new_contact';
  clipId?: string;               // For clip notifications
  message: string;
  isRead: boolean;
  createdAt: string;
}
```

---

## API Endpoints

### 1. Authentication & User Management

#### POST `/api/auth/register`
**Description:** Create new user account
**Authentication:** None
**Rate Limit:** 10/15min per IP

**Request:**
```json
{
  "username": "johndoe",
  "email": "john@example.com",
  "displayName": "John Doe",
  "password": "hashed_password"
}
```

**Response (201):**
```json
{
  "success": true,
  "user": {
    "id": "uuid",
    "username": "johndoe",
    "displayName": "John Doe",
    "createdAt": "2024-01-01T00:00:00Z"
  },
  "token": "jwt_token_here"
}
```

**Errors:**
- 400: Username taken, invalid format
- 429: Rate limit exceeded

---

#### POST `/api/auth/login`
**Description:** Authenticate user
**Authentication:** None
**Rate Limit:** 10/15min per IP

**Request:**
```json
{
  "username": "johndoe",
  "password": "hashed_password"
}
```

**Response (200):**
```json
{
  "success": true,
  "user": { /* User object */ },
  "token": "jwt_token_here"
}
```

**Errors:**
- 401: Invalid credentials
- 429: Rate limit exceeded

---

#### GET `/api/users/me`
**Description:** Get current user profile
**Authentication:** Required

**Response (200):**
```json
{
  "success": true,
  "user": { /* Full User object with settings */ }
}
```

---

#### PUT `/api/users/me`
**Description:** Update user profile
**Authentication:** Required

**Request:**
```json
{
  "displayName": "New Name",
  "email": "new@email.com",
  "isPublic": true,
  "sharingPermissions": "contacts",
  "allowSensitiveShares": false
}
```

**Response (200):**
```json
{
  "success": true,
  "user": { /* Updated User object */ }
}
```

---

#### GET `/api/users/search?q={query}&limit={limit}`
**Description:** Search users by username
**Authentication:** Required
**Rate Limit:** 100/hour

**Query Params:**
- `q`: Search query (min 2 chars)
- `limit`: Max results (default 10, max 50)

**Response (200):**
```json
{
  "success": true,
  "users": [
    {
      "id": "uuid",
      "username": "johndoe",
      "displayName": "John Doe",
      "avatarUrl": "https://...",
      "isPublic": true
    }
  ],
  "count": 1
}
```

---

#### GET `/api/users/{username}`
**Description:** Get public user profile
**Authentication:** Required

**Response (200):**
```json
{
  "success": true,
  "user": {
    "username": "johndoe",
    "displayName": "John Doe",
    "avatarUrl": "https://...",
    "isPublic": true,
    "createdAt": "2024-01-01T00:00:00Z"
  },
  "canShare": true
}
```

**Errors:**
- 404: User not found
- 403: Profile is private

---

### 2. Clip Sharing

#### POST `/api/clips/share`
**Description:** Share clipboard item with user
**Authentication:** Required
**Rate Limit:** 50/hour

**Request:**
```json
{
  "recipientUsername": "janedoe",
  "contentType": "text",
  "content": "Hello, World!",
  "message": "Check this out!",
  "sourceApp": "Xcode",
  "expiresInHours": 24
}
```

**Response (201):**
```json
{
  "success": true,
  "clip": { /* Full SharedClip object */ },
  "message": "Clip shared successfully"
}
```

**Errors:**
- 400: Invalid content, recipient not found
- 403: Recipient blocked you / doesn't accept shares
- 413: Content too large (>5MB)
- 429: Rate limit exceeded

---

#### GET `/api/clips/received?limit={limit}&offset={offset}&unread={bool}`
**Description:** Get clips sent to you
**Authentication:** Required
**Rate Limit:** 200/hour

**Query Params:**
- `limit`: Results per page (default 20, max 100)
- `offset`: Pagination offset (default 0)
- `unread`: Filter unread only (default false)

**Response (200):**
```json
{
  "success": true,
  "clips": [ /* Array of SharedClip objects */ ],
  "total": 50,
  "unreadCount": 5,
  "hasMore": true
}
```

---

#### GET `/api/clips/sent?limit={limit}&offset={offset}`
**Description:** Get clips you've shared
**Authentication:** Required

**Response (200):**
```json
{
  "success": true,
  "clips": [ /* Array of SharedClip objects */ ],
  "total": 30,
  "hasMore": true
}
```

---

#### GET `/api/clips/{clipId}`
**Description:** Get specific clip details
**Authentication:** Required

**Response (200):**
```json
{
  "success": true,
  "clip": { /* SharedClip object */ }
}
```

**Errors:**
- 404: Clip not found
- 403: Not authorized (not sender/recipient)

---

#### PUT `/api/clips/{clipId}/read`
**Description:** Mark clip as read
**Authentication:** Required

**Response (200):**
```json
{
  "success": true,
  "clip": { /* Updated SharedClip with isRead=true */ }
}
```

---

#### DELETE `/api/clips/{clipId}`
**Description:** Delete shared clip (sender or recipient)
**Authentication:** Required

**Response (200):**
```json
{
  "success": true,
  "message": "Clip deleted successfully"
}
```

---

### 3. Contacts & Blocking

#### GET `/api/contacts`
**Description:** Get user's contact list
**Authentication:** Required

**Response (200):**
```json
{
  "success": true,
  "contacts": [ /* Array of Contact objects */ ],
  "count": 10
}
```

---

#### POST `/api/contacts`
**Description:** Add contact
**Authentication:** Required

**Request:**
```json
{
  "username": "janedoe",
  "displayName": "Jane (Work)"
}
```

**Response (201):**
```json
{
  "success": true,
  "contact": { /* Contact object */ }
}
```

---

#### PUT `/api/contacts/{contactId}/block`
**Description:** Block/unblock user
**Authentication:** Required

**Request:**
```json
{
  "blocked": true
}
```

**Response (200):**
```json
{
  "success": true,
  "contact": { /* Updated Contact */ }
}
```

---

#### DELETE `/api/contacts/{contactId}`
**Description:** Remove contact
**Authentication:** Required

**Response (200):**
```json
{
  "success": true
}
```

---

### 4. Notifications

#### GET `/api/notifications?unread={bool}&limit={limit}`
**Description:** Get user notifications
**Authentication:** Required

**Response (200):**
```json
{
  "success": true,
  "notifications": [ /* Array of Notification objects */ ],
  "unreadCount": 3
}
```

---

#### PUT `/api/notifications/{notificationId}/read`
**Description:** Mark notification as read
**Authentication:** Required

**Response (200):**
```json
{
  "success": true
}
```

---

#### PUT `/api/notifications/read-all`
**Description:** Mark all notifications as read
**Authentication:** Required

**Response (200):**
```json
{
  "success": true,
  "count": 5
}
```

---

## Error Response Format

All errors follow consistent format:

```json
{
  "success": false,
  "error": {
    "code": "ERROR_CODE",
    "message": "Human-readable error message",
    "details": { /* Optional additional context */ }
  }
}
```

**Error Codes:**
- `UNAUTHORIZED` - Missing/invalid auth token
- `FORBIDDEN` - Insufficient permissions
- `NOT_FOUND` - Resource not found
- `VALIDATION_ERROR` - Invalid input data
- `RATE_LIMIT_EXCEEDED` - Too many requests
- `CONTENT_TOO_LARGE` - Payload exceeds limit
- `USER_BLOCKED` - Recipient blocked sender
- `PRIVACY_RESTRICTION` - Privacy settings prevent action
- `SENSITIVE_CONTENT_BLOCKED` - Sensitive content not allowed
- `SERVER_ERROR` - Internal server error

---

## Database Schema (D1)

### users
```sql
CREATE TABLE users (
  id TEXT PRIMARY KEY,
  username TEXT UNIQUE NOT NULL,
  email TEXT,
  display_name TEXT NOT NULL,
  password_hash TEXT NOT NULL,
  avatar_url TEXT,
  is_public INTEGER DEFAULT 1,
  sharing_permissions TEXT DEFAULT 'anyone',
  allow_sensitive_shares INTEGER DEFAULT 0,
  created_at INTEGER NOT NULL,
  last_active_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL
);

CREATE UNIQUE INDEX idx_users_username ON users(username);
CREATE INDEX idx_users_email ON users(email);
```

### shared_clips
```sql
CREATE TABLE shared_clips (
  id TEXT PRIMARY KEY,
  sender_id TEXT NOT NULL,
  sender_username TEXT NOT NULL,
  recipient_id TEXT NOT NULL,
  recipient_username TEXT NOT NULL,
  content_type TEXT NOT NULL,
  content TEXT,
  content_url TEXT,
  message TEXT,
  source_app TEXT,
  window_title TEXT,
  is_encrypted INTEGER DEFAULT 0,
  encrypted_blob TEXT,
  encryption_public_key TEXT,
  is_read INTEGER DEFAULT 0,
  read_at INTEGER,
  created_at INTEGER NOT NULL,
  expires_at INTEGER,
  FOREIGN KEY (sender_id) REFERENCES users(id) ON DELETE CASCADE,
  FOREIGN KEY (recipient_id) REFERENCES users(id) ON DELETE CASCADE
);

CREATE INDEX idx_shared_clips_recipient ON shared_clips(recipient_id, created_at DESC);
CREATE INDEX idx_shared_clips_sender ON shared_clips(sender_id, created_at DESC);
CREATE INDEX idx_shared_clips_unread ON shared_clips(recipient_id, is_read, created_at DESC);
CREATE INDEX idx_shared_clips_expires ON shared_clips(expires_at);
```

### contacts
```sql
CREATE TABLE contacts (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL,
  contact_user_id TEXT NOT NULL,
  contact_username TEXT NOT NULL,
  display_name TEXT,
  is_blocked INTEGER DEFAULT 0,
  added_at INTEGER NOT NULL,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  FOREIGN KEY (contact_user_id) REFERENCES users(id) ON DELETE CASCADE,
  UNIQUE(user_id, contact_user_id)
);

CREATE INDEX idx_contacts_user ON contacts(user_id);
CREATE INDEX idx_contacts_blocked ON contacts(user_id, is_blocked);
```

### notifications
```sql
CREATE TABLE notifications (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL,
  type TEXT NOT NULL,
  clip_id TEXT,
  message TEXT NOT NULL,
  is_read INTEGER DEFAULT 0,
  created_at INTEGER NOT NULL,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  FOREIGN KEY (clip_id) REFERENCES shared_clips(id) ON DELETE CASCADE
);

CREATE INDEX idx_notifications_user ON notifications(user_id, created_at DESC);
CREATE INDEX idx_notifications_unread ON notifications(user_id, is_read, created_at DESC);
```

### rate_limits
```sql
CREATE TABLE rate_limits (
  key TEXT PRIMARY KEY,
  count INTEGER NOT NULL,
  reset_at INTEGER NOT NULL
);

CREATE INDEX idx_rate_limits_reset ON rate_limits(reset_at);
```

---

## Cloudflare Worker Structure

### File Organization
```
workers/
├── src/
│   ├── index.ts              # Main router
│   ├── auth/
│   │   ├── jwt.ts            # JWT utilities
│   │   ├── password.ts       # Password hashing
│   │   └── middleware.ts     # Auth middleware
│   ├── routes/
│   │   ├── auth.ts           # Auth endpoints
│   │   ├── users.ts          # User endpoints
│   │   ├── clips.ts          # Sharing endpoints
│   │   ├── contacts.ts       # Contact management
│   │   └── notifications.ts  # Notification endpoints
│   ├── db/
│   │   ├── schema.sql        # Database schema
│   │   └── queries.ts        # Prepared queries
│   ├── middleware/
│   │   ├── rateLimit.ts      # Rate limiting
│   │   ├── validation.ts     # Input validation
│   │   └── cors.ts           # CORS headers
│   ├── utils/
│   │   ├── encryption.ts     # E2E encryption helpers
│   │   ├── storage.ts        # R2 storage
│   │   └── errors.ts         # Error handlers
│   └── types/
│       └── index.ts          # TypeScript interfaces
├── wrangler.toml             # Cloudflare config
├── package.json
└── tsconfig.json
```

### Dependencies
```json
{
  "dependencies": {
    "@cloudflare/workers-types": "^4.0.0",
    "hono": "^3.0.0",
    "jose": "^5.0.0",
    "zod": "^3.0.0"
  }
}
```

### Environment Variables (wrangler.toml)
```toml
[vars]
JWT_SECRET = "secret_key_here"
JWT_EXPIRY_DAYS = "30"
MAX_FILE_SIZE = "5242880"
RATE_LIMIT_SHARE = "50"
RATE_LIMIT_SEARCH = "100"

[[d1_databases]]
binding = "DB"
database_name = "clipmind"
database_id = "your-database-id"

[[r2_buckets]]
binding = "STORAGE"
bucket_name = "clipmind-attachments"
```

---

## Client Integration (Swift)

### Service Structure

```swift
// ClipSharingService.swift
class ClipSharingService: ObservableObject {
    static let shared = ClipSharingService()

    @Published var isAuthenticated = false
    @Published var currentUser: User?
    @Published var receivedClips: [SharedClip] = []
    @Published var sentClips: [SharedClip] = []
    @Published var unreadCount = 0
    @Published var syncState: SyncState = .idle

    private let baseURL = "https://api.clipmind.workers.dev"
    private var authToken: String?

    // Load token from Keychain on init
    init() {
        loadAuthToken()
    }

    // API Methods
    func register(username: String, email: String, password: String) async throws -> User
    func login(username: String, password: String) async throws -> User
    func logout()
    func searchUsers(query: String) async throws -> [User]
    func shareClip(_ request: ShareRequest) async throws -> SharedClip
    func fetchReceivedClips(unreadOnly: Bool) async throws -> [SharedClip]
    func fetchSentClips() async throws -> [SharedClip]
    func markAsRead(_ clipId: String) async throws
    func deleteClip(_ clipId: String) async throws
    func addContact(username: String) async throws -> Contact
    func blockUser(_ contactId: String, blocked: Bool) async throws
    func fetchNotifications() async throws -> [Notification]

    // Background sync (call every 5 minutes)
    func syncInBackground() async
}
```

### Database Integration

Add to existing `DatabaseService.swift`:

```swift
// New tables for local caching
CREATE TABLE local_shared_clips (
    id TEXT PRIMARY KEY,
    sender_id TEXT NOT NULL,
    sender_username TEXT NOT NULL,
    recipient_id TEXT NOT NULL,
    recipient_username TEXT NOT NULL,
    content_type TEXT NOT NULL,
    content TEXT,
    message TEXT,
    is_read INTEGER DEFAULT 0,
    created_at REAL NOT NULL
);

CREATE TABLE local_contacts (
    id TEXT PRIMARY KEY,
    contact_user_id TEXT NOT NULL,
    contact_username TEXT NOT NULL,
    display_name TEXT,
    is_blocked INTEGER DEFAULT 0,
    added_at REAL NOT NULL
);

CREATE TABLE sync_queue (
    id TEXT PRIMARY KEY,
    operation TEXT NOT NULL,
    payload TEXT NOT NULL,
    created_at REAL NOT NULL,
    retry_count INTEGER DEFAULT 0
);
```

---

## Implementation Phases

### Phase 1: Core Infrastructure (2-3 days)
- Set up Cloudflare Worker project with Hono
- Initialize D1 database with schema
- Implement JWT authentication utilities
- Basic routing and middleware
- Error handling framework
- Rate limiting middleware

### Phase 2: User Management (2 days)
- User registration/login endpoints
- Profile management
- Username search with autocomplete
- Password hashing with bcrypt
- Email validation

### Phase 3: Clip Sharing (3 days)
- Share endpoint with validation
- Content storage (text inline, images to R2)
- Received/sent clips endpoints
- Read status tracking
- Clip deletion
- Sensitive content validation
- Expiry handling

### Phase 4: Contacts & Privacy (2 days)
- Contact management CRUD
- Blocking system implementation
- Privacy settings enforcement
- Share permission validation

### Phase 5: Notifications (1 day)
- Notification creation on clip receipt
- Notification fetching with filtering
- Mark as read functionality
- Batch mark all as read

### Phase 6: Client Integration (3-4 days)
- `ClipSharingService.swift` implementation
- `AuthenticationService.swift` implementation
- UI views (ShareClipView, ReceivedClipsView)
- Background sync mechanism
- Local database tables
- Keychain token storage
- Error handling and retry logic

---

## Performance Optimizations

1. **Database Indexes:** All queries optimized with proper indexes on frequently queried columns
2. **R2 for Large Files:** Images/files >100KB stored in R2, URLs in database
3. **Response Caching:** User profiles cached for 5 minutes at edge
4. **Connection Pooling:** D1 prepared statements for query optimization
5. **Lazy Loading:** Paginated responses (20 items default, max 100)
6. **Background Cleanup:** Scheduled cron job to delete expired clips
7. **Edge Caching:** Static responses cached at Cloudflare edge locations
8. **Batch Operations:** Support bulk read/delete operations
9. **Query Optimization:** Use covering indexes where possible
10. **Content Compression:** Gzip compression for responses >1KB

---

## Security Considerations

1. **Password Hashing:** bcrypt with salt (cost factor 10)
2. **JWT Expiry:** 30-day tokens with refresh mechanism
3. **Rate Limiting:** Per-endpoint limits with exponential backoff
4. **Input Validation:** Zod schemas validate all inputs
5. **SQL Injection:** Parameterized queries only, no string interpolation
6. **XSS Prevention:** Content sanitization before storage and retrieval
7. **CORS:** Strict origin checking, whitelist only
8. **Sensitive Content:** Auto-block unless recipient explicitly allows
9. **E2E Encryption:** Optional client-side encryption with public key crypto
10. **HTTPS Only:** TLS 1.3 enforced, no downgrade
11. **Token Storage:** JWT stored in macOS Keychain, never in UserDefaults
12. **Audit Logging:** Track sensitive operations (login, share, block)
13. **CSRF Protection:** Not needed (no cookies, token-based auth)
14. **File Upload Validation:** Check MIME types, size limits, magic bytes

---

## Monitoring & Analytics

### Metrics to Track
- Request count by endpoint
- Error rate by error code
- Response time (p50, p95, p99)
- Rate limit hits
- Storage usage (D1 rows, R2 bytes)
- Active users (DAU, MAU)
- Share volume and success rate
- Failed authentication attempts

### Cloudflare Analytics
- Workers Analytics for request metrics
- D1 Analytics for database performance
- R2 Analytics for storage usage
- Custom logging with Workers Logpush

---

## Future Enhancements

1. **Webhooks:** Real-time push notifications instead of polling
2. **GraphQL API:** Alternative to REST for flexible queries
3. **Batch Sharing:** Share to multiple users at once
4. **Clip Collections:** Group related clips together
5. **Rich Media Preview:** Generate thumbnails server-side
6. **Search & Filter:** Full-text search across shared clips
7. **Usage Analytics:** Personal stats dashboard
8. **Clip Reactions:** Like, comment on shared clips
9. **Temporary Shares:** Self-destructing clips (read once)
10. **API Rate Increase:** Premium tier with higher limits

---

## Testing Strategy

### Unit Tests
- JWT utilities (encode/decode)
- Password hashing/verification
- Input validation schemas
- Rate limiting logic

### Integration Tests
- Full API endpoint testing
- Database operations
- R2 storage operations
- Authentication flow

### Load Tests
- 1000 concurrent users
- Share endpoint under load
- Database query performance
- Rate limiting effectiveness

### Security Tests
- SQL injection attempts
- XSS vulnerability testing
- Authentication bypass attempts
- Rate limit circumvention

---

This specification provides a complete blueprint for implementing the ClipMind Cloudflare Worker API backend. All endpoints, data structures, and implementation details are designed to integrate seamlessly with the existing ClipMind macOS application architecture.
