import { Logger } from '@nestjs/common';
import { NestFactory } from '@nestjs/core';
import { NestExpressApplication } from '@nestjs/platform-express';
import { toNodeHandler } from 'better-auth/node';
import { ANALYTICS, Analytics } from './analytics/analytics';
import { AppModule } from './app.module';
import { Auth, listOf } from './auth/auth';
import { AUTH } from './auth/auth.tokens';
import { LoggingInterceptor } from './common/logging.interceptor';
import { Database, DB, migrateDatabase } from './db/db';

async function bootstrap() {
  // Better Auth reads the raw request body itself, so Nest's parsers are off
  // until its routes are mounted, and switched on for everything after.
  const app = await NestFactory.create<NestExpressApplication>(AppModule, {
    bodyParser: false,
  });
  const logger = new Logger('Bootstrap');

  await migrateDatabase(app.get<Database>(DB));
  logger.log('Database is up to date');

  // In production the web app is served from the same origin as the API and
  // needs none of this. It is for the Flutter dev server on another port.
  app.enableCors({
    origin: [
      ...listOf(process.env.BETTER_AUTH_URL),
      ...listOf(process.env.TRUSTED_ORIGINS),
    ],
    credentials: true,
    methods: ['GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'OPTIONS'],
    allowedHeaders: ['Content-Type', 'Authorization', 'Accept'],
    exposedHeaders: ['set-auth-token'],
    maxAge: 86400,
  });

  app
    .getHttpAdapter()
    .getInstance()
    .all('/api/auth/*splat', toNodeHandler(app.get<Auth>(AUTH)));

  app.useBodyParser('json');
  app.setGlobalPrefix('api');

  // Logs response status, timing, user id and errors for every handled
  // request, and tells PostHog of each write and each failure.
  app.useGlobalInterceptors(
    new LoggingInterceptor(app.get<Analytics>(ANALYTICS)),
  );
  app.enableShutdownHooks();

  await app.listen(process.env.PORT ?? 3000);
  logger.log(`Server listening on port ${process.env.PORT ?? 3000}`);
}
void bootstrap();
