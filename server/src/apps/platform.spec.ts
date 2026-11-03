import { generatedApp } from '../db/schema';
import { AppSnapshot } from './apps.service';
import { COUNTER, serviceForTest, toolCall } from './service.testing';

const dart = (body: string) =>
  `Future<List> run(Map input, Map event, Function call) async { ${body} }`;

/** A small editor: lists the person's apps and makes new ones. */
const EDITOR = {
  name: 'Editor',
  data: { apps: [] as unknown[], made: '', count: 0, peeked: '' },
  ui: [{ id: 'root', component: 'Column', children: [] }],
  actions: {
    refresh: {
      on: 'platform',
      input: [],
      code: dart(
        "final apps = await call('apps.list', {}); return [{'op': 'replace', 'path': '/apps', 'value': apps}];",
      ),
    },
    make: {
      on: 'platform',
      input: [],
      code: dart(
        "final app = (await call('apps.create', {'prompt': event['prompt'], 'form': 'web'})) as Map; return [{'op': 'replace', 'path': '/made', 'value': app['id']}];",
      ),
    },
    make_two: {
      on: 'platform',
      input: [],
      code: dart(
        "await call('apps.create', {'prompt': 'um'}); await call('apps.create', {'prompt': 'dois'}); return [];",
      ),
    },
    peek: {
      on: 'platform',
      input: [],
      code: dart(
        "final app = (await call('apps.get', {'id': event['id']})) as Map; return [{'op': 'replace', 'path': '/peeked', 'value': app['name']}];",
      ),
    },
    bump: {
      input: ['/count'],
      code: dart(
        "return [{'op': 'replace', 'path': '/count', 'value': (input['/count'] as int) + 1}];",
      ),
    },
  },
};

describe('platform actions', () => {
  let t: Awaited<ReturnType<typeof serviceForTest>>;
  let editor: AppSnapshot;
  let bias: AppSnapshot;
  beforeAll(async () => {
    t = await serviceForTest();
    t.reply(toolCall('create_app', EDITOR));
    editor = await t.apps.create('ana', 'Um editor');
    t.reply(toolCall('create_app', COUNTER));
    bias = await t.apps.create('bia', 'O contador da Bia');
  });
  afterAll(() => t.close());

  const data = async () =>
    (await t.apps.get('ana', editor.id)).data as typeof EDITOR.data;

  it('go out as platform actions, never as the device’s to run first', () => {
    expect(editor.actions.refresh.on).toBe('platform');
  });

  it('see only the person’s own apps', async () => {
    const delta = await t.apps.act('ana', editor.id, 'refresh', {});
    expect(delta.delta[0].op).toBe('replace');
    expect((await data()).apps).toEqual([
      { id: editor.id, name: 'Editor', form: 'mobile', seed: null },
    ]);
    await expect(
      t.apps.act('ana', editor.id, 'peek', { id: bias.id }),
    ).rejects.toThrow('App não encontrado.');
  });

  it('build an app, however long the model takes, while taps go on', async () => {
    t.reply(toolCall('create_app', COUNTER));
    // Longer than a run may take (2 s): the clock stops while it waits.
    t.slowly(2_500);
    const making = t.apps.act('ana', editor.id, 'make', { prompt: 'Contar' });
    await new Promise((done) => setTimeout(done, 300));
    await t.apps.act('ana', editor.id, 'bump', {});
    await making;

    const now = await data();
    expect(now.count).toBe(1);
    const made = await t.apps.get('ana', now.made);
    expect(made.name).toBe('Contador');
    expect(made.form).toBe('web');
  }, 10_000);

  it('reach the model once per tap, and say so', async () => {
    t.reply(toolCall('create_app', COUNTER));
    await expect(t.apps.act('ana', editor.id, 'make_two', {})).rejects.toThrow(
      'one request to the model per tap',
    );
  });

  it('refuse a bad request in the person’s words', async () => {
    await expect(
      t.apps.act('ana', editor.id, 'make', { prompt: '   ' }),
    ).rejects.toThrow('Descreva o app em poucas palavras.');
  });

  it('cannot be run by someone else', async () => {
    await expect(t.apps.act('bia', editor.id, 'refresh', {})).rejects.toThrow();
    const [row] = await t.db.select().from(generatedApp);
    expect(row).toBeDefined();
  });
});
