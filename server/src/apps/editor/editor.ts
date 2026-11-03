import type { ActionDef, Bundle, Component } from '../bundle';

/**
 * My Own App Editor: the studio, as an app. Every account gets a copy
 * (`seed: 'editor'`), drawn by the same renderer and run by the same runner
 * as any app, and changed by talking to it like any app.
 *
 * It edits the app at `/editing` (the page opens it with `start {id}`):
 * a Surface runs that app live; the conversation is its versions; the tree
 * and the picked component's menu are its `ui`, read through platform calls
 * (`platform.ts`). Written by hand, not by the model; `npm run
 * apps:rebuild -- --editor` (or Restaurar editor) brings every copy back to
 * this one.
 */

/** Bumped when this file changes: a copy older than it can be reset. */
export const EDITOR_VERSION = 1;

/**
 * Dart every action shares (the runner has no imports): turning the edited
 * app and its history into the rows the editor draws.
 */
const HELPERS = `
String kindName(String t) {
  switch (t) {
    case 'Column': return 'Coluna';
    case 'Row': return 'Linha';
    case 'List': return 'Lista';
    case 'Card': return 'Cartão';
    case 'Divider': return 'Divisória';
    case 'Tabs': return 'Abas';
    case 'Pages': return 'Páginas';
    case 'Modal': return 'Folha';
    case 'Text': return 'Texto';
    case 'Icon': return 'Ícone';
    case 'Image': return 'Imagem';
    case 'Badge': return 'Selo';
    case 'Message': return 'Mensagem';
    case 'TextField': return 'Campo';
    case 'CheckBox': return 'Caixa de seleção';
    case 'Switch': return 'Interruptor';
    case 'ChoicePicker': return 'Escolha';
    case 'Slider': return 'Controle deslizante';
    case 'DateTimeInput': return 'Data e hora';
    case 'Button': return 'Botão';
    case 'Surface': return 'App';
  }
  return t;
}

String placeOf(Object? on) {
  if (on == 'client') return 'só na tela';
  if (on == 'platform') return 'na plataforma';
  return 'salva';
}

List refsOf(Map c) {
  // Every value cast before it is read: the interpreter does not narrow
  // after \`is\`, and reads an untyped loop variable's [] as a list's.
  final out = [];
  final children = c['children'];
  if (children is List) {
    for (final id in (children as List)) {
      out.add([id, false]);
    }
  }
  if (children is Map) {
    final template = children as Map;
    out.add([template['componentId'], true]);
  }
  if (c['child'] is String) out.add([c['child'], false]);
  if (c['content'] is String) out.add([c['content'], false]);
  final tabs = c['tabs'];
  if (tabs is List) {
    for (final tab in (tabs as List)) {
      final t = tab as Map;
      out.add([t['child'], false]);
    }
  }
  final pages = c['pages'];
  if (pages is Map) {
    for (final id in (pages as Map).values) {
      out.add([id, false]);
    }
  }
  return out;
}

List treeOf(Map app, String picked) {
  final rows = [];
  final byId = {};
  for (final c in (app['ui'] as List)) {
    final m = c as Map;
    byId[m['id']] = m;
  }
  final seen = {};
  final stack = [['root', 0, false]];
  while (stack.length > 0) {
    final top = stack.removeAt(stack.length - 1) as List;
    final id = top[0] as String;
    final depth = top[1] as int;
    if (seen[id] != true && byId[id] != null) {
      seen[id] = true;
      final c = byId[id] as Map;
      final type = c['component'] as String;
      rows.add({
        'id': id,
        'label': kindName(type),
        'icon': 'component:' + type,
        'depth': depth,
        'caption': top[2] == true ? id + ' · por item' : id,
        'tone': id == picked ? 'accent' : 'muted',
      });
      final next = refsOf(c);
      for (var i = next.length - 1; i >= 0; i--) {
        final r = next[i] as List;
        stack.add([r[0], depth + 1, r[1]]);
      }
    }
  }
  return rows;
}

List turnsOf(Map history) {
  final out = [];
  final current = history['current'];
  for (final v in (history['versions'] as List)) {
    final m = v as Map;
    final n = m['n'];
    final changes = (m['changes'] as Map?) ?? {};
    final prompt = (m['prompt'] as String?) ?? '';
    var text = (m['reply'] as String?) ?? '';
    if (prompt != '') {
      out.add({'role': 'me', 'text': prompt, 'caption': ''});
    }
    if (changes['restoredFrom'] != null) {
      text = 'Trouxe de volta a versão \${changes['restoredFrom']}.';
    } else if (changes['form'] == 'web') {
      text = 'Agora é um app para web.';
    } else if (changes['form'] == 'mobile') {
      text = 'Agora é um app para celular.';
    } else if (text == '' && n == 1) {
      text = 'Criei o app.';
    } else if (text == '') {
      text = 'Pronto.';
    }
    final tag = n == current ? 'Versão $n · atual' : 'Versão $n';
    out.add({'role': 'other', 'text': text, 'caption': tag});
  }
  return out;
}

List versionRowsOf(Map history) {
  final out = [];
  final current = history['current'];
  final list = history['versions'] as List;
  for (var i = list.length - 1; i >= 0; i--) {
    final m = list[i] as Map;
    final n = m['n'];
    final changes = (m['changes'] as Map?) ?? {};
    final prompt = (m['prompt'] as String?) ?? '';
    var caption = prompt;
    if (changes['restoredFrom'] != null) {
      caption = 'Trouxe de volta a versão \${changes['restoredFrom']}';
    } else if (changes['form'] != null) {
      caption = changes['form'] == 'web' ? 'Agora para web' : 'Agora para celular';
    }
    out.add({
      'n': n,
      'label': 'Versão $n',
      'caption': caption,
      'current': n == current,
    });
  }
  return out;
}

String shown(dynamic v) {
  if (v is Map) {
    final m = v as Map;
    if (m['path'] != null) return '→ \${m['path']}';
  }
  return '$v';
}

List pickedRowsOf(Map app, String id) {
  final rows = [];
  for (final c in (app['ui'] as List)) {
    final m = c as Map;
    if (m['id'] == id) {
    rows.add({'name': 'id', 'value': id});
    rows.add({'name': 'tipo', 'value': kindName(m['component'] as String)});
    for (final key in ['text', 'label', 'value', 'name', 'url', 'app']) {
      if (m[key] != null) rows.add({'name': key, 'value': shown(m[key])});
    }
    final children = m['children'];
    if (children is List) {
      final list = children as List;
      if (list.length > 0) rows.add({'name': 'filhos', 'value': list.join(', ')});
    }
    if (children is Map) {
      final template = children as Map;
      rows.add({'name': 'itens', 'value': '\${template['path']}'});
    }
    final action = m['action'];
    if (action is Map) {
      final event = (action as Map)['event'];
      final name = event is Map ? (event as Map)['name'] : null;
      final def = (app['actions'] as Map)[name];
      if (def is Map) {
        final d = def as Map;
        rows.add({'name': 'ação', 'value': '$name · \${placeOf(d['on'])}'});
        final reads = d['input'] as List;
        if (reads.length > 0) rows.add({'name': 'lê', 'value': reads.join(', ')});
      } else {
        rows.add({'name': 'ação', 'value': '$name'});
      }
    }
    }
  }
  return rows;
}

Map slim(Map app) {
  return {
    'id': app['id'],
    'name': app['name'],
    'form': app['form'],
    'ui': app['ui'],
    'actions': app['actions'],
    'version': app['version'],
  };
}

List viewsOf(Map app, Map history, String picked) {
  return [
    {'op': 'replace', 'path': '/app', 'value': app},
    {'op': 'replace', 'path': '/title', 'value': app['name']},
    {'op': 'replace', 'path': '/formChoice', 'value': [app['form']]},
    {'op': 'replace', 'path': '/history', 'value': history},
    {'op': 'replace', 'path': '/tree', 'value': treeOf(app, picked)},
    {'op': 'replace', 'path': '/turns', 'value': turnsOf(history)},
    {'op': 'replace', 'path': '/versionRows', 'value': versionRowsOf(history)},
  ];
}

List set(String path, Object? value) {
  return [{'op': 'replace', 'path': path, 'value': value}];
}
`;

