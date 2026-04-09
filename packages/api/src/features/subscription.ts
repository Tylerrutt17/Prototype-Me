import * as profileQueries from "../db/queries/profiles.js";
import { config } from "../config.js";

export async function getSubscription(userId: string) {
  const user = await profileQueries.findById(userId);
  if (!user) throw { status: 404, error: "not_found", message: "User not found" };

  return {
    plan: user.plan,
    expiresAt: null,
    isTrialActive: false,
    trialDaysRemaining: null,
  };
}

/**
 * Verify the user's subscription by checking RevenueCat directly.
 * Updates the user's plan in our DB based on RevenueCat's response.
 */
export async function verifySubscription(userId: string) {
  const rcKey = config.revenueCatSecretKey;
  if (!rcKey) {
    console.warn("[Subscription] REVENUECAT_SECRET_KEY not set — skipping verification");
    return getSubscription(userId);
  }

  try {
    const response = await fetch(`https://api.revenuecat.com/v1/subscribers/${userId}`, {
      headers: {
        Authorization: `Bearer ${rcKey}`,
        "Content-Type": "application/json",
      },
    });

    if (!response.ok) {
      console.error(`[Subscription] RevenueCat API error: ${response.status}`);
      // Fall back to cached plan
      return getSubscription(userId);
    }

    const data = (await response.json()) as RevenueCatSubscriberResponse;
    const entitlements = data.subscriber?.entitlements ?? {};
    const proEntitlement = entitlements["Pro"];
    const isPro = proEntitlement?.expires_date
      ? new Date(proEntitlement.expires_date) > new Date()
      : false;
    const plan = isPro ? "pro" : "free";

    // Update our DB to match RevenueCat's truth
    await profileQueries.update(userId, { plan });

    console.log(`[Subscription] Verified with RevenueCat: user=${userId} plan=${plan}`);

    return {
      plan,
      expiresAt: proEntitlement?.expires_date ?? null,
      isTrialActive: false,
      trialDaysRemaining: null,
    };
  } catch (error) {
    console.error("[Subscription] Failed to verify with RevenueCat:", error);
    // Fall back to cached plan
    return getSubscription(userId);
  }
}

// ── Types ──

interface RevenueCatSubscriberResponse {
  subscriber: {
    entitlements: Record<
      string,
      {
        expires_date: string | null;
        purchase_date: string;
        product_identifier: string;
      }
    >;
  };
}
