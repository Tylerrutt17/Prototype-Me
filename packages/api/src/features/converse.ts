import { openai, OPENAI_MODEL } from "../lib/llm.js";
import * as usageQueries from "../db/queries/usage.js";
import * as profileQueries from "../db/queries/profiles.js";
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
    description: "Create a NEW journal entry for a date that doesn't have one yet. Use get_journal_entry first to confirm no entry exists. If an entry already exists for that date, use update_journal_entry instead.",
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
    name: "update_journal_entry",
    description: "Update specific fields of an EXISTING journal entry. Use get_journal_entry first to confirm an entry exists and see current values. Pass ONLY the fields the user wants to change — omitted fields keep their existing values.",
    parameters: {
      type: "object",
      properties: {
        date: { type: "string", description: "ISO date string yyyy-MM-dd of the entry to update." },
        diary: { type: "string", description: `New diary text (max ${LIMITS.journal.diary} chars). Omit to keep current.` },
        rating: { type: "integer", description: "New day rating 1-10. Omit to keep current.", minimum: 1, maximum: 10 },
        tags: { type: "array", items: { type: "string" }, description: `New tags (max ${LIMITS.journal.tagCount} tags, each max ${LIMITS.journal.tag} chars). Omit to keep current.` },
      },
      required: ["date"],
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
        body: { type: "string", description: `Note content (max ${LIMITS.note.body} chars). Optional — omit or pass empty string if the user hasn't provided content.` },
        kind: { type: "string", enum: ["regular", "mode", "framework", "situation", "goal"], description: "Type of note. Default 'regular'." },
      },
      required: ["title"],
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
    description: "List the user's current directives (body is truncated to a preview). Use get_directive to fetch the full body before editing.",
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
    name: "get_directive",
    description: "Get the full details of a specific directive by ID. Use this before updating a directive to see its complete body — list_directives only shows a preview.",
    parameters: {
      type: "object",
      properties: {
        id: { type: "string", description: "The UUID of the directive." },
      },
      required: ["id"],
    },
  },
  {
    type: "function",
    strict: false,
    name: "get_note",
    description: "Get the full details of a specific note by ID. Use this before updating a note to see its complete body — list_notes only shows a preview.",
    parameters: {
      type: "object",
      properties: {
        id: { type: "string", description: "The UUID of the note." },
      },
      required: ["id"],
    },
  },
  {
    type: "function",
    strict: false,
    name: "list_notes",
    description: "List the user's notes (body is truncated to a preview). Use get_note to fetch the full body before editing. Optionally filter by kind.",
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
  {
    type: "function",
    strict: false,
    name: "ask_confirmation",
    description: "Call this when you need a simple YES/NO answer from the user. The client shows Yes/No buttons. ONLY for strictly binary questions. Do NOT combine with write tools.",
    parameters: {
      type: "object",
      properties: {
        question: { type: "string", description: "The yes/no question to display. Be specific: e.g. 'Change the title from \"Morning\" to \"Morning routine\"?'" },
      },
      required: ["question"],
    },
  },
  {
    type: "function",
    strict: false,
    name: "present_options",
    description: "Show the user a set of tappable option buttons when you need them to pick from specific choices. Use this instead of listing options in text. Max 5 options. The client renders each as a tappable button with an SF Symbol icon. The user's tap sends their choice back as a message.",
    parameters: {
      type: "object",
      properties: {
        question: { type: "string", description: "Brief context shown above the options." },
        options: { type: "array", items: { type: "string" }, description: "2-5 short option labels.", minItems: 2, maxItems: 5 },
        icons: { type: "array", items: { type: "string" }, description: "SF Symbol names matching each option. e.g. ['pencil', 'doc.text', 'trash']. Must be same length as options." },
      },
      required: ["question", "options"],
    },
  },
];

// ── System Prompt ──────────────────────────────

