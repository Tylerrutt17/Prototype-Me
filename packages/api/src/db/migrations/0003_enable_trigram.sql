CREATE EXTENSION IF NOT EXISTS pg_trgm;
--> statement-breakpoint
CREATE INDEX IF NOT EXISTS "directive_title_trgm_idx" ON "directive" USING gin ("title" gin_trgm_ops);
--> statement-breakpoint
CREATE INDEX IF NOT EXISTS "note_page_title_trgm_idx" ON "note_page" USING gin ("title" gin_trgm_ops);
--> statement-breakpoint
CREATE INDEX IF NOT EXISTS "folder_name_trgm_idx" ON "folder" USING gin ("name" gin_trgm_ops);
