/**
 * Deterministic conversational flow engine.
 *
 * Handles common user intents (create, update, journal) with instant
 * server-side logic instead of AI round-trips. Falls back to the full
 * AI converse endpoint for freeform/ambiguous requests.
 */

import { openai, OPENAI_MODEL } from "../lib/llm.js";
import * as searchQueries from "../db/queries/search.js";
import * as directiveQueries from "../db/queries/directives.js";
import * as noteQueries from "../db/queries/notes.js";
import * as dayEntryQueries from "../db/queries/dayEntries.js";
import * as modeQueries from "../db/queries/modes.js";
import * as profileQueries from "../db/queries/profiles.js";
import * as usageQueries from "../db/queries/usage.js";
import { classifyIntent, type MatchedIntent } from "./intentPatterns.js";
import { LIMITS } from "../validation/limits.js";

// ── Types ──

interface FlowSession {
  userId: string;
  state: string;
  intent: MatchedIntent;
  searchQuery?: string;
  contentHint?: string;
  selectedItemId?: string;
  selectedItemTitle?: string;
  selectedField?: "title" | "body" | "both";
  existingBody?: string;
  localDate?: string;
  createdAt: number;
}

interface ToolCall {
  id: string;
  function: string;
  arguments: Record<string, unknown>;
}

export interface FlowResponse {
  message: string;
  toolCalls: ToolCall[];
  remainingQuota: number;
  resetAt: string;
  flowId?: string;
  flowState?: string;
  fallbackToConverse?: boolean;
  quotaFree?: boolean;
}

// ── Session Store (in-memory, TTL 5 minutes) ──

const sessions = new Map<string, FlowSession>();
const SESSION_TTL = 5 * 60 * 1000;

function cleanExpiredSessions() {
  const now = Date.now();
  for (const [id, session] of sessions) {
    if (now - session.createdAt > SESSION_TTL) sessions.delete(id);
  }
}

// Run cleanup every minute
setInterval(cleanExpiredSessions, 60_000);

function createSession(userId: string, intent: MatchedIntent, localDate?: string): string {
  const id = `${userId}-${Date.now()}`;
  sessions.set(id, {
    userId,
    state: "started",
    intent,
    localDate,
    createdAt: Date.now(),
  });
  return id;
}

// ── Quota (mirrors converse.ts) ──

const FREE_DAILY_LIMIT = 5;
const PRO_DAILY_LIMIT = 100;

async function getQuota(userId: string) {
  const user = await profileQueries.findById(userId);
  const dailyLimit = user?.plan === "pro" ? PRO_DAILY_LIMIT : FREE_DAILY_LIMIT;
  const usage = await usageQueries.getToday(userId);
  return { dailyLimit, dailyUsed: usage?.count ?? 0 };
}

function getResetTime(): string {
  const tomorrow = new Date();
  tomorrow.setUTCHours(0, 0, 0, 0);
  tomorrow.setUTCDate(tomorrow.getUTCDate() + 1);
  return tomorrow.toISOString();
}

function toolCall(fn: string, args: Record<string, unknown>): ToolCall {
  return { id: `flow-${Date.now()}-${Math.random().toString(36).slice(2, 6)}`, function: fn, arguments: args };
}

// ── Main Entry Point ──

export async function handleFlow(
  userId: string,
  message: string,
  flowId?: string,
  localDate?: string,
): Promise<FlowResponse> {
  const quota = await getQuota(userId);

  // Always classify the message to detect intent switches
  const intent = await classifyIntent(message);

  // Resume existing session?
  if (flowId && sessions.has(flowId)) {
    const session = sessions.get(flowId)!;
    if (Date.now() - session.createdAt > SESSION_TTL) {
      sessions.delete(flowId);
    } else {
      // Check if the user switched intent mid-flow
      // A "freeform" classification during a flow usually means the user is
      // answering our prompt (e.g. typing content), so we continue the flow.
      // But if the AI detects a specific different intent, abandon and restart.
      if (intent && intent.intent !== "freeform" && intent.intent !== session.intent.intent) {
        console.log(`[Flow] Intent switch detected: ${session.intent.intent} → ${intent.intent}`);
        sessions.delete(flowId);
        return startNewFlow(userId, message, intent, localDate, quota);
      }
      return continueFlow(session, flowId, message, quota);
    }
  }

  // New message
  if (!intent || intent.intent === "freeform") {
    return fallback(quota);
  }

  return startNewFlow(userId, message, intent, localDate, quota);
}

