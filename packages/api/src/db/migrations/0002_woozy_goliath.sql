CREATE TYPE "public"."directive_history_action" AS ENUM('create', 'update', 'graduate', 'snooze', 'balloon_pump', 'shrink', 'split', 'checklist_complete');--> statement-breakpoint
CREATE TYPE "public"."directive_status" AS ENUM('active', 'archived');--> statement-breakpoint
CREATE TYPE "public"."friendship_status" AS ENUM('pending', 'accepted', 'declined');--> statement-breakpoint
CREATE TYPE "public"."instance_status" AS ENUM('pending', 'done', 'skipped');--> statement-breakpoint
CREATE TYPE "public"."note_kind" AS ENUM('regular', 'mode', 'framework', 'situation', 'goal');--> statement-breakpoint
CREATE TYPE "public"."schedule_type" AS ENUM('weekly', 'monthly', 'oneOff');--> statement-breakpoint
CREATE TYPE "public"."subscription_plan" AS ENUM('free', 'pro');--> statement-breakpoint
CREATE TYPE "public"."sync_op_type" AS ENUM('create', 'update', 'delete');--> statement-breakpoint
ALTER TABLE "directive" ALTER COLUMN "status" DROP DEFAULT;--> statement-breakpoint
ALTER TABLE "directive" ALTER COLUMN "status" SET DATA TYPE directive_status USING status::directive_status;--> statement-breakpoint
ALTER TABLE "directive" ALTER COLUMN "status" SET DEFAULT 'active';--> statement-breakpoint
ALTER TABLE "directive_history" ALTER COLUMN "action" SET DATA TYPE directive_history_action USING action::directive_history_action;--> statement-breakpoint
ALTER TABLE "friendship" ALTER COLUMN "status" DROP DEFAULT;--> statement-breakpoint
ALTER TABLE "friendship" ALTER COLUMN "status" SET DATA TYPE friendship_status USING status::friendship_status;--> statement-breakpoint
ALTER TABLE "friendship" ALTER COLUMN "status" SET DEFAULT 'pending';--> statement-breakpoint
ALTER TABLE "note_page" ALTER COLUMN "kind" DROP DEFAULT;--> statement-breakpoint
ALTER TABLE "note_page" ALTER COLUMN "kind" SET DATA TYPE note_kind USING kind::note_kind;--> statement-breakpoint
ALTER TABLE "note_page" ALTER COLUMN "kind" SET DEFAULT 'regular';--> statement-breakpoint
ALTER TABLE "schedule_instance" ALTER COLUMN "status" DROP DEFAULT;--> statement-breakpoint
ALTER TABLE "schedule_instance" ALTER COLUMN "status" SET DATA TYPE instance_status USING status::instance_status;--> statement-breakpoint
ALTER TABLE "schedule_instance" ALTER COLUMN "status" SET DEFAULT 'pending';--> statement-breakpoint
ALTER TABLE "schedule_rule" ALTER COLUMN "rule_type" SET DATA TYPE schedule_type USING rule_type::schedule_type;--> statement-breakpoint
ALTER TABLE "users" ALTER COLUMN "plan" DROP DEFAULT;--> statement-breakpoint
ALTER TABLE "users" ALTER COLUMN "plan" SET DATA TYPE subscription_plan USING plan::subscription_plan;--> statement-breakpoint
ALTER TABLE "users" ALTER COLUMN "plan" SET DEFAULT 'free';
