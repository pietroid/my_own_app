// A throwaway Postgres for working offline: PGlite (Postgres in WebAssembly)
// behind the Postgres wire protocol, so the server connects to it exactly as
// it connects to Neon.
//
//   npm run db:local            # data kept in .pglite/
//   DATABASE_URL=postgresql://postgres@localhost:5433/postgres?sslmode=disable
//
// Not for anything but local development.
import { PGlite } from '@electric-sql/pglite';
import { PGLiteSocketServer } from '@electric-sql/pglite-socket';

const port = Number(process.env.PGLITE_PORT ?? 5433);
const dataDir = process.env.PGLITE_DIR ?? '.pglite';

const db = await PGlite.create(dataDir === 'memory' ? undefined : dataDir);
const server = new PGLiteSocketServer({ db, port, host: '127.0.0.1' });
await server.start();

console.log(`Local Postgres on postgresql://postgres@localhost:${port}/postgres`);

const stop = async () => {
  await server.stop();
  await db.close();
  process.exit(0);
};
process.on('SIGINT', stop);
process.on('SIGTERM', stop);
