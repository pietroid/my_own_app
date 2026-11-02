import { Inject, Injectable } from '@nestjs/common';
import { and, desc, eq } from 'drizzle-orm';
import { applyPatch, getValueByPointer, Operation } from 'fast-json-patch';
import {
  ChatMessage,
  OpenRouterClient,
  ToolDefinition,
} from '../assistant/openrouter.client';
import { DB } from '../db/db';
import type { Database } from '../db/db';
import { generatedApp } from '../db/schema';
import { Bundle, InvalidBundleError, parseBundle } from './bundle';
import { ActionFailedError, checkAction, runAction } from './sandbox';

/**
 * An app as the app reads it. Of the actions, only the client ones go out
 * (the device runs them); a server action's code stays here.
 */
export interface AppSnapshot {
  id: string;
  name: string;
  ui: Bundle['ui'];
  data: Record<string, unknown>;
  clientActions: Record<string, { input: string[]; code: string }>;
  rev: number;
}

/** What a tap answers with: the patch, as an AG-UI STATE_DELTA event. */
export interface StateDelta {
  type: 'STATE_DELTA';
  delta: Operation[];
  rev: number;
}

/** Raised when there is no such app, or it is someone else's. */
export class AppNotFoundError extends Error {}

/** Raised when the data changed while an action ran. */
export class AppConflictError extends Error {}

/** One build may take far longer than a chat reply. */
const BUILD_TIMEOUT_MS = 40_000;

/**
 * Apps as data: the assistant builds one once, from a description, and
 * from then on a tap runs the app's own stored code, not the model.
 */
@Injectable()
export class AppsService {
  constructor(
    @Inject(DB) private readonly _db: Database,
    private readonly _model: OpenRouterClient,
  ) {}

  get configured(): boolean {
    return this._model.configured;
  }

  async list(userId: string): Promise<{ id: string; name: string }[]> {
    return this._db
      .select({ id: generatedApp.id, name: generatedApp.name })
      .from(generatedApp)
      .where(eq(generatedApp.userId, userId))
      .orderBy(desc(generatedApp.createdAt));
  }

  async get(userId: string, id: string): Promise<AppSnapshot> {
    const row = await this._row(userId, id);
    const clientActions: AppSnapshot['clientActions'] = {};
    for (const [name, def] of Object.entries(
      row.actions as Bundle['actions'],
    )) {
      if (def.on === 'client') {
        clientActions[name] = { input: def.input, code: def.code };
      }
    }
    return {
      id: row.id,
      name: row.name,
      ui: row.ui as Bundle['ui'],
      data: row.data as Record<string, unknown>,
      clientActions,
      rev: row.rev,
    };
  }

  /** Has the model write a bundle for [prompt], checks it, and keeps it. */
  async create(userId: string, prompt: string): Promise<AppSnapshot> {
    const bundle = await this._build(prompt);
    const [row] = await this._db
      .insert(generatedApp)
      .values({ userId, prompt, ...bundle })
      .returning();
    return this.get(userId, row.id);
  }

  /**
   * Runs [action] on [event] and applies the patch it returns, only if no
   * other change landed meanwhile. The same patch goes back to the app.
   */
  async act(
    userId: string,
    id: string,
    action: string,
    event: Record<string, unknown>,
  ): Promise<StateDelta> {
    const row = await this._row(userId, id);
    const actions = row.actions as Bundle['actions'];
    const def = Object.hasOwn(actions, action) ? actions[action] : undefined;
    // A client action is the device's to run; here it does not exist.
    if (def === undefined || def.on === 'client') {
      throw new ActionFailedError(`no server action ${action}`);
    }

    const data = row.data as Record<string, unknown>;
    const input: Record<string, unknown> = {};
    for (const path of def.input) {
      try {
        input[path] = path === '' ? data : getValueByPointer(data, path);
      } catch {
        input[path] = undefined;
      }
    }

    const delta = runAction(def.code, input, event) as Operation[];
    let next: unknown;
    try {
      next = applyPatch(data, delta, true, false).newDocument;
    } catch (error) {
      throw new ActionFailedError(
        `bad patch: ${error instanceof Error ? error.message : String(error)}`,
      );
    }

    const updated = await this._db
      .update(generatedApp)
      .set({ data: next, rev: row.rev + 1 })
      .where(and(eq(generatedApp.id, id), eq(generatedApp.rev, row.rev)))
      .returning({ rev: generatedApp.rev });
    if (updated.length === 0) throw new AppConflictError();

    return { type: 'STATE_DELTA', delta, rev: updated[0].rev };
  }

  private async _row(userId: string, id: string) {
    const [row] = await this._db
      .select()
      .from(generatedApp)
      .where(and(eq(generatedApp.id, id), eq(generatedApp.userId, userId)));
    if (!row) throw new AppNotFoundError();
    return row;
  }

