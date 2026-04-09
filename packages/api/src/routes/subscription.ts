import type { FastifyInstance } from "fastify";
import * as subscription from "../features/subscription.js";
import { ok } from "../lib/responses.js";

export async function subscriptionRoutes(app: FastifyInstance) {
  // Get cached subscription info
  app.get("/", async (req, reply) => {
    return ok(reply, await subscription.getSubscription(req.userId));
  });

  // Verify subscription with RevenueCat and update plan
  app.post("/verify", async (req, reply) => {
    return ok(reply, await subscription.verifySubscription(req.userId));
  });
}
