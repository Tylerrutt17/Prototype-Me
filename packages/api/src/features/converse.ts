import { openai, OPENAI_MODEL } from "../lib/llm.js";
import * as usageQueries from "../db/queries/usage.js";
import * as profileQueries from "../db/queries/profiles.js";
import * as directiveQueries from "../db/queries/directives.js";
import * as noteQueries from "../db/queries/notes.js";
import * as modeQueries from "../db/queries/modes.js";
import * as dayEntryQueries from "../db/queries/dayEntries.js";
import * as folderQueries from "../db/queries/folders.js";
import * as searchQueries from "../db/queries/search.js";
import { LIMITS } from "../validation/limits.js";
import type OpenAI from "openai";

// ── Quota ──────────────────────────────────────

const FREE_DAILY_LIMIT = 5;
const PRO_DAILY_LIMIT = 100;

async function getQuota(userId: string) {
  const user = await profileQueries.findById(userId);
  const dailyLimit = user?.plan === "pro" ? PRO_DAILY_LIMIT : FREE_DAILY_LIMIT;
  const usage = await usageQueries.getToday(userId);
  return { dailyLimit, dailyUsed: usage?.count ?? 0 };
}

// ── Tool Definitions (Responses API format) ────

const tools: OpenAI.Responses.Tool[] = [
  {
    type: "function",
    strict: false,
    name: "create_directive",
    description: "Create a new directive (habit, rule, or experiment) for the user to follow.",
    parameters: {
      type: "object",
      properties: {
        title: { type: "string", description: `Short, imperative title (max ${LIMITS.directive.title} chars). e.g. 'No caffeine after 12pm'` },
        body: { type: "string", description: `Optional explanation of why this works or how to do it (max ${LIMITS.directive.body} chars).` },
      },
      required: ["title"],
    },
  },
  {
    type: "function",
    strict: false,
    name: "update_directive",
    description: "Update an existing directive's title or body. Use list_directives first to find the directive ID. IMPORTANT: The body field REPLACES the entire body. If the user wants to ADD to the existing body, you must include the original text plus the new content.",
    parameters: {
      type: "object",
      properties: {
        id: { type: "string", description: "The UUID of the directive to update." },
        title: { type: "string", description: `New title (max ${LIMITS.directive.title} chars). Omit to keep current.` },
        body: { type: "string", description: `Full new body (max ${LIMITS.directive.body} chars). This REPLACES the existing body entirely. To append, include the original body text plus the new content. Omit to keep current body unchanged.` },
      },
      required: ["id"],
    },
  },
  {
    type: "function",
    strict: false,
    name: "retire_directive",
    description: "Archive/retire a directive the user no longer wants to follow.",
    parameters: {
      type: "object",
      properties: {
        id: { type: "string", description: "The UUID of the directive to retire." },
      },
      required: ["id"],
    },
  },
  {
    type: "function",
    strict: false,
    name: "create_journal_entry",
    description: "Create or update a journal/diary entry for a given date.",
    parameters: {
      type: "object",
      properties: {
        date: { type: "string", description: "ISO date string yyyy-MM-dd. Use today if not specified." },
        diary: { type: "string", description: `The journal entry text (max ${LIMITS.journal.diary} chars).` },
        rating: { type: "integer", description: "Day rating 1-10. Omit if user didn't mention.", minimum: 1, maximum: 10 },
        tags: { type: "array", items: { type: "string" }, description: `Optional tags for the entry (max ${LIMITS.journal.tagCount} tags, each max ${LIMITS.journal.tag} chars).` },
      },
      required: ["date", "diary"],
    },
  },
  {
    type: "function",
    strict: false,
    name: "create_note",
    description: "Create a note (regular note, mode, framework, situation, or goal).",
    parameters: {
      type: "object",
      properties: {
        title: { type: "string", description: `Note title (max ${LIMITS.note.title} chars).` },
        body: { type: "string", description: `Note content (max ${LIMITS.note.body} chars).` },
        kind: { type: "string", enum: ["regular", "mode", "framework", "situation", "goal"], description: "Type of note. Default 'regular'." },
      },
      required: ["title", "body"],
    },
  },
  {
    type: "function",
    strict: false,
    name: "activate_mode",
    description: "Activate a mode. Use list_modes first to find the note ID.",
    parameters: {
      type: "object",
      properties: {
        noteId: { type: "string", description: "The UUID of the mode note to activate." },
      },
      required: ["noteId"],
    },
  },
  {
    type: "function",
    strict: false,
    name: "deactivate_mode",
    description: "Deactivate a currently active mode.",
    parameters: {
      type: "object",
      properties: {
        noteId: { type: "string", description: "The UUID of the mode note to deactivate." },
      },
      required: ["noteId"],
    },
  },
  {
    type: "function",
    strict: false,
    name: "list_directives",
    description: "List the user's current directives. Use this to look up directive IDs before updating or retiring.",
    parameters: {
      type: "object",
      properties: {
        status: { type: "string", enum: ["active", "archived"], description: "Filter by status. Default 'active'." },
      },
    },
  },
  {
    type: "function",
    strict: false,
    name: "list_modes",
    description: "List available modes (notes with kind='mode') and which are currently active. Use this before activating/deactivating.",
    parameters: {
      type: "object",
      properties: {},
    },
  },
  {
    type: "function",
    strict: false,
    name: "get_journal_entry",
    description: "Look up a journal entry for a specific date. Use this to CHECK if an entry exists before creating/updating. Returns the entry if it exists, or null.",
    parameters: {
      type: "object",
      properties: {
        date: { type: "string", description: "ISO date string yyyy-MM-dd." },
      },
      required: ["date"],
    },
  },
  {
    type: "function",
    strict: false,
    name: "list_notes",
    description: "List the user's notes. Optionally filter by kind. Use to look up note IDs before updating.",
    parameters: {
      type: "object",
      properties: {
        kind: { type: "string", enum: ["regular", "mode", "framework", "situation", "goal"], description: "Filter by note type. Omit for all." },
      },
    },
  },
  {
    type: "function",
    strict: false,
    name: "update_note",
    description: "Update an existing note's title or body. Use list_notes first to find the ID. IMPORTANT: The body field REPLACES the entire body. If the user wants to ADD to the existing body, you must include the original text plus the new content.",
    parameters: {
      type: "object",
      properties: {
        id: { type: "string", description: "The UUID of the note to update." },
        title: { type: "string", description: `New title (max ${LIMITS.note.title} chars). Omit to keep current.` },
        body: { type: "string", description: `Full new body (max ${LIMITS.note.body} chars). This REPLACES the existing body entirely. To append, include the original body text plus the new content. Omit to keep current body unchanged.` },
      },
      required: ["id"],
    },
  },
  {
    type: "function",
    strict: false,
    name: "list_folders",
    description: "List the user's folders. Use to look up folder IDs before renaming.",
    parameters: {
      type: "object",
      properties: {},
    },
  },
  {
    type: "function",
    strict: false,
    name: "search",
    description: "Fuzzy search across directives, notes, and folders by name. Returns the closest matches ranked by similarity. Use this instead of listing everything when the user references something by name.",
    parameters: {
      type: "object",
      properties: {
        query: { type: "string", description: "The name or partial name to search for." },
      },
      required: ["query"],
    },
  },
  {
    type: "function",
    strict: false,
    name: "rename_folder",
    description: "Rename an existing folder. Use list_folders first to find the ID.",
    parameters: {
      type: "object",
      properties: {
        id: { type: "string", description: "The UUID of the folder to rename." },
        name: { type: "string", description: `The new folder name (max ${LIMITS.folder.name} chars).` },
      },
      required: ["id", "name"],
    },
  },
];

