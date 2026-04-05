import { z } from "zod/v4";
import { uuid, directiveStatus } from "./shared.js";
import { LIMITS } from "./limits.js";

const hexColor = z.string().regex(/^#[0-9A-Fa-f]{6}$/);

export const createDirective = z.object({
  id: uuid.optional(),
  title: z.string().min(1).max(LIMITS.directive.title),
  body: z.string().max(LIMITS.directive.body).nullable().optional(),
  color: hexColor.nullable().optional(),
  status: directiveStatus,
  balloonEnabled: z.boolean().default(false),
  balloonDurationSec: z.number().default(0),
  snoozedUntil: z.string().datetime().nullable().optional(),
});

export const updateDirective = z.object({
  title: z.string().min(1).max(LIMITS.directive.title).optional(),
  body: z.string().max(LIMITS.directive.body).nullable().optional(),
  color: hexColor.nullable().optional(),
  status: directiveStatus.optional(),
  balloonEnabled: z.boolean().optional(),
  balloonDurationSec: z.number().optional(),
  balloonSnapshotSec: z.number().optional(),
  snoozedUntil: z.string().datetime().nullable().optional(),
  version: z.int(),
});

export type CreateDirectiveInput = z.infer<typeof createDirective>;
export type UpdateDirectiveInput = z.infer<typeof updateDirective>;
