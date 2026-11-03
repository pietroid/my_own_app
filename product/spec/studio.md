# The studio

The studio is no longer native widgets: it is **My Own App Editor**, an app
built from the catalog and run by the same engine as any app. See
[editor.md](./editor.md).

What stays from before: every request is a **version** (`app_version`:
the request, the reply, the app right after, its `form`, and `changes`,
which now also says `form` and `restoredFrom`); any version can be looked
at (`GET /api/apps/:id/versions/:n`) and brought back
(`POST /api/apps/:id/versions/:n/restore`); a change is made by tools
(`server/src/apps/edit.ts`, `EDIT_PROMPT`), the model reading an action's
code only with `read_action`.

**Form.** `generated_app.form` is `mobile` or `web`; `PATCH /api/apps/:id
{ form }` switches it as a version without the model; the model is told the
form with every build and change (`FORMS`). A web app is drawn in
`AppBrowserFrame`, a phone app in `AppPhoneFrame`.
