import {
  boolean,
  index,
  integer,
  jsonb,
  pgTable,
  text,
  timestamp,
  uniqueIndex,
  uuid,
} from 'drizzle-orm/pg-core';

/**
 * Everything the app keeps, in one Postgres database.
 *
 * The four tables here are Better Auth's and follow its schema exactly: who
 * someone is, their sessions, the Google account behind them, and the
 * short-lived verification rows the OAuth dance needs. The app's own tables
 * go below them. After editing, `npm run db:generate` and commit `drizzle/`.
 */

const createdAt = () =>
  timestamp('created_at', { withTimezone: true }).notNull().defaultNow();
const updatedAt = () =>
  timestamp('updated_at', { withTimezone: true })
    .notNull()
    .defaultNow()
    .$onUpdate(() => new Date());

// ---------------------------------------------------------------------------
// Better Auth
// ---------------------------------------------------------------------------

export const user = pgTable('user', {
  id: text('id').primaryKey(),
  name: text('name').notNull(),
  email: text('email').notNull().unique(),
  emailVerified: boolean('email_verified').notNull().default(false),
  image: text('image'),
  createdAt: createdAt(),
  updatedAt: updatedAt(),
});

export const session = pgTable(
  'session',
  {
    id: text('id').primaryKey(),
    expiresAt: timestamp('expires_at', { withTimezone: true }).notNull(),
    token: text('token').notNull().unique(),
    ipAddress: text('ip_address'),
    userAgent: text('user_agent'),
    userId: text('user_id')
      .notNull()
      .references(() => user.id, { onDelete: 'cascade' }),
    createdAt: createdAt(),
    updatedAt: updatedAt(),
  },
  (table) => [index('session_user_id_idx').on(table.userId)],
);

export const account = pgTable(
  'account',
  {
    id: text('id').primaryKey(),
    accountId: text('account_id').notNull(),
    providerId: text('provider_id').notNull(),
    userId: text('user_id')
      .notNull()
      .references(() => user.id, { onDelete: 'cascade' }),
    accessToken: text('access_token'),
    refreshToken: text('refresh_token'),
    idToken: text('id_token'),
    accessTokenExpiresAt: timestamp('access_token_expires_at', {
      withTimezone: true,
    }),
    refreshTokenExpiresAt: timestamp('refresh_token_expires_at', {
      withTimezone: true,
    }),
    scope: text('scope'),
    password: text('password'),
    createdAt: createdAt(),
    updatedAt: updatedAt(),
  },
  (table) => [index('account_user_id_idx').on(table.userId)],
);

export const verification = pgTable(
  'verification',
  {
    id: text('id').primaryKey(),
    identifier: text('identifier').notNull(),
    value: text('value').notNull(),
    expiresAt: timestamp('expires_at', { withTimezone: true }).notNull(),
    createdAt: createdAt(),
    updatedAt: updatedAt(),
  },
  (table) => [index('verification_identifier_idx').on(table.identifier)],
);

// ---------------------------------------------------------------------------
// The app
// ---------------------------------------------------------------------------

/**
 * An app someone had the assistant build: a stored bundle of its screen
 * (A2UI components), its data (one JSON document) and its actions (small JS
 * functions run in a sandbox). `rev` goes up by one with every change to
 * `data`, so two taps never overwrite each other.
 */
/** What an app is made for: a phone, or a browser on a wide screen. */
export type AppForm = 'mobile' | 'web';

export const generatedApp = pgTable(
  'generated_app',
  {
    id: uuid('id').primaryKey().defaultRandom(),
    userId: text('user_id')
      .notNull()
      .references(() => user.id, { onDelete: 'cascade' }),
    name: text('name').notNull(),
    prompt: text('prompt').notNull(),
    ui: jsonb('ui').notNull(),
    data: jsonb('data').notNull(),
    actions: jsonb('actions').notNull(),
    rev: integer('rev').notNull().default(0),
    /** The number of the [appVersion] the app is at now. */
    version: integer('version').notNull().default(1),
    /** What it is made for: `mobile` (a phone) or `web` (a browser). */
    form: text('form').$type<AppForm>().notNull().default('mobile'),
    /** Which of our own apps this is a copy of (`editor`), or null. */
    seed: text('seed'),
    createdAt: createdAt(),
    updatedAt: updatedAt(),
  },
  (table) => [index('generated_app_user_id_idx').on(table.userId)],
);

/**
 * One point of an app's history: what the person asked, what the model
 * answered, and the app as it was right after (its screen, its actions and
 * its data then). The conversation about an app is its versions, in order.
 */
export const appVersion = pgTable(
  'app_version',
  {
    id: uuid('id').primaryKey().defaultRandom(),
    appId: uuid('app_id')
      .notNull()
      .references(() => generatedApp.id, { onDelete: 'cascade' }),
    n: integer('n').notNull(),
    prompt: text('prompt').notNull(),
    reply: text('reply').notNull().default(''),
    name: text('name').notNull(),
    ui: jsonb('ui').notNull(),
    data: jsonb('data').notNull(),
    actions: jsonb('actions').notNull(),
    form: text('form').$type<AppForm>().notNull().default('mobile'),
    /** What this version changed: component ids and action names. */
    changes: jsonb('changes').notNull(),
    createdAt: createdAt(),
  },
  (table) => [uniqueIndex('app_version_app_id_n_idx').on(table.appId, table.n)],
);

export const schema = {
  user,
  session,
  account,
  verification,
  generatedApp,
  appVersion,
};