// ── Flow Routing ──

async function startNewFlow(
  userId: string,
  message: string,
  intent: MatchedIntent,
  localDate: string | undefined,
  quota: { dailyLimit: number; dailyUsed: number },
): Promise<FlowResponse> {
  switch (intent.intent) {
    case "journal_log":
      return handleJournalLog(userId, intent, localDate, quota);
    case "journal_update":
      return handleJournalUpdate(userId, intent, localDate, quota);
    case "create_directive":
      return handleCreateDirective(userId, intent, quota);
    case "create_note":
      return handleCreateNote(userId, intent, quota);
    case "update":
      return handleUpdate(userId, intent, quota);
    case "retire":
      return handleRetire(userId, intent, quota);
    case "activate_mode":
    case "deactivate_mode":
      return handleMode(userId, intent, quota);
    case "list":
      // List requests are better handled by the AI (it formats nicely)
      return fallback(quota);
    default:
      return fallback(quota);
  }
}

async function continueFlow(
  session: FlowSession,
  flowId: string,
  message: string,
  quota: { dailyLimit: number; dailyUsed: number },
): Promise<FlowResponse> {
  const { state, intent } = session;

  // ── Journal flow continuation ──
  if (intent.intent === "journal_log" || intent.intent === "journal_update") {
    if (state === "awaiting_journal_content") {
      return handleJournalContent(session, flowId, message, quota);
    }
    if (state === "awaiting_journal_choice") {
      return handleJournalChoice(session, flowId, message, quota);
    }
  }

  // ── Create directive/note continuation ──
  if (intent.intent === "create_directive" || intent.intent === "create_note") {
    if (state === "awaiting_search_choice") {
      return handleSearchChoice(session, flowId, message, quota);
    }
    if (state === "awaiting_content") {
      return handleContentProvided(session, flowId, message, quota);
    }
  }

  // ── Update continuation ──
  if (intent.intent === "update") {
    if (state === "awaiting_item_choice") {
      return handleItemChoice(session, flowId, message, quota);
    }
    if (state === "awaiting_field_choice") {
      return handleFieldChoice(session, flowId, message, quota);
    }
    if (state === "awaiting_edit_mode") {
      return handleEditModeChoice(session, flowId, message, quota);
    }
    if (state === "awaiting_field_value") {
      return handleFieldValue(session, flowId, message, quota);
    }
  }

  // ── Retire continuation ──
  if (intent.intent === "retire" && state === "awaiting_item_choice") {
    return handleRetireChoice(session, flowId, message, quota);
  }

  // Unknown state — fall back
  sessions.delete(flowId);
  return fallback(quota);
}

// ── Journal Flows ──

async function handleJournalLog(
  userId: string,
  intent: MatchedIntent,
  localDate: string | undefined,
  quota: { dailyLimit: number; dailyUsed: number },
): Promise<FlowResponse> {
  const date = localDate || new Date().toISOString().split("T")[0]!;
  const entries = await dayEntryQueries.findAll(userId, { from: date, to: date });
  const existing = entries[0] as Record<string, unknown> | undefined;

  if (existing) {
    const flowId = createSession(userId, intent, localDate);
    const session = sessions.get(flowId)!;
    session.state = "awaiting_journal_choice";
    session.selectedItemId = existing.id as string;

    const rating = existing.rating ? ` (currently rated **${existing.rating}/10**)` : "";
    return {
      message: `You already have a journal entry for *${date}*${rating}. What would you like to do?`,
      toolCalls: [toolCall("present_options", {
        question: `You already have a journal entry for ${date}. What would you like to do?`,
        options: ["Update rating", "Add to diary", "Replace diary", "Something else"],
        icons: ["star.fill", "text.append", "arrow.triangle.2.circlepath", "ellipsis.circle"],
      })],
      remainingQuota: quota.dailyLimit - quota.dailyUsed,
      resetAt: getResetTime(),
      flowId,
      flowState: "awaiting_journal_choice",
      quotaFree: true,
    };
  }

  // No entry — prompt for content
  const flowId = createSession(userId, intent, localDate);
  const session = sessions.get(flowId)!;
  session.state = "awaiting_journal_content";
  session.localDate = date;

  return {
    message: "How was your day? **Rate it 1-10** and tell me about it.",
    toolCalls: [],
    remainingQuota: quota.dailyLimit - quota.dailyUsed,
    resetAt: getResetTime(),
    flowId,
    flowState: "awaiting_journal_content",
    quotaFree: true,
  };
}

