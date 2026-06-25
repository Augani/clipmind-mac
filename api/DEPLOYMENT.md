# ClipMind API Deployment Guide

Complete guide for deploying the ClipMind API to Cloudflare Workers.

## Prerequisites

- Cloudflare account (free tier works)
- Node.js 20+ installed
- Wrangler CLI installed (`npm install -g wrangler`)
- Authenticated with Cloudflare (`wrangler login`)

## Initial Setup

### 1. Install Dependencies

```bash
cd api
npm install
```

### 2. Create D1 Database (Production)

```bash
# Create the production database
npx wrangler d1 create clipmind-db
```

You'll get output like:

```
✅ Successfully created DB 'clipmind-db'

[[d1_databases]]
binding = "DB"
database_name = "clipmind-db"
database_id = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
```

Copy the `database_id` and update `wrangler.jsonc`:

```jsonc
"d1_databases": [
  {
    "binding": "DB",
    "database_name": "clipmind-db",
    "database_id": "paste-your-database-id-here"
  }
]
```

### 3. Initialize Database Schema (Production)

```bash
# Apply schema to production database
npx wrangler d1 execute clipmind-db --remote --file=./schema.sql
```

Verify the tables were created:

```bash
npx wrangler d1 execute clipmind-db --remote --command="SELECT name FROM sqlite_master WHERE type='table'"
```

### 4. Create R2 Bucket (Production)

```bash
npx wrangler r2 bucket create clipmind-storage
```

### 5. Set Production Secrets

```bash
# Generate a strong random secret
# You can use: openssl rand -base64 32

npx wrangler secret put JWT_SECRET
# Paste your secret when prompted
```

## Local Development

### 1. Initialize Local Database

```bash
# Initialize local database schema
npx wrangler d1 execute clipmind-db --local --file=./schema.sql
```

### 2. Start Development Server

```bash
npm run dev
```

The API will be available at `http://localhost:8787`.

### 3. Test Endpoints

```bash
# Health check
curl http://localhost:8787/health

# Register a user
curl -X POST http://localhost:8787/api/auth/register \
  -H "Content-Type: application/json" \
  -d '{
    "username": "testuser",
    "email": "test@example.com",
    "password": "password123"
  }'

# Login
curl -X POST http://localhost:8787/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{
    "email": "test@example.com",
    "password": "password123"
  }'

# Get profile (use token from login response)
curl http://localhost:8787/api/users/me \
  -H "Authorization: Bearer YOUR_TOKEN_HERE"
```

## Production Deployment

### 1. Deploy to Cloudflare Workers

```bash
npm run deploy
```

This will:
- Build the worker
- Upload to Cloudflare
- Deploy to production

You'll get a URL like: `https://api.YOUR_SUBDOMAIN.workers.dev`

### 2. Verify Deployment

```bash
# Test health endpoint
curl https://api.YOUR_SUBDOMAIN.workers.dev/health

# Should return: {"status":"ok"}
```

### 3. Custom Domain (Optional)

To use a custom domain:

1. Go to Cloudflare Dashboard
2. Navigate to Workers & Pages > YOUR_WORKER
3. Click "Triggers" tab
4. Add a custom domain

Example: `api.clipmind.com`

### 4. Environment Variables

Update production environment variables:

```bash
# Update JWT secret
npx wrangler secret put JWT_SECRET

# Update environment
npx wrangler secret put ENVIRONMENT
# Enter: production
```

## Database Management

### View Database Tables

```bash
# Production
npx wrangler d1 execute clipmind-db --remote \
  --command="SELECT name FROM sqlite_master WHERE type='table'"

# Local
npx wrangler d1 execute clipmind-db --local \
  --command="SELECT name FROM sqlite_master WHERE type='table'"
```

### Query Database

