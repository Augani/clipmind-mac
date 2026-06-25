# ClipMind API

Cloudflare Worker API for ClipMind clip sharing and social features.

## Tech Stack

- **Cloudflare Workers** - Serverless edge computing
- **Hono** - Fast web framework for edge computing
- **Cloudflare D1** - SQLite database
- **Cloudflare R2** - Object storage for large files
- **Durable Objects** - Real-time notifications via WebSocket
- **JWT** - Authentication with jose library
- **bcryptjs** - Password hashing
- **Zod** - Schema validation

## Project Structure

```
api/
├── src/
│   ├── index.ts                    # Main entry point
│   ├── types.ts                    # TypeScript type definitions
│   ├── errors.ts                   # Error handling utilities
│   ├── routes/
│   │   ├── auth.ts                 # Authentication endpoints
│   │   ├── clips.ts                # Clip sharing endpoints
│   │   ├── contacts.ts             # Contact management
│   │   ├── notifications.ts        # Notification endpoints
│   │   └── settings.ts             # User settings
│   ├── middleware/
│   │   ├── auth.ts                 # Authentication middleware
│   │   └── rateLimit.ts            # Rate limiting
│   ├── utils/
│   │   ├── jwt.ts                  # JWT utilities
│   │   ├── crypto.ts               # Password hashing, ID generation
│   │   ├── validation.ts           # Zod schemas
│   │   └── db.ts                   # Database helpers
│   └── durable-objects/
│       └── NotificationManager.ts  # Real-time notifications
├── schema.sql                      # Database schema
├── wrangler.jsonc                  # Cloudflare Worker configuration
└── package.json
```

## Setup

### 1. Install Dependencies

```bash
npm install
```

### 2. Create D1 Database

```bash
# Create the database
npx wrangler d1 create clipmind-db

# Copy the database_id from output and update wrangler.jsonc
```

Update `wrangler.jsonc` with the actual database ID:

```jsonc
"d1_databases": [
  {
    "binding": "DB",
    "database_name": "clipmind-db",
    "database_id": "<your-database-id-here>"
  }
]
```

### 3. Initialize Database Schema

```bash
# Apply schema to local database
npx wrangler d1 execute clipmind-db --local --file=./schema.sql

# Apply schema to production database
npx wrangler d1 execute clipmind-db --remote --file=./schema.sql
```

### 4. Create R2 Bucket

```bash
npx wrangler r2 bucket create clipmind-storage
```

### 5. Set JWT Secret (Production)

```bash
npx wrangler secret put JWT_SECRET
# Enter a strong random secret when prompted
```

## Development

```bash
# Run local development server
npm run dev

# API will be available at http://localhost:8787
```

## Deployment

```bash
# Deploy to Cloudflare Workers
npm run deploy
```

## API Endpoints

### Authentication

- `POST /api/auth/register` - Register new user
- `POST /api/auth/login` - Login user
- `GET /api/users/me` - Get current user profile
- `PUT /api/users/me` - Update profile
- `GET /api/users/search?q=username` - Search users

### Clip Sharing

- `POST /api/clips/share` - Share a clip
- `GET /api/clips/received` - Get received clips
- `GET /api/clips/sent` - Get sent clips
- `PUT /api/clips/:id/read` - Mark clip as read
- `DELETE /api/clips/:id` - Delete clip
- `GET /api/clips/:id/content` - Get clip content (for R2 files)

### Contacts

- `GET /api/contacts` - Get contacts
- `POST /api/contacts` - Add contact
- `DELETE /api/contacts/:id` - Remove contact
- `POST /api/contacts/block` - Block user
- `DELETE /api/contacts/unblock/:username` - Unblock user
- `GET /api/contacts/blocked` - Get blocked users

### Notifications

- `GET /api/notifications` - Get notifications
- `GET /api/notifications/unread-count` - Get unread count
- `PUT /api/notifications/:id/read` - Mark as read
- `PUT /api/notifications/read-all` - Mark all as read
- `DELETE /api/notifications/:id` - Delete notification

### Settings

- `GET /api/settings` - Get user settings
- `PUT /api/settings` - Update settings

## Authentication

All endpoints (except register and login) require JWT authentication.

Include the token in the Authorization header:

```
Authorization: Bearer <your-jwt-token>
```

## Rate Limiting

Rate limits are applied per endpoint:

- **Register**: 5 requests/hour
- **Login**: 20 requests/hour
- **Share Clip**: 50 requests/hour
- **Add Contact**: 100 requests/hour
- **Search Users**: 200 requests/hour

## Real-time Notifications

Connect to WebSocket for real-time notifications:

```typescript
// Get Durable Object for user
const notificationManager = env.NOTIFICATION_MANAGER.idFromName(userId);
const stub = env.NOTIFICATION_MANAGER.get(notificationManager);

// Connect WebSocket
const response = await stub.fetch('https://notification/ws', {
  headers: { 'Upgrade': 'websocket' }
});
```

## Database Schema

See `schema.sql` for the complete database schema with tables:

- `users` - User accounts
- `shared_clips` - Shared clipboard items
- `contacts` - User contacts and blocks
- `notifications` - User notifications
- `user_settings` - User preferences
- `rate_limits` - Rate limiting data

## Environment Variables

- `JWT_SECRET` - Secret key for JWT signing (set via Wrangler secrets)
- `ENVIRONMENT` - Environment name (development/production)

## Testing

```bash
# Test health endpoint
curl http://localhost:8787/health

# Register a user
curl -X POST http://localhost:8787/api/auth/register \
  -H "Content-Type: application/json" \
  -d '{"username":"testuser","email":"test@example.com","password":"password123"}'

# Login
curl -X POST http://localhost:8787/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"test@example.com","password":"password123"}'
```

## Security

- Passwords are hashed with bcrypt (cost factor 10)
- JWT tokens expire after 30 days
- Rate limiting prevents abuse
- CORS enabled for all origins (configure for production)
- Optional end-to-end encryption for sensitive clips
- Contact blocking prevents unwanted sharing

## Performance

- Database indexes for optimized queries
- R2 storage for files >100KB
- Pagination support on list endpoints
- Edge computing for low latency worldwide
