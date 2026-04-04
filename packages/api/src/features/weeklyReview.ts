import { db } from "../db/client.js";
import { dayEntry, periodicReview, directive, directiveHistory, scheduleInstance } from "../db/schema.js";
import { eq, and, gte, lte, desc, sql, inArray } from "drizzle-orm";
import { callLLMJson } from "../lib/llm.js";

// ── Types ──────────────────────────────────────

type Period = "weekly" | "monthly";

interface Theme {
  name: string;
  mentions: number;
}
interface DirectiveWin {
  directiveTitle: string;
  evidence: string;
}
interface DirectiveFocus {
  directiveTitle: string;
  reason: string;
}
interface DirectiveGap {
  theme: string;
  suggestedTitle: string;
}

interface ReviewOutput {
  themes: Theme[];
  directiveWins: DirectiveWin[];
  directiveFocus: DirectiveFocus[];
  directiveGaps: DirectiveGap[];
  suggestion: string | null;
  summary: string;
  bestDay: string | null;
  bestDayNote: string | null;
  lowestDay: string | null;
  lowestDayNote: string | null;
}

const REVIEW_FALLBACK: ReviewOutput = {
  themes: [],
  directiveWins: [],
  directiveFocus: [],
  directiveGaps: [],
  suggestion: null,
  summary: "",
  bestDay: null,
  bestDayNote: null,
  lowestDay: null,
  lowestDayNote: null,
};

// ── Cron Entry Points ──────────────────────────

/**
 * Generate weekly reviews for all users with entries in the past week.
 * Runs Sunday night.
 */
export async function generateWeeklyReviews() {
  const { start, end } = getWeekRange();
  return generateReviews("weekly", start, end);
}

/**
 * Generate monthly reviews for all users with entries in the past month.
 * Runs 1st of the month.
 */
export async function generateMonthlyReviews() {
  const { start, end } = getMonthRange();
  return generateReviews("monthly", start, end);
}

// ── Core Logic ─────────────────────────────────

async function generateReviews(period: Period, periodStart: string, periodEnd: string) {
  // Find all users with day entries in this period
  const usersWithEntries = await db
    .selectDistinct({ userId: dayEntry.userId })
    .from(dayEntry)
    .where(and(gte(dayEntry.date, periodStart), lte(dayEntry.date, periodEnd)));

  let processed = 0;
  let skipped = 0;
  let errors = 0;

  for (const { userId } of usersWithEntries) {
    try {
      // Check if review already exists
      const existing = await db
        .select({ id: periodicReview.id })
        .from(periodicReview)
        .where(
          and(
            eq(periodicReview.userId, userId),
            eq(periodicReview.period, period),
            eq(periodicReview.periodStart, periodStart),
          ),
        )
        .limit(1);

      if (existing.length > 0) {
        skipped++;
        continue;
      }

      await generateReviewForUser(userId, period, periodStart, periodEnd);
      processed++;
    } catch (err) {
      console.error(`[Review/${period}] Failed for user ${userId}:`, err);
      errors++;
    }
  }

  return { processed, skipped, errors };
}

