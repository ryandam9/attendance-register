/// Maps a bird theme id to its illustration asset, when one exists.
///
/// Only ids listed in [_withArt] have artwork bundled under `assets/birds/`.
/// To add a bird: drop `assets/birds/<id>.svg` in and add `<id>` here.
library;

/// Theme ids that have an SVG illustration in `assets/birds/`.
const _withArt = <String>{
  'bee_eater',
  'galah',
};

/// The asset path for a theme's bird illustration, or null when none exists
/// (e.g. the Material You / "dynamic" theme, or birds without artwork yet).
String? birdAssetForTheme(String themeId) =>
    _withArt.contains(themeId) ? 'assets/birds/$themeId.svg' : null;

/// Whether [themeId] has a bird illustration available.
bool hasBirdArt(String themeId) => _withArt.contains(themeId);
