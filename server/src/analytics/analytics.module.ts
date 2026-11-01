import { Global, Inject, Module, OnApplicationShutdown } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { ANALYTICS, analyticsFrom } from './analytics';
import type { Analytics } from './analytics';

/** PostHog for the whole server, off without `POSTHOG_KEY`. */
@Global()
@Module({
  providers: [
    {
      provide: ANALYTICS,
      inject: [ConfigService],
      useFactory: (config: ConfigService): Analytics =>
        analyticsFrom({
          POSTHOG_KEY: config.get<string>('POSTHOG_KEY'),
          POSTHOG_HOST: config.get<string>('POSTHOG_HOST'),
        }),
    },
  ],
  exports: [ANALYTICS],
})
export class AnalyticsModule implements OnApplicationShutdown {
  constructor(@Inject(ANALYTICS) private readonly _analytics: Analytics) {}

  /** Sends what is still queued before the process goes. */
  async onApplicationShutdown(): Promise<void> {
    await this._analytics.shutdown();
  }
}
