import { z } from "zod/v4";
import { uuid, isoDate } from "./shared.js";

export const createDayEntry = z.object({
  id: uuid.optional(),
  date: isoDate,
  rating: z.int().min(1).max(10).nullable().optional(),
  diary: z.string(),
  tags: z.array(z.string()).default([]),
});

export const updateDayEntry = z.object({
  rating: z.int().min(1).max(10).nullable().optional(),
  diary: z.string().optional(),
  tags: z.array(z.string()).optional(),
});

export type CreateDayEntryInput = z.infer<typeof createDayEntry>;
export type UpdateDayEntryInput = z.infer<typeof updateDayEntry>;
