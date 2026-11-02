/**
 * Builds again, from their prompts, the apps whose actions this runner
 * cannot run as stored: the ones written in JavaScript before actions were
 * Dart. Bytecode from an older runner needs none of this (opening the app
 * recompiles it); this is for source that no longer compiles at all.
 *
 *   npm run build && npm run apps:rebuild
 *   docker exec my-own-app-backend node dist/apps/rebuild.js   # on the Pi
 *
 * Each rebuild is one model call. An app that fails is named and left as
 * it is.
 */
import { NestFactory } from '@nestjs/core';
import { AppModule } from '../app.module';
import { AppsService } from './apps.service';

async function main(): Promise<void> {
  const context = await NestFactory.createApplicationContext(AppModule, {
    logger: ['error', 'warn'],
  });
  const apps = context.get(AppsService);
  let failed = 0;
  try {
    for (const id of await apps.stale()) {
      try {
        await apps.rebuild(id);
        console.log(`rebuilt ${id}`);
      } catch (error) {
        failed++;
        const why = error instanceof Error ? error.message : String(error);
        console.error(`failed ${id}: ${why}`);
      }
    }
  } finally {
    await context.close();
  }
  process.exitCode = failed > 0 ? 1 : 0;
}

void main();
