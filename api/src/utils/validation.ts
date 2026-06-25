// Validation schemas using Zod
import { z } from 'zod';

// Username validation: 3-20 chars, lowercase alphanumeric + underscore
const usernameSchema = z
  .string()
  .min(3, 'Username must be at least 3 characters')
  .max(20, 'Username must be at most 20 characters')
  .regex(/^[a-z0-9_]+$/, 'Username can only contain lowercase letters, numbers, and underscores');

// Email validation
const emailSchema = z
  .string()
  .email('Invalid email address');

// Password validation: min 8 chars
const passwordSchema = z
  .string()
  .min(8, 'Password must be at least 8 characters');

// Auth schemas
export const registerSchema = z.object({
  username: usernameSchema,
  email: emailSchema,
  password: passwordSchema,
  display_name: z.string().max(100).optional()
});

export const loginSchema = z.object({
  email: emailSchema,
  password: z.string().min(1, 'Password is required')
});

export const updateProfileSchema = z.object({
  display_name: z.string().max(100).optional(),
  bio: z.string().max(500).optional()
});

// Clip sharing schemas
export const shareClipSchema = z.object({
  recipient_username: usernameSchema,
  content_type: z.enum(['text', 'url', 'image', 'file', 'code']),
  content: z.string().max(100000).optional(),
  is_encrypted: z.boolean().optional(),
  encryption_metadata: z.string().optional(),
  expires_in: z.number().min(60).max(30 * 24 * 60 * 60).optional(),
  message: z.string().max(500).optional()
});

// Contact schemas
export const addContactSchema = z.object({
  username: usernameSchema
});

// Settings schemas
export const updateSettingsSchema = z.object({
  sharing_permission: z.enum(['anyone', 'contacts', 'none']).optional(),
  notification_enabled: z.boolean().optional(),
  auto_accept_contacts: z.boolean().optional()
});

// Query parameter schemas
export const paginationSchema = z.object({
  limit: z.coerce.number().min(1).max(100).default(20),
  offset: z.coerce.number().min(0).default(0)
});

export const searchUsersSchema = z.object({
  q: z.string().min(1).max(50),
  limit: z.coerce.number().min(1).max(50).default(10)
});

// Helper to validate and parse
export function validate<T>(schema: z.ZodSchema<T>, data: unknown): T {
  return schema.parse(data);
}

// Helper to safely validate
export function safeValidate<T>(
  schema: z.ZodSchema<T>,
  data: unknown
): { success: true; data: T } | { success: false; errors: z.ZodError } {
  const result = schema.safeParse(data);
  if (result.success) {
    return { success: true, data: result.data };
  }
  return { success: false, errors: result.error };
}
