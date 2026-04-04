import { z } from "zod/v4";
import { LIMITS } from "./limits.js";

export const aiSuggest = z.object({
  context: z.string().max(LIMITS.ai.prompt).optional(),
});

export const aiOnboard = z.object({
  prompt: z.string().min(1).max(LIMITS.ai.prompt),
});

export const directiveWizard = z.object({
  problem: z.string().min(1).max(LIMITS.ai.prompt),
});

export type AiSuggestInput = z.infer<typeof aiSuggest>;
export type AiOnboardInput = z.infer<typeof aiOnboard>;
export type DirectiveWizardInput = z.infer<typeof directiveWizard>;
