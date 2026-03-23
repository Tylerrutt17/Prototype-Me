import { z } from "zod/v4";
import { uuid, noteKind } from "./shared.js";

export const createNote = z.object({
  id: uuid.optional(),
  title: z.string().min(1),
  body: z.string(),
  kind: noteKind,
  folderId: uuid.nullable().optional(),
  sortIndex: z.int().default(0),
});

export const updateNote = z.object({
  title: z.string().min(1).optional(),
  body: z.string().optional(),
  kind: noteKind.optional(),
  folderId: uuid.nullable().optional(),
  sortIndex: z.int().optional(),
  version: z.int(),
});

export type CreateNoteInput = z.infer<typeof createNote>;
export type UpdateNoteInput = z.infer<typeof updateNote>;
