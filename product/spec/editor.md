# My Own App Editor: the studio, built with itself

Every account has one project, **My Own App Editor** (`seed: 'editor'`).
It is an ordinary app: a `ui` from the catalog, one `data` document, and
Dart `actions`, drawn by `AppRenderer` and run by `action_runner`. It is
the studio. Opening any app (`/apps/:id`) opens the editor with that app in
it. Opening the editor itself edits the editor.

Source: `server/src/apps/editor/editor.ts`, written by hand, not by the
model. Spec: `editor.spec.ts`.

## How it opens

- `GET /api/apps/editor` answers the person's copy, and makes it the first
  time (version 1, actions compiled).
- `AppRunPage(id)` runs it (`AppRunCubit(source: repository.editor, start:
  {id})`). Once loaded, its `start` action runs with `{id}` (engine rule:
  an action named `start` runs when an app opens).
- The editor can fail to load (a person broke theirs). In that case the app
  runs on its own, under a banner with **Restaurar editor**, which calls
  `POST /api/apps/editor/reset`. That makes a new version from
  `editor.ts`, and the broken one can still be restored.
- `GET /api/apps` lists the editor first (`seed`). The home shows it with
  "O editor dos seus apps".

## What it does, and with what

| Piece | Components | Actions |
|-------|-----------|---------|
| The app, running | `Surface` (`app /editing`, `version /viewing`, `revision /revision`, `picking /picking`, `selected /picked`) | `pick` (client) |
| Celular / Web | `ChoicePicker` (`style: segmented`) on `/formChoice`, in the `TopBar` | `set_form` (platform: `apps.setForm`) |
| Conversation | `List` of `Message` over `/turns`; `/$pending/send` shows the request and "Pensando…" while it runs; `TextField` + `Button` | `send` (platform: `apps.send`, `apps.history`) |
| Focus | `Badge` "Sobre: id", close `Button` | `ask_change`, `clear_focus` (client) |
| Versions | `List` of `ListItem` over `/versionRows`; a `Callout` pinned under the app while one is looked at | `view`, `back` (client), `restore` (platform) |
| Components | `List` of dense `ListItem` over `/tree` (`inset` = depth, `icon component:<Type>`, `selected`), the picked component's rows in a `Box` | `pick`, `toggle_picking` (client) |
| Layout | A `Screen` (`TopBar` header). `Pages` on `/$viewport/size`: `expanded` is a `Split` of three `Panel`s (Conversa, its composer pinned · Prévia · Componentes/Versões tabs); otherwise one `Panel` at a time, picked by a bottom `NavBar` on `/tab` | — |

The Dart the actions share (`treeOf`, `turnsOf`, `versionRowsOf`,
`pickedRowsOf`, `slim`, `viewsOf`) is written once in `editor.ts` and
prepended to each action. The runner has no imports. Platform actions put
the edited app (`slim`: no data, no code) in `/app` and the history in
`/history`. Client actions compute from those on the device.

## The editor as a project

The editor is a `web` app, so opening it (from the home, like any app)
shows it in a browser frame at its wide layout: the whole studio, with its
own Surface drawn as **O motor do app**, a placeholder for the engine. It
is not run live inside itself. Its data carries `editorVersion`; a copy
older than `EDITOR_VERSION` (`editor.ts`) is brought up to date when it is
opened, as a new version ("O editor foi atualizado."), and the old one can
still be restored.

## Selection

The picked component (`selected` on the Surface) is outlined in the
accent and tagged with its id whether or not picking is on, so a pick in
the tree shows in the app. While picking, the innermost component under
the pointer gets a lighter outline and tag, and a tap picks it instead of
running it.

## Limits

- The interpreter has no `continue`, does not narrow after `is`, and reads
  `[]` on an untyped loop variable as a list's. Cast before reading
  (`final t = tab as Map`).
- When the editor edits itself, the change shows when it is opened again,
  not mid-tap. A Surface inside a Surface draws a placeholder.
- A tap reaches the model at most once (`MAX_MODEL_CALLS`), and makes at
  most 8 platform calls.
