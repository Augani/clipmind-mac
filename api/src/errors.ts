// Error handling for ClipMind API

export class APIError extends Error {
  constructor(
    public statusCode: number,
    public code: string,
    message: string,
    public details?: any
  ) {
    super(message);
    this.name = 'APIError';
  }

  toJSON() {
    return {
      error: {
        code: this.code,
        message: this.message,
        ...(this.details && { details: this.details })
      }
    };
  }
}

// Predefined errors
export const Errors = {
  // Authentication errors (401)
  UNAUTHORIZED: (message = 'Unauthorized') =>
    new APIError(401, 'UNAUTHORIZED', message),

  INVALID_TOKEN: () =>
    new APIError(401, 'INVALID_TOKEN', 'Invalid or expired token'),

  INVALID_CREDENTIALS: () =>
    new APIError(401, 'INVALID_CREDENTIALS', 'Invalid email or password'),

  // Authorization errors (403)
  FORBIDDEN: (message = 'Forbidden') =>
    new APIError(403, 'FORBIDDEN', message),

  PERMISSION_DENIED: () =>
    new APIError(403, 'PERMISSION_DENIED', 'You do not have permission to perform this action'),

  // Not found errors (404)
  NOT_FOUND: (resource = 'Resource') =>
    new APIError(404, 'NOT_FOUND', `${resource} not found`),

  USER_NOT_FOUND: () =>
    new APIError(404, 'USER_NOT_FOUND', 'User not found'),

  CLIP_NOT_FOUND: () =>
    new APIError(404, 'CLIP_NOT_FOUND', 'Clip not found'),

  // Validation errors (400)
  VALIDATION_ERROR: (details: any) =>
    new APIError(400, 'VALIDATION_ERROR', 'Validation failed', details),

  INVALID_INPUT: (message: string) =>
    new APIError(400, 'INVALID_INPUT', message),

  // Conflict errors (409)
  CONFLICT: (message: string) =>
    new APIError(409, 'CONFLICT', message),

  USERNAME_EXISTS: () =>
    new APIError(409, 'USERNAME_EXISTS', 'Username already exists'),

  EMAIL_EXISTS: () =>
    new APIError(409, 'EMAIL_EXISTS', 'Email already exists'),

  ALREADY_BLOCKED: () =>
    new APIError(409, 'ALREADY_BLOCKED', 'User is already blocked'),

  // Rate limiting (429)
  RATE_LIMIT_EXCEEDED: (retryAfter?: number) =>
    new APIError(
      429,
      'RATE_LIMIT_EXCEEDED',
      'Too many requests. Please try again later.',
      retryAfter ? { retryAfter } : undefined
    ),

  // File upload errors (413)
  FILE_TOO_LARGE: (maxSize: string) =>
    new APIError(413, 'FILE_TOO_LARGE', `File size exceeds maximum of ${maxSize}`),

  // Server errors (500)
  INTERNAL_ERROR: (message = 'Internal server error') =>
    new APIError(500, 'INTERNAL_ERROR', message),

  DATABASE_ERROR: () =>
    new APIError(500, 'DATABASE_ERROR', 'Database operation failed'),
};

// Error response helper
export function errorResponse(error: unknown): Response {
  console.error('API Error:', error);

  if (error instanceof APIError) {
    return new Response(JSON.stringify(error.toJSON()), {
      status: error.statusCode,
      headers: { 'Content-Type': 'application/json' }
    });
  }

  // Unknown errors
  return new Response(
    JSON.stringify({
      error: {
        code: 'INTERNAL_ERROR',
        message: 'An unexpected error occurred'
      }
    }),
    {
      status: 500,
      headers: { 'Content-Type': 'application/json' }
    }
  );
}
