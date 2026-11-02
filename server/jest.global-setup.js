/**
 * Pins the zone every test worker runs in.
 *
 * It has to happen here, in the parent process before the workers are
 * spawned: a test file gets a sandboxed copy of `process.env`, so setting
 * `TZ` from inside one never reaches the clock `Date` reads.
 */
module.exports = () => {
  process.env.TZ = 'America/Sao_Paulo';
  // The actions' specs run the real action runner (../runner), built here
  // once when its sources changed.
  require('node:child_process').execFileSync(
    'node',
    [require('node:path').join(__dirname, 'scripts/build-runner.mjs')],
    { stdio: 'inherit' },
  );
};