async function handleJournalUpdate(
  userId: string,
  intent: MatchedIntent,
  localDate: string | undefined,
  quota: { dailyLimit: number; dailyUsed: number },
): Promise<FlowResponse> {
  // Same as journal_log — checks existing entry and branches
  return handleJournalLog(userId, intent, localDate, quota);
}

async function handleJournalContent(
  session: FlowSession,
  flowId: string,
  message: string,
  quota: { dailyLimit: number; dailyUsed: number },
): Promise<FlowResponse> {
  const date = session.localDate || new Date().toISOString().split("T")[0]!;

  // Parse rating from message (look for a number 1-10 at the start or standalone)
  const ratingMatch = message.match(/^\s*(\d{1,2})\b/);
  let rating: number | undefined;
  let diary = message;

  if (ratingMatch) {
    const num = parseInt(ratingMatch[1]!, 10);
    if (num >= 1 && num <= 10) {
      rating = num;
      // Remove the rating from the diary text
      diary = message.slice(ratingMatch[0].length).replace(/^[\s,.\-—]+/, "").trim();
    }
  }

  sessions.delete(flowId);

  // Return a create/update journal tool call for the client to render as a suggestion card
  return {
    message: rating
      ? `Got it — **${rating}/10**. Here's your entry:`
      : "Here's your entry:",
    toolCalls: [toolCall("create_journal_entry", {
      date,
      diary: diary || undefined,
      rating: rating || undefined,
    })],
    remainingQuota: quota.dailyLimit - quota.dailyUsed,
    resetAt: getResetTime(),
    flowId: undefined,
    flowState: "done",
    quotaFree: true,
  };
}

async function handleJournalChoice(
  session: FlowSession,
  flowId: string,
  message: string,
  quota: { dailyLimit: number; dailyUsed: number },
): Promise<FlowResponse> {
  const lower = message.toLowerCase();

  if (lower.includes("rating") || lower.includes("rate")) {
    session.state = "awaiting_journal_content";
    session.selectedField = "title"; // repurpose: means "rating only"
    return {
      message: "What would you rate today? (**1-10**)",
      toolCalls: [],
      remainingQuota: quota.dailyLimit - quota.dailyUsed,
      resetAt: getResetTime(),
      flowId,
      flowState: "awaiting_journal_content",
      quotaFree: true,
    };
  }

  if (lower.includes("add") || lower.includes("append")) {
    session.state = "awaiting_journal_content";
    session.selectedField = "body"; // means "append to diary"
    return {
      message: "What would you like to add?",
      toolCalls: [],
      remainingQuota: quota.dailyLimit - quota.dailyUsed,
      resetAt: getResetTime(),
      flowId,
      flowState: "awaiting_journal_content",
      quotaFree: true,
    };
  }

  if (lower.includes("replace")) {
    session.state = "awaiting_journal_content";
    return {
      message: "What should the new entry say? Include your **rating (1-10)** too if you'd like.",
      toolCalls: [],
      remainingQuota: quota.dailyLimit - quota.dailyUsed,
      resetAt: getResetTime(),
      flowId,
      flowState: "awaiting_journal_content",
      quotaFree: true,
    };
  }

  // "Something else" or unrecognized
  sessions.delete(flowId);
  return fallback(quota);
}

// ── Create Directive Flow ──