  /** One build turn, and one more with the error when the first is wrong. */
  private async _build(prompt: string): Promise<Bundle> {
    const messages: ChatMessage[] = [
      { role: 'system', content: BUILD_PROMPT },
      { role: 'user', content: prompt },
    ];
    const started = Date.now();

    for (let attempt = 0; ; attempt++) {
      const outcome = await this._model.generate(messages, [CREATE_APP_TOOL], {
        timeoutMs: BUILD_TIMEOUT_MS,
        forceTool: CREATE_APP_TOOL.function.name,
      });
      const call =
        outcome.kind === 'tool_calls' ? outcome.toolCalls[0] : undefined;
      try {
        if (!call) throw new InvalidBundleError('call create_app');
        let args: unknown;
        try {
          args = JSON.parse(call.function.arguments);
        } catch {
          throw new InvalidBundleError('the arguments are not valid JSON');
        }
        const bundle = parseBundle(args);
        for (const [name, def] of Object.entries(bundle.actions)) {
          try {
            checkAction(def.code);
          } catch (error) {
            throw new InvalidBundleError(
              `${name}: ${(error as Error).message}`,
            );
          }
        }
        return bundle;
      } catch (error) {
        const tooLate = Date.now() - started > BUILD_TIMEOUT_MS;
        if (!(error instanceof InvalidBundleError) || attempt > 0 || tooLate) {
          throw error;
        }
        if (call) {
          messages.push(
            { role: 'assistant', content: '', tool_calls: [call] },
            { role: 'tool', tool_call_id: call.id, content: error.message },
          );
        }
        messages.push({
          role: 'user',
          content: `That app is invalid: ${error.message}. Call create_app again, fixed.`,
        });
      }
    }
  }
}

const CREATE_APP_TOOL: ToolDefinition = {
  type: 'function',
  function: {
    name: 'create_app',
    description: 'Creates the app: its screen, its data and its actions.',
    parameters: {
      type: 'object',
      properties: {
        name: { type: 'string', description: 'Short app name, in Portuguese' },
        ui: { type: 'array', items: { type: 'object' } },
        data: { type: 'object' },
        actions: { type: 'object' },
      },
      required: ['name', 'ui', 'data', 'actions'],
    },
  },
};

/** How the model writes a bundle. Kept in English; the app's words are pt-BR. */
const BUILD_PROMPT = `You build small single-screen apps for a phone. Answer only by calling create_app.

An app is three things:
- data: one JSON object, the app's whole state, with its initial values.
- ui: a flat list of components (a subset of A2UI). The one with id "root" is the screen. Components bind to data by JSON Pointer, written {"path": "/todos"}.
- actions: an object, action name -> {"on": "server" or "client", "input": [JSON Pointers it reads], "code": "function run(input, event) { ... }"}. run gets input keyed by pointer (input["/todos"]) and the event, and returns a JSON Patch (RFC 6902) array to apply to data. It is plain JavaScript with no imports, no network and no Date.now; keep it short.

Where an action runs:
- "server" (the default): on the server; its patch is saved. Anything that must still be there tomorrow is a server action.
- "client": on the person's device, instantly; its patch only changes what is on screen and is not saved. Use it for screen-only state (a filter, a tab, a counter that need not be kept) and to check or prepare input before a server action. A client run gets a third argument, call: "async function run(input, event, call) { const patch = await call('add_todo', {title}); ... }" runs a server action (its patch is saved and applied first) and resolves to that patch. A client action never calls another client action.

Components (every one has "id" and "component"):
- Column / Row / List: "children" is a list of ids, or a template {"componentId": "...", "path": "/todos"} that draws the component once per item of that array. Inside a template, a path without a leading "/" is relative to the item ("title"), and every event fired inside it carries "itemPath", the item's absolute pointer (e.g. "/todos/2") and "index".
- Text: "text" is a string or {"path"}; "variant" is "title", "body" or "caption".
- TextField: "label" (string) and "value" {"path"}. Typing writes to that path on the device only; send it with a button's context.
- CheckBox: "label" (string or {"path"}), "value" {"path"} (a boolean), and "action". It does not change anything itself: its action must.
- Button: "label" (string) and "action".
An action reference is {"event": {"name": "<action name>", "context": {"key": {"path": "/draft"} or a literal}}}; the context values reach run as event.key.

All text the person reads is in Brazilian Portuguese.

Example, a to-do list:
{"name": "Tarefas",
 "data": {"draft": "", "todos": []},
 "ui": [
  {"id": "root", "component": "Column", "children": ["title", "form", "list"]},
  {"id": "title", "component": "Text", "text": "Minhas tarefas", "variant": "title"},
  {"id": "form", "component": "Row", "children": ["field", "add"]},
  {"id": "field", "component": "TextField", "label": "Nova tarefa", "value": {"path": "/draft"}},
  {"id": "add", "component": "Button", "label": "Adicionar", "action": {"event": {"name": "add"}}},
  {"id": "list", "component": "List", "children": {"componentId": "item", "path": "/todos"}},
  {"id": "item", "component": "Row", "children": ["check", "remove"]},
  {"id": "check", "component": "CheckBox", "label": {"path": "title"}, "value": {"path": "done"}, "action": {"event": {"name": "toggle_todo", "context": {"done": {"path": "done"}}}}},
  {"id": "remove", "component": "Button", "label": "Remover", "action": {"event": {"name": "remove_todo"}}}
 ],
 "actions": {
  "add": {"on": "client", "input": ["/draft"], "code": "async function run(input, event, call) { const title = (input['/draft'] || '').trim(); if (!title) return []; await call('add_todo', {title}); return [{op: 'replace', path: '/draft', value: ''}]; }"},
  "add_todo": {"on": "server", "input": [], "code": "function run(input, event) { const title = (event.title || '').trim(); if (!title) return []; return [{op: 'add', path: '/todos/-', value: {title, done: false}}]; }"},
  "toggle_todo": {"on": "server", "input": [], "code": "function run(input, event) { return [{op: 'replace', path: event.itemPath + '/done', value: !event.done}]; }"},
  "remove_todo": {"on": "server", "input": [], "code": "function run(input, event) { return [{op: 'remove', path: event.itemPath}]; }"}
 }}`;
