# Bird artwork

Per-theme bird illustrations used on the Appearance screen, the Home empty
state, and as the marker on the "Return to office" gauge.

## How to add / replace a bird

1. Drop an **SVG** file in this folder named after the theme id, e.g.:
   - `bee_eater.svg`  → Rainbow Bee-eater
   - `galah.svg`      → Galah
   - `spotted_pardalote.svg`, `plains_wanderer.svg`,
     `rose_crowned_fruit_dove.svg`, `eastern_rosella.svg`, `cassowary.svg`, …
   (Theme ids are defined in `lib/themes/bird_themes.dart`.)
2. Add the same id to the `_withArt` set in `lib/themes/bird_art.dart` so the
   app knows the file exists.

The whole folder is bundled (see `pubspec.yaml` → `flutter > assets`), so no
per-file pubspec entry is needed.

The two files currently here (`bee_eater.svg`, `galah.svg`) are **placeholders**
— replace them with the real artwork using the same filenames.

## App icon / splash

Put a square 1024×1024 PNG at `assets/branding/app_icon.png`, then wire up
`flutter_launcher_icons` / `flutter_native_splash` (see project README/TODO).
