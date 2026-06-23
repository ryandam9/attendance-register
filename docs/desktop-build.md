# Building the desktop app (Linux & macOS)

This walks through building **Attendance Register** as a desktop app, giving it a
proper application **icon** (so it shows up in the Dock / taskbar / app launcher),
and creating a **desktop shortcut**.

The repository only ships the Dart sources and a partial `macos/` project — the
platform runner folders are generated on demand with `flutter create`, so the
first build step on a fresh clone is always to generate them.

> The source icon lives at `assets/branding/app_icon.png` (a 1024×1024 PNG).
> Replace it with your own artwork before generating icons if you want.

---

## 0. Common prerequisites

```bash
# A recent stable Flutter (this project is pinned to 3.44.3 in CI)
flutter --version

# Enable desktop support (one-time, per machine)
flutter config --enable-linux-desktop      # Linux
flutter config --enable-macos-desktop       # macOS

flutter pub get
```

---

## macOS

### 1. Prerequisites

- **Xcode** (from the App Store) + command-line tools: `xcode-select --install`
- **CocoaPods**: `sudo gem install cocoapods` (or `brew install cocoapods`)

### 2. Generate the macOS runner

```bash
flutter create --platforms=macos .
```

`flutter create` only fills in missing files, so your committed sources are kept.

### 3. Add the app icon (Dock / Finder / app switcher)

The icon is already wired up in `pubspec.yaml` (`flutter_launcher_icons` with
`macos: true`). Generate it:

```bash
dart run flutter_launcher_icons
```

This writes `macos/Runner/Assets.xcassets/AppIcon.appiconset/` with every size
macOS needs. From now on the built `.app` shows your icon in **Finder**, the
**Dock**, and the **⌘-Tab app switcher**. Re-run this command whenever you change
`assets/branding/app_icon.png`.

### 4. Build

```bash
flutter build macos --release
```

Output: `build/macos/Build/Products/Release/attendance_register.app`

### 5. Install + add to the Dock (the "shortcut")

```bash
# Copy into Applications
cp -R build/macos/Build/Products/Release/attendance_register.app /Applications/
open /Applications      # then drag the app onto the Dock to pin it
```

- To pin: launch it, then **right-click its Dock icon → Options → Keep in Dock**.
- The build is **unsigned** (no Apple Developer certificate), so the **first**
  launch is blocked by Gatekeeper. Open it once with **right-click → Open →
  Open**, or run:
  ```bash
  xattr -dr com.apple.quarantine /Applications/attendance_register.app
  ```

---

## Linux

### 1. Prerequisites (Debian/Ubuntu)

```bash
sudo apt-get update
sudo apt-get install -y \
  clang cmake ninja-build pkg-config \
  libgtk-3-dev liblzma-dev
```

> The database uses a bundled SQLite (`sqlite3_flutter_libs`) that is compiled
> from source during the build, so an internet connection is needed the first
> time you build. No system `libsqlite3` package is required.

### 2. Generate the Linux runner

```bash
flutter create --platforms=linux .
```

### 3. Build

```bash
flutter build linux --release
```

Output (a self-contained folder): `build/linux/x64/release/bundle/`
containing the `attendance_register` executable, plus `lib/` and `data/`. Keep
these together — the executable needs them.

Run it directly to test:

```bash
./build/linux/x64/release/bundle/attendance_register
```

### 4. Add the app icon (taskbar / launcher)

`flutter_launcher_icons` has **no Linux support**, so the icon is set by hand.
There are two places an icon shows up, and they use different mechanisms:

#### (a) The running window's taskbar icon — set it in the runner

Edit `linux/runner/my_application.cc`. Find where the window is shown
(`gtk_widget_show(GTK_WIDGET(window));`) and add, just before it:

```c
  // Show the app's icon in the taskbar / window list while running.
  gtk_window_set_icon_from_file(
      GTK_WINDOW(window),
      "/usr/share/icons/hicolor/512x512/apps/attendance-register.png",
      nullptr);
```

(Use the path you install the icon to in step 5b. For a relative/dev path you can
point it at `assets/branding/app_icon.png`.) Rebuild after editing.

#### (b) The launcher/menu icon — comes from the `.desktop` file (step 5).

### 5. Create a desktop shortcut (`.desktop` launcher) + install the icon

```bash
# 5a. Put the build somewhere stable (not inside build/, which gets wiped)
mkdir -p ~/Apps/attendance-register
cp -r build/linux/x64/release/bundle/* ~/Apps/attendance-register/

# 5b. Install the icon into the icon theme (several sizes is nicer; 512 is fine)
mkdir -p ~/.local/share/icons/hicolor/512x512/apps
cp assets/branding/app_icon.png \
   ~/.local/share/icons/hicolor/512x512/apps/attendance-register.png
gtk-update-icon-cache -f -t ~/.local/share/icons/hicolor 2>/dev/null || true

# 5c. Create the launcher entry
cat > ~/.local/share/applications/attendance-register.desktop <<'EOF'
[Desktop Entry]
Type=Application
Name=Attendance Register
Comment=Office attendance tracker
Exec=/home/USER/Apps/attendance-register/attendance_register
Icon=attendance-register
Terminal=false
Categories=Office;Utility;
EOF

# 5d. Fix the path and refresh the launcher database
sed -i "s|/home/USER|$HOME|" ~/.local/share/applications/attendance-register.desktop
update-desktop-database ~/.local/share/applications 2>/dev/null || true
```

The app now appears in your application menu / launcher with its icon, and you can
add it to your dock/favorites from there.

> Tip: if the **running** window still shows a generic icon, it's the step-4a
> window icon that's missing — make sure the path there points at an installed
> PNG and rebuild. Some desktops also match the running window to the `.desktop`
> file via the app id; the Flutter template's app id is in
> `linux/runner/my_application.cc` (`application_id`), and naming the `.desktop`
> file to match it (e.g. `com.example.attendance_register.desktop`) helps GNOME
> associate the two.

---

## Quick reference

| | macOS | Linux |
|---|---|---|
| Generate runner | `flutter create --platforms=macos .` | `flutter create --platforms=linux .` |
| App icon | `dart run flutter_launcher_icons` | manual (runner + `.desktop`, steps 4–5) |
| Build | `flutter build macos --release` | `flutter build linux --release` |
| Output | `build/macos/Build/Products/Release/attendance_register.app` | `build/linux/x64/release/bundle/` |
| Shortcut | drag `.app` to `/Applications` + Dock | `.desktop` file in `~/.local/share/applications` |

CI also builds both automatically — see `.github/workflows/ci.yml`. Pushed builds
publish a portable zip for each platform to the
[latest release](https://github.com/ryandam9/attendance-register/releases/latest).
