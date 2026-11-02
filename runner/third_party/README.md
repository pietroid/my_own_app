# third_party

`dart_eval/` is [dart_eval](https://pub.dev/packages/dart_eval) 0.8.5
(BSD-3, `dart_eval/LICENSE`), vendored for two changes.
Every change is marked `my_own_app:` (`grep -rn my_own_app: dart_eval`).

- `lib/src/eval/runtime/runtime.dart`: `Runtime.stepLimit` and
  `Runtime.steps`, checked in the interpreter's two loops (`execute` and
  `bridgeCall`); past the limit they throw `StepLimitExceeded`, which the
  running program cannot catch.
- `lib/src/eval/compiler/expression/as.dart`: `x as T?` lets a null
  through (upstream type-tests every value against `T`, so
  `event['title'] as String? ?? ''` threw on a missing key), and a nullable
  `int`/`double` stays boxed. Both sides of the null test are boxed: a
  runtime null is a boxed `$null`, which a raw null does not equal.

Known and left alone: a conditional whose branches have different types
(`d == null ? 'none' : d * 2`) inside a list literal is not boxed and fails
at run time.

Any change here that changes the bytecode bumps `runnerVersion`
(`lib/run.dart`); the server then recompiles stored actions on read.

Its `test/`, `example/` and `bin/` are left out, and so are its
dev_dependencies. To move to a newer dart_eval, copy its `lib/` in and
re-apply the marked changes; the app and the server must move together,
since bytecode is not portable across versions.
