import { z } from "zod/v4";

/**
 * Versioned payload schemas for DirectiveHistory entries.
 *
 * Each action has its own payload shape, versioned via the `v` field.
 * When you need to change a payload shape, add a new version schema and
 * include it in the discriminated union. Old logged entries will continue
 * to parse correctly because history is append-only.
 *
 * Convention:
 *   - `v` is always a literal number (1, 2, 3...)
 *   - Old versions are NEVER removed, only added to
 *   - New optional fields can be added without a version bump
 *   - Version bump required for: renaming fields, changing types, removing fields
 */

// ── Create ──
const createV1 = z.object({
  v: z.literal(1),
  title: z.string().max(500),
});
export const createPayload = z.discriminatedUnion("v", [createV1]);

// ── Update ──
const updateV1 = z.object({
  v: z.literal(1),
});
export const updatePayload = z.discriminatedUnion("v", [updateV1]);

// ── Graduate / Archive ──
const graduateV1 = z.object({
  v: z.literal(1),
  reason: z.enum(["archived", "completed", "retired"]).optional(),
});
export const graduatePayload = z.discriminatedUnion("v", [graduateV1]);

// ── Snooze ──
const snoozeV1 = z.object({
  v: z.literal(1),
  until: z.string().datetime().optional(),
});
export const snoozePayload = z.discriminatedUnion("v", [snoozeV1]);

// ── Balloon Pump ──
const balloonPumpV1 = z.object({
  v: z.literal(1),
});
export const balloonPumpPayload = z.discriminatedUnion("v", [balloonPumpV1]);

// ── Shrink ──
const shrinkV1 = z.object({
  v: z.literal(1),
});
export const shrinkPayload = z.discriminatedUnion("v", [shrinkV1]);

// ── Split ──
const splitV1 = z.object({
  v: z.literal(1),
  newDirectiveIds: z.array(z.string().uuid()).optional(),
});
export const splitPayload = z.discriminatedUnion("v", [splitV1]);

// ── Checklist Complete ──
const checklistCompleteV1 = z.object({
  v: z.literal(1),
  date: z.string().regex(/^\d{4}-\d{2}-\d{2}$/, "date must be yyyy-MM-dd"),
});
export const checklistCompletePayload = z.discriminatedUnion("v", [checklistCompleteV1]);

// ── Action → Schema Lookup ──
export const actionPayloadSchemas = {
  create: createPayload,
  update: updatePayload,
  graduate: graduatePayload,
  snooze: snoozePayload,
  balloon_pump: balloonPumpPayload,
  shrink: shrinkPayload,
  split: splitPayload,
  checklist_complete: checklistCompletePayload,
} as const;

export type DirectiveHistoryAction = keyof typeof actionPayloadSchemas;

/**
 * Validate a directive history payload against the schema for its action.
 * Returns the parsed (and typed) payload, or null if invalid.
 */
export function validateHistoryPayload(
  action: string,
  payload: unknown,
): { ok: true; data: unknown } | { ok: false; error: string } {
  const schema = actionPayloadSchemas[action as DirectiveHistoryAction];
  if (!schema) {
    return { ok: false, error: `Unknown action: ${action}` };
  }

  // Accept either a JSON string or an already-parsed object
  let parsedPayload: unknown = payload;
  if (typeof payload === "string") {
    if (payload.trim() === "") {
      // Treat empty string as v1 with no additional fields (legacy shape).
      parsedPayload = { v: 1 };
    } else {
      try {
        parsedPayload = JSON.parse(payload);
      } catch {
        return { ok: false, error: "Payload is not valid JSON" };
      }
    }
  }

  const result = schema.safeParse(parsedPayload);
  if (!result.success) {
    return { ok: false, error: result.error.issues.map((i) => i.message).join("; ") };
  }
  return { ok: true, data: result.data };
}