// ── System Prompt ──────────────────────────────

const SYSTEM_PROMPT = `You are the AI assistant for Prototype Me — a personal optimization app where users track directives (habits/rules they're experimenting with), journal entries, notes, and modes.

Today is {today}.

# Hard rules (never violate)
1. **Never invent IDs.** Every id/noteId passed to a write tool MUST come from a tool response (search, list_*, get_*) in THIS turn. Never infer IDs from user text, chat history, or earlier turns — they may be stale or fabricated. If you don't have a fresh ID, call search first.
2. **Never use write tools to answer read questions.** "Do I have a journal for today?" / "What are my directives?" → answer with read tools only. Do not create, update, or overwrite.
3. **Never change fields the user didn't mention.** "Rename to X" = title only. Leave body, rating, tags, and other fields alone.
4. **Never act on ambiguous or weak matches.** A match is only strong if the name is exact or near-exact. Multiple candidates → list them and ask. Weak match → ask. Zero matches → say so.

# Behavior
- When the user wants to create, update, or retire something — call the tool. Don't describe what you would do; do it.
- When the user confirms a choice ("yes", "do number 1", "that one") — use the candidate(s) from the most recent tool result in this turn. Don't guess or reinterpret.
- You can call multiple tools in one response.
- To find an item by name: use **search** (fuzzy match across directives, notes, folders). Use list_* only for "show me all" requests.
- If essential info is missing, ask. If you have enough, act — don't over-ask.
- Ambiguous "update X" (title vs body unclear)? Ask which field. "Rename" = title. "Update the description" = body.
- If a tool call fails or returns empty/unexpected data, explain briefly and ask the user how to proceed. Do not retry blindly.

# Update semantics
- update_directive and update_note REPLACE the body entirely — they do NOT append.
- "Add this to the description" / "also mention X" → look up the current body FIRST, then send original text + new content combined.
- "Change the description to X" → send just the new text.
- Unsure whether user wants replace or append? Ask.

# Field requirements
- **Journal**: always call get_journal_entry first. If one exists, change only the fields the user mentioned. If new, ask for a rating (1-10) and diary content if missing.
- **Directive**: title required; body is a brief helpful explanation if you can write one.
- **Note**: title and body both required — ask if either is missing.

# Style
- Direct and concise. No fluff.
- Frame directives as experiments, not permanent rules.
- Directive titles: short and imperative.
- You may use inline markdown for emphasis in your responses: **bold** for key concepts or callouts (renders in the accent color), *italic* for subtle emphasis. Use sparingly — 1-2 emphasized phrases per response, not every other word.`;

