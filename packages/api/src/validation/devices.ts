import { z } from "zod/v4";
import { uuid } from "./shared.js";

export const createDevice = z.object({
  id: uuid.optional(),
  name: z.string().min(1),
  platform: z.string().min(1),
});

export type CreateDeviceInput = z.infer<typeof createDevice>;
