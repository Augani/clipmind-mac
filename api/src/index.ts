// ClipMind API - Main entry point
import { Hono } from 'hono';
import { cors } from 'hono/cors';
import { logger } from 'hono/logger';
import { errorResponse } from './errors';
import { corsHeaders } from './utils/db';
import type { Env } from './types';

// Import routes
import auth from './routes/auth';
import clips from './routes/clips';
import contacts from './routes/contacts';
import notifications from './routes/notifications';
import settings from './routes/settings';

// Import Durable Object
export { NotificationManager } from './durable-objects/NotificationManager';

// Create Hono app
const app = new Hono<{ Bindings: Env }>();

// Global middleware
app.use('*', logger());
app.use('*', cors({
  origin: '*',
  allowMethods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
  allowHeaders: ['Content-Type', 'Authorization'],
  maxAge: 86400
}));

// Health check
app.get('/', (c) => {
  return c.json({
    service: 'ClipMind API',
    version: '1.0.0',
    status: 'healthy'
  });
});

app.get('/health', (c) => {
  return c.json({ status: 'ok' });
});

// Mount routes
app.route('/api/auth', auth);
app.route('/api/users', auth); // User search is in auth routes
app.route('/api/clips', clips);
app.route('/api/contacts', contacts);
app.route('/api/notifications', notifications);
app.route('/api/settings', settings);

// Global error handler
app.onError((error, c) => {
  console.error('Unhandled error:', error);
  return errorResponse(error);
});

// 404 handler
app.notFound((c) => {
  return c.json({
    error: {
      code: 'NOT_FOUND',
      message: 'Route not found'
    }
  }, 404);
});

// Export worker handler
export default {
  async fetch(request: Request, env: Env, ctx: ExecutionContext): Promise<Response> {
    return app.fetch(request, env, ctx);
  }
};
