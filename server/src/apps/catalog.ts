/**
 * The catalog: the components an app's screen is made of, and the icons it
 * may name. Our own subset of the A2UI v0.9 basic catalog
 * (https://a2ui.org/specification/v0_9/catalogs/basic/catalog.json), plus a
 * few of ours (Pages, Badge, Message, Switch, Surface).
 *
 * A component lives in three places: here, `AppRenderer` in the app, and the
 * one line about it in `RULES` (`apps.service.ts`).
 */

/** The components the app knows how to draw. */
export const COMPONENTS = [
  // Layout
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

/**
 * The ids [component] draws, other than through `children`: a Card's
 * child, each tab, each page, a Modal's content.
 */
export function references(component: Loose): string[] {
  const ids: string[] = [];
  if (typeof component.child === 'string') ids.push(component.child);
  if (typeof component.content === 'string') ids.push(component.content);
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
  if (removed.has(component.child as string)) delete component.child;
  if (removed.has(component.content as string)) delete component.content;
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
      return icon(component.icon);
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
