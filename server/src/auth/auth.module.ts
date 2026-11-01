import { Global, Module } from '@nestjs/common';
import { ConfigModule, ConfigService } from '@nestjs/config';
import { DB } from '../db/db';
import type { Database } from '../db/db';
import { createAuth, listOf } from './auth';
import { AUTH } from './auth.tokens';
import { SessionGuard } from './session.guard';

/**
 * Better Auth, as one injectable instance.
 *
 * Its HTTP routes are mounted in `main.ts`, ahead of Nest's body parser,
 * because Better Auth reads the raw request itself. Everything Nest owns
 * reaches it through [SessionGuard].
 */
@Global()
@Module({
  imports: [ConfigModule],
  providers: [
    {
      provide: AUTH,
      inject: [DB, ConfigService],
      useFactory: (db: Database, config: ConfigService) => {
        const required = (key: string): string => {
          const value = config.get<string>(key);
          if (!value) throw new Error(`${key} is not set`);
          return value;
        };

        return createAuth(db, {
          baseUrls: listOf(required('BETTER_AUTH_URL')),
          secret: required('BETTER_AUTH_SECRET'),
          googleClientIds: listOf(required('GOOGLE_CLIENT_IDS')),
          googleClientSecret: required('GOOGLE_CLIENT_SECRET'),
          trustedOrigins: listOf(config.get<string>('TRUSTED_ORIGINS')),
          allowedEmails: listOf(config.get<string>('ALLOWED_EMAILS')),
        });
      },
    },
    SessionGuard,
  ],
  exports: [AUTH, SessionGuard],
})
export class AuthModule {}
