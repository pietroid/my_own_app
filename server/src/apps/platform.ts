import { ModelUnavailableError } from '../assistant/openrouter.client';
import type { AppForm } from '../db/schema';
// Only read when a call fails, long after both modules are loaded.
import {
  AppConflictError,
  AppNotFoundError,
  type AppSnapshot,
  type AppsService,
  type EditOutcome,
  type VersionSummary,
} from './apps.service';
import { InvalidBundleError } from './bundle';
import { ActionFailedError, type PlatformCall } from './runner';

/**
 * The platform calls: what a platform action (`"on": "platform"`) reaches
 * through `call`, to read and change the person's own apps. They are the
 * REST routes' own work (`AppsService`), scoped to the person who tapped,
 * and they answer plain JSON the action reads (`(await call('apps.list',
 * {})) as List`). No action's source is ever answered: an app's actions
 * come by name, where they run, and what they read.
 *
 * | name           | event                     | answers               |
 * |----------------|---------------------------|-----------------------|
 * | apps.list      | {}                        | [{id, name, form}]    |
 * | apps.get       | {id}                      | AppView               |
 * | apps.create    | {prompt, form?}           | AppView               |
 * | apps.send      | {id, prompt, focus?}      | {version, app}        |
 * | apps.history   | {id}                      | {current, versions}   |
 * | apps.version   | {id, n}                   | AppView (read-only)   |
 * | apps.restore   | {id, n}                   | {version, app}        |
 * | apps.setForm   | {id, form}                | {version, app}        |
 *
 * One run may make [MAX_CALLS] calls, and [MAX_MODEL_CALLS] of them may
 * reach the model (create, send): an action is a tap, not a loop that
 * builds apps.
 */
export const PLATFORM_CALLS = [
  'apps.list',
  'apps.get',
  'apps.create',
  'apps.send',
  'apps.history',
  'apps.version',
  'apps.restore',
  'apps.setForm',
] as const;

export const MAX_CALLS = 8;
export const MAX_MODEL_CALLS = 1;
const MAX_PROMPT = 2000;

/** An app as a platform call answers it: no bytecode, no source. */
export interface AppView {
  id: string;
  name: string;
  form: AppForm;
  ui: AppSnapshot['ui'];
  data: AppSnapshot['data'];
  actions: Record<string, { on: string; input: string[] }>;
  version: number;
  rev: number;
}

/**
 * Raised for a call that is refused, in the person's words: the tap fails
 * with them.
 */
export class PlatformCallError extends Error {}

/**
 * The `call` of one platform action run, for the person [userId], and the
 * last refusal it made: the action fails with those words when a refusal
 * is what failed it.
 */
export function platformCalls(
  apps: AppsService,
  userId: string,
): { call: PlatformCall; refused: () => PlatformCallError | undefined } {
  let refused: PlatformCallError | undefined;
  const call = one(apps, userId);
  return {
    call: async (name, event) => {
      try {
        return await call(name, event);
      } catch (error) {
        refused = refusal(error);
        throw refused;
      }
    },
    refused: () => refused,
  };
}

/** [error] in the person's words. */
function refusal(error: unknown): PlatformCallError {
  if (error instanceof PlatformCallError) return error;
  if (error instanceof AppNotFoundError) {
    return new PlatformCallError('App não encontrado.');
  }
  if (error instanceof AppConflictError) {
    return new PlatformCallError('O app mudou enquanto isso. Tente de novo.');
  }
  if (
    error instanceof InvalidBundleError ||
    error instanceof ActionFailedError
  ) {
    return new PlatformCallError(
      'Não consegui fazer isso. Tente descrever de outro jeito.',
    );
  }
  if (error instanceof ModelUnavailableError) {
    return new PlatformCallError('O assistente não respondeu. Tente de novo.');
  }
  return new PlatformCallError('Essa ação falhou.');
}

function one(apps: AppsService, userId: string): PlatformCall {
  let calls = 0;
  let modelCalls = 0;

  return async (name, event) => {
    if (++calls > MAX_CALLS) {
      throw new PlatformCallError(`more than ${MAX_CALLS} calls in one tap`);
    }
    const model = () => {
      if (++modelCalls > MAX_MODEL_CALLS) {
        throw new PlatformCallError('one request to the model per tap');
      }
      if (!apps.configured) {
        throw new PlatformCallError(
          'O assistente ainda não está conectado a um modelo.',
        );
      }
    };

    switch (name) {
      case 'apps.list':
        return apps.list(userId);
      case 'apps.get':
        return view(await apps.get(userId, id(event)));
      case 'apps.create':
        model();
        return view(
          await apps.create(
            userId,
            prompt(event, 'Descreva o app em poucas palavras.'),
            event.form === undefined ? 'mobile' : form(event),
          ),
        );
      case 'apps.send': {
        model();
        const focus = event.focus;
        return outcome(
          await apps.edit(
            userId,
            id(event),
            prompt(event, 'Diga o que mudar em poucas palavras.'),
            typeof focus === 'string' && focus !== '' ? focus : undefined,
          ),
        );
      }
      case 'apps.history':
        return apps.history(userId, id(event));
      case 'apps.version':
        return view(await apps.version(userId, id(event), n(event)));
      case 'apps.restore':
        return outcome(await apps.restore(userId, id(event), n(event)));
      case 'apps.setForm':
        return outcome(await apps.setForm(userId, id(event), form(event)));
      default:
        throw new PlatformCallError(`no call ${name}`);
    }
  };
}

/** [snapshot] without its bytecode. */
export function view(snapshot: AppSnapshot): AppView {
  return {
    id: snapshot.id,
    name: snapshot.name,
    form: snapshot.form,
    ui: snapshot.ui,
    data: snapshot.data,
    actions: Object.fromEntries(
      Object.entries(snapshot.actions).map(([name, def]) => [
        name,
        { on: def.on, input: def.input },
      ]),
    ),
    version: snapshot.version,
    rev: snapshot.rev,
  };
}

function outcome(edit: EditOutcome): {
  version: VersionSummary;
  app: AppView;
} {
  return { version: edit.version, app: view(edit.app) };
}

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

function id(event: Record<string, unknown>): string {
  if (typeof event.id !== 'string' || !UUID.test(event.id)) {
    throw new PlatformCallError('App não encontrado.');
  }
  return event.id;
}

function n(event: Record<string, unknown>): number {
  if (!Number.isInteger(event.n) || (event.n as number) < 1) {
    throw new PlatformCallError('Versão inválida.');
  }
  return event.n as number;
}

function prompt(event: Record<string, unknown>, refusal: string): string {
  const text = typeof event.prompt === 'string' ? event.prompt.trim() : '';
  if (text === '' || text.length > MAX_PROMPT) {
    throw new PlatformCallError(refusal);
  }
  return text;
}

function form(event: Record<string, unknown>): AppForm {
  if (event.form === 'mobile' || event.form === 'web') return event.form;
  throw new PlatformCallError('Escolha celular ou web.');
}
