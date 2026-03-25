import type { FastifyInstance } from "fastify";
import * as subscription from "../features/subscription.js";
import { verifyReceipt } from "../validation/subscription.js";
import { ok } from "../lib/responses.js";

export async function subscriptionRoutes(app: FastifyInstance) {
  app.get("/", async (req, reply) => {
    return ok(reply, await subscription.getSubscription(req.userId));
  });

  app.post("/verify-receipt", async (req, reply) => {
    const body = verifyReceipt.parse(req.body);
    return ok(reply, await subscription.verifyReceipt(req.userId, body.receiptData));
  });
}
