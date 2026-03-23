import * as profileQueries from "../db/queries/profiles.js";

export async function getSubscription(userId: string) {
  const user = await profileQueries.findById(userId);
  if (!user) throw { status: 404, error: "not_found", message: "User not found" };

  return {
    plan: user.plan,
    expiresAt: null, // TODO: integrate with App Store Server API
    isTrialActive: false,
    trialDaysRemaining: null,
  };
}

export async function verifyReceipt(userId: string, _receiptData: string) {
  // TODO: verify receipt with App Store Server API v2
  // For now, upgrade to pro on any receipt
  await profileQueries.update(userId, { plan: "pro" });
  return getSubscription(userId);
}
