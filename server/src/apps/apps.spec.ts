import { applyPatch, Operation } from 'fast-json-patch';
import { InvalidBundleError, parseBundle } from './bundle';
import { BUILD_PROMPT, parseModelJson } from './apps.service';
import { ActionFailedError, ActionRunner } from './runner';

const todo = {
  name: 'Tarefas',
  data: { draft: '', todos: [] as unknown[] },
  ui: [
    { id: 'root', component: 'Column', children: ['add', 'list'] },
    {
      id: 'add',
      component: 'Button',
      label: 'Adicionar',
      action: {
        event: { name: 'add_todo', context: { title: { path: '/draft' } } },
      },
    },
    {
      id: 'list',
      component: 'List',
      children: { componentId: 'item', path: '/todos' },
    },
    { id: 'item', component: 'Text', text: { path: 'title' } },
  ],
  actions: {
    add_todo: {
      input: ['/todos'],
      code: "Future<List> run(Map input, Map event, Function call) async { return [{'op': 'add', 'path': '/todos/-', 'value': {'title': event['title'], 'n': (input['/todos'] as List).length}}]; }",
    },
  },
};

describe('parseBundle', () => {
  it('accepts a to-do list', () => {
    expect(parseBundle(todo).name).toBe('Tarefas');
  });

  it('keeps no bytecode the model wrote', () => {
    const bundle = parseBundle({
      ...todo,
      actions: {
        add_todo: { ...todo.actions.add_todo, evc: 'AAAA', version: 'x' },
      },
    });
    expect(bundle.actions.add_todo).toEqual(todo.actions.add_todo);
  });

  it.each([
    ['no root', { ...todo, ui: todo.ui.slice(1) }],
    [
      'an unknown component',
      { ...todo, ui: [...todo.ui, { id: 'x', component: 'Video' }] },
    ],
    ['an unknown action', { ...todo, actions: {} }],
    [
      'an action that runs nowhere',
      {
        ...todo,
        actions: { add_todo: { ...todo.actions.add_todo, on: 'moon' } },
      },
    ],
    [
      'a missing child',
      {
        ...todo,
        ui: [{ id: 'root', component: 'Column', children: ['nope'] }],
      },
    ],
  ])('refuses %s', (_, bundle) => {
    expect(() => parseBundle(bundle)).toThrow(InvalidBundleError);
  });
});

describe('parseModelJson', () => {
  it('reads a Dart dollar the model left unescaped', () => {
    // What arrives: {"code": "'R\$ ' + t"}, with a bare \$ in the JSON.
    const text = String.raw`{"code": "'R\$ ' + t", "ok": "a\\$b"}`;
    expect(parseModelJson(text)).toEqual({
      code: String.raw`'R\$ ' + t`,
      ok: String.raw`a\$b`,
    });
  });

  it('still refuses what is not JSON', () => {
    expect(() => parseModelJson('{"a": ')).toThrow();
  });
});

describe('ActionRunner', () => {
  const runner = new ActionRunner();
  afterAll(() => runner.onModuleDestroy());

  const run = async (
    code: string,
    input: Record<string, unknown> = {},
    event: Record<string, unknown> = {},
  ) => runner.run((await runner.compile(code)).evc, input, event);

  it('answers with the patch, given only its input', async () => {
    const delta = (await run(
      todo.actions.add_todo.code,
      { '/todos': [1, 2] },
      { title: 'Pão' },
    )) as Operation[];
    expect(
      applyPatch({ todos: [1, 2] }, delta, true, false).newDocument,
    ).toEqual({ todos: [1, 2, { title: 'Pão', n: 2 }] });
  });

  it('cannot reach files, the network or processes', async () => {
    await expect(
      run(`import 'dart:io';
Future<List> run(Map i, Map e, Function c) async {
  return [await File('/etc/hosts').readAsString()];
}`),
    ).rejects.toThrow(ActionFailedError);
    await expect(
      run(`import 'dart:io';
Future<List> run(Map i, Map e, Function c) async {
  return [(await Process.run('ls', [])).stdout];
}`),
    ).rejects.toThrow(ActionFailedError);
  });

  it('stops a loop', async () => {
    await expect(
      run(
        'Future<List> run(Map i, Map e, Function c) async { var n = 0; while (true) { n++; } }',
      ),
    ).rejects.toThrow(/steps/);
  });

  it('writes a dollar sign', async () => {
    expect(
      await run(
        String.raw`Future<List> run(Map i, Map e, Function c) async { final total = 12; return ['R\$ ' + total.toString()]; }`,
      ),
    ).toEqual(['R$ 12']);
  });

  it('says why code does not compile', async () => {
    await expect(
      runner.compile(
        'Future<List> run(Map i, Map e, Function c) async { return [; }',
      ),
    ).rejects.toThrow(ActionFailedError);
  });

  it('starts again after the process dies', async () => {
    await runner.version();
    (
      runner as unknown as { _process: { kill(s: string): void } }
    )._process.kill('SIGKILL');
    await new Promise((resolve) => setTimeout(resolve, 50));
    expect(
      await run(todo.actions.add_todo.code, { '/todos': [] }),
    ).toHaveLength(1);
  });

  it("runs the build prompt's own example", async () => {
    const example = JSON.parse(
      BUILD_PROMPT.slice(BUILD_PROMPT.indexOf('Example, a to-do list:') + 22),
    ) as unknown;
    const bundle = parseBundle(example);
    expect(
      await run(bundle.actions.add_todo.code, {}, { title: ' Pão ' }),
    ).toEqual([
      { op: 'add', path: '/todos/-', value: { title: 'Pão', done: false } },
      { op: 'replace', path: '/draft', value: '' },
    ]);
    expect(
      await run(
        bundle.actions.toggle_todo.code,
        {},
        { itemPath: '/todos/0', done: false },
      ),
    ).toEqual([{ op: 'replace', path: '/todos/0/done', value: true }]);
    expect(
      await run(bundle.actions.remove_todo.code, {}, { itemPath: '/todos/0' }),
    ).toEqual([{ op: 'remove', path: '/todos/0' }]);
  });
});