/** An action: [body] is the inside of `run`, after the shared helpers. */
function action(on: ActionDef['on'], input: string[], body: string): ActionDef {
  return {
    ...(on === 'server' ? {} : { on }),
    input,
    code: `${HELPERS}
Future<List> run(Map input, Map event, Function call) async {
${body}
}`,
  };
}

const ACTIONS: Record<string, ActionDef> = {
  // Opens the app [event.id] in the editor.
  start: action(
    'platform',
    [],
    `  final id = (event['id'] as String?) ?? '';
  if (id == '') return [];
  final app = slim((await call('apps.get', {'id': id})) as Map);
  final history = (await call('apps.history', {'id': id})) as Map;
  final out = [];
  out.add(set('/editing', id)[0]);
  out.add(set('/viewing', null)[0]);
  out.add(set('/viewingOn', false)[0]);
  out.add(set('/picked', '')[0]);
  out.add(set('/pickedRows', [])[0]);
  out.add(set('/focus', '')[0]);
  out.add(set('/picking', false)[0]);
  out.add(set('/pickLabel', 'Escolher')[0]);
  for (final op in viewsOf(app, history, '')) {
    out.add(op);
  }
  return out;`,
  ),
  // Asks the model for a change; the reply is the new version.
  send: action(
    'platform',
    ['/revision'],
    `  final id = (event['id'] as String?) ?? '';
  final prompt = ((event['prompt'] as String?) ?? '').trim();
  if (id == '' || prompt == '') return [];
  final focus = (event['focus'] as String?) ?? '';
  final picked = (event['picked'] as String?) ?? '';
  final outcome = (await call('apps.send', {'id': id, 'prompt': prompt, 'focus': focus})) as Map;
  final history = (await call('apps.history', {'id': id})) as Map;
  final out = [];
  out.add(set('/draft', '')[0]);
  out.add(set('/focus', '')[0]);
  out.add(set('/revision', ((input['/revision'] as int?) ?? 0) + 1)[0]);
  for (final op in viewsOf(slim(outcome['app'] as Map), history, picked)) {
    out.add(op);
  }
  return out;`,
  ),
  // Brings version [event.n] back.
  restore: action(
    'platform',
    ['/revision'],
    `  final id = (event['id'] as String?) ?? '';
  final n = event['n'];
  if (id == '' || n == null) return [];
  final outcome = (await call('apps.restore', {'id': id, 'n': n})) as Map;
  final history = (await call('apps.history', {'id': id})) as Map;
  final out = [];
  out.add(set('/viewing', null)[0]);
  out.add(set('/viewingOn', false)[0]);
  out.add(set('/revision', ((input['/revision'] as int?) ?? 0) + 1)[0]);
  for (final op in viewsOf(slim(outcome['app'] as Map), history, '')) {
    out.add(op);
  }
  return out;`,
  ),
  // Celular | Web: what the app is made for.
  set_form: action(
    'platform',
    ['/revision'],
    `  final id = (event['id'] as String?) ?? '';
  final value = event['value'];
  if (id == '' || value == null) return [];
  final chosen = value as List;
  if (chosen.length == 0) return [];
  final outcome = (await call('apps.setForm', {'id': id, 'form': chosen[0]})) as Map;
  final history = (await call('apps.history', {'id': id})) as Map;
  final out = [];
  out.add(set('/revision', ((input['/revision'] as int?) ?? 0) + 1)[0]);
  for (final op in viewsOf(slim(outcome['app'] as Map), history, '')) {
    out.add(op);
  }
  return out;`,
  ),
  // Looks at version [event.n] in the Surface, read-only.
  view: action(
    'client',
    ['/history'],
    `  final n = event['n'];
  final history = input['/history'] as Map;
  if (n == history['current']) {
    return [
      set('/viewing', null)[0],
      set('/viewingOn', false)[0],
    ];
  }
  return [
    set('/viewing', n)[0],
    set('/viewingOn', true)[0],
    set('/viewingLabel', 'Vendo a versão $n')[0],
    set('/picking', false)[0],
    set('/pickLabel', 'Escolher')[0],
    set('/tab', 'App')[0],
  ];`,
  ),
  back: action(
    'client',
    [],
    `  return [set('/viewing', null)[0], set('/viewingOn', false)[0]];`,
  ),
  toggle_picking: action(
    'client',
    ['/picking'],
    `  final on = input['/picking'] != true;
  return [
    set('/picking', on)[0],
    set('/pickLabel', on ? 'Pronto' : 'Escolher')[0],
  ];`,
  ),
  // A component picked in the Surface, or a row of the tree.
  pick: action(
    'client',
    ['/app'],
    `  final id = (event['componentId'] as String?) ?? '';
  final app = input['/app'] as Map;
  return [
    set('/picked', id)[0],
    set('/pickedRows', pickedRowsOf(app, id))[0],
    set('/tree', treeOf(app, id))[0],
  ];`,
  ),
  // Makes the picked component the subject of the next request.
  ask_change: action(
    'client',
    ['/picked'],
    `  final subject = (input['/picked'] as String?) ?? '';
  if (subject == '') return [];
  return [
    set('/focus', subject)[0],
    set('/focusLabel', 'Sobre: ' + subject)[0],
    set('/picking', false)[0],
    set('/pickLabel', 'Escolher')[0],
    set('/tab', 'Conversa')[0],
  ];`,
  ),
  clear_focus: action('client', [], `  return set('/focus', '');`),
};

