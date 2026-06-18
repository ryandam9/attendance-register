# Bird artwork

Per-theme bird illustrations used on the Appearance screen, the Home app-bar +
empty state, and as the marker on the "Return to office" gauge.

Files are **transparent PNGs** named after the theme id (see
`lib/themes/bird_themes.dart`), trimmed and downsized to ~512 px.

## Currently included
`bee_eater, spotted_pardalote, plains_wanderer, rose_crowned_fruit_dove,
eastern_rosella, oriole, princess_parrot, superb_fairy_wren, galah,
blue_winged_kookaburra`

## Missing (fall back to colour swatches)
- `cassowary` — Cassowary (the supplied "Southern-Cassowary.png" was actually a
  bee-eater, now used for `bee_eater`)
- `yellow_robin` — Eastern Yellow Robin

Drop `assets/birds/bee_eater.png` / `yellow_robin.png` (transparent PNG) in and
add the id to the `_withArt` set in `lib/themes/bird_art.dart`.

The whole folder is bundled (see `pubspec.yaml` → `flutter > assets`), so no
per-file pubspec entry is needed.

## App icon / splash
`assets/branding/app_icon.png` is still a placeholder — see
`assets/branding/README.md`.
