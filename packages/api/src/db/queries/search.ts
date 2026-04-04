import { db } from "../client.js";
import { sql } from "drizzle-orm";

export interface SearchResult {
  id: string;
  type: "directive" | "note" | "folder";
  title: string;
  body: string | null;
  kind: string | null;
  status: string | null;
  similarity: number;
}

/**
 * Fuzzy search across directives, notes, and folders using pg_trgm.
 * Returns up to `limit` results ranked by similarity, filtered above a threshold.
 */
export async function fuzzySearch(
  userId: string,
  query: string,
  limit = 10,
  threshold = 0.15,
): Promise<SearchResult[]> {
  const results = await db.execute(sql`
    SELECT * FROM (
      SELECT
        id::text,
        'directive' AS type,
        title,
        body,
        NULL AS kind,
        status,
        similarity(title, ${query}) AS similarity
      FROM directive
      WHERE user_id = ${userId} AND status = 'active'

      UNION ALL

      SELECT
        id::text,
        'note' AS type,
        title,
        body,
        kind,
        NULL AS status,
        similarity(title, ${query}) AS similarity
      FROM note_page
      WHERE user_id = ${userId}

      UNION ALL

      SELECT
        id::text,
        'folder' AS type,
        name AS title,
        NULL AS body,
        NULL AS kind,
        NULL AS status,
        similarity(name, ${query}) AS similarity
      FROM folder
      WHERE user_id = ${userId}
    ) results
    WHERE similarity > ${threshold}
    ORDER BY similarity DESC
    LIMIT ${limit}
  `);

  return results as unknown as SearchResult[];
}