const SYSTEM_PROMPT = `You are the AI assistant for Prototype Me — a personal optimization app where users track directives (habits/rules they're experimenting with), journal entries, notes, and modes.

Today is {today}.

# Hard rules (never violate)
1. **Never invent IDs.** Every id/noteId passed to a write tool MUST come from a tool response (search, list_*, get_*) in THIS turn. Never infer IDs from user text, chat history, or earlier turns — they may be stale or fabricated. If you don't have a fresh ID, call search first.
2. **Never show IDs to the user.** IDs are internal — use them in tool calls only. When referring to items in your message text, use their **title or name**, never the UUID.
3. **Never use write tools to answer read questions.** "Do I have a journal for today?" / "What are my directives?" → answer with read tools only. Do not create, update, or overwrite.
4. **Never change fields the user didn't mention.** "Rename to X" = title only. Leave body, rating, tags, and other fields alone.
5. **Never act on ambiguous or weak matches.** A match is only strong if the name is exact or near-exact. Multiple candidates → list them and ask. Weak match → ask. Zero matches → say so.

# Behavior
- When the user provides enough detail to fill in the required fields — call the tool. Don't describe what you would do; do it.
- **Never call a create tool with empty or placeholder content.** If the user says "add a note" or "create a journal entry" without saying what it should contain, ask what they want in it first. Every created item must have meaningful content — at minimum a title (directives, notes) or diary text + rating (journal).
- When the user confirms a choice ("yes", "do number 1", "that one") — use the candidate(s) from the most recent tool result in this turn. Don't guess or reinterpret.
- You can call multiple tools in one response.
- To find an item by name: use **search** (fuzzy match across directives, notes, folders). Use list_* only for "show me all" requests.
- If essential info is missing, ask. If you have enough, act — don't over-ask.
- **Ambiguous updates require clarification.** If the user says "change it to X" or "can you update this" without specifying which field (title vs body), ALWAYS ask: "Do you want to change the title or the description?" Never guess. Only these keywords are unambiguous: "rename" / "change the name" = title. "Update the description" / "change the body" = body. Everything else → ask.
- If a tool call fails or returns empty/unexpected data, explain briefly and ask the user how to proceed. Do not retry blindly.
- **When you need a binary yes/no answer before acting, use the ask_confirmation tool.** The client shows Yes/No buttons the user can tap.
- **When you need the user to pick from 2-5 options, use present_options.** The client shows each option as a tappable button — much faster than asking in plain text. Use this for: which field to edit, append vs replace, picking between similar items, choosing a date, etc.
- **Always include a brief message when calling tools.** The client shows your message above the action cards. Never return tool calls with an empty message — always add a short line like "Here's what I'd suggest:" or "I've got a few options:" so the user has context.

# Update semantics
- update_directive and update_note REPLACE the body entirely — the API does NOT append.
- **Before any update**, call **get_directive** or **get_note** to fetch the full current body. List tools only show a truncated preview — you MUST have the full content to avoid losing data.
- **Default to APPEND.** When a user says "update", "edit", "add to", or provides new content for an existing item, they almost always mean ADD to what's there. Fetch the full body first, then combine: original text + new content.
- Only REPLACE when the user explicitly says "change to", "replace with", "make it say", or "rewrite".
- If genuinely unclear, use **present_options** to ask: e.g. options ["Add to existing description", "Replace the entire description"].

# Field requirements
- **Journal**: entries have only these fields — **date** (yyyy-MM-dd, no time), **rating** (1-10), **diary** (text), **tags** (array). There is NO time field, no hour/minute, no location, no mood enum, no anything else. Never ask about fields that don't exist.
  - Always call **get_journal_entry** first to check if an entry exists for that date.
  - If an entry EXISTS → use **update_journal_entry** with only the fields the user wants to change. Unspecified fields keep their existing values.
  - If NO entry exists → use **create_journal_entry** with diary content. If the user didn't provide diary text AND a rating, ask before creating. Never create an empty journal entry.
  - A bare number 1-10 in journal context is a **rating**, not a time.
- **Directive**: title required; body is a brief helpful explanation if you can write one. If the user says "add a directive" without specifying what it's about, ask what they want to work on.
  - **Before suggesting new directives**, use **search** or **list_directives** to check what the user already has. If they have something similar, mention it ("You already have a directive for that — want to update it instead?"). Only suggest new ones if nothing relevant exists.
- **Note**: title required; body is optional. If the user says "add a note" without specifying content, ask what the note should be about.
  - Similarly, use **search** before creating notes to avoid duplicates.

# What you can't do
- **You cannot place items in folders or link directives to notes.** If the user asks to add something to a specific folder or note, create the item normally and let them know: "I've created it — you can move it to the right folder in the Library tab."
- **You cannot set reminders, notifications, or schedules.** If asked, let them know they can set those up in the directive's detail screen.

**Never invent fields or options that aren't defined in a tool's parameters.** If a tool doesn't have a field, don't offer it to the user.

# Response formatting (required)
Every response you write MUST use inline formatting to emphasize meaningful words. Plain unformatted text is not acceptable — add emphasis wherever it helps the meaning land.

Formatting options:
- **bold** — for key concepts, actions, names, numbers, and important phrases (renders in the accent color)
- *italic* — for qualifiers, nuance, dates, softer emphasis
- <u>underline</u> — for specific terms, references, or things the user should notice

Target: multiple emphasized words/phrases per sentence. Mix all three formats.

Example:
- Bad: "There is a journal entry for tomorrow (2026-04-05) with a current rating of 8. You want to change it to 7, correct?"
- Good: "You have a **journal entry** for *tomorrow* (<u>2026-04-05</u>) with a current rating of **8**. Change it to **7**?"

# Style
- Direct and concise. No fluff.
- Frame directives as experiments, not permanent rules.
- Directive titles: short and imperative.`;

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