// ── Types ──────────────────────────────────────

export interface ConversationMessage {
  role: "user" | "assistant";
  content: string;
}

export interface ToolCall {
  id: string;
  function: string;
  arguments: Record<string, unknown>;
}

export interface ConverseResult {
  message: string;
  toolCalls: ToolCall[];
  remainingQuota: number;
  resetAt: string;
}

// ── Converse ───────────────────────────────────

const READ_TOOLS = new Set(["list_directives", "list_modes", "get_journal_entry", "list_notes", "list_folders", "search"]);
const MAX_TOOL_ROUNDS = 3;

export async function converse(
  userId: string,
  messages: ConversationMessage[],
): Promise<ConverseResult> {
  const quota = await getQuota(userId);
  if (quota.dailyUsed >= quota.dailyLimit) {
    throw { status: 429, error: "quota_exceeded", message: "Daily AI quota exceeded" };
  }

  if (!openai) {
    throw { status: 500, error: "not_configured", message: "OpenAI API key not configured" };
  }

  const today = new Date().toISOString().split("T")[0];
  const systemContext = SYSTEM_PROMPT.replace("{today}", today);

  // Build input — system prompt as first user message, then conversation
  const input: OpenAI.Responses.ResponseInputItem[] = [
    { role: "user", content: systemContext },
    { role: "assistant", content: "Understood. I'm ready to help." },
    ...messages.map((m) => ({
      role: m.role as "user" | "assistant",
      content: m.content,
    })),
  ];

  // Loop: call model, resolve read-only tools server-side, repeat until done
  let response = await openai.responses.create({
    model: OPENAI_MODEL,

    input,
    tools,
    max_output_tokens: 1024,
  });

  let actionCalls: ToolCall[] = [];
  let rounds = 0;

  while (rounds < MAX_TOOL_ROUNDS) {
    rounds++;
    const functionCalls = response.output.filter(
      (item): item is OpenAI.Responses.ResponseFunctionToolCall => item.type === "function_call",
    );

    if (functionCalls.length === 0) break;

    const readCalls = functionCalls.filter((fc) => READ_TOOLS.has(fc.name));
    const writes = functionCalls.filter((fc) => !READ_TOOLS.has(fc.name));

    // Collect action calls for iOS
    for (const fc of writes) {
      actionCalls.push({
        id: fc.call_id,
        function: fc.name,
        arguments: JSON.parse(fc.arguments),
      });
    }

    // If no read calls, we're done
    if (readCalls.length === 0) break;

    // Execute read calls server-side and feed results back
    const toolOutputs: OpenAI.Responses.ResponseInputItem[] = [];
    for (const fc of readCalls) {
      const result = await executeReadCall(userId, fc.name, fc.arguments);
      // Feed back the function call and its result
      toolOutputs.push({
        type: "function_call_output",
        call_id: fc.call_id,
        output: result,
      } as OpenAI.Responses.ResponseInputItem);
    }

    // Continue the conversation with tool results
    response = await openai.responses.create({
      model: OPENAI_MODEL,
  
      previous_response_id: response.id,
      input: toolOutputs,
      tools,
      max_output_tokens: 1024,
    });
  }

  // Extract final text message
  const textOutput = response.output.find(
    (item): item is OpenAI.Responses.ResponseOutputMessage => item.type === "message",
  );
  let finalMessage = textOutput?.content
    ?.filter((c): c is OpenAI.Responses.ResponseOutputText => c.type === "output_text")
    .map((c) => c.text)
    .join("") ?? "";

  // Validate that any IDs referenced in write tool calls actually exist.
  // The model sometimes hallucinates UUIDs; drop those tool calls so the client
  // doesn't try to execute against a non-existent item.
  const { validCalls, droppedSummaries } = await validateActionIds(userId, actionCalls);
  actionCalls = validCalls;
  if (droppedSummaries.length > 0) {
    const note = droppedSummaries.length === 1
      ? `I couldn't find ${droppedSummaries[0]} — could you clarify which one you mean?`
      : `I couldn't find: ${droppedSummaries.join(", ")}. Could you clarify?`;
    finalMessage = finalMessage ? `${finalMessage}\n\n${note}` : note;
  }

  await usageQueries.increment(userId);
  const updatedQuota = await getQuota(userId);

  return {
    message: finalMessage,
    toolCalls: actionCalls,
    remainingQuota: updatedQuota.dailyLimit - updatedQuota.dailyUsed,
    resetAt: getResetTime(),
  };
}

