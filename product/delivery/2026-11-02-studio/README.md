# The studio: chat, pick, versions

## 1. The prompt

> it is working good. Now lets make an improvement, we can have a chat inside the prototype screen, we should also be able to select any component on the tree, highlight it (it will show a menu on the sidebar), and in each point of history of the chat I can see the version of the things.
>
> Also, a improvement: if actions definitions are in the same json prompt, I would recommend to separate them in other files because imagine the case where I ask to change a minor thing and it also changes the action, and it would consume a lot of tokens. Take the advantage to use a tool call if the action needs to be changed or removed or added

During the design phase:

> oh dont need to use the preview, just go

> just build it i approve

## 2. The design

No mockup: the person skipped it and approved building straight away. The
decisions taken in the build:

| # | Decision | Chosen | Why |
|---|----------|--------|-----|
| 1 | Where the chat lives | Left panel beside the phone (≥ 720 px); a sheet from the app bar on a phone | The phone frame already leaves room on a wide window |
| 2 | Inspector | Right panel, ≥ 1100 px only: the tree, then the picked component's menu | Three panels need the width |
| 3 | Picking | A cursor toggle in the app bar; a tap picks the innermost component; all copies of a list template are outlined in the accent | Taps must not run actions while inspecting |
| 4 | The menu's action | **Pedir mudança**: makes the component the subject of the next request (a chip over the field, `focus` sent to the server) | Gives the model the target and keeps the request short |
| 5 | History | The conversation *is* the versions (`app_version`), one turn per version, a chip under each reply opens it | Nothing else to store; every point of the chat has its app |
| 6 | Looking at an old version | Read-only on the phone, with "Voltar à atual" / "Restaurar esta" | Running old actions against today's data could corrupt it |
| 7 | Restore | A new version, never a rewind; data kept when its top-level keys match | History stays append-only |
| 8 | Actions out of the prompt | The model sees actions by name and input only; `read_action` to see code, `set_action` / `remove_action` to change it | A label change no longer re-sends or re-writes every action's Dart |
| 9 | Creation | Unchanged (`create_app`, one forced call) | It works; the waste the request named is in edits |

Icons (Phosphor): `cursor` (pick), `treeStructure` (tree),
`clockCounterClockwise` (version), `arrowCounterClockwise` (restore),
`lightning` (action), and one per component type.

## 3. What was built

No prints: the person asked to skip the preview. The proof is the tests
and a run against Postgres:

```
edit 2 { components: [ 'add' ], actions: [], … } 2 { todos: [ 'Pão' ] }
restore 3 { components: [ 'add' ], restoredFrom: 1, … } Adicionar { todos: [ 'Pão' ] }
history 3 [ [ 1, 'Uma lista', '' ], [ 2, 'Mude o botão', 'Mudei o botão.' ], [ 3, '', '' ] ]
v2 2 Nova [ 'add_todo' ]
```

(a temporary script over the real `AppsService`, local PGlite, the real
action runner, a scripted model: create, tap, edit, restore, history,
version; deleted afterwards.)

**The rule that matters:** an edit is tools on a draft. The whole draft
must pass `parseBundle` before anything is kept; only actions whose code
changed are compiled; the version and the app are written in one
transaction, and taps that landed meanwhile keep their data (the edit's
data patches are replayed on top).

Server:
- `src/apps/edit.ts`: `EditDraft` (the seven tools), `runEdit` (the loop:
  up to 8 calls, errors sent back), `diff`, `describeApp`, `EDIT_TOOLS`.
- `src/apps/apps.service.ts`: `history`, `version`, `edit`, `restore`,
  `_commit`, `_firstVersion` (an old app gets its v1 lazily); `create`
  writes v1; `_compile` skips bytecode that is current; the prompt is now
  `RULES` + `EXAMPLE`, shared by `BUILD_PROMPT` (unchanged text) and the
  new `EDIT_PROMPT`.
- `src/apps/apps.controller.ts`: `GET :id/versions`, `GET :id/versions/:n`,
  `POST :id/messages`, `POST :id/versions/:n/restore`.
- `src/db/schema.ts`: `app_version`, `generated_app.version`;
  `drizzle/0002_app_versions.sql`.
- `src/analytics/events.ts`: `app_edited`, `app_restored`.

App:
- `lib/apps/studio_cubit.dart`: the conversation, sending, picking,
  focus, looking at and restoring versions.
- `lib/apps/studio_chat.dart`, `lib/apps/studio_inspector.dart`.
- `lib/apps/app_run_page.dart`: the three layouts.
- `lib/apps/app_renderer.dart`: `onSelect` / `selectedId`.
- `lib/apps/apps_repository.dart`: `AppVersion`, `AppChanges`,
  `AppHistory`, `AppEdit`, and the four calls; `AppRunCubit.replace`.
- `app_ui`: 12 icons, 8 spacing tokens; 46 strings in `app_pt.arb`.

Tests: server 40 (9 new in `edit.spec.ts`), app `test/apps` 20 (5 new in
`studio_cubit_test.dart`, 1 new renderer test). `.tool/check` green. No
flaky tests.

**Not tested:** against a real model (the tools' descriptions and
`EDIT_PROMPT` have never met one), and the studio UI has not been seen
running: no prints, no manual run.

## 4. How to turn it on

Nothing new: the migration runs on boot. Without `OPENROUTER_*` the
conversation answers 503 ("O assistente ainda não está conectado a um
modelo."); history, looking at versions and restoring still work.

## 5. Cost and time

One session, design and build together. USD from usage-bars at the end
of the build: **$3.75**. `.tool/cost` failed (it looks for the transcript
under `-my_own_app`, but Claude Code names the folder with `-my-own-app`),
so there is no per-message table and no token totals. No spend outside
Claude: no OpenRouter call was made.
