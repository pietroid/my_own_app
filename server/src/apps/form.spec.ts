import { COUNTER, serviceForTest, toolCall } from './service.testing';

describe('an app’s form', () => {
  let t: Awaited<ReturnType<typeof serviceForTest>>;
  beforeAll(async () => {
    t = await serviceForTest();
  });
  afterAll(() => t.close());

  it('is built for the form asked, and the model is told it', async () => {
    t.reply(toolCall('create_app', COUNTER));
    const app = await t.apps.create('ana', 'Um contador', 'web');

    expect(app.form).toBe('web');
    const asked = t.calls.at(-1)!.messages.at(-1)!.content;
    expect(asked).toContain('for the web');
    expect(asked).toContain('Um contador');
    expect(await t.apps.list('ana')).toEqual([
      { id: app.id, name: 'Contador', form: 'web' },
    ]);
  });

  it('is a phone unless said otherwise', async () => {
    t.reply(toolCall('create_app', COUNTER));
    const app = await t.apps.create('ana', 'Outro contador');
    expect(app.form).toBe('mobile');
    expect(t.calls.at(-1)!.messages.at(-1)!.content).toContain('for a phone');
  });

  it('switches as a version of its own, without the model', async () => {
    t.reply(toolCall('create_app', COUNTER));
    const app = await t.apps.create('ana', 'Mais um');
    const asked = t.calls.length;

    const switched = await t.apps.setForm('ana', app.id, 'web');
    expect(t.calls).toHaveLength(asked);
    expect(switched.app.form).toBe('web');
    expect(switched.app.version).toBe(2);
    expect(switched.version.changes.form).toBe('web');
    expect(switched.app.ui).toEqual(app.ui);

    // Switching to what it is already is no new version.
    const again = await t.apps.setForm('ana', app.id, 'web');
    expect(again.app.version).toBe(2);

    // An earlier version brings its form back, and says so.
    const restored = await t.apps.restore('ana', app.id, 1);
    expect(restored.app.form).toBe('mobile');
    expect(restored.version.changes.form).toBe('mobile');
    expect((await t.apps.version('ana', app.id, 2)).form).toBe('web');
  });

  it('tells the model the form with every change asked', async () => {
    t.reply(toolCall('create_app', COUNTER));
    const app = await t.apps.create('ana', 'Um contador', 'web');
    t.reply({ kind: 'final', content: 'Nada a mudar.' });
    await t.apps.edit('ana', app.id, 'Está bom?');
    const asked = t.calls.at(-1)!.messages.at(-1)!.content;
    expect(asked).toContain('for the web');
  });

  it('is only the owner’s to switch', async () => {
    t.reply(toolCall('create_app', COUNTER));
    const app = await t.apps.create('ana', 'Meu');
    await expect(t.apps.setForm('bia', app.id, 'web')).rejects.toThrow();
  });
});
