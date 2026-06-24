#!/usr/bin/env bash
#
# Wrapper around `flutter` that stamps the current git commit + build date into
# the app via --dart-define, so a locally-built (or locally-run) app reports its
# exact commit on the About page instead of "local".
#
# It just forwards whatever you pass to `flutter` and appends the defines, e.g.:
#
#   ./scripts/flutter-stamped.sh build macos --release
#   ./scripts/flutter-stamped.sh build linux --release
#   ./scripts/flutter-stamped.sh build windows --release
#   ./scripts/flutter-stamped.sh run
#
# CI stamps the same two defines itself (see .github/workflows/ci.yml), so this
# is only for local builds.
set -euo pipefail

commit=$(git rev-parse --short HEAD 2>/dev/null || echo local)

# Flag a dirty working tree so it's obvious the binary doesn't match that commit
# exactly (uncommitted changes were compiled in).
if [ "$commit" != "local" ] &&
  { ! git diff --quiet 2>/dev/null || ! git diff --cached --quiet 2>/dev/null; }; then
  commit="${commit}-dirty"
fi

build_time=$(date -u +%Y-%m-%d)

# Only `flutter build <platform>` and `flutter run` accept --dart-define; other
# subcommands (create, pub, …) reject it with "Could not find an option named
# --dart-define". Find the subcommand (first non-flag arg) and only stamp those,
# so the wrapper is safe to use in place of `flutter` for any command.
subcommand=""
for arg in "$@"; do
  case "$arg" in
  -*) continue ;;
  *)
    subcommand="$arg"
    break
    ;;
  esac
done

if [ "$subcommand" = "build" ] || [ "$subcommand" = "run" ]; then
  echo "Stamping build: GIT_COMMIT=$commit BUILD_TIME=$build_time" >&2
  exec flutter "$@" \
    --dart-define=GIT_COMMIT="$commit" \
    --dart-define=BUILD_TIME="$build_time"
fi

# Not a build/run — pass through untouched (e.g. `create`, `pub get`).
exec flutter "$@"