interface ReadToolRequest {
  callId: string;
  function: string;
  arguments: Record<string, unknown>;
}

export interface ConverseResult {
  message: string;
  toolCalls: ToolCall[];
  remainingQuota: number;
  resetAt: string;
  /** Read tool requests for the client to execute locally, then call back with results */
  readToolRequests: ReadToolRequest[];
  /** OpenAI response ID — client sends this back for continuation after executing reads */
  responseId: string;
}

// ── Converse ───────────────────────────────────

const READ_TOOLS = new Set(["list_directives", "list_modes", "get_journal_entry", "get_directive", "get_note", "list_notes", "list_folders", "search"]);

export async function converse(
  userId: string,
  messages: ConversationMessage[],
  localDate?: string,
  previousResponseId?: string,
  toolOutputs?: { callId: string; output: string }[],
): Promise<ConverseResult> {
  const isContinuation = !!previousResponseId;

  // Quota check only on fresh turns (not continuations)
  if (!isContinuation) {
    const quota = await getQuota(userId);
    if (quota.dailyUsed >= quota.dailyLimit) {
      throw { status: 429, error: "quota_exceeded", message: "Daily AI quota exceeded" };
    }
  }

  if (!openai) {
    throw { status: 500, error: "not_configured", message: "OpenAI API key not configured" };
  }

  let response: OpenAI.Responses.Response;

  if (isContinuation && previousResponseId && toolOutputs) {
    // Continuation: feed client-executed read results back to the AI
    const inputs: OpenAI.Responses.ResponseInputItem[] = toolOutputs.map((to) => ({
      type: "function_call_output" as const,
      call_id: to.callId,
      output: to.output,
    }));
    response = await openai.responses.create({
      model: OPENAI_MODEL,
      previous_response_id: previousResponseId,
      input: inputs,
      tools,
      max_output_tokens: 1024,
    });
  } else {
    // Fresh turn: build system prompt + conversation
    const today = localDate || new Date().toISOString().split("T")[0]!;
    const systemContext = SYSTEM_PROMPT.replace("{today}", today);

    const input: OpenAI.Responses.ResponseInputItem[] = [
      { role: "user", content: systemContext },
      { role: "assistant", content: "Understood. I'm ready to help." },
      ...messages.map((m) => ({
        role: m.role as "user" | "assistant",
        content: m.content,
      })),
    ];

    response = await openai.responses.create({
      model: OPENAI_MODEL,
      input,
      tools,
      max_output_tokens: 1024,
    });
  }

  // Partition function calls into reads vs writes
  const functionCalls = response.output.filter(
    (item): item is OpenAI.Responses.ResponseFunctionToolCall => item.type === "function_call",
  );

  const readCalls = functionCalls.filter((fc) => READ_TOOLS.has(fc.name));
  const writeCalls = functionCalls.filter((fc) => !READ_TOOLS.has(fc.name));

  // If there are read calls, return them to the client for local execution
  if (readCalls.length > 0) {
    const quota = await getQuota(userId);
    return {
      message: "",
      toolCalls: [],
      readToolRequests: readCalls.map((fc) => ({
        callId: fc.call_id,
        function: fc.name,
        arguments: JSON.parse(fc.arguments),
      })),
      responseId: response.id,
      remainingQuota: quota.dailyLimit - quota.dailyUsed,
      resetAt: getResetTime(),
    };
  }

  // No read calls — turn is complete. Extract final message + write tool calls.
  const textOutput = response.output.find(
    (item): item is OpenAI.Responses.ResponseOutputMessage => item.type === "message",
  );
  const finalMessage = textOutput?.content
    ?.filter((c): c is OpenAI.Responses.ResponseOutputText => c.type === "output_text")
    .map((c) => c.text)
    .join("") ?? "";

  const actionCalls: ToolCall[] = writeCalls.map((fc) => ({
    id: fc.call_id,
    function: fc.name,
    arguments: JSON.parse(fc.arguments),
  }));

  // Increment usage only on fresh turns
  if (!isContinuation) {
    await usageQueries.increment(userId);
  }
  const updatedQuota = await getQuota(userId);

  return {
    message: finalMessage,
    toolCalls: actionCalls,
    readToolRequests: [],
    responseId: response.id,
    remainingQuota: updatedQuota.dailyLimit - updatedQuota.dailyUsed,
    resetAt: getResetTime(),
  };
}

// ── Helpers ────────────────────────────────────

function getResetTime(): string {
  const tomorrow = new Date();
  tomorrow.setUTCHours(0, 0, 0, 0);
  tomorrow.setUTCDate(tomorrow.getUTCDate() + 1);
  return tomorrow.toISOString();
}
