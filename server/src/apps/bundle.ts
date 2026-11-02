/**
 * An app as data: what the assistant writes once and the server keeps.
 *
 * - `ui`: the screen, a flat list of components in our own subset of A2UI
 *   v0.9. The one with id `root` is drawn first. Components bind to `data`
 *   by JSON Pointer (`{ "path": "/todos" }`) and name actions; they hold no
 *   values and no code.
 * - `data`: one JSON document, the app's whole state.
 * - `actions`: small Dart functions, `Future<List> run(Map input, Map
 *   event, Function call) async`, given only the paths they declare and
 *   answering with a JSON Patch, compiled once into dart_eval bytecode
 *   (`ActionRunner`). A server action (the default) runs here and its patch
 *   is kept; a client action runs on the device, may `await call(name,
 *   event)` a server one, and its own patch changes only what is on screen.
 */
export interface Bundle {
  name: string;
  ui: Component[];
  data: Record<string, unknown>;
  actions: Record<string, ActionDef>;
}

export interface ActionDef {
  /** Where it runs: here, kept (the default), or on the device, not kept. */
  on?: 'server' | 'client';
  /** The JSON Pointers the action reads; `run` gets them keyed by path. */
  input: string[];
  /** `Future<List> run(Map input, Map event, Function call) async { ... }` */
  code: string;
  /** [code] compiled, base64: what runs, here and on the device. */
  evc?: string;
  /** The runner that compiled [evc]; another one recompiles it. */
  version?: string;
}

export type Component = { id: string; component: string } & Record<
  string,
  unknown
>;

/** The components the app knows how to draw. */
export const COMPONENTS = [
  'Column',
  'Row',
  'List',
  'Text',
  'TextField',
  'CheckBox',
  'Button',
] as const;

/** Raised when a bundle breaks the rules; the message says which. */
export class InvalidBundleError extends Error {}

const POINTER = /^(\/[^/]*)*$/;
const NAME = /^[A-Za-z_][A-Za-z0-9_]{0,63}$/;
const MAX_BYTES = 200_000;

/** Checks [value] is a [Bundle] the app can draw and the server can run. */
export function parseBundle(value: unknown): Bundle {
  const fail = (why: string): never => {
    throw new InvalidBundleError(why);
  };
  if (JSON.stringify(value ?? null).length > MAX_BYTES) fail('too large');

  const bundle = value as Partial<Bundle> | null;
  if (typeof bundle !== 'object' || bundle === null) fail('not an object');
  const { name, ui, data, actions } = bundle as Partial<Bundle>;

  if (typeof name !== 'string' || name.trim() === '' || name.length > 60) {
    fail('name must be a short string');
  }
  if (!isObject(data)) fail('data must be an object');
  if (!isObject(actions)) fail('actions must be an object');
  if (!Array.isArray(ui) || ui.length === 0) fail('ui must be a list');

  const ids = new Set<string>();
  for (const item of ui!) {
    if (!isObject(item) || typeof item.id !== 'string') {
      fail('every component needs an id');
    }
    const component = item;
    if (ids.has(component.id)) fail(`duplicate id ${component.id}`);
    ids.add(component.id);
    if (!(COMPONENTS as readonly string[]).includes(component.component)) {
      fail(`${component.id}: unknown component ${component.component}`);
    }
  }
  if (!ids.has('root')) fail('no component has the id "root"');

  for (const component of ui as Component[]) {
    const children = component.children;
    if (Array.isArray(children)) {
      for (const child of children) {
        if (typeof child !== 'string' || !ids.has(child)) {
          fail(`${component.id}: unknown child ${String(child)}`);
        }
      }
    } else if (isObject(children)) {
      const template = children as { componentId?: unknown; path?: unknown };
      if (typeof template.componentId !== 'string') {
        fail(`${component.id}: a template needs a componentId`);
      }
      if (!ids.has(template.componentId as string)) {
        fail(
          `${component.id}: unknown template ${String(template.componentId)}`,
        );
      }
      if (typeof template.path !== 'string') {
        fail(`${component.id}: a template needs a path`);
      }
    }

    const action = component.action as
      { event?: { name?: unknown } } | undefined;
    if (action !== undefined) {
      const event = action?.event?.name;
      if (typeof event !== 'string' || !(event in actions!)) {
        fail(`${component.id}: unknown action ${String(event)}`);
      }
    }
  }

  for (const [actionName, def] of Object.entries(actions!)) {
    if (!NAME.test(actionName)) fail(`bad action name ${actionName}`);
    const action = def as Partial<ActionDef>;
    if (
      !Array.isArray(action?.input) ||
      !action.input.every((p) => typeof p === 'string' && POINTER.test(p))
    ) {
      fail(`${actionName}: input must be a list of JSON Pointers`);
    }
    if (
      action.on !== undefined &&
      action.on !== 'server' &&
      action.on !== 'client'
    ) {
      fail(`${actionName}: on must be "server" or "client"`);
    }
    if (typeof action.code !== 'string' || !action.code.includes('run')) {
      fail(
        `${actionName}: code must define Future<List> run(Map input, Map event, Function call) async`,
      );
    }
  }

  return {
    name: name!.trim(),
    ui: ui as Component[],
    data: data!,
    // Only what the model may write: the bytecode is ours to add.
    actions: Object.fromEntries(
      Object.entries(actions!).map(([name, def]) => {
        const { on, input, code } = def;
        return [name, on === undefined ? { input, code } : { on, input, code }];
      }),
    ),
  };
}

function isObject(value: unknown): value is Record<string, unknown> {
  return typeof value === 'object' && value !== null && !Array.isArray(value);
}