async function handleCreateDirective(
  userId: string,
  intent: MatchedIntent,
  quota: { dailyLimit: number; dailyUsed: number },
): Promise<FlowResponse> {
  const searchQuery = intent.searchQuery;

  if (searchQuery) {
    // Search for similar existing directives
    const results = await searchQueries.fuzzySearch(userId, searchQuery, 5, 0.2);
    const directives = results.filter((r) => r.type === "directive");

    if (directives.length > 0) {
      const flowId = createSession(userId, intent);
      const session = sessions.get(flowId)!;
      session.state = "awaiting_search_choice";
      session.searchQuery = searchQuery;

      const options = [
        ...directives.slice(0, 3).map((d) => `Edit: ${d.title}`),
        "Create new directive",
      ];

      const icons = [
        ...directives.slice(0, 3).map(() => "pencil.circle"),
        "plus.circle",
      ];

      return {
        message: "I found some similar directives:",
        toolCalls: [toolCall("present_options", {
          question: "I found some similar directives:",
          options,
          icons,
        })],
        remainingQuota: quota.dailyLimit - quota.dailyUsed,
        resetAt: getResetTime(),
        flowId,
        flowState: "awaiting_search_choice",
        quotaFree: true,
      };
    }
  }

  // No search query or no matches — prompt for content
  const flowId = createSession(userId, intent);
  const session = sessions.get(flowId)!;
  session.state = "awaiting_content";

  return {
    message: "What should the directive be about? Describe the habit or rule you want to try.",
    toolCalls: [],
    remainingQuota: quota.dailyLimit - quota.dailyUsed,
    resetAt: getResetTime(),
    flowId,
    flowState: "awaiting_content",
    quotaFree: true,
  };
}

// ── Create Note Flow ──

async function handleCreateNote(
  userId: string,
  intent: MatchedIntent,
  quota: { dailyLimit: number; dailyUsed: number },
): Promise<FlowResponse> {
  const flowId = createSession(userId, intent);
  const session = sessions.get(flowId)!;
  session.state = "awaiting_content";

  return {
    message: "What should the note be about?",
    toolCalls: [],
    remainingQuota: quota.dailyLimit - quota.dailyUsed,
    resetAt: getResetTime(),
    flowId,
    flowState: "awaiting_content",
    quotaFree: true,
  };
}

// ── Update Flow ──

async function handleUpdate(
  userId: string,
  intent: MatchedIntent,
  quota: { dailyLimit: number; dailyUsed: number },
): Promise<FlowResponse> {
  const searchQuery = intent.searchQuery;
  if (!searchQuery) {
    return fallback(quota);
  }

  const results = await searchQueries.fuzzySearch(userId, searchQuery, 5, 0.15);
  if (results.length === 0) {
    return {
      message: `I couldn't find anything matching "${searchQuery}". Could you be more specific?`,
      toolCalls: [],
      remainingQuota: quota.dailyLimit - quota.dailyUsed,
      resetAt: getResetTime(),
      quotaFree: true,
    };
  }

  if (results.length === 1 && results[0]!.similarity > 0.4) {
    // Strong single match — ask what to change
    const item = results[0]!;
    const flowId = createSession(userId, intent);
    const session = sessions.get(flowId)!;
    session.state = "awaiting_field_choice";
    session.selectedItemId = item.id;
    session.selectedItemTitle = item.title;
    session.intent.entityType = item.type as MatchedIntent["entityType"];

    return {
      message: `Found **${item.title}**. What would you like to change?`,
      toolCalls: [toolCall("present_options", {
        question: `Found "${item.title}". What would you like to change?`,
        options: ["Change title", "Change description", "Both", "Something else"],
        icons: ["textformat", "doc.text", "square.and.pencil", "ellipsis.circle"],
      })],
      remainingQuota: quota.dailyLimit - quota.dailyUsed,
      resetAt: getResetTime(),
      flowId,
      flowState: "awaiting_field_choice",
      quotaFree: true,
    };
  }

  // Multiple matches — let user pick
  const flowId = createSession(userId, intent);
  const session = sessions.get(flowId)!;
  session.state = "awaiting_item_choice";

  const typeIcons: Record<string, string> = {
    directive: "target",
    note: "doc.text",
    folder: "folder",
    mode: "bolt.fill",
  };
  const options = results.slice(0, 4).map((r) => `${r.type}: ${r.title}`);
  const icons = results.slice(0, 4).map((r) => typeIcons[r.type] || "doc");
  options.push("Something else");
  icons.push("ellipsis.circle");

  return {
    message: "Which one did you mean?",
    toolCalls: [toolCall("present_options", {
      question: "Which one did you mean?",
      options,
      icons,
    })],
    remainingQuota: quota.dailyLimit - quota.dailyUsed,
    resetAt: getResetTime(),
    flowId,
    flowState: "awaiting_item_choice",
    quotaFree: true,
  };
}

// ── Retire Flow ──