async function generateReviewForUser(userId: string, period: Period, periodStart: string, periodEnd: string) {
  // ── Gather data ──

  const entries = await db
    .select()
    .from(dayEntry)
    .where(and(eq(dayEntry.userId, userId), gte(dayEntry.date, periodStart), lte(dayEntry.date, periodEnd)))
    .orderBy(dayEntry.date);

  if (entries.length === 0) return;

  // Active directives with their IDs
  const directives = await db
    .select({ id: directive.id, title: directive.title })
    .from(directive)
    .where(and(eq(directive.userId, userId), eq(directive.status, "active")))
    .limit(30);

  // Directive completion stats for the period
  const directiveIds = directives.map((d) => d.id);
  let completionStats: { directiveId: string; done: number; skipped: number; total: number }[] = [];
  if (directiveIds.length > 0) {
    const instances = await db
      .select({
        directiveId: scheduleInstance.directiveId,
        status: scheduleInstance.status,
      })
      .from(scheduleInstance)
      .where(
        and(
          eq(scheduleInstance.userId, userId),
          inArray(scheduleInstance.directiveId, directiveIds),
          gte(scheduleInstance.date, periodStart),
          lte(scheduleInstance.date, periodEnd),
        ),
      );

    // Group by directive
    const grouped = new Map<string, { done: number; skipped: number; total: number }>();
    for (const inst of instances) {
      const stats = grouped.get(inst.directiveId) ?? { done: 0, skipped: 0, total: 0 };
      stats.total++;
      if (inst.status === "done") stats.done++;
      if (inst.status === "skipped") stats.skipped++;
      grouped.set(inst.directiveId, stats);
    }
    completionStats = Array.from(grouped.entries()).map(([directiveId, stats]) => ({ directiveId, ...stats }));
  }

  // Tag frequency
  const tagCounts = new Map<string, number>();
  for (const entry of entries) {
    for (const tag of entry.tags) {
      tagCounts.set(tag, (tagCounts.get(tag) ?? 0) + 1);
    }
  }
  const topTags = [...tagCounts.entries()].sort((a, b) => b[1] - a[1]).slice(0, 10);

  // For monthly: include weekly review summaries for extra context
  let weeklyContext = "";
  if (period === "monthly") {
    const weeklyReviews = await db
      .select({ summary: periodicReview.summary, periodStart: periodicReview.periodStart })
      .from(periodicReview)
      .where(
        and(
          eq(periodicReview.userId, userId),
          eq(periodicReview.period, "weekly"),
          gte(periodicReview.periodStart, periodStart),
          lte(periodicReview.periodStart, periodEnd),
        ),
      )
      .orderBy(periodicReview.periodStart);

    if (weeklyReviews.length > 0) {
      weeklyContext =
        "\n\nWeekly summaries from this month:\n" +
        weeklyReviews.map((r) => `Week of ${r.periodStart}: ${r.summary}`).join("\n");
    }
  }

  // ── Compute stats ──

  const rated = entries.filter((e) => e.rating != null);
  const avgRating = rated.length > 0 ? rated.reduce((sum, e) => sum + e.rating!, 0) / rated.length : null;

  // ── Build prompt ──

  const entriesText = entries
    .map((e) => {
      const parts = [`${e.date}`];
      if (e.rating != null) parts.push(`Rating: ${e.rating}/10`);
      if (e.tags.length > 0) parts.push(`Tags: ${e.tags.join(", ")}`);
      if (e.diary) parts.push(`Journal: ${e.diary}`);
      return parts.join(" | ");
    })
    .join("\n");

  const directivesText =
    directives.length > 0
      ? "\n\nActive habits/directives:\n" +
        directives
          .map((d) => {
            const stats = completionStats.find((s) => s.directiveId === d.id);
            if (stats && stats.total > 0) {
              const pct = Math.round((stats.done / stats.total) * 100);
              return `- ${d.title} (${pct}% completed — ${stats.done}/${stats.total} done, ${stats.skipped} skipped)`;
            }
            return `- ${d.title}`;
          })
          .join("\n")
      : "";

  const tagsText = topTags.length > 0 ? `\n\nMost used tags: ${topTags.map(([t, c]) => `${t} (${c}x)`).join(", ")}` : "";

  const periodLabel = period === "weekly" ? "week" : "month";

  const system = `You analyze someone's ${periodLabel} from their journal and map it to their directives (habits/intentions they've set for themselves).

Your job is to answer four questions from the data:
1. What themes are they writing about? (stress, sleep, relationships, focus, etc.)
2. Which directives are working? (evidence in journal + completion data)
3. Which directives need re-focus? (themes match them but completion is low, or journal shows struggle with them)
4. What themes have no directive yet? (recurring topics with no related habit)

Tone rules:
- Direct and declarative. State observations as facts.
- No coaching voice, no encouragement, no motivational wrap-ups.
- Never start with "You" or "Your".
- Drop filler phrases: "it seems", "overall", "great job", "you're doing well".
- No emojis, no exclamation marks.
- Reference specific days, tags, or directive titles by name.
- Return empty arrays or null when there's nothing meaningful to say.

Return a JSON object with these fields:
- "themes": array of {name, mentions}. Top 3-5 recurring topics in the journal. name = short phrase ("sleep quality", "work stress"). mentions = rough count of entries referencing it.
- "directiveWins": array of {directiveTitle, evidence}. Directives with signs of working. directiveTitle = exact title from the directive list. evidence = one sentence, what in the journal suggests it's helping.
- "directiveFocus": array of {directiveTitle, reason}. Directives to re-focus on. directiveTitle = exact title. reason = one sentence, why (low completion, journal shows struggle).
- "directiveGaps": array of {theme, suggestedTitle}. Recurring themes with no matching directive. suggestedTitle = a concise directive title they could add.
- "suggestion": one concrete action for next ${periodLabel}. Imperative voice. Null if no clear pattern.
- "summary": 1-3 sentences of context. What happened, in plain terms.
- "bestDay": yyyy-MM-dd of highest-rated day, or null.
- "bestDayNote": what made it highest. Null if no ratings.
- "lowestDay": yyyy-MM-dd of lowest-rated day, or null.
- "lowestDayNote": what pulled it down. Null if no ratings.

Return ONLY valid JSON. No markdown.`;

  const prompt = `Here are my journal entries for the ${periodLabel} of ${periodStart} to ${periodEnd}:

${entriesText}
${directivesText}
${tagsText}
${weeklyContext}

${avgRating != null ? `Average rating: ${avgRating.toFixed(1)}/10` : "No ratings this period."}
${entries.length} total entries.`;

  const { data } = await callLLMJson<ReviewOutput>(
    { system, prompt, maxTokens: period === "monthly" ? 1200 : 900 },
    { ...REVIEW_FALLBACK, summary: `Logged ${entries.length} journal ${entries.length === 1 ? "entry" : "entries"} this ${periodLabel}.` },
  );

  // ── Insert ──

  await db.insert(periodicReview).values({
    userId,
    period,
    periodStart,
    periodEnd,
    themes: data.themes ?? [],
    directiveWins: data.directiveWins ?? [],
    directiveFocus: data.directiveFocus ?? [],
    directiveGaps: data.directiveGaps ?? [],
    suggestion: data.suggestion,
    summary: data.summary,
    bestDay: data.bestDay,
    bestDayNote: data.bestDayNote,
    lowestDay: data.lowestDay,
    lowestDayNote: data.lowestDayNote,
    avgRating,
    entryCount: entries.length,
  });
}

