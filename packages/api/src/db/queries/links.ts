import { eq, and } from "drizzle-orm";
import { db } from "../client.js";
import { noteDirective } from "../schema.js";

// ── Note ↔ Directive ────────────────────────
export function linkNoteDirective(noteId: string, directiveId: string, sortIndex = 0) {
  return db.insert(noteDirective).values({ noteId, directiveId, sortIndex });
}

export function unlinkNoteDirective(noteId: string, directiveId: string) {
  return db.delete(noteDirective).where(and(eq(noteDirective.noteId, noteId), eq(noteDirective.directiveId, directiveId)));
}
