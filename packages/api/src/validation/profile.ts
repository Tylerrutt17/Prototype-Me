import { z } from "zod/v4";

export const updateProfile = z.object({
  displayName: z.string().min(1).optional(),
  bio: z.string().nullable().optional(),
  avatarSystemImage: z.string().optional(),
  moodChips: z.array(z.string()).optional(),
  plan: z.enum(["free", "pro"]).optional(),
});

export type UpdateProfileInput = z.infer<typeof updateProfile>;
