import { InvalidBundleError, parseBundle } from './bundle';
import { dropReferences, references } from './catalog';

/** One app that uses every component of the catalog. */
const everything = {
  name: 'Tudo',
  data: {
    page: '',
    tab: 'Lista',
    open: false,
    on: true,
    level: 3,
    chosen: [] as string[],
    when: '',
    note: '',
  },
  ui: [
    {
      id: 'root',
      component: 'Pages',
      current: { path: '/page' },
      pages: { home: 'home', about: 'about' },
    },
    {
      id: 'home',
      component: 'Column',
      justify: 'start',
      align: 'stretch',
      children: ['title', 'tabs', 'divider', 'sheet'],
    },
    { id: 'title', component: 'Text', text: 'Olá', variant: 'h1' },
    {
      id: 'tabs',
      component: 'Tabs',
      value: { path: '/tab' },
      tabs: [
        { title: 'Lista', child: 'card' },
        { title: 'Ajustes', child: 'inputs' },
      ],
    },
    {
      id: 'card',
      component: 'Card',
      child: 'row',
      action: { event: { name: 'open_sheet' } },
    },
    {
      id: 'row',
      component: 'Row',
      children: ['icon', 'pic', 'badge', 'msg'],
    },
    { id: 'icon', component: 'Icon', name: 'star', tone: 'accent' },
    {
      id: 'pic',
      component: 'Image',
      url: 'https://example.com/a.png',
      variant: 'avatar',
    },
    { id: 'badge', component: 'Badge', text: '3', weight: 1 },
    { id: 'msg', component: 'Message', text: 'Oi', role: 'me', inset: 1 },
    { id: 'divider', component: 'Divider' },
    {
      id: 'inputs',
      component: 'Column',
      children: ['field', 'check', 'switch', 'pick', 'slider', 'date', 'go'],
    },
    {
      id: 'field',
      component: 'TextField',
      label: 'Nota',
      value: { path: '/note' },
      variant: 'longText',
    },
    {
      id: 'check',
      component: 'CheckBox',
      label: 'Feito',
      value: { path: '/on' },
    },
    {
      id: 'switch',
      component: 'Switch',
      label: 'Ligado',
      value: { path: '/on' },
      visible: { path: '/on' },
    },
    {
      id: 'pick',
      component: 'ChoicePicker',
      options: [{ label: 'A', value: 'a' }],
      value: { path: '/chosen' },
    },
    {
      id: 'slider',
      component: 'Slider',
      min: 0,
      max: 10,
      value: { path: '/level' },
    },
    {
      id: 'date',
      component: 'DateTimeInput',
      value: { path: '/when' },
      enableDate: true,
    },
    {
      id: 'go',
      component: 'Button',
      label: 'Sobre',
      icon: 'forward',
      variant: 'primary',
      action: { event: { name: 'go_about' } },
    },
    {
      id: 'sheet',
      component: 'Modal',
      open: { path: '/open' },
      content: 'about',
    },
    { id: 'about', component: 'Text', text: 'Sobre' },
  ],
  actions: {
    open_sheet: {
      on: 'client',
      input: [],
      code: "Future<List> run(Map input, Map event, Function call) async { return [{'op': 'replace', 'path': '/open', 'value': true}]; }",
    },
    go_about: {
      on: 'client',
      input: [],
      code: "Future<List> run(Map input, Map event, Function call) async { return [{'op': 'replace', 'path': '/page', 'value': 'about'}]; }",
    },
  },
};

const replacing = (id: string, next: Record<string, unknown>): unknown[] =>
  everything.ui.map((c) => (c.id === id ? { ...c, ...next } : c));

describe('the catalog', () => {
  it('accepts an app that uses every component', () => {
    expect(parseBundle(everything).ui).toHaveLength(everything.ui.length);
  });

  it.each([
    ['an unknown icon', replacing('icon', { name: 'unicorn' })],
    ['an unknown button icon', replacing('go', { icon: 'sparkles' })],
    ['an image off https', replacing('pic', { url: 'http://x.com/a.png' })],
    ['a tab without a child', replacing('tabs', { tabs: [{ title: 'A' }] })],
    ['a missing tab child', replacing('tabs', { tabs: [{ child: 'nope' }] })],
    ['a missing page', replacing('root', { pages: { home: 'nope' } })],
    ['a missing card child', replacing('card', { child: 'nope' })],
    ['a modal without content', replacing('sheet', { content: undefined })],
  ])('refuses %s', (_, ui) => {
    expect(() => parseBundle({ ...everything, ui })).toThrow(
      InvalidBundleError,
    );
  });

  it('accepts an icon bound to the data', () => {
    const ui = replacing('icon', { name: { path: '/icon' } });
    expect(() => parseBundle({ ...everything, ui })).not.toThrow();
  });

  it('lists and forgets every kind of reference', () => {
    const tabs = everything.ui.find((c) => c.id === 'tabs')!;
    const pages = everything.ui.find((c) => c.id === 'root')!;
    expect(references(tabs)).toEqual(['card', 'inputs']);
    expect(references(pages)).toEqual(['home', 'about']);

    const gone = new Set(['card', 'about']);
    const t = structuredClone(tabs) as Record<string, unknown>;
    const p = structuredClone(pages) as Record<string, unknown>;
    const s = structuredClone(
      everything.ui.find((c) => c.id === 'sheet')!,
    ) as Record<string, unknown>;
    dropReferences(t, gone);
    dropReferences(p, gone);
    dropReferences(s, gone);
    expect(references(t)).toEqual(['inputs']);
    expect(p.pages).toEqual({ home: 'home' });
    expect(s.content).toBeUndefined();
  });
});