async function validateActionIds(
  userId: string,
  calls: ToolCall[],
): Promise<{ validCalls: ToolCall[]; droppedSummaries: string[] }> {
  const validCalls: ToolCall[] = [];
  const droppedSummaries: string[] = [];

  for (const call of calls) {
    const args = call.arguments as Record<string, unknown>;
    let valid = true;
    let droppedLabel: string | null = null;

    if (call.function === "update_directive" || call.function === "retire_directive") {
      const id = typeof args.id === "string" ? args.id : null;
      if (!id || !(await directiveQueries.findById(userId, id))) {
        valid = false;
        droppedLabel = "that directive";
      }
    } else if (call.function === "update_note") {
      const id = typeof args.id === "string" ? args.id : null;
      if (!id || !(await noteQueries.findById(userId, id))) {
        valid = false;
        droppedLabel = "that note";
      }
    } else if (call.function === "activate_mode" || call.function === "deactivate_mode") {
      const id = typeof args.noteId === "string" ? args.noteId : null;
      if (!id || !(await noteQueries.findById(userId, id))) {
        valid = false;
        droppedLabel = "that mode";
      }
    } else if (call.function === "rename_folder") {
      const id = typeof args.id === "string" ? args.id : null;
      if (!id || !(await folderQueries.findById(userId, id))) {
        valid = false;
        droppedLabel = "that folder";
      }
    }

    if (valid) {
      validCalls.push(call);
    } else if (droppedLabel) {
      droppedSummaries.push(droppedLabel);
    }
  }

  return { validCalls, droppedSummaries };
}

// ── Helpers ────────────────────────────────────

async function executeReadCall(userId: string, name: string, argsJson: string): Promise<string> {
  const args = JSON.parse(argsJson);

  if (name === "list_directives") {
    const directives = await directiveQueries.findAll(userId, { status: args.status ?? "active" });
    return JSON.stringify(
      directives.map((d: Record<string, unknown>) => ({
        id: d.id,
        title: d.title,
        body: d.body,
        status: d.status,
      })),
    );
  }

  if (name === "list_modes") {
    const modes = await noteQueries.findAll(userId, { kind: "mode" });
    const activeModes = await modeQueries.findAll(userId);
    const activeNoteIds = new Set(activeModes.map((m: Record<string, unknown>) => m.noteId));
    return JSON.stringify(
      modes.map((n: Record<string, unknown>) => ({
        id: n.id,
        title: n.title,
        active: activeNoteIds.has(n.id as string),
      })),
    );
  }

  if (name === "list_notes") {
    const filters: Record<string, string> = {};
    if (args.kind) filters.kind = args.kind;
    const notes = await noteQueries.findAll(userId, filters);
    return JSON.stringify(
      notes.map((n: Record<string, unknown>) => ({
        id: n.id,
        title: n.title,
        body: n.body,
        kind: n.kind,
      })),
    );
  }

  if (name === "search") {
    const results = await searchQueries.fuzzySearch(userId, args.query, 10);
    return JSON.stringify(results.map((r) => ({
      id: r.id,
      type: r.type,
      title: r.title,
      body: r.body,
      kind: r.kind,
      status: r.status,
      similarity: Math.round(r.similarity * 100) + "%",
    })));
  }

  if (name === "list_folders") {
    const folders = await folderQueries.findAll(userId);
    return JSON.stringify(
      folders.map((f: Record<string, unknown>) => ({
        id: f.id,
        name: f.name,
      })),
    );
  }

  if (name === "get_journal_entry") {
    const entries = await dayEntryQueries.findAll(userId, { from: args.date, to: args.date });
    if (entries.length === 0) return JSON.stringify({ exists: false });
    const e = entries[0] as Record<string, unknown>;
    return JSON.stringify({
      exists: true,
      id: e.id,
      date: e.date,
      diary: e.diary,
      rating: e.rating,
      tags: e.tags,
    });
  }

  return "{}";
}

function getResetTime(): string {
  const tomorrow = new Date();
  tomorrow.setUTCHours(0, 0, 0, 0);
  tomorrow.setUTCDate(tomorrow.getUTCDate() + 1);
  return tomorrow.toISOString();
}
