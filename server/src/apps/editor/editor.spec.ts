import { parseBundle } from '../bundle';
import { AppSnapshot } from '../apps.service';
import { COUNTER, serviceForTest, toolCall } from '../service.testing';
import { eq } from 'drizzle-orm';
import { generatedApp } from '../../db/schema';
import { EDITOR, EDITOR_VERSION } from './editor';

type Row = Record<string, unknown>;

describe('My Own App Editor', () => {
  let t: Awaited<ReturnType<typeof serviceForTest>>;
  let editor: AppSnapshot;
  let counter: AppSnapshot;
  beforeAll(async () => {
    t = await serviceForTest();
    editor = await t.apps.editor('ana');
    t.reply(toolCall('create_app', COUNTER));
    counter = await t.apps.create('ana', 'Um contador');
  }, 60_000);
  afterAll(() => t.close());

  const data = async () => (await t.apps.get('ana', editor.id)).data;

  /** Runs a client action of the editor, as the device would. */
  const client = async (
    name: string,
    input: Record<string, unknown>,
    event: Record<string, unknown> = {},
  ) => (await t.runner.run(editor.actions[name].evc, input, event)) as Row[];

  it('is a valid app whose every action compiles', () => {
    expect(() => parseBundle(EDITOR)).not.toThrow();
    for (const def of Object.values(editor.actions)) {
      expect(def.evc.length).toBeGreaterThan(0);
    }
    expect(editor.actions.start.on).toBe('platform');
    expect(editor.actions.pick.on).toBe('client');
  });

  it('is made once per person, and comes first in their list', async () => {
    expect((await t.apps.editor('ana')).id).toBe(editor.id);
    expect((await t.apps.editor('bia')).id).not.toBe(editor.id);
    const list = await t.apps.list('ana');
    expect(list[0]).toMatchObject({ id: editor.id, seed: 'editor' });
    expect(list[1]).toMatchObject({ id: counter.id, seed: null });
  });

  it('opens an app: its tree, its conversation, its versions', async () => {
    await t.apps.act('ana', editor.id, 'start', { id: counter.id });
    const now = await data();
    expect(now.editing).toBe(counter.id);
    expect(now.title).toBe('Contador');
    expect(now.formChoice).toEqual(['mobile']);
    expect(now.tree).toEqual([
      expect.objectContaining({ id: 'root', depth: 0, label: 'Coluna' }),
      expect.objectContaining({ id: 'n', depth: 1, icon: 'component:Text' }),
      expect.objectContaining({ id: 'more', depth: 1, label: 'Botão' }),
    ]);
    expect(now.turns).toEqual([
      { role: 'me', text: 'Um contador', caption: '' },
      { role: 'other', text: 'Criei o app.', caption: 'Versão 1 · atual' },
    ]);
    expect(now.versionRows).toEqual([
      { n: 1, label: 'Versão 1', caption: 'Um contador', current: true },
    ]);
  });

  it('asks for a change, and shows the new version', async () => {
    t.reply({ kind: 'final', content: 'Nada mudou, está bom.' });
    await t.apps.act('ana', editor.id, 'send', {
      id: counter.id,
      prompt: 'Está bom?',
      focus: 'more',
      picked: 'more',
    });
    const asked = t.calls.at(-1)!.messages.at(-1)!.content;
    expect(asked).toContain('selected the component "more"');
    const now = await data();
    expect(now.revision).toBe(1);
    expect((now.turns as Row[]).at(-1)).toEqual({
      role: 'other',
      text: 'Nada mudou, está bom.',
      caption: 'Versão 2 · atual',
    });
    expect((now.tree as Row[]).find((r) => r.id === 'more')!.selected).toBe(
      true,
    );
  });

  it('switches the app to web, and brings a version back', async () => {
    await t.apps.act('ana', editor.id, 'set_form', {
      id: counter.id,
      value: ['web'],
    });
    let now = await data();
    expect(now.formChoice).toEqual(['web']);
    expect((now.turns as Row[]).at(-1)!.text).toBe('Agora é um app para web.');

    await t.apps.act('ana', editor.id, 'restore', { id: counter.id, n: 1 });
    now = await data();
    expect(now.formChoice).toEqual(['mobile']);
    expect((now.turns as Row[]).at(-1)!.text).toBe(
      'Trouxe de volta a versão 1.',
    );
    expect(now.revision).toBe(3);
  });

  it('picks a component, and asks about it', async () => {
    const app = (await data()).app;
    const picked = await client(
      'pick',
      { '/app': app },
      { componentId: 'more' },
    );
    const rows = picked.find((op) => op.path === '/pickedRows')!.value as Row[];
    expect(rows).toEqual(
      expect.arrayContaining([
        { name: 'tipo', value: 'Botão' },
        { name: 'label', value: 'Mais um' },
        { name: 'ação', value: 'increment · salva' },
        { name: 'lê', value: '/count' },
      ]),
    );
    const asked = await client('ask_change', { '/picked': 'more' });
    expect(asked).toContainEqual({
      op: 'replace',
      path: '/focusLabel',
      value: 'Sobre: more',
    });
  });

  it('looks at an earlier version, and back at the current one', async () => {
    const history = (await data()).history as Row;
    const looked = await client('view', { '/history': history }, { n: 1 });
    expect(looked).toContainEqual({
      op: 'replace',
      path: '/viewing',
      value: 1,
    });
    const current = await client(
      'view',
      { '/history': history },
      { n: history.current },
    );
    expect(current).toContainEqual({
      op: 'replace',
      path: '/viewing',
      value: null,
    });
  });

  it('opens itself: the editor is a web project like any other', async () => {
    expect(editor.form).toBe('web');
    await t.apps.act('ana', editor.id, 'start', { id: editor.id });
    const now = await data();
    expect(now.title).toBe('My Own App Editor');
    expect(now.formChoice).toEqual(['web']);
    const tree = now.tree as Row[];
    expect(tree[0]).toMatchObject({ id: 'root', label: 'Tela' });
    // Every pane is in the tree: the slots and the trailing ids are read.
    for (const id of [
      'topBar',
      'pickButton',
      'chatPanel',
      'composer',
      'surface',
    ]) {
      expect(tree.some((r) => r.id === id)).toBe(true);
    }
  });

  it('comes back as the original, as a new version', async () => {
    const reset = await t.apps.resetEditor('ana');
    expect(reset.app.id).toBe(editor.id);
    expect(reset.app.version).toBe(2);
    expect(reset.app.data.editing).toBe('');
    expect(reset.version.reply).toBe('O editor voltou a ser o original.');
    expect(reset.app.form).toBe('web');
  });

  it('brings a copy made from an older editor up to this one', async () => {
    await t.apps.act('ana', editor.id, 'start', { id: counter.id });
    await t.db
      .update(generatedApp)
      .set({ data: { editorVersion: 1 } })
      .where(eq(generatedApp.id, editor.id));
    const upgraded = await t.apps.editor('ana');
    expect(upgraded.id).toBe(editor.id);
    expect(upgraded.data.editorVersion).toBe(EDITOR_VERSION);
    const history = await t.apps.history('ana', editor.id);
    expect(history.versions.at(-1)!.reply).toBe('O editor foi atualizado.');
    // Up to date: opening it again makes no other version.
    await t.apps.editor('ana');
    expect((await t.apps.history('ana', editor.id)).versions).toHaveLength(
      history.versions.length,
    );
  });
});
