/**
 * AI-powered intent classification.
 *
 * One lightweight, focused AI call to classify user intent and extract
 * search terms. No regex — the AI handles all the natural language
 * interpretation, then the flow engine takes over deterministically.
 */

import { openai, OPENAI_MODEL } from "../lib/llm.js";

export interface MatchedIntent {
  intent:
    | "create_directive"
    | "create_note"
    | "create_journal"
    | "update"
    | "journal_log"
    | "journal_update"
    | "activate_mode"
    | "deactivate_mode"
    | "retire"
    | "list"
    | "freeform";
  entityType?: "directive" | "note" | "journal" | "mode" | "folder";
  /** Search terms extracted from the user's message (cleaned up, not the raw message) */
  searchQuery?: string;
  /** Any content the user already provided inline */
  contentHint?: string;
}

const CLASSIFICATION_PROMPT = `Classify the user's intent for a personal optimization app. The app has:
- Directives (habits/rules to follow)
- Notes (regular, mode, framework, situation, goal)
- Journal entries (daily diary + rating 1-10)
- Modes (activate/deactivate)

Return JSON with these fields:
- "intent": one of: "create_directive", "create_note", "journal_log", "journal_update", "update", "retire", "activate_mode", "deactivate_mode", "list", "freeform"
- "entityType": one of: "directive", "note", "journal", "mode", "folder", or null
- "searchQuery": extracted search keywords to find the item they're referring to (short, cleaned — NOT the full message). null if creating something new or no specific item referenced.
- "contentHint": any content/description the user provided for what they want to create or change. null if none.

Rules:
- "freeform" = conversational question, advice seeking, or anything that doesn't map to a specific action
- "journal_log" = creating/logging a new journal entry. "journal_update" = editing an existing one.
- "update" = editing an existing directive, note, or folder (title, body, or both)
- "retire" = archiving/deleting a directive
- For searchQuery: extract just the key identifying words. "the directive about going to bed early" → "going to bed early". "my morning routine note" → "morning routine".
- If the user says something like "change the lights out directive", searchQuery should be "lights out", NOT "the lights out directive"
- If the user describes what they want to create, put that in contentHint, not searchQuery

Return ONLY the JSON object, no other text.`;

/**
 * Classify user intent using a lightweight AI call.
 * Returns null only if the AI call fails entirely.
 */
export async function classifyIntent(message: string): Promise<MatchedIntent | null> {
  if (!openai) return null;

  try {
    const response = await openai.responses.create({
      model: OPENAI_MODEL,
      input: [
        { role: "user", content: `${CLASSIFICATION_PROMPT}\n\nUser message: "${message}"` },
      ],
      text: { format: { type: "json_object" } },
      max_output_tokens: 150,
    });

    const parsed = JSON.parse(response.output_text);

    const validIntents = new Set([
      "create_directive", "create_note", "create_journal", "journal_log",
      "journal_update", "update", "retire", "activate_mode", "deactivate_mode",
      "list", "freeform",
    ]);

    const intent = validIntents.has(parsed.intent) ? parsed.intent : "freeform";

    return {
      intent,
      entityType: parsed.entityType || undefined,
      searchQuery: parsed.searchQuery || undefined,
      contentHint: parsed.contentHint || undefined,
    };
  } catch (err) {
    console.error("[Flow] Intent classification failed:", err);
    return null;
  }
}
