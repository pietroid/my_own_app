# Actions

An app's actions are small Dart functions the model writes once, compiled
into dart_eval bytecode, and run without the model from then on. **Every
action runs on the device first**, so the screen changes the moment the
person taps. A saved action (`on: "server"`, the default) is then run again
by the server on its own copy, which keeps the patch; a client action
(`on: "client"`) only changes the screen.

## Local first (`AppRunCubit`)

1. A tap on a saved action runs it on the device and shows its patch.
2. The tap is queued; the queue sends one at a time, in order, so the
   server reads the same data the device did.
3. The server's patch equal to the one shown: nothing more. Different: the
   server's copy is loaded. A refusal: the server's copy is loaded and its
   words shown.
4. An action the device cannot run (bytecode from a newer server) waits for
   the server and shows its patch, as before.
5. A client action's `call(name, event)` is step 1–3 for that saved action,
   and resolves to the patch shown.

What a person types (a `TextField`) lives only on the device, so a saved
action reads it from the event (the button's `context`), never from
`input`: on the server, `input` would read the saved, empty field. The
prompt says so, and the example does it.

## The contract

```dart
Future<List> run(Map input, Map event, Function call) async { ... }
```

- `input`: the JSON Pointers the action declared, keyed by pointer, read
  from the app's data. `event`: the component's context (and `itemPath`,
  `index` inside a template).
- It answers a JSON Patch (RFC 6902) as a `List` of `Map`s.
- Always `async`: dart_eval will not `await` a value that is not a `Future`.
- `call(name, event)`, in a client action, runs a saved action (above)
  and resolves to its patch.
- Values cross in and out as JSON strings: nothing but plain data.
- The subset of Dart that works is listed in `BUILD_PROMPT`
  (`server/src/apps/apps.service.ts`); no imports, classes, mixins,
  extensions, `late`, generators, switch expressions, records or patterns.

## The interpreter (`runner/`)

- `runner/third_party/dart_eval`: dart_eval 0.8.5, vendored with one change,
  a **step budget** (`Runtime.stepLimit`, checked in its two interpreter
  loops, uncatchable by the program). 2,000,000 steps per run, across every
  `await`; time spent waiting on `call` does not count.
- `lib/compile.dart`: source → bytecode, or `ActionCompileError` with the
  compiler's words. Server only (it brings the Dart analyzer).
- `lib/run.dart`: bytecode → patch, or `ActionRunError` (`tooLong` past the
  budget). No files, network or processes are granted. A `call` that throws
  fails the action with that same error.
- `bin/runner.dart`: the server's process, JSON lines on stdin/stdout:
  `version`, `compile`, `run`.
- `runnerVersion` names the runner; bytecode runs only on the one that wrote
  it. Bump it with any change to `third_party/` that changes what runs.

## The server

- `ActionRunner` (`server/src/apps/runner.ts`) starts the process on first
  use, matches answers by id, fails a request that takes too long
  (compile 10 s, run 2 s) by killing the process, and starts it again on the
  next request. Its heap is capped by `ACTION_RUNNER_HEAP_MB` (default 128)
  through `DART_VM_OPTIONS=--old_gen_heap_size`; past it the process dies
  and the same happens.
- Building an app compiles every action; a compile error is a bad bundle,
  sent back to the model in the one retry. Stored per action: `code`, `evc`
  (base64), `version`.
- Reading an app whose bytecode another runner version wrote recompiles it
  from `code` and keeps it.
- Apps with actions that were never compiled (JavaScript, from before) are
  rebuilt from their prompt by `node dist/apps/rebuild.js`: one model call
  each; the old data is kept when the new data has the same top-level keys.
  `--all` rebuilds every app from fresh data, for a changed `BUILD_PROMPT`.
- Model JSON is read leniently in two lossless ways: an `actions` sent as a
  JSON-encoded string is decoded, and a Dart `\$` left unescaped in the
  JSON is read as the `\$` it is (`parseModelJson`).

## The app

- `ClientRunner` (`app/lib/apps/client_runner.dart`) runs `run.dart` on the
  main isolate, the same on web, iOS and Android. A failure of any kind is
  `ClientActionFailed`; the person sees the app's usual error.
- `GET /api/apps/:id` sends `actions: { name: { on, input, evc } }`, every
  action's bytecode; no source leaves the server.