// ── Query Helpers ──────────────────────────────

/** Get recent reviews for a user, optionally filtered by period. */
export async function getReviews(userId: string, period?: Period, limit = 12) {
  const conditions = [eq(periodicReview.userId, userId)];
  if (period) conditions.push(eq(periodicReview.period, period));

  return db
    .select()
    .from(periodicReview)
    .where(and(...conditions))
    .orderBy(desc(periodicReview.periodStart))
    .limit(limit);
}

/**
 * TEST ONLY: Force-generate a review for the current user for the current week or month.
 * Deletes any existing review for that period first, then regenerates.
 */
export async function triggerTestReview(userId: string, period: Period): Promise<{ success: boolean; message: string }> {
  const { start, end } = period === "weekly" ? getCurrentWeekRange() : getCurrentMonthRange();

  // Delete any existing review for this period
  await db
    .delete(periodicReview)
    .where(
      and(
        eq(periodicReview.userId, userId),
        eq(periodicReview.period, period),
        eq(periodicReview.periodStart, start),
      ),
    );

  try {
    await generateReviewForUser(userId, period, start, end);
    return { success: true, message: `Generated ${period} review for ${start} to ${end}` };
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    return { success: false, message };
  }
}

/** Get a specific review by period and start date. */
export async function getReview(userId: string, period: Period, periodStartDate: string) {
  const rows = await db
    .select()
    .from(periodicReview)
    .where(
      and(
        eq(periodicReview.userId, userId),
        eq(periodicReview.period, period),
        eq(periodicReview.periodStart, periodStartDate),
      ),
    )
    .limit(1);
  return rows[0] ?? null;
}

// ── Date Helpers ───────────────────────────────

function toDateStr(d: Date): string {
  return d.toISOString().split("T")[0];
}

/** Current week (Monday → today), for test triggers. */
function getCurrentWeekRange(): { start: string; end: string } {
  const now = new Date();
  const day = now.getUTCDay(); // 0=Sun, 1=Mon, ...
  // Monday of this week
  const start = new Date(now);
  const daysFromMonday = day === 0 ? 6 : day - 1;
  start.setUTCDate(now.getUTCDate() - daysFromMonday);
  start.setUTCHours(0, 0, 0, 0);

  const end = new Date(now);
  end.setUTCHours(0, 0, 0, 0);

  return { start: toDateStr(start), end: toDateStr(end) };
}

/** Current month (1st → today), for test triggers. */
function getCurrentMonthRange(): { start: string; end: string } {
  const now = new Date();
  const start = new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), 1));
  const end = new Date(now);
  end.setUTCHours(0, 0, 0, 0);
  return { start: toDateStr(start), end: toDateStr(end) };
}

function getWeekRange(): { start: string; end: string } {
  const now = new Date();
  const day = now.getUTCDay(); // 0=Sun
  // End = today (Sunday) or last Sunday
  const end = new Date(now);
  end.setUTCDate(now.getUTCDate() - (day === 0 ? 0 : day));
  end.setUTCHours(0, 0, 0, 0);

  const start = new Date(end);
  start.setUTCDate(end.getUTCDate() - 6);

  return { start: toDateStr(start), end: toDateStr(end) };
}

function getMonthRange(): { start: string; end: string } {
  const now = new Date();
  // Previous month
  const year = now.getUTCMonth() === 0 ? now.getUTCFullYear() - 1 : now.getUTCFullYear();
  const month = now.getUTCMonth() === 0 ? 11 : now.getUTCMonth() - 1; // 0-indexed
  const start = new Date(Date.UTC(year, month, 1));
  const end = new Date(Date.UTC(year, month + 1, 0)); // last day of month

  return { start: toDateStr(start), end: toDateStr(end) };
}
