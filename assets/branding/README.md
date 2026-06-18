# Branding — app icon & splash

`app_icon.png` is a **placeholder** (a simple bee-eater on the navy brand
colour). Replace it with the real artwork, then regenerate the native assets.

## Requirements
- `app_icon.png` — square **1024×1024 PNG**.

## Regenerate after replacing the file
```sh
dart run flutter_launcher_icons          # app launcher icons (Android/iOS)
dart run flutter_native_splash:create    # splash screen
```

Configuration for both lives in `pubspec.yaml`
(`flutter_launcher_icons:` and `flutter_native_splash:`). The brand colour is
`#00346E` (Rainbow Bee-eater navy).

> Note: these generators write into the `android/` and `ios/` folders, so run
> them locally and commit the results once the real icon is in place.
