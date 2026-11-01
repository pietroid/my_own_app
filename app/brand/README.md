# Brand

The source art for the app's icons and splash. The generated files land in
the platform folders and are committed.

```
icon.svg/.png        launcher icon (iOS, web, Android legacy)
foreground.svg/.png  Android adaptive foreground: the mark in the safe zone
splash.svg/.png      the native splash (iOS, Android, web)
```

The in-app mark (the sign-in screen) is
`packages/app_ui/assets/brand/mark.png`.

## Regenerating

After changing the art, from `app/`:

```bash
# SVG to PNG (headless Chrome keeps the gradients ImageMagick drops)
chrome="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
for n in icon foreground splash; do
  "$chrome" --headless=new --hide-scrollbars --default-background-color=00000000 \
    --window-size=1024,1024 --screenshot="$PWD/brand/$n.png" \
    "file://$PWD/brand/$n.svg"
done
sips -Z 512 brand/splash.png --out packages/app_ui/assets/brand/mark.png

dart run flutter_launcher_icons          # reads flutter_launcher_icons.yaml
dart run flutter_native_splash:create    # reads flutter_native_splash.yaml
```

The colours in both YAML files follow `AppColors`: change them together.
`flutter_native_splash` also rewrites `ios/Runner/Info.plist`; keep
`CFBundleDisplayName` as `$(FLAVOR_APP_NAME)`.
