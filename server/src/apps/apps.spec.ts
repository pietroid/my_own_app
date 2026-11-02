import { applyPatch, Operation } from 'fast-json-patch';
import { InvalidBundleError, parseBundle } from './bundle';
import { ActionFailedError, checkAction, runAction } from './sandbox';

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
      code: "function run(input, event) { return [{op: 'add', path: '/todos/-', value: {title: event.title, n: input['/todos'].length}}]; }",
    },
  },
};

describe('parseBundle', () => {
  it('accepts a to-do list', () => {
    expect(parseBundle(todo).name).toBe('Tarefas');
  });

  it.each([
    ['no root', { ...todo, ui: todo.ui.slice(1) }],
    [
      'an unknown component',
      { ...todo, ui: [...todo.ui, { id: 'x', component: 'Video' }] },
    ],
    ['an unknown action', { ...todo, actions: {} }],
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

describe('runAction', () => {
  it('answers with the patch, given only its input', () => {
    const delta = runAction(
      todo.actions.add_todo.code,
      { '/todos': [] },
      { title: 'Pão' },
    ) as Operation[];
    expect(applyPatch(todo.data, delta, true, false).newDocument).toEqual({
      draft: '',
      todos: [{ title: 'Pão', n: 0 }],
    });
  });

  it('cannot reach the server', () => {
    expect(() =>
      runAction("function run() { return require('fs'); }", {}, {}),
    ).toThrow(ActionFailedError);
    expect(() =>
      runAction('function run() { return process.env; }', {}, {}),
    ).toThrow(ActionFailedError);
  });

  it('stops a loop', () => {
    expect(() =>
      runAction('function run() { while (true) {} }', {}, {}),
    ).toThrow(ActionFailedError);
  });

  it('checks that run exists', () => {
    expect(() => checkAction('const x = 1;')).toThrow(ActionFailedError);
    expect(() => checkAction(todo.actions.add_todo.code)).not.toThrow();
  });
});
