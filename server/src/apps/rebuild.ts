/**
 * Builds apps again from their prompts.
 *
 * - By default, the apps whose actions this runner cannot run as stored:
 *   the ones written in JavaScript before actions were Dart. Their data is
 *   kept when its shape survives. Bytecode from an older runner needs none
 *   of this (opening the app recompiles it).
 * - With `--all`, every app, from fresh data: for when `BUILD_PROMPT`
 *   changed how apps should be built. What the apps held is lost.
 *
 *   npm run build && npm run apps:rebuild [-- --all]
 *   docker exec my-own-app-backend node dist/apps/rebuild.js [--all]   # on the Pi
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
  const all = process.argv.includes('--all');
  let failed = 0;
  try {
    for (const id of all ? await apps.all() : await apps.stale()) {
      try {
        await apps.rebuild(id, { keepData: !all });
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
