/**
 * Better Auth's `baseURL` for [origins]: the one origin as it is, or, with
 * more than one, the host of each request when it is one of theirs.
 */
export function baseUrlOf(
  origins: string[],
):
  | string
  | { allowedHosts: string[]; fallback: string; protocol: 'http' | 'https' } {
  if (origins.length === 0) throw new Error('No base URL');
  if (origins.length === 1) return origins[0];

  const urls = origins.map((origin) => new URL(origin));
  return {
    allowedHosts: urls.map((url) => url.host),
    fallback: origins[0],
    // Behind the tunnel nginx sees plain http, so the scheme comes from the
    // configured origins rather than from the request.
    protocol: urls[0].protocol === 'https:' ? 'https' : 'http',
  };
}
