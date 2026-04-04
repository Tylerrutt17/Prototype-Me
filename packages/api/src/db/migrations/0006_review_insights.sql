ALTER TABLE "periodic_review" ADD COLUMN "themes" jsonb DEFAULT '[]'::jsonb NOT NULL;--> statement-breakpoint
ALTER TABLE "periodic_review" ADD COLUMN "directive_wins" jsonb DEFAULT '[]'::jsonb NOT NULL;--> statement-breakpoint
ALTER TABLE "periodic_review" ADD COLUMN "directive_focus" jsonb DEFAULT '[]'::jsonb NOT NULL;--> statement-breakpoint
ALTER TABLE "periodic_review" ADD COLUMN "directive_gaps" jsonb DEFAULT '[]'::jsonb NOT NULL;--> statement-breakpoint
ALTER TABLE "periodic_review" DROP COLUMN "directive_insights";
