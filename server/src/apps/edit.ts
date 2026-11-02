import { applyPatch, Operation, validate } from 'fast-json-patch';
import type {
  ChatMessage,
  ModelOutcome,
  ToolCall,
  ToolDefinition,
} from '../assistant/openrouter.client';
import {
  ActionDef,
  Bundle,
  Component,
  COMPONENTS,
  InvalidBundleError,
  parseBundle,
} from './bundle';
import { dropReferences } from './catalog';

/**
 * Changing an app the person already has, by tools, one piece at a time.
 *
 * The model sees the screen and the data, but of the actions only their
 * names and what they read: their Dart is read with `read_action` when a
 * change needs it, and written with `set_action` only when it changes. A
 * request to move a button costs the button, not every action's code.
 */

/** What one version changed, against the one before it. */
export interface Changes {
  /** Components added or changed, by id. */
  components: string[];
  /** Components removed, by id. */
  removed: string[];
  /** Actions added or changed, by name. */
  actions: string[];
  /** Actions removed, by name. */
  removedActions: string[];
  /** Whether the app's name changed. */
  name: boolean;
  /** Whether the shape of the data changed (its top-level keys). */
  data: boolean;
  /** When the version brought an earlier one back: that one's number. */
  restoredFrom?: number;
  /** When the version switched what the app is made for: the new form. */
  form?: 'mobile' | 'web';
}

/** What [after] changed against [before]. */
export function diff(before: Bundle, after: Bundle): Changes {
  const byId = (ui: Component[]) =>
    new Map(ui.map((c) => [c.id, JSON.stringify(c)]));
  const was = byId(before.ui);
  const now = byId(after.ui);
  const source = (def: ActionDef) =>
    JSON.stringify([def.on ?? 'server', def.input, def.code]);
  const keys = (data: Record<string, unknown>) =>
    Object.keys(data).sort().join();

  return {
    components: [...now]
      .filter(([id, c]) => was.get(id) !== c)
      .map(([id]) => id),
    removed: [...was.keys()].filter((id) => !now.has(id)),
    actions: Object.entries(after.actions)
      .filter(([name, def]) => {
        const old = Object.hasOwn(before.actions, name)
          ? before.actions[name]
          : undefined;
        return old === undefined || source(old) !== source(def);
      })
      .map(([name]) => name),
    removedActions: Object.keys(before.actions).filter(
      (name) => !Object.hasOwn(after.actions, name),
    ),
    name: before.name !== after.name,
    data: keys(before.data) !== keys(after.data),
  };
}

/** Whether [changes] changed anything at all. */
export function changedAnything(changes: Changes): boolean {
  return (
    changes.components.length +
      changes.removed.length +
      changes.actions.length +
      changes.removedActions.length >
      0 ||
    changes.name ||
    changes.data
  );
}

/**
 * An app being changed: every tool call lands here, on a copy, and is
 * answered with what happened. Nothing is kept until the whole app checks.
 */
export class EditDraft {
  readonly draft: Bundle;
  /** The data patches the model made, to replay on fresher data. */
  readonly dataPatches: Operation[][] = [];

  constructor(readonly base: Bundle) {
    this.draft = structuredClone(base);
  }

  /** Runs one tool call; answers what the model is told back. */
  apply(call: ToolCall): string {
    let args: Record<string, unknown>;
    try {
      const parsed = JSON.parse(call.function.arguments) as unknown;
      if (!isObject(parsed)) throw new Error();
      args = parsed;
    } catch {
      return 'error: the arguments are not a JSON object';
    }
    try {
      switch (call.function.name) {
        case 'set_components':
          return this._setComponents(args.components);
        case 'remove_components':
          return this._removeComponents(args.ids);
        case 'update_data':
          return this._updateData(args.patch);
        case 'read_action':
          return this._readAction(args.name);
        case 'set_action':
          return this._setAction(args);
        case 'remove_action':
          return this._removeAction(args.name);
        case 'rename_app':
          return this._rename(args.name);
        default:
          return `error: no tool ${call.function.name}`;
      }
    } catch (error) {
      return `error: ${error instanceof Error ? error.message : String(error)}`;
    }
  }

