import * as noteQueries from "../db/queries/notes.js";

export async function listNotes(userId: string, filters?: { kind?: string; folderId?: string }) {
  return noteQueries.findAll(userId, filters);
}

export async function getNote(userId: string, id: string) {
  const note = await noteQueries.findById(userId, id);
  if (!note) throw { status: 404, error: "not_found", message: "Note not found" };
  return note;
}

export async function createNote(userId: string, data: { id?: string; title: string; body: string; kind: string; folderId?: string | null; sortIndex?: number }) {
  return noteQueries.insert(userId, data);
}

export async function updateNote(userId: string, id: string, data: { title?: string; body?: string; kind?: string; folderId?: string | null; sortIndex?: number; version: number }) {
  const existing = await noteQueries.findById(userId, id);
  if (!existing) throw { status: 404, error: "not_found", message: "Note not found" };
  if (existing.version !== data.version) throw { status: 409, error: "version_conflict", message: "Version mismatch" };

  const { version: _, ...updates } = data;
  return noteQueries.update(userId, id, { ...updates, version: existing.version + 1 });
}

export async function deleteNote(userId: string, id: string) {
  const existing = await noteQueries.findById(userId, id);
  if (!existing) throw { status: 404, error: "not_found", message: "Note not found" };
  await noteQueries.remove(userId, id);
}