```bash
# Count users
npx wrangler d1 execute clipmind-db --remote \
  --command="SELECT COUNT(*) as count FROM users"

# View recent clips
npx wrangler d1 execute clipmind-db --remote \
  --command="SELECT * FROM shared_clips ORDER BY created_at DESC LIMIT 5"
```

### Backup Database

```bash
# Export database
npx wrangler d1 export clipmind-db --remote --output=backup.sql
```

### Restore Database

```bash
# Import from backup
npx wrangler d1 execute clipmind-db --remote --file=backup.sql
```

## Monitoring

### View Logs

```bash
# Tail production logs
npx wrangler tail

# Filter by specific endpoint
npx wrangler tail --format=pretty --search="POST /api/clips/share"
```

### Analytics

Visit Cloudflare Dashboard:
- Workers & Pages > YOUR_WORKER > Metrics
- View requests, errors, CPU time, etc.

## Updating the API

### 1. Make Changes

Edit your code in `src/` directory.

### 2. Test Locally

```bash
npm run dev
# Test your changes at http://localhost:8787
```

### 3. Deploy

```bash
npm run deploy
```

### 4. Update Database Schema

If you added new tables or columns:

```bash
# Create migration file
cat > migrations/001_add_new_feature.sql <<EOF
ALTER TABLE users ADD COLUMN new_field TEXT;
CREATE INDEX idx_users_new_field ON users(new_field);
EOF

# Apply migration
npx wrangler d1 execute clipmind-db --remote --file=migrations/001_add_new_feature.sql
```

## Rollback

If deployment fails or has issues:

```bash
# View deployments
npx wrangler deployments list

# Rollback to previous version
npx wrangler rollback [DEPLOYMENT_ID]
```

## Security Checklist

- [ ] JWT_SECRET is set in production (not the default)
- [ ] Environment is set to "production"
- [ ] CORS origins are restricted (update in src/index.ts)
- [ ] Rate limits are appropriate for your use case
- [ ] Database is not publicly accessible
- [ ] R2 bucket has proper access controls

## Troubleshooting

### Database Not Found

```bash
# List all D1 databases
npx wrangler d1 list

# Verify database ID in wrangler.jsonc matches
```

### R2 Bucket Not Found

```bash
# List all R2 buckets
npx wrangler r2 bucket list

# Create if missing
npx wrangler r2 bucket create clipmind-storage
```

### Authentication Errors

```bash
# Re-login to Cloudflare
npx wrangler logout
npx wrangler login
```

### Deployment Fails

```bash
# Check for TypeScript errors
npx tsc --noEmit

# Regenerate types
npm run cf-typegen

# Try deploying again
npm run deploy
```

## Performance Optimization

### Database Indexes

Verify indexes are created:

```bash
npx wrangler d1 execute clipmind-db --remote \
  --command="SELECT name FROM sqlite_master WHERE type='index'"
```

### R2 Storage

Monitor R2 usage:

```bash
npx wrangler r2 bucket list
```

### Rate Limiting

Adjust rate limits in `src/middleware/rateLimit.ts` based on usage patterns.

## Costs

### Free Tier Limits (as of 2025)

- **Workers**: 100,000 requests/day
- **D1**: 5GB storage, 5M reads/day, 100K writes/day
- **R2**: 10GB storage, 1M Class A operations/month, 10M Class B operations/month
- **Durable Objects**: 1M requests/month

### Beyond Free Tier

- **Workers**: $5/month for 10M requests
- **D1**: $0.75/GB storage, $0.001 per 1K reads
- **R2**: $0.015/GB storage, $4.50 per 1M Class A ops

## Support

For issues or questions:

1. Check logs: `npx wrangler tail`
2. Review Cloudflare status: https://www.cloudflarestatus.com/
3. Consult docs: https://developers.cloudflare.com/workers/

## Next Steps

After deployment:

1. Update ClipMind Swift client with API URL
2. Test all endpoints from the iOS app
3. Monitor logs for errors
4. Set up alerts for critical issues
5. Implement proper CORS for production domains
