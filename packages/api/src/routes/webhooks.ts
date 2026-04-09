import type { FastifyInstance } from "fastify";
import { config } from "../config.js";
import * as profileQueries from "../db/queries/profiles.js";

/**
 * RevenueCat webhook handler.
 * Receives subscription events and updates the user's plan accordingly.
 *
 * Setup in RevenueCat dashboard:
 *   - URL: https://your-api.com/v1/webhooks/revenuecat
 *   - Authorization header: Bearer <REVENUECAT_WEBHOOK_SECRET>
 */
export async function webhookRoutes(app: FastifyInstance) {
  app.post("/revenuecat", async (req, reply) => {
    // Verify authorization header
    const authHeader = req.headers.authorization;
    const expectedSecret = config.revenueCatWebhookSecret;

    if (!expectedSecret || authHeader !== `Bearer ${expectedSecret}`) {
      return reply.status(401).send({ error: "unauthorized" });
    }

    const body = req.body as RevenueCatWebhookPayload;
    const event = body?.event;

    if (!event) {
      return reply.status(400).send({ error: "missing event" });
    }

    const appUserId = event.app_user_id;
    const eventType = event.type;

    console.log(`[Webhook] RevenueCat ${eventType} for user ${appUserId} (${event.environment})`);

    // Skip anonymous RevenueCat IDs — we need the real user ID
    if (appUserId.startsWith("$RCAnonymousID:")) {
      // Try aliases — RevenueCat sends the original app user ID,
      // but if the user was identified, the aliases field may contain the real ID.
      // For now, just acknowledge and skip.
      console.log(`[Webhook] Skipping anonymous user ${appUserId}`);
      return reply.status(200).send({ ok: true });
    }

    // Determine plan based on event type
    switch (eventType) {
      case "INITIAL_PURCHASE":
      case "RENEWAL":
      case "UNCANCELLATION":
      case "NON_RENEWING_PURCHASE":
      case "SUBSCRIPTION_EXTENDED":
        await profileQueries.update(appUserId, { plan: "pro" });
        console.log(`[Webhook] Set plan=pro for ${appUserId}`);
        break;

      case "EXPIRATION":
      case "BILLING_ISSUE":
        await profileQueries.update(appUserId, { plan: "free" });
        console.log(`[Webhook] Set plan=free for ${appUserId}`);
        break;

      case "CANCELLATION":
        // Cancellation means auto-renew is off, but subscription is still active
        // until EXPIRATION. Don't change plan yet.
        console.log(`[Webhook] Cancellation noted for ${appUserId} — plan unchanged until expiration`);
        break;

      default:
        console.log(`[Webhook] Ignoring event type ${eventType}`);
    }

    return reply.status(200).send({ ok: true });
  });
}

// ── Types ──

interface RevenueCatWebhookPayload {
  api_version: string;
  event: {
    type: string;
    app_user_id: string;
    environment: "SANDBOX" | "PRODUCTION";
    event_timestamp_ms: number;
    product_id?: string;
    transaction_id?: string;
  };
}
