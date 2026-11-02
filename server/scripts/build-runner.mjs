// Compiles the action runner (../runner) into ../runner/build/runner, the
// executable ActionRunner starts, when any of its sources is newer than it.
// Needs Dart on the PATH (Flutter's will do). The image builds its own.
import { execFileSync } from 'node:child_process';
import { mkdirSync, readdirSync, statSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const runner = resolve(dirname(fileURLToPath(import.meta.url)), '../../runner');
const out = join(runner, 'build/runner');

function newest(dir) {
  let latest = 0;
  for (const entry of readdirSync(dir, { withFileTypes: true })) {
    const path = join(dir, entry.name);
    latest = Math.max(
      latest,
      entry.isDirectory() ? newest(path) : statSync(path).mtimeMs,
    );
  }
  return latest;
}

const built = (() => {
  try {
    return statSync(out).mtimeMs;
  } catch {
    return 0;
  }
})();
const sources = Math.max(
  ...['bin', 'lib', 'third_party', 'pubspec.yaml'].map((name) => {
    const path = join(runner, name);
    return statSync(path).isDirectory() ? newest(path) : statSync(path).mtimeMs;
  }),
);

if (sources > built) {
  console.log('Building the action runner…');
  execFileSync('dart', ['pub', 'get'], { cwd: runner, stdio: 'inherit' });
  // `dart compile exe` does not create the folder it writes into.
  mkdirSync(dirname(out), { recursive: true });
  execFileSync('dart', ['compile', 'exe', 'bin/runner.dart', '-o', out], {
    cwd: runner,
    stdio: 'inherit',
  });
}
