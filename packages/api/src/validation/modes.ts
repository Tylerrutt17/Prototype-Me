import { z } from "zod/v4";
import { uuid } from "./shared.js";

export const activateMode = z.object({
  noteId: uuid,
});

export type ActivateModeInput = z.infer<typeof activateMode>;
