import { eq, and, gt, sql } from "drizzle-orm";
import { db } from "../client.js";
import { noteDirective } from "../schema.js";

// ── Note ↔ Directive ────────────────────────
export function linkNoteDirective(noteId: string, directiveId: string, sortIndex = 0) {
  return db.insert(noteDirective).values({ noteId, directiveId, sortIndex });
}

export async function unlinkNoteDirective(noteId: string, directiveId: string) {
  // Get the sortIndex of the link being removed
  const [removed] = await db
    .select({ sortIndex: noteDirective.sortIndex })
    .from(noteDirective)
    .where(and(eq(noteDirective.noteId, noteId), eq(noteDirective.directiveId, directiveId)));

  await db.delete(noteDirective).where(and(eq(noteDirective.noteId, noteId), eq(noteDirective.directiveId, directiveId)));

  // Close the gap: decrement sortIndex for all links that came after
  if (removed) {
    await db
      .update(noteDirective)
      .set({ sortIndex: sql`${noteDirective.sortIndex} - 1` })
      .where(and(eq(noteDirective.noteId, noteId), gt(noteDirective.sortIndex, removed.sortIndex)));
  }
}