  private _setComponents(value: unknown): string {
    if (!Array.isArray(value) || value.length === 0) {
      throw new Error('components must be a non-empty list');
    }
    for (const item of value) {
      if (!isObject(item) || typeof item.id !== 'string' || item.id === '') {
        throw new Error('every component needs an id');
      }
      if (
        !(COMPONENTS as readonly string[]).includes(item.component as string)
      ) {
        throw new Error(
          `${item.id}: unknown component ${String(item.component)}`,
        );
      }
    }
    for (const component of value as Component[]) {
      const at = this.draft.ui.findIndex((c) => c.id === component.id);
      if (at === -1) this.draft.ui.push(component);
      else this.draft.ui[at] = component;
    }
    return `ok: ${(value as Component[]).map((c) => c.id).join(', ')}`;
  }

  private _removeComponents(value: unknown): string {
    if (!Array.isArray(value) || !value.every((id) => typeof id === 'string')) {
      throw new Error('ids must be a list of component ids');
    }
    const ids = new Set(value);
    if (ids.has('root')) throw new Error('root cannot be removed');
    this.draft.ui = this.draft.ui.filter((c) => !ids.has(c.id));
    // A parent that drew a removed child stops drawing it.
    for (const component of this.draft.ui) dropReferences(component, ids);
    return `ok: removed ${[...ids].join(', ')}`;
  }

  private _updateData(value: unknown): string {
    if (!Array.isArray(value))
      throw new Error('patch must be a JSON Patch list');
    const patch = value as Operation[];
    const invalid = validate(patch, this.draft.data);
    if (invalid) throw new Error(invalid.message);
    this.draft.data = applyPatch(
      this.draft.data,
      patch,
      false,
      false,
    ).newDocument;
    this.dataPatches.push(patch);
    return 'ok';
  }

  private _readAction(name: unknown): string {
    const def = this._action(name);
    return JSON.stringify({
      on: def.on ?? 'server',
      input: def.input,
      code: def.code,
    });
  }

  private _setAction(args: Record<string, unknown>): string {
    const { name, on, input, code } = args;
    if (typeof name !== 'string') throw new Error('name must be a string');
    const def: ActionDef = {
      ...(on === 'client' || on === 'platform' ? { on } : {}),
      input: input as string[],
      code: code as string,
    };
    // Checked as part of a whole app, with only this action.
    parseBundle({
      name: 'x',
      ui: [{ id: 'root', component: 'Column', children: [] }],
      data: {},
      actions: { [name]: def },
    });
    this.draft.actions[name] = def;
    return `ok: ${name}`;
  }

  private _removeAction(name: unknown): string {
    this._action(name);
    delete this.draft.actions[name as string];
    return `ok: removed ${String(name)}`;
  }

  private _rename(name: unknown): string {
    if (typeof name !== 'string' || name.trim() === '' || name.length > 60) {
      throw new Error('name must be a short string');
    }
    this.draft.name = name.trim();
    return 'ok';
  }

  private _action(name: unknown): ActionDef {
    if (typeof name !== 'string' || !Object.hasOwn(this.draft.actions, name)) {
      throw new Error(`no action ${String(name)}`);
    }
    return this.draft.actions[name];
  }
}

/** What an edit came to: the new app, what changed, and the reply. */
export interface EditResult {
  bundle: Bundle;
  changes: Changes;
  reply: string;
  dataPatches: Operation[][];
}

/** How many model calls one edit may make, fixing its own errors included. */
export const MAX_EDIT_ROUNDS = 8;

/**
 * Talks to the model until it answers in words, applying each tool call to
 * a draft; then checks the whole app, and gives the model one more round
 * per error it made. [check] compiles what changed and says why it fails.
 */
export async function runEdit(
  base: Bundle,
  messages: ChatMessage[],
  generate: (messages: ChatMessage[]) => Promise<ModelOutcome>,
  check: (bundle: Bundle, changes: Changes) => Promise<Bundle>,
  { deadline = Infinity }: { deadline?: number } = {},
): Promise<EditResult> {
  const draft = new EditDraft(base);
  const talk = [...messages];

  for (let round = 0; round < MAX_EDIT_ROUNDS; round++) {
    const outcome = await generate(talk);
    if (outcome.kind === 'tool_calls') {
      talk.push({
        role: 'assistant',
        content: '',
        tool_calls: outcome.toolCalls,
      });
      for (const call of outcome.toolCalls) {
        talk.push({
          role: 'tool',
          tool_call_id: call.id,
          content: draft.apply(call),
        });
      }
      if (Date.now() > deadline) break;
      continue;
    }

    try {
      const bundle = parseBundle(draft.draft);
      // parseBundle keeps only what the model writes; bytecode comes back
      // for the actions the edit did not touch.
      for (const [name, def] of Object.entries(bundle.actions)) {
        const old = base.actions[name];
        if (old && old.code === def.code) {
          bundle.actions[name] = { ...def, evc: old.evc, version: old.version };
        }
      }
      const changes = diff(base, bundle);
      return {
        bundle: await check(bundle, changes),
        changes,
        reply: outcome.content.trim(),
        dataPatches: draft.dataPatches,
      };
    } catch (error) {
      if (!(error instanceof InvalidBundleError) || Date.now() > deadline) {
        throw error;
      }
      talk.push(
        { role: 'assistant', content: outcome.content },
        {
          role: 'user',
          content: `The app is invalid: ${error.message}. Fix it with the tools, then answer again.`,
        },
      );
    }
  }
  throw new InvalidBundleError('the edit did not finish');
}

