/// Build metadata injected at build time via `--dart-define`, so the running app
/// can report exactly which commit it was built from (shown on the About page).
///
/// CI stamps these (see `.github/workflows/ci.yml`). For a local build you can
/// stamp them too:
///
/// ```sh
/// flutter run --dart-define=GIT_COMMIT=$(git rev-parse --short HEAD)
/// ```
class BuildInfo {
  const BuildInfo._();

  /// Marketing version — keep in sync with `pubspec.yaml`'s `version:`.
  static const String version = '1.0.0';

  /// Short git commit the build was made from. `'local'` for an un-stamped
  /// (e.g. plain `flutter run`) build.
  static const String commit = String.fromEnvironment(
    'GIT_COMMIT',
    defaultValue: 'local',
  );

  /// UTC build date (YYYY-MM-DD), empty for an un-stamped build.
  static const String buildTime = String.fromEnvironment('BUILD_TIME');

  /// True when this build carries a real CI commit stamp.
  static bool get isStamped => commit != 'local' && commit.isNotEmpty;
}
