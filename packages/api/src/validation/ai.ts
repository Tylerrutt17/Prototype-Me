import { z } from "zod/v4";

export const aiSuggest = z.object({
  context: z.string().optional(),
});

export const aiOnboard = z.object({
  prompt: z.string().min(1),
});

export type AiSuggestInput = z.infer<typeof aiSuggest>;
export type AiOnboardInput = z.infer<typeof aiOnboard>;
