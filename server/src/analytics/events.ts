/**
 * The person's actions, one event per write that succeeded, by route. Reads
 * are not events, and neither is a refusal (a 4xx): only what changed.
 *
 * Keyed by method and the route as Nest declares it, without the global
 * prefix, so an id in the path never reaches an event name. A new write
 * route gets its row here.
 */
const EVENTS: Record<string, string> = {
  'POST /assistant/chat': 'assistant_turn',
};

/** The route a request matched, without the `/api` prefix (`/items/:id`). */
export function routeOf(path: string | undefined): string | undefined {
  if (!path) return undefined;
  return path.replace(/^\/api(?=\/|$)/, '') || '/';
}

/** The event a successful `method route` is, or undefined when it is none. */
export function eventFor(
  method: string,
  route: string | undefined,
): string | undefined {
  if (!route) return undefined;
  return EVENTS[`${method.toUpperCase()} ${route}`];
}
