CREATE TABLE "app_version" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"app_id" uuid NOT NULL,
	"n" integer NOT NULL,
	"prompt" text NOT NULL,
	"reply" text DEFAULT '' NOT NULL,
	"name" text NOT NULL,
	"ui" jsonb NOT NULL,
	"data" jsonb NOT NULL,
	"actions" jsonb NOT NULL,
	"changes" jsonb NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
ALTER TABLE "generated_app" ADD COLUMN "version" integer DEFAULT 1 NOT NULL;--> statement-breakpoint
ALTER TABLE "app_version" ADD CONSTRAINT "app_version_app_id_generated_app_id_fk" FOREIGN KEY ("app_id") REFERENCES "public"."generated_app"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
CREATE UNIQUE INDEX "app_version_app_id_n_idx" ON "app_version" USING btree ("app_id","n");