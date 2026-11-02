# third_party

`dart_eval/` is [dart_eval](https://pub.dev/packages/dart_eval) 0.8.5
(BSD-3, `dart_eval/LICENSE`), vendored for one change: a step budget.
Every change is marked `my_own_app:` (`grep -rn my_own_app: dart_eval`).

- `lib/src/eval/runtime/runtime.dart`: `Runtime.stepLimit` and
  `Runtime.steps`, checked in the interpreter's two loops (`execute` and
  `bridgeCall`); past the limit they throw `StepLimitExceeded`, which the
  running program cannot catch.

Its `test/`, `example/` and `bin/` are left out, and so are its
dev_dependencies. To move to a newer dart_eval, copy its `lib/` in and
re-apply the marked changes; the app and the server must move together,
since bytecode is not portable across versions.
