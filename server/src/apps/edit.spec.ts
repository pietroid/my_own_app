import type {
  ChatMessage,
  ModelOutcome,
  ToolCall,
} from '../assistant/openrouter.client';
import { Bundle, InvalidBundleError } from './bundle';
import { describeApp, diff, EditDraft, runEdit } from './edit';

const ADD =
  "Future<List> run(Map input, Map event, Function call) async { return [{'op': 'add', 'path': '/todos/-', 'value': event['title']}]; }";

const base: Bundle = {
  name: 'Tarefas',
  data: { draft: '', todos: ['a', 'b', 'c', 'd', 'e'] },
  ui: [
    { id: 'root', component: 'Column', children: ['add', 'list'] },
    {
      id: 'add',
      component: 'Button',
      label: 'Adicionar',
      action: { event: { name: 'add_todo' } },
    },
    {
      id: 'list',
      component: 'List',
      children: { componentId: 'item', path: '/todos' },
    },
    { id: 'item', component: 'Text', text: { path: '' } },
  ],
  actions: {
    add_todo: { input: [], code: ADD, evc: 'BYTES', version: 'v1' },
  },
};

let n = 0;
const call = (name: string, args: unknown): ToolCall => ({
  id: `c${++n}`,
  type: 'function',
  function: { name, arguments: JSON.stringify(args) },
});

/** A model that answers with each of [turns] in order. */
function model(...turns: ModelOutcome[]) {
  const seen: ChatMessage[][] = [];
  return {
    seen,
    generate: (messages: ChatMessage[]) => {
      seen.push([...messages]);
      const next = turns.shift();
      if (!next) throw new Error('no more turns');
      return Promise.resolve(next);
    },
  };
}

const compiled = (bundle: Bundle) => Promise.resolve(bundle);

describe('describeApp', () => {
  it('shows the actions by name only, and cuts long lists', () => {
    const text = describeApp(base);
    expect(text).toContain('- add_todo: on server, input []');
    expect(text).not.toContain('Future<List>');
    expect(text).toContain('"…2 more"');
  });
});

describe('EditDraft', () => {
  it('replaces a component by id and adds a new one', () => {
    const draft = new EditDraft(base);
    expect(
      draft.apply(
        call('set_components', {
          components: [
            {
              id: 'add',
              component: 'Button',
              label: 'Nova',
              action: { event: { name: 'add_todo' } },
            },
            { id: 'title', component: 'Text', text: 'Oi' },
          ],
        }),
      ),
    ).toMatch(/^ok/);
    expect(draft.draft.ui.find((c) => c.id === 'add')?.label).toBe('Nova');
    expect(draft.draft.ui).toHaveLength(5);
    expect(base.ui[1].label).toBe('Adicionar');
  });

  it('removes a component from its parent too, but never root', () => {
    const draft = new EditDraft(base);
    expect(draft.apply(call('remove_components', { ids: ['add'] }))).toMatch(
      /^ok/,
    );
    expect(draft.draft.ui[0].children).toEqual(['list']);
    expect(draft.apply(call('remove_components', { ids: ['root'] }))).toMatch(
      /^error/,
    );
  });

  it('reads, writes and removes actions, refusing bad ones', () => {
    const draft = new EditDraft(base);
    expect(draft.apply(call('read_action', { name: 'add_todo' }))).toContain(
      ADD.slice(0, 20),
    );
    expect(draft.apply(call('read_action', { name: 'nope' }))).toMatch(
      /^error/,
    );
    expect(
      draft.apply(
        call('set_action', {
          name: 'clear',
          input: ['/todos'],
          code: 'nothing',
        }),
      ),
    ).toMatch(/^error/);
    expect(
      draft.apply(
        call('set_action', {
          name: 'clear',
          on: 'client',
          input: [],
          code: ADD,
        }),
      ),
    ).toBe('ok: clear');
    expect(draft.draft.actions.clear).toEqual({
      on: 'client',
      input: [],
      code: ADD,
    });
    expect(draft.apply(call('remove_action', { name: 'clear' }))).toMatch(
      /^ok/,
    );
  });

  it('patches the data, and keeps the patch to replay', () => {
    const draft = new EditDraft(base);
    const patch = [{ op: 'add', path: '/filter', value: 'all' }];
    expect(draft.apply(call('update_data', { patch }))).toBe('ok');
    expect(draft.draft.data.filter).toBe('all');
    expect(draft.dataPatches).toEqual([patch]);
    expect(
      draft.apply(
        call('update_data', { patch: [{ op: 'remove', path: '/nope' }] }),
      ),
    ).toMatch(/^error/);
  });
});

describe('diff', () => {
  it('names what changed', () => {
    const after: Bundle = {
      ...base,
      ui: [
        ...base.ui.slice(0, 1),
        { ...base.ui[1], label: 'Nova' },
        ...base.ui.slice(2, 3),
      ],
      actions: { other: { input: [], code: ADD } },
    };
    expect(diff(base, after)).toEqual({
      components: ['add'],
      removed: ['item'],
      actions: ['other'],
      removedActions: ['add_todo'],
      name: false,
      data: false,
    });
  });
});

describe('runEdit', () => {
  it('changes only the screen, keeping the bytecode it did not touch', async () => {
    const fake = model(
      {
        kind: 'tool_calls',
        toolCalls: [
          call('set_components', {
            components: [{ ...base.ui[1], label: 'Nova tarefa' }],
          }),
        ],
      },
      { kind: 'final', content: ' Mudei o texto do botão. ' },
    );
    const result = await runEdit(base, [], fake.generate, compiled);
    expect(result.reply).toBe('Mudei o texto do botão.');
    expect(result.changes.components).toEqual(['add']);
    expect(result.changes.actions).toEqual([]);
    expect(result.bundle.actions.add_todo.evc).toBe('BYTES');
    // The tool's answer went back to the model.
    expect(fake.seen[1].at(-1)).toMatchObject({
      role: 'tool',
      content: 'ok: add',
    });
  });

  it('tells the model what is wrong, once it says it is done', async () => {
    const fake = model(
      {
        kind: 'tool_calls',
        toolCalls: [call('remove_action', { name: 'add_todo' })],
      },
      { kind: 'final', content: 'Pronto.' },
      {
        kind: 'tool_calls',
        toolCalls: [
          call('set_components', {
            components: [{ id: 'add', component: 'Text', text: 'x' }],
          }),
        ],
      },
      { kind: 'final', content: 'Agora sim.' },
    );
    const result = await runEdit(base, [], fake.generate, compiled);
    expect(fake.seen[2].at(-1)?.content).toContain('unknown action add_todo');
    expect(result.reply).toBe('Agora sim.');
    expect(result.changes.removedActions).toEqual(['add_todo']);
  });

  it('gives up when it never ends', async () => {
    const forever = () =>
      Promise.resolve<ModelOutcome>({
        kind: 'tool_calls',
        toolCalls: [call('read_action', { name: 'add_todo' })],
      });
    await expect(runEdit(base, [], forever, compiled)).rejects.toThrow(
      InvalidBundleError,
    );
  });
});
