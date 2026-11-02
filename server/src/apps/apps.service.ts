import { Inject, Injectable } from '@nestjs/common';
import { and, asc, desc, eq } from 'drizzle-orm';
import { applyPatch, getValueByPointer, Operation } from 'fast-json-patch';
import {
  ChatMessage,
  OpenRouterClient,
  ToolDefinition,
} from '../assistant/openrouter.client';
import { DB } from '../db/db';
import type { Database } from '../db/db';
import { appVersion, generatedApp } from '../db/schema';
import { Bundle, InvalidBundleError, parseBundle } from './bundle';
import { Changes, describeApp, diff, EDIT_TOOLS, runEdit } from './edit';
import { ActionFailedError, ActionRunner } from './runner';

/**
 * An app as the app reads it. Every action goes out as bytecode: the device
 * runs each one at once, and sends the saved ones here to be kept. No
 * action's source goes out.
 */
export interface AppSnapshot {
  id: string;
  name: string;
  ui: Bundle['ui'];
  data: Record<string, unknown>;
  actions: Record<
    string,
    { on: 'server' | 'client'; input: string[]; evc: string }
  >;
  rev: number;
  /** The version this is: the app's current one, or the one asked for. */
  version: number;
}

/** One point of an app's history, as the conversation shows it. */
export interface VersionSummary {
  n: number;
  /** What the person asked; empty when the version brought one back. */
  prompt: string;
  /** What the model answered. */
  reply: string;
  changes: Changes;
  createdAt: string;
}

/** An edit's answer: the new point of history, and the app at it. */
export interface EditOutcome {
  version: VersionSummary;
  app: AppSnapshot;
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
 * How long a whole edit, all its rounds, may go on: under the proxy's 100 s
 * (deploy/nginx.conf), with each call cut to what is left.
 */
const EDIT_BUDGET_MS = 80_000;

/** How many earlier turns of the conversation an edit sees. */
const EDIT_HISTORY = 6;

/** The changes of a first version: everything is new. */
function created(bundle: Bundle): Changes {
  return diff({ name: bundle.name, ui: [], data: {}, actions: {} }, bundle);
}

/**
 * Apps as data: the assistant builds one once, from a description, and
 * from then on a tap runs the app's own stored code, not the model.
 */
@Injectable()
export class AppsService {
  constructor(
    @Inject(DB) private readonly _db: Database,
    private readonly _model: OpenRouterClient,
    private readonly _runner: ActionRunner,
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
    return snapshot(row, row.actions, row.version);
  }

  /**
   * The app's conversation: one entry per version, oldest first, and the
   * number of the one it is at. An app from before versions gets its
   * first one now, from what it was built from.
   */
  async history(
    userId: string,
    id: string,
  ): Promise<{ current: number; versions: VersionSummary[] }> {
    const row = await this._row(userId, id);
    await this._firstVersion(row);
    const rows = await this._db
      .select()
      .from(appVersion)
      .where(eq(appVersion.appId, id))
      .orderBy(asc(appVersion.n));
    return { current: row.version, versions: rows.map(summary) };
  }

  /** The app as it was at version [n]: to look at, not to run against. */
  async version(userId: string, id: string, n: number): Promise<AppSnapshot> {
    const row = await this._row(userId, id);
    await this._firstVersion(row);
    const version = await this._versionRow(id, n);
    const actions = await this._fresh(version.actions as Bundle['actions']);
    return snapshot(
      { ...row, name: version.name, ui: version.ui, data: version.data },
      actions,
      n,
    );
  }

