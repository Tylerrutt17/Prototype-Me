import { z } from "zod/v4";
import { uuid, isoDate } from "./shared.js";
import { LIMITS } from "./limits.js";

const tag = z.string().min(1).max(LIMITS.journal.tag);

export const createDayEntry = z.object({
  id: uuid.optional(),
  date: isoDate,
  rating: z.int().min(1).max(10).nullable().optional(),
  diary: z.string().max(LIMITS.journal.diary),
  tags: z.array(tag).max(LIMITS.journal.tagCount).default([]),
});

export const updateDayEntry = z.object({
  rating: z.int().min(1).max(10).nullable().optional(),
  diary: z.string().max(LIMITS.journal.diary).optional(),
  tags: z.array(tag).max(LIMITS.journal.tagCount).optional(),
});

export type CreateDayEntryInput = z.infer<typeof createDayEntry>;
export type UpdateDayEntryInput = z.infer<typeof updateDayEntry>;
