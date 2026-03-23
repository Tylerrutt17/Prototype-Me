import type { FastifyInstance } from "fastify";
import * as subscription from "../features/subscription.js";
import { verifyReceipt } from "../validation/subscription.js";

export async function subscriptionRoutes(app: FastifyInstance) {
  app.get("/", async (req) => subscription.getSubscription(req.userId));

  app.post("/verify-receipt", async (req) => {
    const body = verifyReceipt.parse(req.body);
    return subscription.verifyReceipt(req.userId, body.receiptData);
  });
}