  /**
   * Changes the app as the person asked, by the model's tools: only what
   * the request is about is written, and only the actions it changed are
   * compiled. The change is a new version, with the model's reply.
   * [focus] is the component the person had selected.
   */
  async edit(
    userId: string,
    id: string,
    prompt: string,
    focus?: string,
  ): Promise<EditOutcome> {
    const row = await this._row(userId, id);
    await this._firstVersion(row);
    const base = bundleOf(row);
    const earlier = await this._db
      .select({ prompt: appVersion.prompt, reply: appVersion.reply })
      .from(appVersion)
      .where(eq(appVersion.appId, id))
      .orderBy(desc(appVersion.n))
      .limit(EDIT_HISTORY);

    const focused =
      focus !== undefined ? base.ui.find((c) => c.id === focus) : undefined;
    const messages: ChatMessage[] = [
      { role: 'system', content: EDIT_PROMPT },
      ...earlier
        .reverse()
        .filter((turn) => turn.prompt !== '')
        .flatMap((turn): ChatMessage[] => [
          { role: 'user', content: turn.prompt },
          { role: 'assistant', content: turn.reply || 'Pronto.' },
        ]),
      {
        role: 'user',
        content: [
          `The app now:\n${describeApp(base)}`,
          focused
            ? `The person selected the component "${focused.id}" (${focused.component}): the request is about it.`
            : '',
          `Request: ${prompt}`,
        ]
          .filter((part) => part !== '')
          .join('\n\n'),
      },
    ];

    const deadline = Date.now() + EDIT_BUDGET_MS;
    const result = await runEdit(
      base,
      messages,
      (talk) =>
        this._model.generate(talk, EDIT_TOOLS, {
          timeoutMs: Math.max(
            5_000,
            Math.min(BUILD_TIMEOUT_MS, deadline - Date.now()),
          ),
        }),
      (bundle) =>
        this._compile(bundle.actions).then((actions) => ({
          ...bundle,
          actions,
        })),
      { deadline },
    );

    return this._commit(userId, id, row, {
      prompt,
      reply: result.reply,
      bundle: result.bundle,
      changes: result.changes,
      // Taps may have changed the data while the model worked: its own
      // changes to the data go on top of what is there now.
      data: (fresh) => {
        let next = fresh;
        for (const patch of result.dataPatches) {
          next = applyPatch(next, patch, true, false).newDocument;
        }
        return next;
      },
    });
  }

  /**
   * Brings version [n] back as a new version: its screen and its actions.
   * The data stays as it is when it has the same top-level keys; otherwise
   * it is that version's.
   */
  async restore(userId: string, id: string, n: number): Promise<EditOutcome> {
    const row = await this._row(userId, id);
    await this._firstVersion(row);
    const version = await this._versionRow(id, n);
    const bundle: Bundle = {
      name: version.name,
      ui: version.ui as Bundle['ui'],
      data: version.data as Record<string, unknown>,
      actions: await this._fresh(version.actions as Bundle['actions']),
    };
    const keys = (data: unknown) =>
      Object.keys(data as Record<string, unknown>)
        .sort()
        .join();
    return this._commit(userId, id, row, {
      prompt: '',
      reply: '',
      bundle,
      changes: { ...diff(bundleOf(row), bundle), restoredFrom: n },
      data: (fresh) =>
        keys(fresh) === keys(bundle.data) ? fresh : bundle.data,
    });
  }

