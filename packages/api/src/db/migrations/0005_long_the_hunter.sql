CREATE TYPE "public"."review_period" AS ENUM('weekly', 'monthly');--> statement-breakpoint
ALTER TABLE "weekly_review" RENAME TO "periodic_review";--> statement-breakpoint
ALTER TABLE "periodic_review" DROP CONSTRAINT "weekly_review_user_id_users_id_fk";
--> statement-breakpoint
DROP INDEX "weekly_review_user_week_idx";--> statement-breakpoint
DROP INDEX "weekly_review_user_idx";--> statement-breakpoint
ALTER TABLE "periodic_review" ADD COLUMN "period" "review_period" NOT NULL;--> statement-breakpoint
ALTER TABLE "periodic_review" ADD COLUMN "period_start" date NOT NULL;--> statement-breakpoint
ALTER TABLE "periodic_review" ADD COLUMN "period_end" date NOT NULL;--> statement-breakpoint
ALTER TABLE "periodic_review" ADD COLUMN "directive_insights" text;--> statement-breakpoint
ALTER TABLE "periodic_review" ADD CONSTRAINT "periodic_review_user_id_users_id_fk" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
CREATE UNIQUE INDEX "periodic_review_user_period_idx" ON "periodic_review" USING btree ("user_id","period","period_start");--> statement-breakpoint
CREATE INDEX "periodic_review_user_idx" ON "periodic_review" USING btree ("user_id");--> statement-breakpoint
ALTER TABLE "periodic_review" DROP COLUMN "week_start";--> statement-breakpoint
ALTER TABLE "periodic_review" DROP COLUMN "week_end";