import Anthropic from "@anthropic-ai/sdk";
import { config } from "../config.js";
import * as usageQueries from "../db/queries/usage.js";
import * as profileQueries from "../db/queries/profiles.js";

const anthropic = new Anthropic({ apiKey: config.anthropicApiKey });

const FREE_DAILY_LIMIT = 5;
const PRO_DAILY_LIMIT = 50;

export async function suggest(userId: string, context?: string) {
  const quota = await getQuota(userId);
  if (quota.dailyUsed >= quota.dailyLimit) {
    throw { status: 429, error: "quota_exceeded", message: "Daily AI quota exceeded" };
  }

  const message = await anthropic.messages.create({
    model: "claude-sonnet-4-6",
    max_tokens: 1024,
    system: `You are a personal development assistant for the Prototype Me app. Generate actionable suggestions as JSON chips. Each chip has: action (createDirective|updateDirective|createNote|activateMode|addSchedule|createSituation), title, subtitle, destination, prefillTitle, prefillBody. Return a JSON array of 2-4 chips.`,
    messages: [{ role: "user", content: context || "Give me suggestions based on my current setup." }],
  });

  await usageQueries.increment(userId);

  const text = message.content[0]?.type === "text" ? message.content[0].text : "[]";
  let chips;
  try {
    chips = JSON.parse(text);
  } catch {
    chips = [];
  }

  const updatedQuota = await getQuota(userId);
  return {
    chips: Array.isArray(chips)
      ? chips.map((c: Record<string, unknown>, i: number) => ({
          id: crypto.randomUUID(),
          action: c.action ?? "createDirective",
          title: c.title ?? "Suggestion",
          subtitle: c.subtitle ?? "",
          destination: c.destination ?? "",
          status: "suggested",
          prefillTitle: c.prefillTitle ?? null,
          prefillBody: c.prefillBody ?? null,
        }))
      : [],
    remainingQuota: updatedQuota.dailyLimit - updatedQuota.dailyUsed,
    resetAt: getResetTime(),
  };
}

export async function onboard(prompt: string) {
  const message = await anthropic.messages.create({
    model: "claude-sonnet-4-6",
    max_tokens: 1024,
    system: `You are an onboarding assistant for the Prototype Me app. Based on the user's goals, generate a seed plan as a JSON array of cards. Each card has: type ("directive" or "playbook"), title, body. Return 3-5 cards.`,
    messages: [{ role: "user", content: prompt }],
  });

  const text = message.content[0]?.type === "text" ? message.content[0].text : "[]";
  let cards;
  try {
    cards = JSON.parse(text);
  } catch {
    cards = [];
  }

  return {
    cards: Array.isArray(cards)
      ? cards.map((c: Record<string, unknown>) => ({
          id: crypto.randomUUID(),
          type: c.type ?? "directive",
          title: c.title ?? "Untitled",
          body: c.body ?? "",
        }))
      : [],
  };
}

async function getQuota(userId: string) {
  const user = await profileQueries.findById(userId);
  const dailyLimit = user?.plan === "pro" ? PRO_DAILY_LIMIT : FREE_DAILY_LIMIT;
  const usage = await usageQueries.getToday(userId);
  return {
    dailyLimit,
    dailyUsed: usage?.count ?? 0,
    resetAt: getResetTime(),
  };
}

export { getQuota };

function getResetTime(): string {
  const tomorrow = new Date();
  tomorrow.setUTCHours(0, 0, 0, 0);
  tomorrow.setUTCDate(tomorrow.getUTCDate() + 1);
  return tomorrow.toISOString();
}