  /** Has the model write a bundle for [prompt], checks it, and keeps it. */
  async create(userId: string, prompt: string): Promise<AppSnapshot> {
    const bundle = await this._build(prompt);
    const row = await this._db.transaction(async (tx) => {
      const [app] = await tx
        .insert(generatedApp)
        .values({ userId, prompt, ...bundle })
        .returning();
      await tx.insert(appVersion).values({
        appId: app.id,
        n: 1,
        prompt,
        ...bundle,
        changes: created(bundle),
      });
      return app;
    });
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
    const actions = row.actions;
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

    const delta = (await this._runner.run(
      def.evc!,
      input,
      event,
    )) as Operation[];
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

  /**
   * Builds the app again from the words it was built from: for an app
   * whose actions no longer compile (the JS ones from before Dart), or for
   * every app when the build prompt changed. Its data is kept when
   * [keepData] and the new app keeps the same top-level keys; otherwise it
   * starts from the new app's initial data.
   */
  async rebuild(id: string, { keepData = true } = {}): Promise<void> {
    const [row] = await this._db
      .select()
      .from(generatedApp)
      .where(eq(generatedApp.id, id));
    if (!row) throw new AppNotFoundError();
    const bundle = await this._build(row.prompt);
    const old = row.data as Record<string, unknown>;
    const sameShape =
      keepData &&
      Object.keys(old).sort().join() === Object.keys(bundle.data).sort().join();
    await this._db
      .update(generatedApp)
      .set({ ...bundle, data: sameShape ? old : bundle.data, rev: row.rev + 1 })
      .where(eq(generatedApp.id, id));
  }

  /** Every app's id, everyone's. */
  async all(): Promise<string[]> {
    const rows = await this._db
      .select({ id: generatedApp.id })
      .from(generatedApp);
    return rows.map((row) => row.id);
  }

  /**
   * The apps with an action that was never compiled: the ones from before
   * actions were Dart, which only [rebuild] can bring back. Bytecode an
   * older runner wrote needs nothing: opening the app compiles it again.
   */
  async stale(): Promise<string[]> {
    const rows = await this._db
      .select({ id: generatedApp.id, actions: generatedApp.actions })
      .from(generatedApp);
    return rows
      .filter((row) =>
        Object.values(row.actions as Bundle['actions']).some(
          (def) => def.evc === undefined,
        ),
      )
      .map((row) => row.id);
  }

  /**
   * Keeps [change] as version `row.version + 1` and makes it the app, if
   * no other edit landed first. Taps may land meanwhile: [change.data] is
   * given the data as it is then, and asked again if a tap beats it.
   */
  private async _commit(
    userId: string,
    id: string,
    row: Awaited<ReturnType<AppsService['_row']>>,
    change: {
      prompt: string;
      reply: string;
      bundle: Bundle;
      changes: Changes;
      data: (fresh: Record<string, unknown>) => unknown;
    },
  ): Promise<EditOutcome> {
    const n = row.version + 1;
    for (let attempt = 0; attempt < 3; attempt++) {
      const [now] = await this._db
        .select({
          rev: generatedApp.rev,
          version: generatedApp.version,
          data: generatedApp.data,
        })
        .from(generatedApp)
        .where(eq(generatedApp.id, id));
      if (!now || now.version !== row.version) throw new AppConflictError();
      let data: unknown;
      try {
        data = change.data(now.data as Record<string, unknown>);
      } catch {
        throw new AppConflictError();
      }

      const saved = await this._db.transaction(async (tx) => {
        const updated = await tx
          .update(generatedApp)
          .set({
            name: change.bundle.name,
            ui: change.bundle.ui,
            actions: change.bundle.actions,
            data,
            rev: now.rev + 1,
            version: n,
          })
          .where(and(eq(generatedApp.id, id), eq(generatedApp.rev, now.rev)))
          .returning({ id: generatedApp.id });
        if (updated.length === 0) return undefined;
        const [version] = await tx
          .insert(appVersion)
          .values({
            appId: id,
            n,
            prompt: change.prompt,
            reply: change.reply,
            name: change.bundle.name,
            ui: change.bundle.ui,
            data,
            actions: change.bundle.actions,
            changes: change.changes,
          })
          .returning();
        return version;
      });
      if (saved) {
        return { version: summary(saved), app: await this.get(userId, id) };
      }
    }
    throw new AppConflictError();
  }

  /** An app from before versions gets its first one, from what it is now. */
  private async _firstVersion(
    row: Awaited<ReturnType<AppsService['_row']>>,
  ): Promise<void> {
    const [any] = await this._db
      .select({ n: appVersion.n })
      .from(appVersion)
      .where(eq(appVersion.appId, row.id))
      .limit(1);
    if (any) return;
    const bundle = bundleOf(row);
    await this._db
      .insert(appVersion)
      .values({
        appId: row.id,
        n: row.version,
        prompt: row.prompt,
        ...bundle,
        changes: created(bundle),
      })
      .onConflictDoNothing();
  }

  private async _versionRow(id: string, n: number) {
    const [version] = await this._db
      .select()
      .from(appVersion)
      .where(and(eq(appVersion.appId, id), eq(appVersion.n, n)));
    if (!version) throw new AppNotFoundError();
    return version;
  }

  /** [actions] with bytecode this runner wrote, compiling what is stale. */
  private async _fresh(actions: Bundle['actions']): Promise<Bundle['actions']> {
    const version = await this._runner.version();
    if (Object.values(actions).every((def) => def.version === version)) {
      return actions;
    }
    return this._compile(actions);
  }

  /**
   * The app's row, its actions' bytecode written by this runner: bytecode
   * another version wrote is compiled again from its source, and kept.
   */
  private async _row(userId: string, id: string) {
    const [row] = await this._db
      .select()
      .from(generatedApp)
      .where(and(eq(generatedApp.id, id), eq(generatedApp.userId, userId)));
    if (!row) throw new AppNotFoundError();
    const actions = row.actions as Bundle['actions'];
    const version = await this._runner.version();
    if (Object.values(actions).every((def) => def.version === version)) {
      return { ...row, actions };
    }
    const fresh = await this._compile(actions);
    await this._db
      .update(generatedApp)
      .set({ actions: fresh })
      .where(eq(generatedApp.id, id));
    return { ...row, actions: fresh };
  }

  /** Every action of [actions] compiled; one that does not, fails it. */
  private async _compile(
    actions: Bundle['actions'],
  ): Promise<Bundle['actions']> {
    const out: Bundle['actions'] = {};
    const version = await this._runner.version();
    for (const [name, def] of Object.entries(actions)) {
      // Unchanged and compiled by this runner: kept as it is.
      if (def.evc !== undefined && def.version === version) {
        out[name] = def;
        continue;
      }
      try {
        out[name] = { ...def, ...(await this._runner.compile(def.code)) };
      } catch (error) {
        if (!(error instanceof ActionFailedError)) throw error;
        throw new InvalidBundleError(`${name}: ${error.message}`);
      }
    }
    return out;
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
          args = parseModelJson(call.function.arguments);
        } catch {
          throw new InvalidBundleError('the arguments are not valid JSON');
        }
        // Some models send the actions as one JSON-encoded string; that is
        // the same object, written twice over.
        if (isObject(args) && typeof args.actions === 'string') {
          try {
            args = { ...args, actions: parseModelJson(args.actions) };
          } catch {
            // Left as it is: parseBundle says what is wrong with it.
          }
        }
        const bundle = parseBundle(args);
        return { ...bundle, actions: await this._compile(bundle.actions) };
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
        // Spelled out: with a bare object, models tend to send the actions
        // as one JSON-encoded string once the code inside them is Dart.
        actions: {
          type: 'object',
          description:
            'Action name -> the action. A JSON object, not a string.',
          additionalProperties: {
            type: 'object',
            properties: {
              on: { type: 'string', enum: ['server', 'client'] },
              input: { type: 'array', items: { type: 'string' } },
              code: {
                type: 'string',
                description:
                  'Dart: Future<List> run(Map input, Map event, Function call) async { ... }',
              },
            },
            required: ['input', 'code'],
          },
        },
      },
      required: ['name', 'ui', 'data', 'actions'],
    },
  },
};

