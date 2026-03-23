import { z } from "zod/v4";
import { uuid } from "./shared.js";

export const createTag = z.object({
  id: uuid.optional(),
  name: z.string().min(1),
  color: z.string().regex(/^#[0-9A-Fa-f]{6}$/).nullable().optional(),
});

export type CreateTagInput = z.infer<typeof createTag>;
