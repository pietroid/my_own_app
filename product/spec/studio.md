# The studio: changing an app by talking about it

A built app opens in the **studio**: the conversation that changes it, the
app running inside a phone, and an inspector of its components. Every
request is a **version**; any version can be looked at and brought back.

## Layout (`app/lib/apps/app_run_page.dart`)

| Window | What it shows |
|--------|---------------|
| ≥ `AppSpacing.studioBreakpoint` (1100) | conversation · phone · inspector |
| ≥ `AppSpacing.phoneFrameBreakpoint` (720) | conversation · phone |
| narrower | the app is the screen; the conversation opens as a sheet (app bar) |

- **Conversation** (`StudioChat`): one turn per version: the request, the
  reply, and a version chip (`Versão n`, `atual`, what it changed) that
  opens that version on the phone. A request with no change keeps its
  turn and says "Sem mudanças no app".
- **Picking** (`AppRenderer.onSelect`): the cursor button in the app bar
  turns it on. A tap picks the innermost component instead of running it;
  every copy of the picked one (a list template draws one per item) is
  outlined in the accent. Picking a row of the tree turns picking on too.
- **Inspector** (`StudioInspector`): the tree from `root` in drawing order
  (a template child marked "por item"), and the picked component's menu:
  id, text, label, value binding, children or items, its action (saved or
  screen-only, what it reads), and **Pedir mudança**, which makes it the
  subject of the next request (a chip over the field).
- **Looking at a version**: the phone shows it read-only (taps do
  nothing), with a bar over it: "Voltar à atual" and "Restaurar esta".

## Versions (`app_version`)

One row per version: `n` (from 1), `prompt`, `reply`, and the app right
after it: `name`, `ui`, `actions` (source and bytecode), `data`, and
`changes` (`components`, `removed`, `actions`, `removedActions`, `name`,
`data`, `restoredFrom`). `generated_app.version` is the number the app is
at. The conversation is the versions; nothing else is stored.

An app from before versions gets its version 1, from its build prompt and
what it is now, the first time its history is read or it is changed.

## Changing an app: tools, not a whole bundle

`POST /api/apps/:id/messages { prompt, focus? }` runs `runEdit`
(`server/src/apps/edit.ts`). The model gets `EDIT_PROMPT`, the last 6 turns,
and the app as it is (`describeApp`): `name`, `data` (lists cut to 3 items),
`ui`, and **the actions by name and input only, never their code**. It
changes the app with tools, on a draft:

| Tool | Does |
|------|------|
| `set_components` | adds components, or replaces whole ones by id |
| `remove_components` | removes by id; parents stop listing them; never `root` |
| `update_data` | a JSON Patch on the data (a new field, a default) |
| `read_action` | answers an action's code, to change it |
| `set_action` | adds or replaces one action (checked on its own at once) |
| `remove_action` | removes one |
| `rename_app` | renames |

When it answers in words, the whole draft must pass `parseBundle`;
otherwise the error goes back and it fixes it, up to 8 model calls and
80 s (under the proxy's 100 s). Only actions whose code changed are
compiled; the rest keep their bytecode. A change to the screen costs the
components it touches, not every action's Dart.

The new version is written in one transaction with the app, under the
`rev` check. Taps that land while the model works keep their data: the
edit's own data patches are replayed on the data as it is then. Another
edit that landed first is a 409.

## Routes

| Route | Answers |
|-------|---------|
| `GET /api/apps/:id/versions` | `{ current, versions: [{ n, prompt, reply, changes, createdAt }] }` |
| `GET /api/apps/:id/versions/:n` | the app at version n (same shape as `GET /api/apps/:id`, `version: n`) |
| `POST /api/apps/:id/messages` | `{ version, app }`; analytics `app_edited` |
| `POST /api/apps/:id/versions/:n/restore` | `{ version, app }`, a new version with `restoredFrom: n`; the data stays when its top-level keys match that version's, otherwise it is that version's; analytics `app_restored` |

`GET /api/apps/:id` now also says `version`.

## Not done

- `npm run apps:rebuild` rewrites an app without a new version.
- Picking needs the studio's width; on a phone there is no inspector.
- A version is looked at, not run: its actions never run on the device.
