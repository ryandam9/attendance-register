/// Maps a bird theme id to its illustration asset, when one exists.
///
/// Only ids listed in [_withArt] have artwork bundled under `assets/birds/`.
/// To add a bird: drop `assets/birds/<id>.png` in (transparent PNG) and add
/// `<id>` here.
library;

/// Theme ids that have an illustration in `assets/birds/`.
///
/// Missing (no artwork supplied yet): `cassowary` and `yellow_robin` — these
/// fall back to colour swatches / default icons.
const _withArt = <String>{
  'bee_eater',
  'spotted_pardalote',
  'plains_wanderer',
  'rose_crowned_fruit_dove',
  'eastern_rosella',
  'oriole',
  'princess_parrot',
  'superb_fairy_wren',
  'galah',
  'blue_winged_kookaburra',
};

/// The asset path for a theme's bird illustration, or null when none exists
/// (e.g. the Material You / "dynamic" theme, or birds without artwork yet).
String? birdAssetForTheme(String themeId) =>
    _withArt.contains(themeId) ? 'assets/birds/$themeId.png' : null;

/// Whether [themeId] has a bird illustration available.
bool hasBirdArt(String themeId) => _withArt.contains(themeId);
