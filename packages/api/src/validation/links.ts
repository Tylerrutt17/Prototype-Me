import { z } from "zod/v4";
import { uuid } from "./shared.js";

export const noteDirectiveLink = z.object({
  noteId: uuid,
  directiveId: uuid,
  sortIndex: z.int().default(0),
});

export type NoteDirectiveLinkInput = z.infer<typeof noteDirectiveLink>;