/** What an app is, and how its code is written: the same for both prompts. */
const RULES = `An app is three things:
- data: one JSON object, the app's whole state, with its initial values.
- ui: a flat list of components (a subset of A2UI). The one with id "root" is the screen. Components bind to data by JSON Pointer, written {"path": "/todos"}.
- actions: an object, action name -> {"on": "server" or "client", "input": [JSON Pointers it reads], "code": "<Dart>"}. The code is Dart defining exactly Future<List> run(Map input, Map event, Function call) async { ... }. run gets input keyed by pointer (input['/todos']) and the event, and returns a JSON Patch (RFC 6902) as a List of Maps to apply to data. Keep it short.

The Dart runs in an interpreter (dart_eval) that supports a subset of the language. Use only: functions, local variables (final/var), if/else, for, for-in, while, switch statements, String/int/double/bool/List/Map and their common methods (map, where, toList, length, isEmpty, trim, contains, indexOf, add, removeAt, keys, values), string interpolation, collection literals, and as casts. Never use: imports, classes, mixins, extension methods, late, typedefs, generators (sync*/async*), switch expressions, records, patterns, DateTime.now, Random, print. Every value from input or event is dynamic: cast it before use ((input['/todos'] as List), (event['title'] as String? ?? '')). run is always async, even when it awaits nothing.

Where an action runs. Every action runs on the person's device the moment they tap, so the screen changes at once; what differs is whether the change is saved:
- "server" (the default): saved. The device shows its patch at once, then the server runs the same action on its own copy of the data and keeps the patch. Anything that must still be there tomorrow is a server action, and most actions are. Because it also runs on the server, where nothing typed on the device exists, a server action reads what the person typed only from the event (a button's context, {"title": {"path": "/draft"}}), never from input; input is for saved data (the list, a total). It can clear the field in the same patch.
- "client": not saved; only for screen-only state (a filter, a tab, a form step). Its third argument, call: "final List kept = await call('save_item', {'title': title});" runs a server action and resolves to its patch. Never write a client action that only calls a server one: write the server action and point the button at it.

Components (every one has "id" and "component"):
- Column / Row / List: "children" is a list of ids, or a template {"componentId": "...", "path": "/todos"} that draws the component once per item of that array. Inside a template, a path without a leading "/" is relative to the item ("title"), and every event fired inside it carries "itemPath", the item's absolute pointer (e.g. "/todos/2") and "index".
- Text: "text" is a string or {"path"}; "variant" is "title", "body" or "caption".
- TextField: "label" (string) and "value" {"path"}. Typing writes to that path on the device only; send it with a button's context.
- CheckBox: "label" (string or {"path"}), "value" {"path"} (a boolean), and "action". It does not change anything itself: its action must.
- Button: "label" (string) and "action".
An action reference is {"event": {"name": "<action name>", "context": {"key": {"path": "/draft"} or a literal}}}; the context values reach run as event.key.

All text the person reads is in Brazilian Portuguese.`;