async function handleRetire(
  userId: string,
  intent: MatchedIntent,
  quota: { dailyLimit: number; dailyUsed: number },
): Promise<FlowResponse> {
  const searchQuery = intent.searchQuery;
  if (!searchQuery) {
    return fallback(quota);
  }

  const results = await searchQueries.fuzzySearch(userId, searchQuery, 5, 0.2);
  const directives = results.filter((r) => r.type === "directive");

  if (directives.length === 0) {
    return {
      message: `I couldn't find a directive matching "${searchQuery}".`,
      toolCalls: [],
      remainingQuota: quota.dailyLimit - quota.dailyUsed,
      resetAt: getResetTime(),
      quotaFree: true,
    };
  }

  if (directives.length === 1) {
    // Single match — confirm
    const d = directives[0]!;
    return {
      message: `Retire **${d.title}**?`,
      toolCalls: [toolCall("ask_confirmation", { question: `Retire "${d.title}"?` })],
      remainingQuota: quota.dailyLimit - quota.dailyUsed,
      resetAt: getResetTime(),
      quotaFree: true,
    };
  }

  // Multiple — pick
  const flowId = createSession(userId, intent);
  const session = sessions.get(flowId)!;
  session.state = "awaiting_item_choice";

  return {
    message: "Which directive did you want to retire?",
    toolCalls: [toolCall("present_options", {
      question: "Which directive?",
      options: [...directives.slice(0, 4).map((d) => d.title), "Cancel"],
      icons: [...directives.slice(0, 4).map(() => "archivebox"), "xmark.circle"],
    })],
    remainingQuota: quota.dailyLimit - quota.dailyUsed,
    resetAt: getResetTime(),
    flowId,
    flowState: "awaiting_item_choice",
    quotaFree: true,
  };
}

// ── Mode Flow ──

async function handleMode(
  userId: string,
  intent: MatchedIntent,
  quota: { dailyLimit: number; dailyUsed: number },
): Promise<FlowResponse> {
  const searchQuery = intent.searchQuery;
  if (!searchQuery) return fallback(quota);

  const modes = await noteQueries.findAll(userId, { kind: "mode" });
  const match = modes.find((m: Record<string, unknown>) =>
    (m.title as string).toLowerCase().includes(searchQuery.toLowerCase()),
  );

  if (!match) {
    return {
      message: `I couldn't find a mode matching "${searchQuery}".`,
      toolCalls: [],
      remainingQuota: quota.dailyLimit - quota.dailyUsed,
      resetAt: getResetTime(),
      quotaFree: true,
    };
  }

  const fn = intent.intent === "activate_mode" ? "activate_mode" : "deactivate_mode";
  const verb = intent.intent === "activate_mode" ? "Activate" : "Deactivate";

  return {
    message: `${verb} **${(match as Record<string, unknown>).title}**?`,
    toolCalls: [toolCall(fn, { noteId: (match as Record<string, unknown>).id })],
    remainingQuota: quota.dailyLimit - quota.dailyUsed,
    resetAt: getResetTime(),
    quotaFree: true,
  };
}

// ── Continuation Handlers ──

async function handleSearchChoice(
  session: FlowSession,
  flowId: string,
  message: string,
  quota: { dailyLimit: number; dailyUsed: number },
): Promise<FlowResponse> {
  const lower = message.toLowerCase();

  if (lower.includes("create new")) {
    session.state = "awaiting_content";
    const entityLabel = session.intent.entityType === "note" ? "note" : "directive";
    return {
      message: `What should the ${entityLabel} be about?`,
      toolCalls: [],
      remainingQuota: quota.dailyLimit - quota.dailyUsed,
      resetAt: getResetTime(),
      flowId,
      flowState: "awaiting_content",
      quotaFree: true,
    };
  }

  if (lower.startsWith("edit:") || lower.startsWith("edit ")) {
    // User chose to edit an existing item — switch to update flow
    const title = message.replace(/^edit:\s*/i, "").trim();
    const results = await searchQueries.fuzzySearch(session.userId, title, 1, 0.1);
    if (results.length > 0) {
      session.state = "awaiting_field_choice";
      session.selectedItemId = results[0]!.id;
      session.selectedItemTitle = results[0]!.title;
      session.intent.entityType = results[0]!.type as MatchedIntent["entityType"];
      session.intent.intent = "update";

      return {
        message: `What would you like to change about **${results[0]!.title}**?`,
        toolCalls: [toolCall("present_options", {
          question: `What would you like to change?`,
          options: ["Change title", "Change description", "Both", "Something else"],
        })],
        remainingQuota: quota.dailyLimit - quota.dailyUsed,
        resetAt: getResetTime(),
        flowId,
        flowState: "awaiting_field_choice",
        quotaFree: true,
      };
    }
  }

  // Unrecognized choice
  sessions.delete(flowId);
  return fallback(quota);
}

