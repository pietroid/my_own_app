import { PostHog } from 'posthog-node';

/** Injection token of the one `Analytics` the server sends through. */
export const ANALYTICS = Symbol('ANALYTICS');

/**
 * What the server tells PostHog: the person's actions, by name, and the
 * failures nobody answered for. Never a body, a title, a note or an email:
 * the properties are the route and the status, nothing a person wrote.
 */
export interface Analytics {
  capture(
    userId: string,
    event: string,
    properties?: Record<string, unknown>,
  ): void;
  captureException(
    error: unknown,
    userId: string | undefined,
    properties: Record<string, unknown>,
  ): void;
  shutdown(): Promise<void>;
}

/** Sends nothing: tests, CI, local work, and any server without a key. */
export class NoAnalytics implements Analytics {
  capture(): void {}
  captureException(): void {}
  async shutdown(): Promise<void> {}
}

/** Every event and exception tagged as the server's, beside the app's. */
const SOURCE = { source: 'server' };

export class PostHogAnalytics implements Analytics {
  private readonly _client: PostHog;

  constructor(key: string, host: string) {
    // Autocapture catches what escapes every request: a promise nobody
    // awaited, an idle database connection lost.
    this._client = new PostHog(key, {
      host,
      enableExceptionAutocapture: true,
    });
  }

  capture(
    userId: string,
    event: string,
    properties: Record<string, unknown> = {},
  ): void {
    this._client.capture({
      distinctId: userId,
      event,
      properties: { ...SOURCE, ...properties },
    });
  }

  captureException(
    error: unknown,
    userId: string | undefined,
    properties: Record<string, unknown>,
  ): void {
    this._client.captureException(error, userId, {
      ...SOURCE,
      ...properties,
    });
  }

  shutdown(): Promise<void> {
    return this._client.shutdown();
  }
}

/** PostHog when `POSTHOG_KEY` is set, nothing otherwise. */
export function analyticsFrom(
  env: Record<string, string | undefined>,
): Analytics {
  const key = env.POSTHOG_KEY?.trim();
  if (!key) return new NoAnalytics();
  return new PostHogAnalytics(
    key,
    env.POSTHOG_HOST?.trim() || 'https://us.i.posthog.com',
  );
}
