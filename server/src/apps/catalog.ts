/**
 * The catalog: the components an app's screen is made of, and the icons it
 * may name. Our own subset of the A2UI v0.9 basic catalog
 * (https://a2ui.org/specification/v0_9/catalogs/basic/catalog.json), plus a
 * few of ours (Pages, Badge, Message, Switch, Surface, and the structure a
 * real app is drawn with: Screen, TopBar, NavBar, Split, Panel, Box,
 * ListItem, ...).
 *
 * A component lives in three places: here, `AppRenderer` in the app, and the
 * one line about it in `RULES` (`apps.service.ts`).
 */

/** The components the app knows how to draw. */
export const COMPONENTS = [
  // Structure: what a real app's screen is framed with
  'Screen',
  'TopBar',
  'NavBar',
  'Split',
  'Panel',
  // Layout
  'Box',
  'Grid',
  'Spacer',
  'Column',
  'Row',
  'List',
  'Card',
  'Divider',
  'Tabs',
  'Pages',
  'Modal',
  // Display
  'Text',
  'Icon',
  'Image',
  'Badge',
  'Message',
  'ListItem',
  'Avatar',
  'Progress',
  'Stat',
  'Callout',
  'EmptyState',
  // Input
  'TextField',
  'CheckBox',
  'Switch',
  'ChoicePicker',
  'Slider',
  'DateTimeInput',
  'Button',
  // Engine
  'Surface',
] as const;

/**
 * The icons a component may name (`Icon.name`, `Button.icon`). The app maps
 * each one in `AppIcons.named`; `app/test/apps/catalog_test.dart` checks
 * the two lists agree.
 */
export const ICONS = [
  'add',
  'remove',
  'edit',
  'delete',
  'check',
  'checkCircle',
  'close',
  'search',
  'settings',
  'home',
  'person',
  'people',
  'favorite',
  'star',
  'calendar',
  'clock',
  'notifications',
  'mail',
  'chat',
  'send',
  'phone',
  'camera',
  'image',
  'location',
  'cart',
  'bag',
  'money',
  'card',
  'chart',
  'list',
  'grid',
  'folder',
  'file',
  'book',
  'bookmark',
  'tag',
  'filter',
  'sort',
  'menu',
  'more',
  'back',
  'forward',
  'up',
  'down',
  'open',
  'play',
  'pause',
  'lock',
  'share',
  'link',
  'info',
  'warning',
  'sun',
  'moon',
  'music',
  'gift',
  'globe',
  'desktop',
  'mobile',
  'browser',
  'code',
  'visible',
  'download',
  'flag',
  'food',
  'travel',
  'car',
  'fitness',
  // The studio's own: what an editor built with the catalog draws.
  'assistant',
  'cursor',
  'tree',
  'version',
  'restore',
  'action',
  'component',
  'layout',
  'sidebar',
  'engine',
  'trendUp',
  'trendDown',
] as const;

type Loose = Record<string, unknown>;

/** One of [ICONS], or `component:<a component>` (its type's own icon). */
export function isIcon(name: string): boolean {
  if (name.startsWith('component:')) {
    return (COMPONENTS as readonly string[]).includes(
      name.slice('component:'.length),
    );
  }
  return (ICONS as readonly string[]).includes(name);
}

/** The properties that hold one component id (`trailing` may hold a list). */
const SLOTS = [
  'child',
  'content',
  'header',
  'body',
  'footer',
  'nav',
  'leading',
] as const;

/**
 * The ids [component] draws, other than through `children`: a Card's
 * child, a Screen's header, body, footer and nav, a TopBar's leading, the
 * trailing ones (a TopBar's, a Panel's, a ListItem's), each tab, each page,
 * a Modal's content.
 */