async function handleContentProvided(
  session: FlowSession,
  flowId: string,
  message: string,
  quota: { dailyLimit: number; dailyUsed: number },
): Promise<FlowResponse> {
  // User provided a description — use AI to generate a clean title + body
  // This is the ONE step that uses AI
  if (quota.dailyUsed >= quota.dailyLimit) {
    sessions.delete(flowId);
    return {
      message: "You've hit your daily AI limit. Try again tomorrow, or create the directive manually in the Focus tab.",
      toolCalls: [],
      remainingQuota: 0,
      resetAt: getResetTime(),
    };
  }

  const entityType = session.intent.entityType === "note" ? "note" : "directive";
  const fn = entityType === "note" ? "create_note" : "create_directive";

  try {
    const result = await generateTitleBody(message, entityType);
    await usageQueries.increment(session.userId);
    const updatedQuota = await getQuota(session.userId);

    sessions.delete(flowId);

    const args: Record<string, unknown> = { title: result.title };
    if (result.body) args.body = result.body;

    return {
      message: `Here's what I came up with:`,
      toolCalls: [toolCall(fn, args)],
      remainingQuota: updatedQuota.dailyLimit - updatedQuota.dailyUsed,
      resetAt: getResetTime(),
      flowState: "done",
      quotaFree: false,
    };
  } catch {
    sessions.delete(flowId);
    return fallback(quota);
  }
}

async function handleItemChoice(
  session: FlowSession,
  flowId: string,
  message: string,
  quota: { dailyLimit: number; dailyUsed: number },
): Promise<FlowResponse> {
  const lower = message.toLowerCase();
  if (lower === "something else" || lower === "cancel") {
    sessions.delete(flowId);
    return fallback(quota);
  }

  // Try to match the selection to a search result
  const cleanMessage = message.replace(/^(directive|note|folder|mode):\s*/i, "").trim();
  const results = await searchQueries.fuzzySearch(session.userId, cleanMessage, 1, 0.1);

  if (results.length === 0) {
    sessions.delete(flowId);
    return {
      message: `I couldn't find "${cleanMessage}". Could you try again?`,
      toolCalls: [],
      remainingQuota: quota.dailyLimit - quota.dailyUsed,
      resetAt: getResetTime(),
      quotaFree: true,
    };
  }

  const item = results[0]!;
  session.selectedItemId = item.id;
  session.selectedItemTitle = item.title;
  session.intent.entityType = item.type as MatchedIntent["entityType"];

  if (session.intent.intent === "retire") {
    return handleRetireChoice(session, flowId, item.title, quota);
  }

  session.state = "awaiting_field_choice";
  return {
    message: `What would you like to change about **${item.title}**?`,
    toolCalls: [toolCall("present_options", {
      question: `What would you like to change?`,
      options: ["Change title", "Change description", "Both", "Something else"],
    })],
    remainingQuota: quota.dailyLimit - quota.dailyUsed,
    resetAt: getResetTime(),
    flowId,
    flowState: "awaiting_field_choice",
    quotaFree: true,
  };
}

