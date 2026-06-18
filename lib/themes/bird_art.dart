/// Maps a bird theme id to its illustration asset, when one exists.
///
/// Every bird theme now has artwork under `assets/birds/<id>.png`. To add or
/// change one: drop a transparent PNG named `<id>.png` in and (if new) add the
/// id to [_withArt].
library;

/// Theme ids that have an illustration in `assets/birds/`.
const _withArt = <String>{
  'bee_eater',
  'spotted_pardalote',
  'plains_wanderer',
  'rose_crowned_fruit_dove',
  'eastern_rosella',
  'oriole',
  'princess_parrot',
  'superb_fairy_wren',
  'cassowary',
  'yellow_robin',
  'galah',
  'blue_winged_kookaburra',
};

/// The asset path for a theme's bird illustration, or null when none exists
/// (e.g. the Material You / "dynamic" theme).
String? birdAssetForTheme(String themeId) =>
    _withArt.contains(themeId) ? 'assets/birds/$themeId.png' : null;

/// Whether [themeId] has a bird illustration available.
bool hasBirdArt(String themeId) => _withArt.contains(themeId);
