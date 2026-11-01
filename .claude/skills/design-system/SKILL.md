---
name: design-system
description: Tune the app's design system into this app's own look — colours, type, shape, the mark, the launcher icon and the splash — from a short interview. Use right after the app is created from the template, or whenever the user wants to restyle the app.
---

# Design system

The app was made from the app template, which ships a neutral placeholder
look (white, indigo, Inter, a ring for a mark). This skill turns it into the
app's own, in four steps: **interview, proposal, apply, verify**. Do not
skip the proposal: nothing is written before the user agrees to it.

Everything visual lives in a few places, and screens only read tokens, so a
restyle never touches a screen:

| What | Where |
|---|---|
| Colours | `app/packages/app_ui/lib/src/theme/app_colors.dart` |
| Type | `app/packages/app_ui/lib/src/theme/app_typography.dart` (`google_fonts`) |
| Spacing, radii, sizes | `app/packages/app_ui/lib/src/theme/app_spacing.dart` |
| Light or dark, the mark | `app/packages/app_ui/lib/src/theme/app_brand.dart` |
| Component themes | `app/packages/app_ui/lib/src/theme/app_theme.dart` |
| Widgets | `app/packages/app_ui/lib/src/widgets/` |
| Icon, Android foreground, splash | `app/brand/*.svg` → PNGs (see `app/brand/README.md`) |
| In-app mark | `app/packages/app_ui/assets/brand/mark.png` |
| Icon and splash colours | `app/flutter_launcher_icons.yaml`, `app/flutter_native_splash.yaml` |
| Web colours and name | `app/web/index.html`, `app/web/manifest.json` |

## 1. Interview

Read `AGENTS.md` and `README.md` first: what the app is for shapes
everything. Then ask, in one round with `AskUserQuestion` where the answer
is a choice (and plainly where it is free text), only what you cannot
infer:

- **Feeling**: three words for how it should feel (calm, sharp, playful,
  editorial, clinical, warm…), and who opens it, when.
- **References**: apps or sites whose look they like. If the Mobbin tools
  are connected, search a couple of them for screens to ground the
  proposal, and say which you looked at.
- **Light or dark**: one theme ships (`AppBrand.brightness`).
- **Accent**: a colour they already have in mind, or let you propose.
- **Type**: a face they like, or the character (geometric, humanist,
  grotesque, serif for headings…). It must be on Google Fonts.
- **Shape**: sharp, soft or round corners; dense or airy.
- **Mark**: an idea for the icon (a letter, a symbol, an abstract shape), or
  let you propose.

## 2. Proposal

Write the whole system down before touching code, and show it as a page the
user can look at, not only as text: an HTML file in the scratchpad (or an
Artifact, when available) with the palette as swatches labelled with token
names and hex values, the type scale set in the chosen face, the radii, a
mocked sign-in screen, the home's empty state and an assistant conversation,
and the mark at icon size. Open it for them.

Rules the proposal must keep:

- **Every token in `AppColors` keeps its meaning**; values change, names do
  not. A new need is a new token, with a doc comment saying what it is for.
- **Contrast**: `ink` on `bg` and `onAccent` on `accent` at least 4.5:1;
  `ink2` on `bg` at least 4.5:1; `ink3` is for placeholders only. Check the
  numbers and put them on the page.
- **One accent**: colour means "can be acted on" or a state, never
  decoration.
- The icon reads at 29 pt and on both a light and a dark home screen.

Ask for changes until they approve. Then apply exactly what was approved.

## 3. Apply

1. Tokens: `AppColors`, `AppTypography` (swap `GoogleFonts.inter` for the
   chosen face in `face()`; keep the method names of the scale),
   `AppSpacing` radii, `AppBrand.brightness`, and anything in `AppTheme` or
   the widgets the new shape needs (button height, field fill, bubble
   radius). Update the doc comments that describe the look; they are read.
2. The mark: write `app/brand/icon.svg`, `foreground.svg` and `splash.svg`
   on the 64-unit grid the current ones use, then render and regenerate as
   `app/brand/README.md` says (PNGs, `mark.png`, launcher icons, splash).
   Set the colours in both YAML files first.
3. Web: `background-color` in `web/index.html`'s splash style and
   `background_color` / `theme_color` in `web/manifest.json`;
   `apple-mobile-web-app-status-bar-style` to `black-translucent` for a dark
   app, `default` for a light one.
4. Check `ios/Runner/Info.plist` still says `$(FLAVOR_APP_NAME)` for
   `CFBundleDisplayName` (the splash generator rewrites the file).

## 4. Verify

From `app/`:

```bash
flutter analyze lib test packages/*/lib packages/*/test
flutter test && (cd packages/app_ui && flutter test)
flutter build web --release --pwa-strategy=none --dart-define-from-file env/dev.json
```

Then look at it: run the web build (`flutter run -d chrome --web-port 5173
--dart-define-from-file env/dev.json`) or take screenshots, and compare the
sign-in, the home and the assistant against the approved proposal. Fix what
differs.

Finish with a short list of what changed, and leave the commit to the user:
do not commit or push.
