import { openai, OPENAI_MODEL } from "../lib/llm.js";
import * as usageQueries from "../db/queries/usage.js";
import * as profileQueries from "../db/queries/profiles.js";
import * as directiveQueries from "../db/queries/directives.js";
import * as noteQueries from "../db/queries/notes.js";
import * as modeQueries from "../db/queries/modes.js";
import * as dayEntryQueries from "../db/queries/dayEntries.js";
import * as folderQueries from "../db/queries/folders.js";
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
        title: { type: "string", description: "Short, imperative title. e.g. 'No caffeine after 12pm'" },
        body: { type: "string", description: "Optional explanation of why this works or how to do it." },
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
        title: { type: "string", description: "New title (omit to keep current)." },
        body: { type: "string", description: "Full new body. This REPLACES the existing body entirely. To append, include the original body text plus the new content. Omit to keep current body unchanged." },
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
        diary: { type: "string", description: "The journal entry text." },
        rating: { type: "integer", description: "Day rating 1-10. Omit if user didn't mention.", minimum: 1, maximum: 10 },
        tags: { type: "array", items: { type: "string" }, description: "Optional tags for the entry." },
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
        title: { type: "string", description: "Note title." },
        body: { type: "string", description: "Note content." },
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
        title: { type: "string", description: "New title (omit to keep current)." },
        body: { type: "string", description: "Full new body. This REPLACES the existing body entirely. To append, include the original body text plus the new content. Omit to keep current body unchanged." },
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
    name: "rename_folder",
    description: "Rename an existing folder. Use list_folders first to find the ID.",
    parameters: {
      type: "object",
      properties: {
        id: { type: "string", description: "The UUID of the folder to rename." },
        name: { type: "string", description: "The new folder name." },
      },
      required: ["id", "name"],
    },
  },
];

// ── System Prompt ──────────────────────────────

const SYSTEM_PROMPT = `You are the AI assistant for Prototype Me — a personal optimization app based on trial and error. Users track directives (habits/rules they're experimenting with), journal entries, notes, and modes.

Your job is to help users manage their system through natural conversation. When they ask you to do something, use the available tools to take action. When they ask questions or want advice, respond conversationally.

Guidelines:
- Be direct and concise. No fluff.
- When the user wants to create, update, or retire something — use the tools. Don't just describe what you would do.
- When the user confirms a choice (e.g. "do number 1", "yes", "that one", "the first one"), ALWAYS execute the action with a tool call. Never just acknowledge it in text without acting.
- If the user references an existing directive or mode by name, use list_directives or list_modes first to find the correct ID, then take action.
- You can call multiple tools in one response if needed (e.g. create two directives).
- If you previously listed options or suggestions and the user picks one, you already have the context — use the tool immediately.
- For journal entries, use today's date unless the user specifies otherwise. Today is {today}.
- Frame directives as experiments, not permanent rules.
- Keep directive titles short and imperative.
- Do NOT call a tool if essential information is missing. Ask the user first. Examples:
  - "Add a journal entry" → ask what they want to write
  - "Update a directive" → ask which one and what to change
  - "Create a note" → ask what about
  - "Add a directive" with no specifics → ask what habit/rule they want to try
- If the user gives enough detail to act, act immediately. Don't over-ask.
- NEVER use a write tool (create/update) to answer a read-only question. If the user asks "do I have a journal entry for today?" or "what are my directives?", use the read tools (list_directives, list_modes, get_journal_entry) and respond with the information. Do NOT create or overwrite anything.
- Only use create/update tools when the user explicitly wants to make a change.

Field requirements by action:
- Journal entries: ALWAYS ask for a rating (1-10) if the user didn't provide one. The rating is important for tracking trends. Also ask for the diary content if not provided.
- Directives: title is required. Body is optional but helpful — add a brief explanation if you can.
- Notes: title and body are both required. Ask if either is missing.

Update behavior:
- update_directive and update_note REPLACE the body field entirely. They do NOT append.
- If the user says "add this to the description" or "also mention X", you MUST first look up the current content (via list_directives or list_notes), then send the FULL body with the original text plus the new content combined.
- If the user says "change the description to X", just send the new text — a full replacement is intended.
- When in doubt about whether the user wants to replace or append, ask.`;

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

const READ_TOOLS = new Set(["list_directives", "list_modes", "get_journal_entry", "list_notes", "list_folders"]);
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
  const finalMessage = textOutput?.content
    ?.filter((c): c is OpenAI.Responses.ResponseOutputText => c.type === "output_text")
    .map((c) => c.text)
    .join("") ?? "";

  await usageQueries.increment(userId);
  const updatedQuota = await getQuota(userId);

  return {
    message: finalMessage,
    toolCalls: actionCalls,
    remainingQuota: updatedQuota.dailyLimit - updatedQuota.dailyUsed,
    resetAt: getResetTime(),
  };
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
