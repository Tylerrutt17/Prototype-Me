import { z } from "zod/v4";
import { uuid } from "./shared.js";
import { LIMITS } from "./limits.js";

export const createFolder = z.object({
  id: uuid.optional(),
  name: z.string().min(1).max(LIMITS.folder.name),
  parentFolderId: uuid.optional(),
});

export const updateFolder = z.object({
  name: z.string().min(1).max(LIMITS.folder.name).optional(),
  parentFolderId: uuid.nullable().optional(),
});

export type CreateFolderInput = z.infer<typeof createFolder>;
export type UpdateFolderInput = z.infer<typeof updateFolder>;
