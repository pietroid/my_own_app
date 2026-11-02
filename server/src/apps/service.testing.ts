import * as path from 'path';
import { PGlite } from '@electric-sql/pglite';
import { drizzle } from 'drizzle-orm/pglite';
import { migrate } from 'drizzle-orm/pglite/migrator';
import type {
  ChatMessage,
  ModelOutcome,
  OpenRouterClient,
  ToolDefinition,
} from '../assistant/openrouter.client';
import type { Database } from '../db/db';
import { schema, user } from '../db/schema';
import { AppsService } from './apps.service';
import { ActionRunner } from './runner';

/** What the fake model was asked, call by call. */
export interface ModelCall {
  messages: ChatMessage[];
  tools: ToolDefinition[];
}

/**
 * An [AppsService] over a real Postgres in memory (PGlite, with every
 * migration), the real action runner, and a model that answers from a
 * script: each [reply] is the outcome of one call, in order.
 */
export async function serviceForTest(): Promise<{
  apps: AppsService;
  db: Database;
  runner: ActionRunner;
  calls: ModelCall[];
  reply: (...outcomes: ModelOutcome[]) => void;
  /** Makes the model's next answer take [ms]. */
  slowly: (ms: number) => void;
  close: () => Promise<void>;
}> {
  const client = new PGlite();
  const pglite = drizzle(client, { schema });
  await migrate(pglite, {
    migrationsFolder: path.join(__dirname, '..', '..', 'drizzle'),
  });
  // The same queries, the same schema: only the driver differs.
  const db = pglite as unknown as Database;
  await db.insert(user).values([
    { id: 'ana', name: 'Ana', email: 'ana@exemplo.com' },
    { id: 'bia', name: 'Bia', email: 'bia@exemplo.com' },
  ]);

  const calls: ModelCall[] = [];
  const script: ModelOutcome[] = [];
  let delay = 0;
  const model = {
    configured: true,
    generate: async (messages: ChatMessage[], tools: ToolDefinition[]) => {
      calls.push({ messages: structuredClone(messages), tools });
      const next = script.shift();
      if (!next) throw new Error('the model was not expecting a call');
      const wait = delay;
      delay = 0;
      if (wait > 0) await new Promise((done) => setTimeout(done, wait));
      return next;
    },
  } as unknown as OpenRouterClient;

  const runner = new ActionRunner();
  return {
    apps: new AppsService(db, model, runner),
    db,
    runner,
    calls,
    reply: (...outcomes) => script.push(...outcomes),
    slowly: (ms) => {
      delay = ms;
    },
    close: async () => {
      runner.onModuleDestroy();
      await client.close();
    },
  };
}

/** The model calling one tool with [args]. */
export function toolCall(
  name: string,
  args: unknown,
  id = 'call-1',
): ModelOutcome {
  return {
    kind: 'tool_calls',
    toolCalls: [
      {
        id,
        type: 'function',
        function: { name, arguments: JSON.stringify(args) },
      },
    ],
  };
}

/** A small app the fake model builds: a counter. */
export const COUNTER = {
  name: 'Contador',
  data: { count: 0 },
  ui: [
    { id: 'root', component: 'Column', children: ['n', 'more'] },
    { id: 'n', component: 'Text', text: { path: '/count' }, variant: 'h1' },
    {
      id: 'more',
      component: 'Button',
      label: 'Mais um',
      action: { event: { name: 'increment' } },
    },
  ],
  actions: {
    increment: {
      input: ['/count'],
      code: "Future<List> run(Map input, Map event, Function call) async { return [{'op': 'replace', 'path': '/count', 'value': (input['/count'] as int) + 1}]; }",
    },
  },
};
