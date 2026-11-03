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
export const EDITOR_VERSION = 2;

/**
 * Dart every action shares (the runner has no imports): turning the edited
 * app and its history into the rows the editor draws.
 */
const HELPERS = `
String kindName(String t) {
  switch (t) {
    case 'Screen': return 'Tela';
    case 'TopBar': return 'Barra superior';
    case 'NavBar': return 'Navegação';
    case 'Split': return 'Divisão';
    case 'Panel': return 'Painel';
    case 'Box': return 'Caixa';
    case 'Grid': return 'Grade';
    case 'Spacer': return 'Espaço';
    case 'ListItem': return 'Item';
    case 'Avatar': return 'Avatar';
    case 'Progress': return 'Progresso';
    case 'Stat': return 'Número';
    case 'Callout': return 'Aviso';
    case 'EmptyState': return 'Vazio';
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
  for (final slot in ['header', 'leading', 'child', 'content', 'body', 'footer', 'nav']) {
    if (c[slot] is String) out.add([c[slot], false]);
  }
  final trailing = c['trailing'];
  if (trailing is String) out.add([trailing, false]);
  if (trailing is List) {
    for (final id in (trailing as List)) {
      out.add([id, false]);
    }
  }
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
        'selected': id == picked,
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
    for (final key in ['title', 'text', 'label', 'subtitle', 'value', 'name', 'icon', 'url', 'app', 'variant']) {
      if (m[key] != null && m[key] != '') {
          rows.add({'name': key, 'value': shown(m[key])});
        }
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
  out.add(set('/pickVariant', 'default')[0]);
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
    set('/pickVariant', 'default')[0],
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
    set('/pickVariant', on ? 'primary' : 'default')[0],
  ];`,
  ),
  // A component picked in the Surface, or a row of the tree.
  pick: action(
    'client',
    ['/app'],
    `  final id = (event['componentId'] as String?) ?? '';
  final app = input['/app'] as Map;
  var type = '';
  for (final c in (app['ui'] as List)) {
    final m = c as Map;
    if (m['id'] == id) type = m['component'] as String;
  }
  return [
    set('/picked', id)[0],
    set('/pickedTitle', kindName(type) + ' · ' + id)[0],
    set('/pickedIcon', 'component:' + type)[0],
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
    set('/pickVariant', 'default')[0],
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
  // The frame: the edited app's name over everything; three panes on a
  // wide window, one page at a time (and a bottom navigation) otherwise.
  {
    id: 'root',
    component: 'Screen',
    header: 'topBar',
    body: 'layout',
    nav: 'mobileNav',
  },
  {
    id: 'topBar',
    component: 'TopBar',
    title: { path: '/title' },
    subtitle: 'My Own App Editor',
    leading: 'mark',
    trailing: ['form', 'pickTools'],
  },
  {
    id: 'mark',
    component: 'Box',
    visible: { path: '/$viewport/size', is: 'expanded' },
    shape: 'rounded',
    radius: 'md',
    background: 'accentSoft',
    padding: 'sm',
    child: 'markIcon',
  },
  {
    id: 'markIcon',
    component: 'Icon',
    name: 'layout',
    tone: 'accent',
    size: 'sm',
  },
  {
    id: 'form',
    component: 'ChoicePicker',
    variant: 'mutuallyExclusive',
    style: 'segmented',
    options: [
      { label: 'Celular', value: 'mobile' },
      { label: 'Web', value: 'web' },
    ],
    value: { path: '/formChoice' },
    action: {
      event: { name: 'set_form', context: { id: { path: '/editing' } } },
    },
  },
  // Picking: hidden while a version is looked at; an icon alone on a phone.
  {
    id: 'pickTools',
    component: 'Row',
    gap: 'none',
    visible: { path: '/viewingOn', is: false },
    children: ['pickButton', 'pickIcon'],
  },
  {
    id: 'pickButton',
    component: 'Button',
    icon: 'cursor',
    label: { path: '/pickLabel' },
    variant: { path: '/pickVariant' },
    visible: { path: '/$viewport/size', is: 'expanded' },
    action: { event: { name: 'toggle_picking' } },
  },
  {
    id: 'pickIcon',
    component: 'Button',
    icon: 'cursor',
    label: '',
    variant: { path: '/pickVariant' },
    visible: { path: '/$viewport/size', is: 'expanded', not: true },
    action: { event: { name: 'toggle_picking' } },
  },
  {
    id: 'mobileNav',
    component: 'NavBar',
    visible: { path: '/$viewport/size', is: 'expanded', not: true },
    value: { path: '/tab' },
    items: [
      { label: 'App', icon: 'visible', value: 'App' },
      { label: 'Conversa', icon: 'assistant', value: 'Conversa' },
      { label: 'Componentes', icon: 'tree', value: 'Componentes' },
      { label: 'Versões', icon: 'version', value: 'Versões' },
    ],
  },
  {
    id: 'layout',
    component: 'Pages',
    current: { path: '/$viewport/size' },
    pages: { expanded: 'wide', medium: 'narrow', compact: 'narrow' },
  },
  {
    id: 'wide',
    component: 'Split',
    children: ['chatPanel', 'previewPanel', 'inspectorPanel'],
  },
  {
    id: 'narrow',
    component: 'Pages',
    current: { path: '/tab' },
    pages: {
      App: 'previewPanel',
      Conversa: 'chatPanel',
      Componentes: 'treePanel',
      Versões: 'versionsPanel',
    },
  },

  // The conversation: one bubble per turn, the request on its way, and the
  // composer pinned under them.
  {
    id: 'chatPanel',
    component: 'Panel',
    title: 'Conversa',
    icon: 'assistant',
    width: 'lg',
    background: 'surface',
    children: ['opening', 'turns', 'sending', 'thinking'],
    footer: 'composer',
  },
  {
    id: 'opening',
    component: 'Message',
    role: 'system',
    text: 'Abrindo…',
    visible: { path: '/$pending/start' },
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
    id: 'composer',
    component: 'Column',
    gap: 'sm',
    children: ['focusRow', 'composerRow'],
  },
  {
    id: 'focusRow',
    component: 'Row',
    gap: 'xs',
    visible: { path: '/focus' },
    children: ['focusBadge', 'focusClear', 'focusRest'],
  },
  {
    id: 'focusBadge',
    component: 'Badge',
    icon: 'cursor',
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
  { id: 'focusRest', component: 'Spacer' },
  {
    id: 'composerRow',
    component: 'Row',
    gap: 'sm',
    children: ['draft', 'sendButton'],
  },
  {
    id: 'draft',
    component: 'TextField',
    label: 'Peça uma mudança…',
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

  // The app, running (or a version of it, looked at).
  {
    id: 'previewPanel',
    component: 'Panel',
    title: 'Prévia',
    icon: 'visible',
    trailing: ['viewingBadge'],
    scroll: false,
    padding: 'xl',
    child: 'surface',
    footer: 'viewingBar',
  },
  {
    id: 'viewingBadge',
    component: 'Badge',
    icon: 'version',
    text: { path: '/viewingLabel' },
    tone: 'warning',
    visible: { path: '/viewingOn' },
  },
  {
    id: 'surface',
    component: 'Surface',
    app: { path: '/editing' },
    version: { path: '/viewing' },
    revision: { path: '/revision' },
    picking: { path: '/picking' },
    selected: { path: '/picked' },
    action: { event: { name: 'pick' } },
  },
  {
    id: 'viewingBar',
    component: 'Callout',
    tone: 'warning',
    icon: 'version',
    title: { path: '/viewingLabel' },
    text: 'Só para ver: as mudanças vão na versão atual.',
    visible: { path: '/viewingOn' },
    trailing: ['backButton', 'restoreButton'],
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

  // The components and the versions: side by side with the app on a wide
  // window, a page each otherwise.
  {
    id: 'inspectorPanel',
    component: 'Panel',
    width: 'md',
    background: 'surface',
    child: 'inspectorTabs',
  },
  {
    id: 'inspectorTabs',
    component: 'Tabs',
    value: { path: '/inspectorTab' },
    tabs: [
      { title: 'Componentes', icon: 'tree', child: 'inspector' },
      { title: 'Versões', icon: 'version', child: 'versions' },
    ],
  },
  {
    id: 'treePanel',
    component: 'Panel',
    title: 'Componentes',
    icon: 'tree',
    child: 'inspector',
  },
  {
    id: 'versionsPanel',
    component: 'Panel',
    title: 'Versões',
    icon: 'version',
    child: 'versions',
  },
  {
    id: 'inspector',
    component: 'Column',
    gap: 'lg',
    children: ['tree', 'picked'],
  },
  {
    id: 'tree',
    component: 'List',
    gap: 'none',
    children: { componentId: 'treeRow', path: '/tree' },
  },
  {
    id: 'treeRow',
    component: 'ListItem',
    dense: true,
    inset: { path: 'depth' },
    icon: { path: 'icon' },
    title: { path: 'label' },
    meta: { path: 'caption' },
    selected: { path: 'selected' },
    action: {
      event: { name: 'pick', context: { componentId: { path: 'id' } } },
    },
  },
  {
    id: 'picked',
    component: 'Box',
    visible: { path: '/picked' },
    background: 'bg',
    border: true,
    padding: 'lg',
    gap: 'md',
    children: ['pickedHead', 'pickedRows', 'askButton'],
  },
  {
    id: 'pickedHead',
    component: 'Row',
    gap: 'sm',
    children: ['pickedIcon', 'pickedTitle'],
  },
  {
    id: 'pickedIcon',
    component: 'Icon',
    name: { path: '/pickedIcon' },
    tone: 'accent',
    size: 'sm',
  },
  {
    id: 'pickedTitle',
    component: 'Text',
    text: { path: '/pickedTitle' },
    variant: 'strong',
    maxLines: 1,
  },
  {
    id: 'pickedRows',
    component: 'List',
    divided: true,
    children: { componentId: 'pickedRow', path: '/pickedRows' },
  },
  {
    id: 'pickedRow',
    component: 'Row',
    padding: 'sm',
    align: 'start',
    children: ['pickedName', 'pickedValue'],
  },
  {
    id: 'pickedName',
    component: 'Text',
    text: { path: 'name' },
    variant: 'caption',
    width: 72,
  },
  {
    id: 'pickedValue',
    component: 'Text',
    text: { path: 'value' },
    variant: 'label',
    tone: 'muted',
  },
  {
    id: 'askButton',
    component: 'Button',
    label: 'Pedir mudança',
    icon: 'assistant',
    variant: 'primary',
    width: 'fill',
    action: { event: { name: 'ask_change' } },
  },

  // The versions, newest first.
  {
    id: 'versions',
    component: 'List',
    gap: 'xs',
    children: { componentId: 'versionRow', path: '/versionRows' },
  },
  {
    id: 'versionRow',
    component: 'ListItem',
    icon: 'version',
    title: { path: 'label' },
    subtitle: { path: 'caption' },
    trailing: ['versionCurrent'],
    action: { event: { name: 'view', context: { n: { path: 'n' } } } },
  },
  {
    id: 'versionCurrent',
    component: 'Badge',
    text: 'atual',
    tone: 'accent',
    visible: { path: 'current' },
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
    pickVariant: 'default',
    pickedTitle: '',
    pickedIcon: 'component',
    viewing: null,
    viewingOn: false,
    viewingLabel: '',
    draft: '',
    revision: 0,
    tab: 'App',
    inspectorTab: 'Componentes',
    editorVersion: EDITOR_VERSION,
  },
  actions: ACTIONS,
};
