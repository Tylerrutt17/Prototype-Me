import { z } from "zod/v4";
import { uuid } from "./shared.js";

export const sendFriendRequest = z.object({
  userId: uuid,
});

export type SendFriendRequestInput = z.infer<typeof sendFriendRequest>;