/** The tools an edit has, and nothing else. */
export const EDIT_TOOLS: ToolDefinition[] = [
  {
    type: 'function',
    function: {
      name: 'set_components',
      description:
        "Adds components, or replaces whole components with the same id. Send each component complete. A new component must also be listed in its parent's children.",
      parameters: {
        type: 'object',
        properties: {
          components: { type: 'array', items: { type: 'object' } },
        },
        required: ['components'],
      },
    },
  },
  {
    type: 'function',
    function: {
      name: 'remove_components',
      description:
        'Removes components by id; their parents stop listing them. Remove their own children too.',
      parameters: {
        type: 'object',
        properties: { ids: { type: 'array', items: { type: 'string' } } },
        required: ['ids'],
      },
    },
  },
  {
    type: 'function',
    function: {
      name: 'update_data',
      description:
        "Changes the app's data with a JSON Patch (RFC 6902): a new field a component binds to, a default. The data is the person's: never drop what they wrote unless asked.",
      parameters: {
        type: 'object',
        properties: { patch: { type: 'array', items: { type: 'object' } } },
        required: ['patch'],
      },
    },
  },
  {
    type: 'function',
    function: {
      name: 'read_action',
      description: "Answers an action's Dart code. Read it before changing it.",
      parameters: {
        type: 'object',
        properties: { name: { type: 'string' } },
        required: ['name'],
      },
    },
  },
  {
    type: 'function',
    function: {
      name: 'set_action',
      description:
        'Adds an action, or replaces the one with that name. Only when its code must change; a screen change never needs one.',
      parameters: {
        type: 'object',
        properties: {
          name: { type: 'string' },
          on: { type: 'string', enum: ['server', 'client', 'platform'] },
          input: { type: 'array', items: { type: 'string' } },
          code: {
            type: 'string',
            description:
              'Dart: Future<List> run(Map input, Map event, Function call) async { ... }',
          },
        },
        required: ['name', 'input', 'code'],
      },
    },
  },
  {
    type: 'function',
    function: {
      name: 'remove_action',
      description: 'Removes an action no component uses any more.',
      parameters: {
        type: 'object',
        properties: { name: { type: 'string' } },
        required: ['name'],
      },
    },
  },
  {
    type: 'function',
    function: {
      name: 'rename_app',
      description: "Changes the app's name.",
      parameters: {
        type: 'object',
        properties: { name: { type: 'string' } },
        required: ['name'],
      },
    },
  },
];

/**
 * The app as the model reads it for an edit: the screen and the data whole
 * (a long list cut to its first items), the actions by name and input only.
 */
export function describeApp(bundle: Bundle): string {
  const actions = Object.entries(bundle.actions)
    .map(
      ([name, def]) =>
        `- ${name}: on ${def.on ?? 'server'}, input ${JSON.stringify(def.input)}`,
    )
    .join('\n');
  return [
    `name: ${bundle.name}`,
    `data: ${JSON.stringify(trimmed(bundle.data))}`,
    `ui: ${JSON.stringify(bundle.ui)}`,
    `actions (their code is not shown; read_action reads one):\n${actions || '(none)'}`,
  ].join('\n');
}

/** [value] with every array past 3 items cut, saying how many were left. */
function trimmed(value: unknown): unknown {
  if (Array.isArray(value)) {
    const head = value.slice(0, 3).map(trimmed);
    return value.length > 3 ? [...head, `…${value.length - 3} more`] : head;
  }
  if (isObject(value)) {
    return Object.fromEntries(
      Object.entries(value).map(([key, item]) => [key, trimmed(item)]),
    );
  }
  return value;
}

function isObject(value: unknown): value is Record<string, unknown> {
  return typeof value === 'object' && value !== null && !Array.isArray(value);
}