/** A whole app, as the build prompt shows it. */
const EXAMPLE = `{"name": "Tarefas",
 "data": {"draft": "", "todos": []},
 "ui": [
  {"id": "root", "component": "Column", "children": ["title", "form", "list"]},
  {"id": "title", "component": "Text", "text": "Minhas tarefas", "variant": "title"},
  {"id": "form", "component": "Row", "children": ["field", "add"]},
  {"id": "field", "component": "TextField", "label": "Nova tarefa", "value": {"path": "/draft"}},
  {"id": "add", "component": "Button", "label": "Adicionar", "action": {"event": {"name": "add_todo", "context": {"title": {"path": "/draft"}}}}},
  {"id": "list", "component": "List", "children": {"componentId": "item", "path": "/todos"}},
  {"id": "item", "component": "Row", "children": ["check", "remove"]},
  {"id": "check", "component": "CheckBox", "label": {"path": "title"}, "value": {"path": "done"}, "action": {"event": {"name": "toggle_todo", "context": {"done": {"path": "done"}}}}},
  {"id": "remove", "component": "Button", "label": "Remover", "action": {"event": {"name": "remove_todo"}}}
 ],
 "actions": {
  "add_todo": {"on": "server", "input": [], "code": "Future<List> run(Map input, Map event, Function call) async { final title = (event['title'] as String? ?? '').trim(); if (title.isEmpty) return []; return [{'op': 'add', 'path': '/todos/-', 'value': {'title': title, 'done': false}}, {'op': 'replace', 'path': '/draft', 'value': ''}]; }"},
  "toggle_todo": {"on": "server", "input": [], "code": "Future<List> run(Map input, Map event, Function call) async { final path = event['itemPath'] as String; return [{'op': 'replace', 'path': '$path/done', 'value': event['done'] != true}]; }"},
  "remove_todo": {"on": "server", "input": [], "code": "Future<List> run(Map input, Map event, Function call) async { return [{'op': 'remove', 'path': event['itemPath'] as String}]; }"}
 }}`;

