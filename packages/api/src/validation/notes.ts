import { z } from "zod/v4";
import { uuid, noteKind } from "./shared.js";
import { LIMITS } from "./limits.js";

export const createNote = z.object({
  id: uuid.optional(),
  title: z.string().min(1).max(LIMITS.note.title),
  body: z.string().max(LIMITS.note.body),
  kind: noteKind,
  folderId: uuid.nullable().optional(),
  sortIndex: z.int().default(0),
});

export const updateNote = z.object({
  title: z.string().min(1).max(LIMITS.note.title).optional(),
  body: z.string().max(LIMITS.note.body).optional(),
  kind: noteKind.optional(),
  folderId: uuid.nullable().optional(),
  sortIndex: z.int().optional(),
  version: z.int(),
});

export type CreateNoteInput = z.infer<typeof createNote>;
export type UpdateNoteInput = z.infer<typeof updateNote>;
