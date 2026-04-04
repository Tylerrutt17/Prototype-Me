CREATE TYPE "public"."review_period" AS ENUM('weekly', 'monthly');--> statement-breakpoint
CREATE TABLE "periodic_review" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"user_id" uuid NOT NULL,
	"period" "review_period" NOT NULL,
	"period_start" date NOT NULL,
	"period_end" date NOT NULL,
	"summary" text NOT NULL,
	"best_day" date,
	"best_day_note" text,
	"lowest_day" date,
	"lowest_day_note" text,
	"suggestion" text,
	"directive_insights" text,
	"avg_rating" double precision,
	"entry_count" integer DEFAULT 0 NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
ALTER TABLE "periodic_review" ADD CONSTRAINT "periodic_review_user_id_users_id_fk" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
CREATE UNIQUE INDEX "periodic_review_user_period_idx" ON "periodic_review" USING btree ("user_id","period","period_start");--> statement-breakpoint
CREATE INDEX "periodic_review_user_idx" ON "periodic_review" USING btree ("user_id");