const send = {
  event: {
    name: 'send',
    context: {
      id: { path: '/editing' },
      prompt: { path: '/draft' },
      focus: { path: '/focus' },
      picked: { path: '/picked' },
    },
  },
};

const UI: Component[] = [
  {
    id: 'root',
    component: 'Column',
    children: ['header', 'form', 'viewingBar', 'opening', 'wide', 'narrow'],
  },

  // The app's name, its form, and picking.
  {
    id: 'header',
    component: 'Row',
    children: ['title', 'pickButton'],
  },
  {
    id: 'title',
    component: 'Text',
    text: { path: '/title' },
    variant: 'h3',
    weight: 1,
  },
  {
    id: 'form',
    component: 'ChoicePicker',
    variant: 'mutuallyExclusive',
    options: [
      { label: 'Celular', value: 'mobile' },
      { label: 'Web', value: 'web' },
    ],
    value: { path: '/formChoice' },
    action: {
      event: { name: 'set_form', context: { id: { path: '/editing' } } },
    },
  },
  {
    id: 'pickButton',
    component: 'Button',
    icon: 'cursor',
    label: { path: '/pickLabel' },
    visible: { path: '/viewingOn', is: false },
    action: { event: { name: 'toggle_picking' } },
  },
  {
    id: 'opening',
    component: 'Text',
    text: 'Abrindo…',
    tone: 'muted',
    visible: { path: '/$pending/start' },
  },

  // Looking at an earlier version.
  {
    id: 'viewingBar',
    component: 'Card',
    child: 'viewingRow',
    visible: { path: '/viewingOn' },
  },
  {
    id: 'viewingRow',
    component: 'Row',
    children: ['viewingText', 'backButton', 'restoreButton'],
  },
  {
    id: 'viewingText',
    component: 'Text',
    text: { path: '/viewingLabel' },
  },
  {
    id: 'backButton',
    component: 'Button',
    label: 'Voltar à atual',
    variant: 'borderless',
    action: { event: { name: 'back' } },
  },
  {
    id: 'restoreButton',
    component: 'Button',
    label: 'Restaurar esta',
    icon: 'restore',
    variant: 'primary',
    action: {
      event: {
        name: 'restore',
        context: { id: { path: '/editing' }, n: { path: '/viewing' } },
      },
    },
  },

  // A wide window: conversation · app · components, side by side.
  {
    id: 'wide',
    component: 'Row',
    align: 'start',
    visible: { path: '/$viewport/size', is: 'expanded' },
    children: ['side', 'surface', 'inspector'],
  },
  {
    id: 'side',
    component: 'Tabs',
    weight: 3,
    value: { path: '/sideTab' },
    tabs: [
      { title: 'Conversa', child: 'chat' },
      { title: 'Versões', child: 'versions' },
    ],
  },
  {
    id: 'surface',
    component: 'Surface',
    weight: 5,
    app: { path: '/editing' },
    version: { path: '/viewing' },
    revision: { path: '/revision' },
    picking: { path: '/picking' },
    selected: { path: '/picked' },
    action: { event: { name: 'pick' } },
  },
  {
    id: 'inspector',
    component: 'Column',
    weight: 3,
    children: ['treeTitle', 'tree', 'pickedDivider', 'picked'],
  },

  // Anything narrower: one tab at a time.
  {
    id: 'narrow',
    component: 'Tabs',
    visible: { path: '/$viewport/size', is: 'expanded', not: true },
    value: { path: '/tab' },
    tabs: [
      { title: 'App', child: 'surface' },
      { title: 'Conversa', child: 'chat' },
      { title: 'Componentes', child: 'inspector' },
      { title: 'Versões', child: 'versions' },
    ],
  },

  // The conversation: one bubble per turn, the request on its way, the field.
  {
    id: 'chat',
    component: 'Column',
    children: ['turns', 'sending', 'thinking', 'focusRow', 'composer'],
  },
  {
    id: 'turns',
    component: 'List',
    children: { componentId: 'turn', path: '/turns' },
  },
  {
    id: 'turn',
    component: 'Message',
    role: { path: 'role' },
    text: { path: 'text' },
    caption: { path: 'caption' },
  },
  {
    id: 'sending',
    component: 'Message',
    role: 'me',
    text: { path: '/$pending/send/prompt' },
    visible: { path: '/$pending/send' },
  },
  {
    id: 'thinking',
    component: 'Message',
    role: 'other',
    text: 'Pensando…',
    visible: { path: '/$pending/send' },
  },
  {
    id: 'focusRow',
    component: 'Row',
    visible: { path: '/focus' },
    children: ['focusBadge', 'focusClear'],
  },
  {
    id: 'focusBadge',
    component: 'Badge',
    text: { path: '/focusLabel' },
    tone: 'accent',
  },
  {
    id: 'focusClear',
    component: 'Button',
    icon: 'close',
    label: '',
    variant: 'borderless',
    action: { event: { name: 'clear_focus' } },
  },
  {
    id: 'composer',
    component: 'Row',
    children: ['draft', 'sendButton'],
  },
  {
    id: 'draft',
    component: 'TextField',
    label: 'Peça uma mudança',
    value: { path: '/draft' },
    action: send,
  },
  {
    id: 'sendButton',
    component: 'Button',
    icon: 'send',
    label: '',
    variant: 'primary',
    action: send,
  },

  // The versions, newest first.
  {
    id: 'versions',
    component: 'List',
    children: { componentId: 'versionRow', path: '/versionRows' },
  },
  {
    id: 'versionRow',
    component: 'Card',
    child: 'versionLine',
    action: { event: { name: 'view', context: { n: { path: 'n' } } } },
  },
  {
    id: 'versionLine',
    component: 'Column',
    children: ['versionHead', 'versionCaption'],
  },
  {
    id: 'versionHead',
    component: 'Row',
    children: ['versionIcon', 'versionLabel', 'versionCurrent'],
  },
  { id: 'versionIcon', component: 'Icon', name: 'version' },
  {
    id: 'versionLabel',
    component: 'Text',
    text: { path: 'label' },
  },
  {
    id: 'versionCurrent',
    component: 'Badge',
    text: 'atual',
    tone: 'accent',
    visible: { path: 'current' },
  },
  {
    id: 'versionCaption',
    component: 'Text',
    text: { path: 'caption' },
    variant: 'caption',
    visible: { path: 'caption' },
  },

  // The components: the tree, and the picked one's menu.
  {
    id: 'treeTitle',
    component: 'Text',
    text: 'Componentes',
    variant: 'h3',
  },
  {
    id: 'tree',
    component: 'List',
    children: { componentId: 'treeRow', path: '/tree' },
  },
  {
    id: 'treeRow',
    component: 'Row',
    inset: { path: 'depth' },
    children: ['treeIcon', 'treeLabel', 'treeId'],
    action: {
      event: { name: 'pick', context: { componentId: { path: 'id' } } },
    },
  },
  {
    id: 'treeIcon',
    component: 'Icon',
    name: { path: 'icon' },
    tone: { path: 'tone' },
  },
  {
    id: 'treeLabel',
    component: 'Text',
    text: { path: 'label' },
    tone: { path: 'tone' },
    weight: 2,
  },
  {
    id: 'treeId',
    component: 'Text',
    text: { path: 'caption' },
    variant: 'caption',
    weight: 2,
  },
  {
    id: 'pickedDivider',
    component: 'Divider',
    visible: { path: '/picked' },
  },
  {
    id: 'picked',
    component: 'Column',
    visible: { path: '/picked' },
    children: ['pickedRows', 'askButton'],
  },
  {
    id: 'pickedRows',
    component: 'List',
    children: { componentId: 'pickedRow', path: '/pickedRows' },
  },
  {
    id: 'pickedRow',
    component: 'Row',
    children: ['pickedName', 'pickedValue'],
  },
  {
    id: 'pickedName',
    component: 'Text',
    text: { path: 'name' },
    variant: 'caption',
    weight: 1,
  },
  {
    id: 'pickedValue',
    component: 'Text',
    text: { path: 'value' },
    weight: 3,
  },
  {
    id: 'askButton',
    component: 'Button',
    label: 'Pedir mudança',
    variant: 'primary',
    action: { event: { name: 'ask_change' } },
  },
];

/** The editor as a bundle, before its actions are compiled. */
export const EDITOR: Bundle = {
  name: 'My Own App Editor',
  ui: UI,
  data: {
    editing: '',
    title: '',
    app: { id: '', name: '', form: 'mobile', ui: [], actions: {}, version: 0 },
    history: { current: 0, versions: [] },
    formChoice: ['mobile'],
    turns: [],
    versionRows: [],
    tree: [],
    picked: '',
    pickedRows: [],
    focus: '',
    focusLabel: '',
    picking: false,
    pickLabel: 'Escolher',
    viewing: null,
    viewingOn: false,
    viewingLabel: '',
    draft: '',
    revision: 0,
    tab: 'App',
    sideTab: 'Conversa',
  },
  actions: ACTIONS,
};
