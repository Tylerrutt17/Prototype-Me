ALTER TABLE "periodic_review" ADD COLUMN "missed_scheduled" jsonb DEFAULT '[]'::jsonb NOT NULL;
