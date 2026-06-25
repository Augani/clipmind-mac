// Rate limiting middleware for ClipMind API
import { Context, Next } from 'hono';
import { Errors } from '../errors';
import type { Env, RateLimit } from '../types';

interface RateLimitConfig {
  windowMs: number; // Time window in milliseconds
  maxRequests: number; // Max requests per window
}

// Rate limit configurations per endpoint
export const RateLimits: Record<string, RateLimitConfig> = {
  'auth:register': { windowMs: 60 * 60 * 1000, maxRequests: 5 }, // 5/hour
  'auth:login': { windowMs: 60 * 60 * 1000, maxRequests: 20 }, // 20/hour
  'clip:share': { windowMs: 60 * 60 * 1000, maxRequests: 50 }, // 50/hour
  'contact:add': { windowMs: 60 * 60 * 1000, maxRequests: 100 }, // 100/hour
  'search:users': { windowMs: 60 * 60 * 1000, maxRequests: 200 }, // 200/hour
  default: { windowMs: 60 * 60 * 1000, maxRequests: 100 } // 100/hour
};

export function rateLimitMiddleware(limitKey: string) {
  return async (c: Context<{ Bindings: Env }>, next: Next) => {
    const config = RateLimits[limitKey] || RateLimits.default;

    // Get identifier (IP or user ID)
    const identifier = getIdentifier(c);
    const key = `ratelimit:${limitKey}:${identifier}`;

    const now = Date.now();
    const windowStart = now - config.windowMs;

    // Get current rate limit data
    const existing = await c.env.DB
      .prepare('SELECT * FROM rate_limits WHERE key = ?')
      .bind(key)
      .first<RateLimit>();

    if (existing) {
      // Check if window has expired
      if (existing.window_start < windowStart) {
        // Reset window
        await c.env.DB
          .prepare('UPDATE rate_limits SET count = 1, window_start = ? WHERE key = ?')
          .bind(now, key)
          .run();
      } else {
        // Within window
        if (existing.count >= config.maxRequests) {
          const retryAfter = Math.ceil((existing.window_start + config.windowMs - now) / 1000);
          throw Errors.RATE_LIMIT_EXCEEDED(retryAfter);
        }

        // Increment counter
        await c.env.DB
          .prepare('UPDATE rate_limits SET count = count + 1 WHERE key = ?')
          .bind(key)
          .run();
      }
    } else {
      // Create new rate limit entry
      await c.env.DB
        .prepare('INSERT INTO rate_limits (key, count, window_start) VALUES (?, 1, ?)')
        .bind(key, now)
        .run();
    }

    await next();
  };
}

function getIdentifier(c: Context): string {
  // Try to get user ID from context (if authenticated)
  const userId = c.get('userId');
  if (userId) {
    return `user:${userId}`;
  }

  // Fall back to IP address
  const ip = c.req.header('CF-Connecting-IP') || c.req.header('X-Forwarded-For') || 'unknown';
  return `ip:${ip}`;
}

// Cleanup old rate limit entries (should be called periodically)
export async function cleanupRateLimits(db: D1Database) {
  const cutoff = Date.now() - (24 * 60 * 60 * 1000); // 24 hours ago
  await db
    .prepare('DELETE FROM rate_limits WHERE window_start < ?')
    .bind(cutoff)
    .run();
}
