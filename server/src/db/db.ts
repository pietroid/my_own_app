import * as path from 'path';
import { drizzle, NodePgDatabase } from 'drizzle-orm/node-postgres';
import { migrate } from 'drizzle-orm/node-postgres/migrator';
import { Logger } from '@nestjs/common';
import { Pool } from 'pg';
import { schema } from './schema';

/** The Nest token the database is injected under. */
export const DB = Symbol('DB');

export type Database = NodePgDatabase<typeof schema>;

/**
 * One pool for the whole process.
 *
 * Neon is reached over plain TCP: the server is a long-running container on
 * the Pi, not a serverless function, so a small pool of real connections is
 * the right shape. The connection string carries `sslmode=require`.
 *
 * Neon closes the connections it holds when its compute sleeps, and an idle
 * client that loses its connection makes the pool emit `error`, which with
 * no listener would end the process. It is logged instead: the pool opens a
 * fresh connection on the next query, which wakes the compute.
 */
export function createPool(url: string): Pool {
  const pool = new Pool({ connectionString: url, max: 5 });
  const logger = new Logger('Database');
  pool.on('error', (error) => {
    logger.warn(`Idle connection lost: ${error.message}`);
  });
  return pool;
}

/** Drizzle over [pool], with the schema so relational queries type-check. */
export function databaseOf(pool: Pool): Database {
  return drizzle(pool, { schema });
}

/**
 * Brings the schema up to date before the server takes a request.
 *
 * Deploying is pulling an image and starting it, with nothing run by hand in
 * between, so the image carries its migrations and applies them on boot.
 */
export async function migrateDatabase(db: Database): Promise<void> {
  await migrate(db, {
    migrationsFolder:
      process.env.MIGRATIONS_DIR ?? path.join(process.cwd(), 'drizzle'),
  });
}
