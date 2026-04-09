/**
 * Deterministic intent matching via keyword/regex patterns.
 * Returns a structured intent if matched, or null to fall back to AI classification.
 */

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
  /** Extracted search terms for finding existing items */
  searchQuery?: string;
  /** Any content the user already provided inline */
  contentHint?: string;
}

// ── Patterns ──

interface Pattern {
  regex: RegExp;
  intent: MatchedIntent["intent"];
  entityType?: MatchedIntent["entityType"];
  /** Named capture groups to extract */
  extractSearch?: string; // capture group name for searchQuery
  extractContent?: string; // capture group name for contentHint
}

const patterns: Pattern[] = [
  // ── Journal ──
  {
    regex: /\b(log|rate|record)\s+(my\s+)?(day|today|yesterday|the day)\b/i,
    intent: "journal_log",
    entityType: "journal",
  },
  {
    regex: /\b(add|write|create|make|new)\s+(a\s+)?(journal|diary|day)\s*(entry)?\b/i,
    intent: "journal_log",
    entityType: "journal",
  },
  {
    regex: /\bhow was (my|your|the) day\b/i,
    intent: "journal_log",
    entityType: "journal",
  },
  {
    regex: /\b(update|change|edit)\s+(my\s+)?(journal|diary|day)\s*(entry)?\b/i,
    intent: "journal_update",
    entityType: "journal",
  },

  // ── Create Directive ──
  {
    regex: /\b(add|create|make|new|suggest)\s+(a\s+)?(directive|habit|rule|experiment)s?\s*(about|for|to|called|named)?\s*(?<search>.+)?/i,
    intent: "create_directive",
    entityType: "directive",
    extractSearch: "search",
  },
  {
    regex: /\bsuggest\s+(some\s+)?directives?\b/i,
    intent: "create_directive",
    entityType: "directive",
  },
  {
    regex: /\bi\s+(want|need)\s+(a\s+)?(new\s+)?(directive|habit|rule)\b/i,
    intent: "create_directive",
    entityType: "directive",
  },

  // ── Create Note ──
  {
    regex: /\b(add|create|make|new)\s+(a\s+)?(note|mode|framework|situation)\s*(about|for|to|called|named)?\s*(?<search>.+)?/i,
    intent: "create_note",
    entityType: "note",
    extractSearch: "search",
  },

  // ── Update (generic — entity type determined by search) ──
  {
    regex: /\b(update|change|edit|modify|rename|fix)\s+(my\s+|the\s+)?(?<search>.+)/i,
    intent: "update",
    extractSearch: "search",
  },
  {
    regex: /\b(add\s+to|append\s+to)\s+(my\s+|the\s+)?(?<search>.+)/i,
    intent: "update",
    extractSearch: "search",
  },

  // ── Retire / Delete ──
  {
    regex: /\b(retire|archive|delete|remove)\s+(my\s+|the\s+)?(directive|habit|rule)\s*(?<search>.+)?/i,
    intent: "retire",
    entityType: "directive",
    extractSearch: "search",
  },

  // ── Modes ──
  {
    regex: /\b(activate|turn on|enable|start)\s+(my\s+|the\s+)?(?<search>.+)\s*mode\b/i,
    intent: "activate_mode",
    entityType: "mode",
    extractSearch: "search",
  },
  {
    regex: /\b(deactivate|turn off|disable|stop)\s+(my\s+|the\s+)?(?<search>.+)\s*mode\b/i,
    intent: "deactivate_mode",
    entityType: "mode",
    extractSearch: "search",
  },

  // ── List ──
  {
    regex: /\b(list|show|what are)\s+(my\s+|all\s+)?(directives|notes|modes|folders)\b/i,
    intent: "list",
  },
];

// ── Matcher ──

export function matchIntent(text: string): MatchedIntent | null {
  const trimmed = text.trim();

  for (const pattern of patterns) {
    const match = trimmed.match(pattern.regex);
    if (!match) continue;

    const result: MatchedIntent = {
      intent: pattern.intent,
      entityType: pattern.entityType,
    };

    if (pattern.extractSearch && match.groups?.[pattern.extractSearch.replace("search", "search")]) {
      const raw = match.groups.search?.trim();
      if (raw && raw.length > 0 && raw.length < 200) {
        result.searchQuery = raw;
      }
    }

    if (pattern.extractContent && match.groups?.[pattern.extractContent]) {
      result.contentHint = match.groups[pattern.extractContent]?.trim();
    }

    return result;
  }

  return null;
}
