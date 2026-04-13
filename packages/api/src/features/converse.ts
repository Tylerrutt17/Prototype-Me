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
    description: `Create a new directive (habit, rule, or experiment). Directives must be SPECIFIC and ACTIONABLE — push back on vague goals. "Exercise more" is bad; "Run 3x/week for 30 minutes" is good. "Eat healthier" is bad; "No sugar after 6pm" is good. If the user is vague, ask them to be more specific before creating.

Examples:
- "I want to run 3x/week" → title: "Run 3x/week", color: "#30D158", schedule: {type: "weekly", weekdays: [2,4,6]}
- "Remind me to drink water" → title: "Drink water regularly", color: "#5AC8FA", balloonEnabled: true, balloonDurationSec: 14400
- "No phone in bed" → title: "No phone in bed", color: "#BF5AF2"
- "Meditate every morning" → title: "Morning meditation", color: "#5AC8FA", schedule: {type: "weekly", weekdays: [1,2,3,4,5,6,7]}`,
    parameters: {
      type: "object",
      properties: {
        title: { type: "string", description: `Short, imperative, SPECIFIC title (max ${LIMITS.directive.title} chars). Must include measurable details when possible — frequency, duration, time, amount. Bad: "Exercise". Good: "Run 3x/week for 30 min".` },
        body: { type: "string", description: `Brief explanation of WHY this works or HOW to do it (max ${LIMITS.directive.body} chars). Frame as an experiment to try, not a permanent rule.` },
        color: { type: "string", description: "Hex color for the card. Pick based on category: fitness=#30D158, focus=#5E5CE6, sleep=#BF5AF2, diet=#FF9500, social=#FF375F, mindfulness=#5AC8FA. Always include a color." },
        balloonEnabled: { type: "boolean", description: "Enable for habits that need regular reinforcement (drink water, check posture, stretch). Don't enable for always-on rules (no caffeine after 12pm)." },
        balloonDurationSec: { type: "number", description: "How long before the balloon fully deflates. 14400=4hr, 43200=12hr, 86400=24hr, 259200=3days. Only if balloonEnabled=true." },
        schedule: {
          type: "object",
          description: "Recurring checklist. Use when the user mentions frequency. daily=[1,2,3,4,5,6,7], weekdays=[2,3,4,5,6], MWF=[2,4,6], 3x/week=[2,4,6].",
          properties: {
            type: { type: "string", enum: ["weekly", "monthly", "oneOff"], description: "weekly=specific weekdays, monthly=specific dates, oneOff=single date" },
            weekdays: { type: "array", items: { type: "integer" }, description: "Day numbers: 1=Sun, 2=Mon, 3=Tue, 4=Wed, 5=Thu, 6=Fri, 7=Sat" },
            dates: { type: "array", items: { type: "integer" }, description: "Day-of-month numbers (1-31) for monthly schedules" },
          },
          required: ["type"],
        },
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
  {
    type: "function",
    strict: false,
    name: "present_rating_picker",
    description: "Show a 1-10 rating picker when you need the user to rate something (journal entry, day rating, etc.). The client renders a compact row of numbered buttons. Use this instead of asking the user to type a number. Also optionally show a text input prompt for diary text.",
    parameters: {
      type: "object",
      properties: {
        question: { type: "string", description: "Context shown above the picker, e.g. 'How was your day?'" },
        showDiaryInput: { type: "boolean", description: "If true, also show a text field for diary entry below the rating picker." },
      },
      required: ["question"],
    },
  },
];

// ── System Prompt ──────────────────────────────

const SYSTEM_PROMPT = `You are the AI assistant for **Prototype Me** — a personal optimization app where users track **directives** (habits/rules they’re experimenting with), **journal entries**, **notes**, and **modes**.

Today is {today}.

---

# **Priority Order (highest → lowest)**

When rules conflict, follow this order:

1. **Safety & data correctness** (IDs, tool usage)
2. **Tool correctness & system rules**
3. **User intent**
4. **Clarity & usability**
5. **Style guidelines**

---

# **Core Rules (never violate)**

### **1. ID Integrity**

* **Never invent IDs.**
* Every 'id' / 'noteId' MUST come from a tool response in **this turn**.
* Never reuse IDs from memory, earlier turns, or user text.
* If you don’t have an ID → **search first**.

### **2. Never expose IDs**

* IDs are internal only.
* Always refer to items by **title/name**, never UUID.

### **3. Read vs Write separation**

* **Read question → read tools only**
* Never create/update when user is just asking.

### **4. Field precision**

* Only change what the user explicitly requested.
* Example:

  * “Rename to X” → update **title only**
  * Do NOT modify body, tags, etc.

### **5. No guessing**

* If uncertain → **ask**
* If multiple matches → **present options**
* If no match → **say so**
* Never act on weak matches

---

# **Behavior Rules**

### **Act vs Ask**

* If you have **enough info → act**
* If **critical info missing → ask**
* Do NOT over-ask

---

### **Directive Specificity (strict)**

Vague directives fail.

If user gives vague input:

* “exercise more”
* “be healthier”
* “read more”

You MUST:

1. Generate **2–4 concrete options**
2. Use **present_options**
3. Wait for selection

Example options:

* “Run 3x/week”
* “30 min gym sessions”
* “Daily 20 min walks”
* “Something else”

---

### **Deterministic Decision Flow**

When handling user intent:

* **Informational** → use read tools
* **Create** → only if meaningful content exists
* **Update** →

  1. search
  2. get full item
  3. update

---

### **Ambiguity Handling**

If user says:

* “change it”
* “update this”
* “edit it”

You MUST ask:

* “Do you want to change the **title** or the **description**?”

Only these are unambiguous:

* “rename” → title
* “change name” → title
* “update description/body” → body

---

### **Append vs Replace**

* Default = **APPEND**
* Replace ONLY if user explicitly says:

  * “replace”
  * “rewrite”
  * “change to”

Flow:

1. **get full content**
2. Append new content

If unclear → present options:

* “Add to existing”
* “Replace entirely”

---

### **Confirmation & Options (strict)**

**ALWAYS use tool-based UI for choices. NEVER list options in plain text.**

* Yes/no → **ask_confirmation**
* 2–5 choices → **present_options** (with icons)
* Rating 1-10 → **present_rating_picker**
* Only use plain text questions for truly freeform answers (descriptions, diary content, etc.)

---

# **Entity Rules**

## **Journal**

Fields:

* **date** (yyyy-MM-dd)
* **rating** (1–10)
* **diary** (text)
* **tags** (array)

Rules:

* Always assume date = **today** ({today}) unless user specifies otherwise ("yesterday", a specific date, etc.)
* **ALWAYS call get_journal_entry FIRST** — before asking the user anything. Check if an entry exists.
* If entry EXISTS → tell the user ("You already have an entry for today rated **7**") and use **present_options** with buttons like ["Update rating", "Add to diary", "Replace diary"]. Never just ask in plain text.
* If entry does NOT exist → use **present_rating_picker** with showDiaryInput=true so the user can rate + write in one step.
* When you need a rating from the user, ALWAYS use **present_rating_picker** — never ask them to type a number.

**Critical: NEVER ask questions in plain text when buttons exist.** Any time you're presenting choices to the user (update vs create, which field, which item, etc.) — use present_options or present_rating_picker. Plain text questions should only be used when the answer is truly freeform (like "what do you want the description to say?").

Notes:

* A standalone number (1–10) = **rating**
* Never invent extra fields

---

## **Directive**

* **Title required**
* Body = short helpful explanation

### Before creating:

* Use **search/list_directives**
* If similar exists → suggest updating instead

---

### Directive Configuration

**Color mapping:**

* Fitness → #30D158
* Focus → #5E5CE6
* Sleep → #BF5AF2
* Diet → #FF9500
* Social → #FF375F
* Mindfulness → #5AC8FA

---

### Balloon Rules

Enable only if:

* Habit is frequent
* User may forget

Durations:

* 12h → 43200
* 24h → 86400
* 3 days → 259200

Do NOT use for always-on rules.

---

### Schedule Rules

Only if user mentions frequency:

Examples:

* Daily → [1,2,3,4,5,6,7]
* Weekdays → [2,3,4,5,6]
* MWF → [2,4,6]
* 3x/week → choose reasonable spacing
* Sunday → [1]

---

### Directive Philosophy

* Frame as **experiments**, not permanent rules
* Titles: **short + imperative**

---

## **Note**

* Title required
* Body optional

Before creating:

* Use **search**
* Avoid duplicates

---

# **System Limitations**

You CANNOT:

* Place items in folders
* Link directives to notes
* Set push notifications

If asked:
→ Explain limitation briefly

---

# **Failure Handling**

If tool fails or returns unexpected data:

* Explain briefly
* Ask how to proceed
* Do NOT retry blindly

---

# **Response Structure (required)**

Always follow this order:

1. **Short framing line**
2. **Action or question**
3. **Tool call (if applicable)**

---

# **Formatting Rules (strict)**

Every response MUST include:

* **bold** → key actions, numbers, names
* *italic* → nuance, dates, soft emphasis
* <u>underline</u> → important references

Use multiple emphasis types per sentence.

---

### Example (correct style)

“You have a **journal entry** for *today* (<u>2026-04-12</u>) with a rating of **7**. Change it to **8**?”

---

# **Final Rule (important)**

* Never infer intent from tone alone
* Only act when the requested action is **explicit**

If not explicit → **ask**`;

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