export function references(component: Loose): string[] {
  const ids: string[] = [];
  for (const slot of SLOTS) {
    if (typeof component[slot] === 'string') ids.push(component[slot]);
  }
  if (typeof component.trailing === 'string') ids.push(component.trailing);
  if (Array.isArray(component.trailing)) {
    for (const id of component.trailing) {
      if (typeof id === 'string') ids.push(id);
    }
  }
  if (Array.isArray(component.tabs)) {
    for (const tab of component.tabs as Loose[]) {
      if (isObject(tab) && typeof tab.child === 'string') ids.push(tab.child);
    }
  }
  if (isObject(component.pages)) {
    for (const id of Object.values(component.pages)) {
      if (typeof id === 'string') ids.push(id);
    }
  }
  return ids;
}

/** Forgets every reference [component] holds to one of [removed]. */
export function dropReferences(component: Loose, removed: Set<string>): void {
  if (Array.isArray(component.children)) {
    component.children = component.children.filter(
      (id) => !removed.has(id as string),
    );
  }
  for (const slot of SLOTS) {
    if (removed.has(component[slot] as string)) delete component[slot];
  }
  if (removed.has(component.trailing as string)) delete component.trailing;
  if (Array.isArray(component.trailing)) {
    component.trailing = component.trailing.filter(
      (id) => !removed.has(id as string),
    );
  }
  if (Array.isArray(component.tabs)) {
    component.tabs = (component.tabs as Loose[]).filter(
      (tab) => !(isObject(tab) && removed.has(tab.child as string)),
    );
  }
  if (isObject(component.pages)) {
    component.pages = Object.fromEntries(
      Object.entries(component.pages).filter(
        ([, id]) => !removed.has(id as string),
      ),
    );
  }
}

/**
 * What is wrong with [component]'s own properties, beyond its references:
 * the shapes the renderer cannot guess. Undefined when nothing is.
 */
export function componentProblem(component: Loose): string | undefined {
  const icon = (name: unknown): string | undefined =>
    typeof name === 'string' && !isIcon(name)
      ? `unknown icon ${name}`
      : undefined;

  switch (component.component) {
    case 'Icon':
      if (component.name === undefined) return 'an Icon needs a name';
      return icon(component.name);
    case 'Button':
    case 'ListItem':
    case 'Callout':
    case 'EmptyState':
    case 'Stat':
    case 'Panel':
    case 'Badge':
    case 'TextField':
      return icon(component.icon);
    case 'Screen':
      if (typeof component.body !== 'string') {
        return 'a Screen needs a body id';
      }
      return undefined;
    case 'Split':
      if (!Array.isArray(component.children)) {
        return 'a Split needs children, a list of pane ids';
      }
      return undefined;
    case 'NavBar':
      if (
        !Array.isArray(component.items) ||
        !component.items.every((item) => isObject(item) && 'value' in item)
      ) {
        return 'items must be a list of {"label", "icon", "value"}';
      }
      for (const item of component.items as Loose[]) {
        const wrong = icon(item.icon);
        if (wrong) return wrong;
      }
      return undefined;
    case 'Image':
      if (component.url === undefined) return 'an Image needs a url';
      if (
        typeof component.url === 'string' &&
        !component.url.startsWith('https://')
      ) {
        return 'an Image url must start with https://';
      }
      return undefined;
    case 'Tabs':
      if (
        !Array.isArray(component.tabs) ||
        !component.tabs.every(
          (tab) => isObject(tab) && typeof tab.child === 'string',
        )
      ) {
        return 'tabs must be a list of {"title", "child"}';
      }
      return undefined;
    case 'Pages':
      if (!isObject(component.pages)) {
        return 'pages must be an object, page name -> component id';
      }
      return undefined;
    case 'Modal':
      if (typeof component.content !== 'string') {
        return 'a Modal needs a content id';
      }
      return undefined;
    case 'Surface':
      if (component.app === undefined) {
        return 'a Surface needs an app (an app id, or {"path"} to one)';
      }
      return undefined;
    case 'ChoicePicker':
      if (component.options === undefined) {
        return 'a ChoicePicker needs options';
      }
      return undefined;
    default:
      return undefined;
  }
}

function isObject(value: unknown): value is Loose {
  return typeof value === 'object' && value !== null && !Array.isArray(value);
}