/** How the model writes a bundle. Kept in English; the app's words are pt-BR. */
export const BUILD_PROMPT = `You build small single-screen apps for a phone. Answer only by calling create_app.

${RULES}

Example, a to-do list:
${EXAMPLE}`;

/**
 * How the model changes an app the person has: by tools, touching only
 * what the request is about.
 */
export const EDIT_PROMPT = `You change a small single-screen phone app the person already has, as they ask. You get the app as it is now: its name, data, ui, and its actions by name and input (not their code).

Change it with the tools, touching only what the request is about:
- set_components / remove_components for the screen. Send each component you change complete. A new component must be listed in its parent's children.
- update_data for a new field a component binds to. The data is the person's: keep what is there.
- set_action / remove_action only when an action's code must change, or a new one is needed. Moving, restyling or relabelling something never needs one. read_action before changing an action's code.
- rename_app only when asked.
Several tools may be called at once. When the app is right, answer in one or two short sentences of Brazilian Portuguese saying what changed, and call no tool. When the request is a question, or not possible with these components, change nothing and say so.

${RULES}`;

function isObject(value: unknown): value is Record<string, unknown> {
  return typeof value === 'object' && value !== null && !Array.isArray(value);
}

/** An app's row as the bundle it is. */
function bundleOf(row: {
  name: string;
  ui: unknown;
  data: unknown;
  actions: Bundle['actions'];
}): Bundle {
  return {
    name: row.name,
    ui: row.ui as Bundle['ui'],
    data: row.data as Record<string, unknown>,
    actions: row.actions,
  };
}

/** What the app reads: every action's bytecode, never its source. */
function snapshot(
  row: { id: string; name: string; ui: unknown; data: unknown; rev: number },
  defs: Bundle['actions'],
  version: number,
): AppSnapshot {
  const actions: AppSnapshot['actions'] = {};
  for (const [name, def] of Object.entries(defs)) {
    actions[name] = { on: def.on ?? 'server', input: def.input, evc: def.evc! };
  }
  return {
    id: row.id,
    name: row.name,
    ui: row.ui as Bundle['ui'],
    data: row.data as Record<string, unknown>,
    actions,
    rev: row.rev,
    version,
  };
}

function summary(row: typeof appVersion.$inferSelect): VersionSummary {
  return {
    n: row.n,
    prompt: row.prompt,
    reply: row.reply,
    changes: row.changes as Changes,
    createdAt: row.createdAt.toISOString(),
  };
}

/**
 * JSON the model wrote. Dart escapes a literal dollar as `\$` ('R\$ 10'),
 * and models copy that into JSON as is, where `\$` is not an escape: it is
 * read as the `\\$` it means, so the Dart gets the `\$` it was written with.
 */
export function parseModelJson(text: string): unknown {
  try {
    return JSON.parse(text);
  } catch (error) {
    const fixed = text.replace(/(?<!\\)((?:\\\\)*)\\\$/g, '$1\\\\$$');
    if (fixed === text) throw error;
    return JSON.parse(fixed);
  }
}
