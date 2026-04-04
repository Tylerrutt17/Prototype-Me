import { db } from "../db/client.js";
import { dayEntry, periodicReview, directive, directiveHistory, scheduleRule } from "../db/schema.js";
import { eq, and, gte, lte, desc, inArray } from "drizzle-orm";
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

  // Schedule-based completion stats for the period.
  // For each directive with a schedule rule, compute which dates were *expected*
  // based on the rule, then compare to actual checklist_complete rows.
  const directiveIds = directives.map((d) => d.id);
  type CompletionStat = {
    directiveId: string;
    scheduled: number;
    completed: number;
    missedDates: string[];
    hasSchedule: boolean;
  };
  const completionStats: CompletionStat[] = [];

  if (directiveIds.length > 0) {
    // Fetch schedule rules for these directives
    const rules = await db
      .select({
        directiveId: scheduleRule.directiveId,
        ruleType: scheduleRule.ruleType,
        params: scheduleRule.params,
      })
      .from(scheduleRule)
      .where(inArray(scheduleRule.directiveId, directiveIds));

    // Fetch checklist completions for the period from the directive_history table.
    // Payload shape: {"v":1,"date":"yyyy-MM-dd"} — we match on payload->>'date'.
    const checklistRows = await db
      .select({ directiveId: directiveHistory.directiveId, payload: directiveHistory.payload })
      .from(directiveHistory)
      .where(
        and(
          inArray(directiveHistory.directiveId, directiveIds),
          eq(directiveHistory.action, "checklist_complete"),
        ),
      );

    // Index completed dates per directive (only dates inside the period)
    const completedDatesPerDirective = new Map<string, Set<string>>();
    for (const row of checklistRows) {
      const date = extractPayloadDate(row.payload);
      if (!date || date < periodStart || date > periodEnd) continue;
      let set = completedDatesPerDirective.get(row.directiveId);
      if (!set) {
        set = new Set<string>();
        completedDatesPerDirective.set(row.directiveId, set);
      }
      set.add(date);
    }

    // Group schedule rules by directiveId
    const rulesByDirective = new Map<string, typeof rules>();
    for (const rule of rules) {
      const existing = rulesByDirective.get(rule.directiveId) ?? [];
      existing.push(rule);
      rulesByDirective.set(rule.directiveId, existing);
    }

    // Compute expected dates for each directive, then diff against completions
    for (const { id: directiveId } of directives) {
      const directiveRules = rulesByDirective.get(directiveId) ?? [];
      const completedDates = completedDatesPerDirective.get(directiveId) ?? new Set<string>();

      if (directiveRules.length === 0) {
        // No schedule — only count raw completions. Not a "has schedule" directive.
        completionStats.push({
          directiveId,
          scheduled: 0,
          completed: completedDates.size,
          missedDates: [],
          hasSchedule: false,
        });
        continue;
      }

      const expectedDates = new Set<string>();
      for (const date of enumerateDates(periodStart, periodEnd)) {
        for (const rule of directiveRules) {
          if (ruleMatchesDate(rule.ruleType, rule.params, date)) {
            expectedDates.add(date);
            break;
          }
        }
      }

      const missed: string[] = [];
      for (const date of expectedDates) {
        if (!completedDates.has(date)) missed.push(date);
      }
      missed.sort();

      completionStats.push({
        directiveId,
        scheduled: expectedDates.size,
        completed: expectedDates.size - missed.length,
        missedDates: missed,
        hasSchedule: true,
      });
    }
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

  const periodLabel = period === "weekly" ? "week" : "month";

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
            const parts: string[] = [`- ${d.title}`];
            if (stats?.hasSchedule && stats.scheduled > 0) {
              const pct = Math.round((stats.completed / stats.scheduled) * 100);
              parts.push(`(${stats.completed}/${stats.scheduled} scheduled days completed, ${pct}%)`);
              if (stats.missedDates.length > 0) {
                parts.push(`(missed: ${stats.missedDates.join(", ")})`);
              }
            } else if (stats && !stats.hasSchedule && stats.completed > 0) {
              parts.push(`(no schedule, ${stats.completed} check-in${stats.completed === 1 ? "" : "s"})`);
            } else if (stats?.hasSchedule && stats.scheduled === 0) {
              parts.push(`(scheduled but not this ${periodLabel})`);
            }
            return parts.join(" ");
          })
          .join("\n")
      : "";

  const tagsText = topTags.length > 0 ? `\n\nMost used tags: ${topTags.map(([t, c]) => `${t} (${c}x)`).join(", ")}` : "";

  const system = `You analyze someone's ${periodLabel} from their journal and map it to their directives (habits/intentions they've set for themselves).

Core method: find themes in the journal, then EVERY directive insight must be causally linked to a specific theme you extracted.

Process:
1. Read the journal entries. Identify recurring themes — what are they actually writing about? (tiredness, sleep, work stress, loneliness, focus, exercise, diet, etc.)
2. For each theme, check the directive list for directives that address that theme.
   - If a directive addresses the theme AND has low completion (many missed days) OR the journal shows struggle with it → directiveFocus.
   - If a directive addresses the theme AND the journal shows evidence it's helping → directiveWin.
   - If a theme has NO directive addressing it → directiveGap.
3. Completion % alone is never enough. A directive with many missed days is only a focus area if the journal shows they need it. A directive completed every scheduled day is only a win if the journal mentions it helping.

Directive completion data format:
- "X/Y scheduled days completed, Z%" means this directive was scheduled Y times; the user checked off X of them.
- "(missed: yyyy-MM-dd, yyyy-MM-dd, ...)" lists specific dates the user skipped the scheduled directive.
- "(no schedule, N check-ins)" means the user has no recurring schedule for this but checked in N times anyway.
- "(scheduled but not this ${periodLabel})" means the schedule doesn't land on any day in this period.
- Use missed dates to cross-reference journal entries. If the user complains about tiredness on a day they missed their "Go for a run" directive, that's a causal link.

Tone rules:
- Direct and declarative. State observations as facts.
- No coaching voice, no encouragement, no motivational wrap-ups.
- Never start with "You" or "Your".
- Drop filler phrases: "it seems", "overall", "great job", "you're doing well".
- No emojis, no exclamation marks.
- Reference specific days, tags, or directive titles by name.
- Return empty arrays when there's no causal link to make. Never list a directive just because its completion is low.

Return a JSON object with these fields:
- "themes": array of {name, mentions}. Top 3-5 recurring topics in the journal. name = short phrase ("tiredness", "work stress"). mentions = rough count of entries referencing it.
- "directiveWins": array of {directiveTitle, evidence}. directiveTitle = exact title from the list. evidence = one sentence quoting or paraphrasing what in the journal shows this directive helping. Must reference a theme.
- "directiveFocus": array of {directiveTitle, reason}. directiveTitle = exact title. reason = one sentence connecting a journal theme to this directive and why it needs attention. Format: "[theme] appears in journal but [directive] is [completion status / evidence of struggle]."
- "directiveGaps": array of {theme, suggestedTitle}. Only for themes that recurred but have NO matching directive in the list. suggestedTitle = concise directive title they could add.
- "suggestion": one concrete action for next ${periodLabel}. Imperative voice. Tied to the most important focus area or gap. Null if no clear pattern.
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

/** Extract the "date" field from a checklist_complete payload JSON string. */
function extractPayloadDate(payload: string): string | null {
  try {
    const parsed = JSON.parse(payload);
    const date = parsed?.date;
    if (typeof date === "string" && /^\d{4}-\d{2}-\d{2}$/.test(date)) return date;
    return null;
  } catch {
    return null;
  }
}

/** Yield every yyyy-MM-dd between start and end, inclusive. */
function* enumerateDates(startStr: string, endStr: string): Generator<string> {
  const start = new Date(`${startStr}T12:00:00Z`);
  const end = new Date(`${endStr}T12:00:00Z`);
  const cursor = new Date(start);
  while (cursor <= end) {
    yield toDateStr(cursor);
    cursor.setUTCDate(cursor.getUTCDate() + 1);
  }
}

/**
 * Match a schedule rule against a specific date string.
 * Port of iOS ScheduleRule.ruleMatchesDate — params shape supports weekdays,
 * monthDays, and oneOffs (flat [y, m, d, y, m, d, ...] triplets).
 */
function ruleMatchesDate(
  ruleType: "weekly" | "monthly" | "oneOff",
  params: Record<string, number[]>,
  dateStr: string,
): boolean {
  const d = new Date(`${dateStr}T12:00:00Z`);
  // JS getUTCDay: 0=Sun, 1=Mon, ... 6=Sat. iOS Calendar weekday: 1=Sun, 2=Mon, ... 7=Sat.
  const weekday = d.getUTCDay() + 1;
  const dayOfMonth = d.getUTCDate();
  const year = d.getUTCFullYear();
  const month = d.getUTCMonth() + 1;

  const weekdays = params.weekdays ?? (ruleType === "weekly" ? params.days : undefined);
  if (weekdays?.includes(weekday)) return true;

  if (params.monthDays?.includes(dayOfMonth)) return true;

  const oneOffs = params.oneOffs;
  if (oneOffs && oneOffs.length >= 3) {
    for (let i = 0; i <= oneOffs.length - 3; i += 3) {
      if (oneOffs[i] === year && oneOffs[i + 1] === month && oneOffs[i + 2] === dayOfMonth) return true;
    }
  }
  return false;
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
