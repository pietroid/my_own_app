ALTER TABLE "app_version" ADD COLUMN "form" text DEFAULT 'mobile' NOT NULL;--> statement-breakpoint
ALTER TABLE "generated_app" ADD COLUMN "form" text DEFAULT 'mobile' NOT NULL;