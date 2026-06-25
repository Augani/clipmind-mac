// Notification Manager Durable Object
// Handles real-time notifications via WebSocket
import { DurableObject } from 'cloudflare:workers';
import type { Env } from '../types';

export class NotificationManager extends DurableObject<Env> {
  private sessions: Map<string, WebSocket>;

  constructor(ctx: DurableObjectState, env: Env) {
    super(ctx, env);
    this.sessions = new Map();
  }

  async fetch(request: Request): Promise<Response> {
    const url = new URL(request.url);

    // WebSocket upgrade for real-time notifications
    if (url.pathname === '/ws' && request.headers.get('Upgrade') === 'websocket') {
      return this.handleWebSocket(request);
    }

    // HTTP endpoints for sending notifications
    if (url.pathname === '/notify' && request.method === 'POST') {
      return this.handleNotify(request);
    }

    return new Response('Not found', { status: 404 });
  }

  private async handleWebSocket(request: Request): Promise<Response> {
    const pair = new WebSocketPair();
    const [client, server] = Object.values(pair);

    // Accept WebSocket
    server.accept();

    // Generate session ID
    const sessionId = crypto.randomUUID();
    this.sessions.set(sessionId, server);

    // Handle WebSocket events
    server.addEventListener('close', () => {
      this.sessions.delete(sessionId);
    });

    server.addEventListener('error', () => {
      this.sessions.delete(sessionId);
    });

    server.addEventListener('message', async (event) => {
      try {
        const data = JSON.parse(event.data as string);

        // Handle ping/pong for keepalive
        if (data.type === 'ping') {
          server.send(JSON.stringify({ type: 'pong' }));
        }
      } catch (error) {
        console.error('WebSocket message error:', error);
      }
    });

    // Send initial connection confirmation
    server.send(JSON.stringify({
      type: 'connected',
      sessionId
    }));

    return new Response(null, {
      status: 101,
      webSocket: client
    });
  }

  private async handleNotify(request: Request): Promise<Response> {
    try {
      const notification = await request.json() as {
        type: string;
        clipId?: string;
        senderId?: string;
      };

      // Broadcast to all connected sessions
      const message = JSON.stringify({
        type: 'notification',
        data: notification
      });

      for (const [sessionId, ws] of this.sessions.entries()) {
        try {
          ws.send(message);
        } catch (error) {
          console.error('Failed to send to session:', sessionId, error);
          this.sessions.delete(sessionId);
        }
      }

      return new Response(JSON.stringify({ success: true }), {
        headers: { 'Content-Type': 'application/json' }
      });
    } catch (error) {
      return new Response(JSON.stringify({ error: 'Invalid notification' }), {
        status: 400,
        headers: { 'Content-Type': 'application/json' }
      });
    }
  }

  // RPC method for getting active session count
  async getSessionCount(): Promise<number> {
    return this.sessions.size;
  }

  // RPC method for broadcasting to all sessions
  async broadcast(message: any): Promise<void> {
    const messageStr = JSON.stringify(message);

    for (const [sessionId, ws] of this.sessions.entries()) {
      try {
        ws.send(messageStr);
      } catch (error) {
        console.error('Failed to broadcast to session:', sessionId, error);
        this.sessions.delete(sessionId);
      }
    }
  }
}