async function handleFieldChoice(
  session: FlowSession,
  flowId: string,
  message: string,
  quota: { dailyLimit: number; dailyUsed: number },
): Promise<FlowResponse> {
  const lower = message.toLowerCase();

  if (lower.includes("something else") || lower.includes("cancel")) {
    sessions.delete(flowId);
    return fallback(quota);
  }

  if (lower.includes("title") || lower.includes("name") || lower.includes("rename")) {
    session.selectedField = "title";
    session.state = "awaiting_field_value";
    return {
      message: "What should the new **title** be?",
      toolCalls: [],
      remainingQuota: quota.dailyLimit - quota.dailyUsed,
      resetAt: getResetTime(),
      flowId,
      flowState: "awaiting_field_value",
      quotaFree: true,
    };
  }

  if (lower.includes("both")) {
    session.selectedField = "both";
    session.state = "awaiting_field_value";
    return {
      message: "What should the new **title and description** be?",
      toolCalls: [],
      remainingQuota: quota.dailyLimit - quota.dailyUsed,
      resetAt: getResetTime(),
      flowId,
      flowState: "awaiting_field_value",
      quotaFree: true,
    };
  }

  // Description/body selected — ask how they want to edit it
  session.selectedField = "body";
  session.state = "awaiting_edit_mode";

  return {
    message: "How would you like to change the description?",
    toolCalls: [toolCall("present_options", {
      question: "How would you like to change the description?",
      options: ["Add to the end", "Replace entirely", "Update a specific part"],
      icons: ["text.append", "arrow.triangle.2.circlepath", "pencil.and.outline"],
    })],
    remainingQuota: quota.dailyLimit - quota.dailyUsed,
    resetAt: getResetTime(),
    flowId,
    flowState: "awaiting_edit_mode",
    quotaFree: true,
  };
}

async function handleEditModeChoice(
  session: FlowSession,
  flowId: string,
  message: string,
  quota: { dailyLimit: number; dailyUsed: number },
): Promise<FlowResponse> {
  const lower = message.toLowerCase();

  if (lower.includes("add") || lower.includes("append") || lower.includes("end")) {
    session.state = "awaiting_field_value";
    // Store edit mode so handleFieldValue knows to append
    (session as any).editMode = "append";
    return {
      message: "What would you like to add?",
      toolCalls: [],
      remainingQuota: quota.dailyLimit - quota.dailyUsed,
      resetAt: getResetTime(),
      flowId,
      flowState: "awaiting_field_value",
      quotaFree: true,
    };
  }

  if (lower.includes("replace") || lower.includes("entirely") || lower.includes("whole")) {
    session.state = "awaiting_field_value";
    (session as any).editMode = "replace";
    return {
      message: "What should the new description be?",
      toolCalls: [],
      remainingQuota: quota.dailyLimit - quota.dailyUsed,
      resetAt: getResetTime(),
      flowId,
      flowState: "awaiting_field_value",
      quotaFree: true,
    };
  }

  if (lower.includes("specific") || lower.includes("part") || lower.includes("update")) {
    session.state = "awaiting_field_value";
    (session as any).editMode = "specific";
    return {
      message: "Describe what you want to change — e.g. \"change the part about X to say Y\"",
      toolCalls: [],
      remainingQuota: quota.dailyLimit - quota.dailyUsed,
      resetAt: getResetTime(),
      flowId,
      flowState: "awaiting_field_value",
      quotaFree: true,
    };
  }

  // Default to append
  session.state = "awaiting_field_value";
  (session as any).editMode = "append";
  return {
    message: "What would you like to add?",
    toolCalls: [],
    remainingQuota: quota.dailyLimit - quota.dailyUsed,
    resetAt: getResetTime(),
    flowId,
    flowState: "awaiting_field_value",
    quotaFree: true,
  };
}

