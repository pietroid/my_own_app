# Actions in Dart

## 1. The prompt

> is there a way to make js reponse faster on web client?

> yep please build

> on a mobile for ios and android how much would you estimate to be this tap to effect duration?

> I mean for native, you can research and already start thinking on how this would work for android and ios

> ok and could i run dart on native as im using flutter?

> lets use dart eval then, and the web is simplified also. We should also find a way to run dart on the backend

> a process i mean

> Apps saved today with JS actions get rebuilt It gets thrown away rather than committed. yep

> we can have a single dart server on the backend that receives functions

(Answers: rebuild the JS apps from their prompts; discard the Worker
speed-up, which had meanwhile been committed as `5869555`, by replacing it.)

## 2. The plan

Track: **plan** (no screen changes; a failed action shows the same error it
shows today).

### Approach

An action becomes a Dart function, `Future<List> run(Map input, Map event,
Call call)`, compiled once and run by [dart_eval] everywhere, in place of JS:

1. **`runner/`** (new, at the repo root): one Dart package, `action_runner`,
   used by both sides. It wraps the model's `run` in a fixed entry point
   (input and event go in as JSON strings, the patch comes out as one), binds
   `call`, and holds the **step budget** (below). It has a `bin/` that the
   server runs as a **child process**.
2. **Server:** `sandbox.ts` stops using isolated-vm. Nest starts the runner
   process once and talks to it over stdin/stdout, one JSON line per
   request: `compile` (Dart source → EVC bytecode, or the compiler's errors)
   and `run` (bytecode + input + event → patch). Each run goes in an
   `Isolate` of its own inside the process, killed at 50 ms. If the process
   dies (out of memory), Nest fails what was running and starts it again.
3. **Build:** `parseBundle` stays the same; `create_app` then compiles every
   action through the runner, and a compile error goes back to the model in
   the one retry, as a bad bundle does today. The bytecode is stored next to
   the source (`actions` keeps `code`, adds `evc`, base64, and the dart_eval
   version). `BUILD_PROMPT` asks for Dart and lists what dart_eval cannot do.
4. **App:** `client_runner_web.dart` and the stub are replaced by one
   `client_runner_eval.dart`, used on web, iOS and Android. It runs the
   bytecode it got from `GET /api/apps/:id` (no compiler on the device) on the
   main isolate, inside the step budget. `call` goes to `_server`, as now.
   The Worker, the `data:` URL and the spare are gone.
5. **Image:** the server's production stage moves from `node:24-alpine` to
   `node:24-bookworm-slim` (a Dart AOT binary needs glibc), and the build
   stage compiles `runner/bin` with `dart compile exe` for ARM64.
6. **Old apps:** apps stored with JS actions are rebuilt from their stored
   `prompt` by a one-off script; anything that fails is deleted.

**The step budget.** dart_eval has no timeout and no memory limit, and its
interpreter is one loop (`Runtime.execute` and `Runtime.bridgeCall`,
`lib/src/eval/runtime/runtime.dart:858` and `:881` in 0.8.5). We vendor
0.8.5 (`runner/third_party/dart_eval`, MIT/BSD kept) and add a counter to
both loops: every 4096 ops it checks a `Stopwatch` against the run's
deadline and throws. That is what makes it safe to run on the web's main
thread: a runaway action freezes the screen for at most its budget (50 ms on
the device, the same as the server), not forever.

### References

- [dart_eval on pub.dev][dart_eval] (0.8.5): "the runtime will not allow
  running programs to access the file system, network, or other system
  resources" by default; async/await supported, Futures partial; no
  generators, mixins, extension methods, `late` or switch expressions;
  "10-50x slower than standard AOT Dart"; "pre-compile your Dart code to EVC
  bytecode"; bytecode carries "magic constant and version" (0.6.4).
- [dart_eval changelog][changelog]: 0.5.0 "Web support for both compiler and
  runtime"; 0.8.1 "Improve error handling when using `await` on a bridged
  future", the path `call` takes.
- dart_eval 0.8.5 source, `runtime.dart:851-895`: the two interpreter loops
  the step budget goes into, and the only two.

[dart_eval]: https://pub.dev/packages/dart_eval
[changelog]: https://pub.dev/packages/dart_eval/changelog

### Decisions

| # | Decision | Chosen | Why |
|---|----------|--------|-----|
| 1 | Where the server's Dart runs | A child process of Nest, in the same image | No new image, port or deploy step; one restart restarts both. A separate container would only isolate a crash better, and the process is restarted anyway. |
| 2 | Time limit | A step budget patched into dart_eval, plus `Isolate.kill` on the server | dart_eval has none. The budget works on the web, where there are no isolates; `kill` is a second wall on the server. |
| 3 | Memory limit | Server: the process heap is capped (`--old_gen_heap_size`, ~128 MB) and restarted if it dies. Device: none | No per-isolate cap exists in Dart. On the device the worst case is the person's own tab or app crashing, not anyone else's. This is weaker than today's 32 MB per action. |
| 4 | Compile where | Server only; the device gets bytecode | The compiler pulls in `analyzer` (a large dependency); keeping it off the app keeps the app small and catches errors at build time. |
| 5 | Bytecode versions | Pinned: app and runner use the same vendored dart_eval; the server recompiles stored source when its version changes | Bytecode is not portable across versions. A native app on an old version fails the action with the usual error until it updates. |
| 6 | Vendor or fork | Vendored copy in `runner/third_party/` | Two small changes; no fork to keep on GitHub. |
| 7 | JS actions | Removed, old apps rebuilt from their prompt | One language, one runner; the product is early. |
| 8 | The model | Writes Dart within dart_eval's subset | The expected cost: more failed builds than JS. The retry with the compiler's errors is the guard; measured in 3. |

### Risks I'll check first (a spike, before the rest)

1. `call` as a bridged async function returning a `Future`, awaited inside
   evaluated code, on dart2js and AOT.
2. `jsonDecode`/`jsonEncode` inside dart_eval (its `dart:convert` binding).
3. Speed: compile + run time of a typical action, on the web and in the
   runner, against today's numbers.

If 1 fails, client actions can't call server ones, and I come back to you
before building the rest.

### How it will be proved

- `runner/`: `dart test` covering patch out, `call` round trip, no `dart:io`
  without a grant, a runaway loop stopped by the budget, a compile error
  answered as errors.
- Server: `npm test` with the runner process (the sandbox specs, ported),
  plus a spec for a dead process being restarted.
- App: `flutter test` and `flutter test --platform chrome` on the eval
  runner (the five Worker tests, ported), and the tap-to-patch benchmark
  from earlier, before and after.
- The image: `docker buildx build --platform linux/arm64` and one action
  run inside it.
- The model: five app prompts built end to end against OpenRouter, with how
  many needed the retry.

## 3. What was built

### The contract

An action is `Future<List> run(Map input, Map event, Function call) async`
in Dart, compiled once by the server into dart_eval bytecode and run by the
same interpreter on the server and on every device. It gets no files,
network or processes, and stops past 2,000,000 interpreter steps. The whole
contract is in [product/spec/actions.md](../../spec/actions.md).

### Proof

| What | Command | Result |
|---|---|---|
| Runner, Dart VM | `cd runner && dart test` | 7 passed: patch out, `call` round trip, server error passed through, throw, runaway loop stopped (and not catchable), no `dart:io`, compile error |
| Runner, Chrome (dart2js) | `dart test -p chrome` | 7 passed |
| Server | `npm test` | 31 passed (apps: 16, against the real runner process: patch, no files or processes, loop stopped, compile error, restart after `SIGKILL`, a `$` in Dart, the build prompt's own example compiled and run, the `\$` JSON repair) |
| App | `flutter test` | 17 passed (the client runner on the VM: patch + `call`, throw, loop, unreadable bytecode, server error); the runner file also 5/5 with `--platform chrome` |
| Everything CI runs | `.tool/check` | runner, app, server, tools: all ✓ |
| Real model (Claude Haiku 5.5 on OpenRouter) | 5 prompts × 2 through `AppsService._build` | **10/10 built**, 9 on the first call, 1 after the retry; every action compiled |
| An app the model wrote, run | the to-do list's server actions on the runner: add Pão, add Leite, toggle 0, remove 1 | `{"draft":"","todos":[{"title":"Pão","done":true}]}` |
| Heap cap | an AOT binary allocating forever, `DART_VM_OPTIONS=--old_gen_heap_size=64` | `Out of Memory` at 73 MB resident, exit 255 |
| Image's binary | `dart compile exe --target-os=linux --target-arch=arm64` (on the Mac) | `ELF 64-bit … ARM aarch64 … interpreter /lib/ld-linux-aarch64.so.1` |

Speed of one tap, before and after (headless Chrome on the Mac, a to-do
`add` over 20 items):

| | median | p90 |
|---|---|---|
| Before: a Worker per tap (`b55a5ab`) | 5.2 ms | 7.5 ms |
| A pre-started Worker (`5869555`) | 1.0 ms | 1.6 ms |
| **Now: dart_eval on the page** | **0.5 ms** | **0.9 ms** |

On the server a run takes ~0.5 ms in the process (isolated-vm built a new
isolate each time). Compiling takes ~350 ms the first time (the analyzer
loads) and a few ms after. The 2M-step budget is used up in 8 ms on the
Dart VM, 20 ms in desktop Chrome.

The web bundle: `main.dart.js` 3,534,809 → 3,909,608 bytes (+375 KB, +11 %,
uncompressed); none of the analyzer reached it.

### Server

- `runner/` (new): `action_runner`, with `third_party/dart_eval` (0.8.5,
  BSD-3, the step budget marked `my_own_app:`), `lib/compile.dart`,
  `lib/run.dart`, `bin/runner.dart`.
- `server/src/apps/runner.ts` (new, `ActionRunner`) replaces
  `sandbox.ts`; `isolated-vm` and every `--no-node-snapshot` are gone.
- `apps.service.ts`: compiles on build, stores `evc` + `version`, recompiles
  stale bytecode on read, runs through the runner; `BUILD_PROMPT` and the
  `create_app` schema now ask for Dart; `parseModelJson`; `rebuild` and
  `stale` for `src/apps/rebuild.ts` (`npm run apps:rebuild`).
- `bundle.ts`: Dart in the rules; bytecode the model writes is dropped.
- `scripts/build-runner.mjs`: builds `runner/build/runner` when its
  sources changed (run by `start:local` and Jest's global setup).
- `Dockerfile`: a `dart:3.12` stage cross-compiles the runner for the
  target (`--build-context runner=../runner`); production moves to
  `node:24-bookworm-slim` (the binary needs glibc).
- CI: Flutter is set up first; runner analyze + tests on the VM and Chrome;
  the backend image gets `build-contexts: runner=./runner`.
- `.tool/check`: a change under `runner/` checks the runner, the server and
  the app.

### App

- `lib/apps/client_runner.dart`: one runner on every platform (dart_eval);
  `client_runner_web.dart`, `client_runner_stub.dart` and the Worker test
  are deleted. `ClientAction.code` → `ClientAction.evc`.
- `test/apps/client_runner_test.dart` (new).
- `pubspec.yaml`: `action_runner` (path); **`bloc_lint` ^0.4.1 → ^0.3.7**.

### Where the build differs from the plan

1. **No isolate per run on the server.** The step budget already stops a
   runaway action in ~8 ms, and the process is killed if a request takes
   over 2 s, so `Isolate.kill` would only add cost to every run.
2. **`run` is always `async`.** dart_eval refuses to `await` a value that is
   not a `Future`, so a sync `run` cannot be wrapped. The prompt says so.
3. **Compile rejects no more than parseBundle did; the model JSON is read
   more leniently.** Two failures the switch to Dart caused, both found by
   the real-model runs: models sent `actions` as a JSON string, and wrote
   Dart's `\$` (for "R$") bare into JSON, which is invalid there. Both are
   now read losslessly (`parseModelJson`), and the tool schema spells out
   the action's shape. Before these fixes the shopping-list prompt failed
   5 times in 5.
4. **`bloc_lint` downgraded to ^0.3.7.** The app depends on dart_eval, whose
   compiler needs `analyzer` <10, and bloc_lint 0.4 needs a newer one. The
   compiler does not build on analyzer 12 (317 errors), and the runtime
   imports the compiler throughout, so splitting them is a fork, not a
   patch. bloc_lint is a dev-only lint; this pins it until dart_eval moves.
5. **No compiler on the device**, as planned: source never leaves the
   server, only client bytecode does.

### Not verified

- **The Docker image was not built** (no Docker on this Mac). Its pieces
  were: the `dart:3.12` tag exists for amd64 and arm64, the ARM64
  cross-compile works, the binary is glibc-linked. CI's first build is the
  real test.
- **iOS and Android were not run.** The interpreter is pure Dart and
  passed on the VM (AOT-like) and in Chrome; no device or simulator run.
- **`rebuild.js` was not run against a database** (no stored JS app here).
  `rebuild` and `stale` have no spec of their own.
- **Memory on the device is uncapped**, as the plan said: an action that
  allocates without end crashes the person's own tab or app.

## 4. How to turn it on

- **Locally:** Dart on the `PATH` (Flutter's). `npm run start:local` and
  `npm test` build `runner/build/runner` when it is missing or stale.
- **Env (optional):** `ACTION_RUNNER` (the executable; the image sets
  `/usr/local/bin/action-runner`), `ACTION_RUNNER_HEAP_MB` (default 128).
  Both in `server/.env.example`.
- **After deploying:** once, `ssh focus docker exec my-own-app-backend node
  dist/apps/rebuild.js` (in SETUP.md). Until then, an app with JavaScript
  actions answers "Não consegui montar esse app" when opened.
- Without the runner the server still boots; building or running an app
  fails as "Essa ação falhou." / a bad bundle.

## 5. Cost and time

One session, from the first question (Worker speed-up, native research)
through this build:

| | |
|---|---|
| USD | **$7.33** (`mcp__usage-bars__session_cost`, at 20:02) |
| Tokens in | 74 fresh + 1,859,889 cache reads + 116,862 cache writes |
| Tokens out | 35,873 |
| Wall clock | not measured: `.tool/cost` failed (below) |

`.tool/cost` could not produce its per-message table: it looks for the
transcript under `~/.claude/projects/-Users-pietro-Documents-pietroid-dev-my_own_app`,
but Claude Code names the folder with `-` for `_` (`…-my-own-app`). Worth
an `/improve`.

Outside Claude: about 40 build calls to Claude Haiku 5.5 on OpenRouter for
the real-model runs (a few cents).
