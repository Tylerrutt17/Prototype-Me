import { callLLMJson } from "../lib/llm.js";
import * as usageQueries from "../db/queries/usage.js";
import * as profileQueries from "../db/queries/profiles.js";

const FREE_DAILY_LIMIT = 5;
const PRO_DAILY_LIMIT = 50;

export async function suggest(userId: string, context?: string) {
  const quota = await getQuota(userId);
  if (quota.dailyUsed >= quota.dailyLimit) {
    throw { status: 429, error: "quota_exceeded", message: "Daily AI quota exceeded" };
  }

  const { data: chips } = await callLLMJson<unknown[]>(
    {
      system: `You are a personal development assistant for the Prototype Me app. Generate actionable suggestions as JSON chips. Each chip has: action (createDirective|updateDirective|createNote|activateMode|addSchedule|createSituation), title, subtitle, destination, prefillTitle, prefillBody. Return a JSON array of 2-4 chips.`,
      prompt: context || "Give me suggestions based on my current setup.",
    },
    [],
  );

  await usageQueries.increment(userId);

  const updatedQuota = await getQuota(userId);
  return {
    chips: Array.isArray(chips)
      ? chips.map((_c: unknown) => {
          const c = _c as Record<string, unknown>;
          return {
            id: crypto.randomUUID(),
            action: c.action ?? "createDirective",
            title: c.title ?? "Suggestion",
            subtitle: c.subtitle ?? "",
            destination: c.destination ?? "",
            status: "suggested",
            prefillTitle: c.prefillTitle ?? null,
            prefillBody: c.prefillBody ?? null,
          };
        })
      : [],
    remainingQuota: updatedQuota.dailyLimit - updatedQuota.dailyUsed,
    resetAt: getResetTime(),
  };
}

export async function onboard(prompt: string) {
  const { data: cards } = await callLLMJson<unknown[]>(
    {
      system: `You are an onboarding assistant for the Prototype Me app. Based on the user's goals, generate a seed plan as a JSON array of cards. Each card has: type ("directive" or "playbook"), title, body. Return 3-5 cards.`,
      prompt,
    },
    [],
  );

  return {
    cards: Array.isArray(cards)
      ? cards.map((_c: unknown) => {
          const c = _c as Record<string, unknown>;
          return {
            id: crypto.randomUUID(),
            type: c.type ?? "directive",
            title: c.title ?? "Untitled",
            body: c.body ?? "",
          };
        })
      : [],
  };
}

export async function directiveWizard(userId: string, problem: string) {
  const quota = await getQuota(userId);
  if (quota.dailyUsed >= quota.dailyLimit) {
    throw { status: 429, error: "quota_exceeded", message: "Daily AI quota exceeded" };
  }

  const systemPrompt = `You are a directive suggestion engine for the Prototype Me app — a personal optimization system based on trial and error.

The user will describe a problem or weak point. Suggest exactly 3 directives — specific, high-impact things they can actually do. Not a laundry list of small habits. Each one should meaningfully move the needle on this specific problem.

Rules:
- Via negativa: remove what's causing the problem, don't just add positive habits on top
- Be SPECIFIC and DIRECT. "Clear your desk of everything except what you're working on" not "reduce distractions." "No caffeine after 12pm" not "watch your caffeine intake."
- Back each one up with WHY it works — cite the actual mechanism. Neuroscience, Huberman, research, physiology. Not "because it's good for you."
- Each directive is ONE thing. Not a routine, not a system — one clear action or rule.
- These are experiments to try, not permanent life rules. Frame them that way.
- Don't suggest obvious stuff everyone already knows unless there's a specific angle they probably haven't tried.
- Fewer is better. 3 strong ones beats 5 mediocre ones.

Return a JSON array of objects, each with:
- "title": short, imperative, no fluff (e.g. "No caffeine after 12pm", "NSDR for 10 min when energy dips")
- "body": 1-2 sentences explaining the mechanism — why this actually works, not just what to do

Return ONLY the JSON array. No markdown, no explanation, no preamble.`;

  const { data: suggestions } = await callLLMJson<unknown[]>(
    { system: systemPrompt, prompt: problem },
    [],
  );

  await usageQueries.increment(userId);

  const updatedQuota = await getQuota(userId);
  return {
    suggestions: Array.isArray(suggestions)
      ? suggestions.slice(0, 3).map((_s: unknown) => {
          const s = _s as Record<string, unknown>;
          return {
            id: crypto.randomUUID(),
            title: (s.title as string) ?? "Suggestion",
            body: (s.body as string) ?? "",
          };
        })
      : [],
    remainingQuota: updatedQuota.dailyLimit - updatedQuota.dailyUsed,
    resetAt: getResetTime(),
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