async function handleFieldValue(
  session: FlowSession,
  flowId: string,
  message: string,
  quota: { dailyLimit: number; dailyUsed: number },
): Promise<FlowResponse> {
  if (!session.selectedItemId) {
    sessions.delete(flowId);
    return fallback(quota);
  }

  const entityType = session.intent.entityType;
  const fn = entityType === "directive" ? "update_directive" : "update_note";
  const args: Record<string, unknown> = { id: session.selectedItemId };

  const editMode = (session as any).editMode as string | undefined;
  let usedAI = false;

  if (session.selectedField === "title") {
    args.title = message.trim().slice(0, LIMITS.directive.title);

  } else if (session.selectedField === "body") {
    // Fetch current body for append/specific modes
    let currentBody = "";
    if (editMode === "append" || editMode === "specific") {
      if (entityType === "directive") {
        const d = await directiveQueries.findById(session.userId, session.selectedItemId!);
        currentBody = (d as Record<string, unknown>)?.body as string ?? "";
      } else {
        const n = await noteQueries.findById(session.userId, session.selectedItemId!);
        currentBody = (n as Record<string, unknown>)?.body as string ?? "";
      }
    }

    if (editMode === "append") {
      // Combine existing + new content
      const newContent = message.trim();
      args.body = currentBody ? `${currentBody}\n\n${newContent}` : newContent;

    } else if (editMode === "specific") {
      // Use AI to apply the specific edit to the existing body
      if (quota.dailyUsed >= quota.dailyLimit) {
        sessions.delete(flowId);
        return {
          message: "You've hit your daily AI limit. Try editing directly in the app.",
          toolCalls: [],
          remainingQuota: 0,
          resetAt: getResetTime(),
        };
      }
      try {
        const edited = await applySpecificEdit(currentBody, message);
        await usageQueries.increment(session.userId);
        usedAI = true;
        args.body = edited;
      } catch {
        // Fallback: just replace
        args.body = message.trim();
      }

    } else {
      // Replace entirely
      args.body = message.trim();
    }

  } else if (session.selectedField === "both") {
    try {
      const result = await generateTitleBody(message, entityType === "note" ? "note" : "directive");
      await usageQueries.increment(session.userId);
      usedAI = true;
      args.title = result.title;
      args.body = result.body;
    } catch {
      args.body = message.trim();
    }
  }

  sessions.delete(flowId);

  const updatedQuota = await getQuota(session.userId);

  return {
    message: `Here are the changes for **${session.selectedItemTitle}**:`,
    toolCalls: [toolCall(fn, args)],
    remainingQuota: updatedQuota.dailyLimit - updatedQuota.dailyUsed,
    resetAt: getResetTime(),
    flowState: "done",
    quotaFree: !usedAI,
  };
}

async function handleRetireChoice(
  session: FlowSession,
  flowId: string,
  message: string,
  quota: { dailyLimit: number; dailyUsed: number },
): Promise<FlowResponse> {
  sessions.delete(flowId);

  if (!session.selectedItemId) return fallback(quota);

  return {
    message: `Retire **${session.selectedItemTitle}**?`,
    toolCalls: [toolCall("retire_directive", { id: session.selectedItemId })],
    remainingQuota: quota.dailyLimit - quota.dailyUsed,
    resetAt: getResetTime(),
    quotaFree: true,
  };
}

// ── AI Content Generation (focused, one-shot) ──

async function generateTitleBody(
  description: string,
  entityType: "directive" | "note",
): Promise<{ title: string; body: string }> {
  if (!openai) throw new Error("OpenAI not configured");

  const prompt = entityType === "directive"
    ? `Generate a short, imperative directive title (max ${LIMITS.directive.title} chars) and a brief body (max ${LIMITS.directive.body} chars) explaining the habit/rule. Return JSON: {"title": "...", "body": "..."}`
    : `Generate a concise note title (max ${LIMITS.note.title} chars) and body content (max ${LIMITS.note.body} chars). Return JSON: {"title": "...", "body": "..."}`;

  const response = await openai.responses.create({
    model: OPENAI_MODEL,
    input: [
      { role: "user", content: `${prompt}\n\nUser's description: "${description}"` },
    ],
    text: { format: { type: "json_object" } },
    max_output_tokens: 256,
  });

  const text = response.output_text;
  const parsed = JSON.parse(text);
  return {
    title: (parsed.title || description.slice(0, 60)).slice(0, LIMITS.directive.title),
    body: (parsed.body || "").slice(0, LIMITS.directive.body),
  };
}

/**
 * Use AI to apply a specific edit instruction to existing text.
 * e.g. currentBody = "Wake up at 6am, meditate", instruction = "change 6am to 7am"
 * → "Wake up at 7am, meditate"
 */
async function applySpecificEdit(currentBody: string, instruction: string): Promise<string> {
  if (!openai) throw new Error("OpenAI not configured");

  const response = await openai.responses.create({
    model: OPENAI_MODEL,
    input: [
      {
        role: "user",
        content: `Apply this edit to the text below. Return ONLY the updated text, nothing else.

Edit instruction: "${instruction}"

Current text:
${currentBody}`,
      },
    ],
    max_output_tokens: 512,
  });

  return response.output_text.trim();
}

// ── Fallback ──

function fallback(quota: { dailyLimit: number; dailyUsed: number }): FlowResponse {
  return {
    message: "",
    toolCalls: [],
    remainingQuota: quota.dailyLimit - quota.dailyUsed,
    resetAt: getResetTime(),
    fallbackToConverse: true,
  };
}
