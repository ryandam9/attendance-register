# Attendance Register — Feathers Palette Flutter Design Instructions

This document combines the design direction, exact colour palettes, Flutter implementation notes, and LLM prompts for redesigning the **Attendance Register** app using bird-inspired colour palettes from the Feathers palette style.

Primary app concept:

> **A field guide for your office attendance patterns.**

The goal is not just to change colours. The app should feel like a polished, personal, bird-inspired attendance tracker.

---

## 1. Overall Design Direction

I am building a Flutter app called **Attendance Register**.

I want to redesign the app using bird-inspired colour palettes from the Feathers palette style.

Important:

- Use the exact hex colours listed in this document.
- Do not invent random colours.
- Do not replace them with generic Material colours.
- Use the selected bird palette consistently across the app.
- Keep the app clean, calm, personal, and professional.
- The app should not look like a boring corporate attendance app.

Design theme:

> Make the app feel like a clean **field guide for office attendance patterns**.

The app should combine:

- Calendar-first attendance tracking
- Bird-inspired colour themes
- Clear status icons
- Friendly statistics
- Soft cards
- Calm backgrounds
- Material 3 inspired components
- Strong but not harsh contrast

---

## 2. Main Theme — Rainbow Bee-eater

Use **Rainbow Bee-eater** as the default app theme.

### Rainbow Bee-eater Palette

| Role | Colour | Hex |
|---|---:|---|
| Deep navy blue | Primary / app bar | `#00346E` |
| Bright blue | Buttons / selected states | `#007CBF` |
| Cyan | Secondary / info accents | `#06ABDF` |
| Yellow | Target / warning marker | `#EDD03E` |
| Orange | Alert / highlight | `#F5A200` |
| Olive green | Success / attended | `#6D8600` |
| Dark olive | Dark text / accent | `#424D0C` |

### Primary Colour Usage

Use these colours exactly:

```text
App bar:                 #00346E
Primary buttons:          #007CBF
Selected navigation item:  #00346E
Secondary accents:         #06ABDF
Target/warning colour:     #EDD03E
Alert/highlight colour:    #F5A200
Success/attended colour:   #6D8600
Dark text/accent:          #424D0C
```

### Flutter Colour Constants

```dart
import 'package:flutter/material.dart';

class FeathersColors {
  FeathersColors._();

  // Rainbow Bee-eater
  static const rainbowDeepBlue = Color(0xFF00346E);
  static const rainbowBlue = Color(0xFF007CBF);
  static const rainbowCyan = Color(0xFF06ABDF);
  static const rainbowYellow = Color(0xFFEDD03E);
  static const rainbowOrange = Color(0xFFF5A200);
  static const rainbowGreen = Color(0xFF6D8600);
  static const rainbowDarkOlive = Color(0xFF424D0C);

  // Attendance status colours
  static const attended = Color(0xFF6D8600);
  static const workFromHome = Color(0xFFBD338F);
  static const publicHoliday = Color(0xFF007CBF);
  static const sickLeave = Color(0xFFF5A200);
  static const annualLeave = Color(0xFF7090C9);
  static const carersLeave = Color(0xFF3EBCB6);
  static const miscLeave = Color(0xFF727B98);

  // Dark mode
  static const darkBackground = Color(0xFF061522);
  static const darkSurface = Color(0xFF0B2236);
  static const darkText = Color(0xFFF5F7FA);
  static const darkMutedText = Color(0xFFB8C4CC);
}
```

---

## 3. Attendance Status Colours

Each attendance status should have a clear colour, icon, and label.

Do not rely only on colour. Every status must also have an icon and text label.

| Attendance Status | Colour | Hex | Suggested Icon |
|---|---:|---:|---|
| Attended | Olive green | `#6D8600` | check circle |
| Work from Home | Magenta | `#BD338F` | home |
| Public Holiday | Bright blue | `#007CBF` | umbrella / event |
| Sick Leave | Orange | `#F5A200` | sick face / medical |
| Annual Leave | Soft blue-purple | `#7090C9` | suitcase |
| Carer’s Leave | Teal | `#3EBCB6` | heart / hand |
| Misc Leave | Grey-slate | `#727B98` | more / dash |

### Flutter Enum

```dart
enum AttendanceStatus {
  attended,
  workFromHome,
  publicHoliday,
  sickLeave,
  annualLeave,
  carersLeave,
  miscLeave,
}
```

### Status Colour Mapper

```dart
import 'package:flutter/material.dart';

Color attendanceStatusColor(AttendanceStatus status) {
  switch (status) {
    case AttendanceStatus.attended:
      return const Color(0xFF6D8600);
    case AttendanceStatus.workFromHome:
      return const Color(0xFFBD338F);
    case AttendanceStatus.publicHoliday:
      return const Color(0xFF007CBF);
    case AttendanceStatus.sickLeave:
      return const Color(0xFFF5A200);
    case AttendanceStatus.annualLeave:
      return const Color(0xFF7090C9);
    case AttendanceStatus.carersLeave:
      return const Color(0xFF3EBCB6);
    case AttendanceStatus.miscLeave:
      return const Color(0xFF727B98);
  }
}
```

---

## 4. Calendar Screen Design

The home screen should be calendar-first.

### Calendar Behaviour

Use a monthly calendar grid.

Design rules:

```text
Current selected day:     deep navy #00346E
Attended days:            small green dot or green circular marker
WFH days:                 pink/magenta home icon
Public holidays:          blue marker
Sick leave:               orange marker
Annual leave:             purple/soft blue marker
Carer’s leave:            teal marker
Misc leave:               grey marker
```

### Calendar UI Ideas

- Use small icons or dots inside each day cell.
- Keep the selected day clearly visible.
- Add a compact legend below the calendar.
- Use white rounded cards on a soft blue-tinted background.
- Use enough spacing so the calendar does not feel crowded.
- Use labels in the legend so the user does not need to memorise colours.

### Suggested Legend

```text
● Attended       🏠 WFH       ☂ Public Holiday
● Sick Leave     💼 Annual    ♥ Carer's Leave     ● Misc
```

Use Flutter icons instead of emoji in production.

---

## 5. Insights Screen Design

The Insights screen should make the return-to-office percentage feel clear and motivating.

### Main Card

Show:

```text
Return to office
28.6%
14 of 49 working days
50% target
```

### Visual Treatment

Use a curved progress arc or a strong progress card.

Below target:

```text
Use soft yellow/orange warning styling.
Use #EDD03E and #F5A200.
Do not use yellow text on white.
Use warning colour as a tint, border, icon, or background accent.
```

On target or above target:

```text
Use green success styling.
Use #6D8600.
```

### Creative Idea

Instead of a normal progress bar, show a bird-flight arc:

```text
0% ─────── 28.6% ─────── 50% target ─────── 100%
          small bird marker
```

If the app does not include illustrations, use a small circular marker or feather icon instead.

---

## 6. Mark a Day Screen Design

The **Mark a Day** screen should feel quick and easy.

### Layout

Use:

- App bar with deep navy
- Date selector card
- Status selector card
- Notes field
- Primary save button

### Status Selector

Each status row should include:

- Icon
- Label
- Status colour
- Radio button or selected state

Example:

```text
✓ Attended        #6D8600
⌂ Work from Home  #BD338F
☂ Public Holiday  #007CBF
☹ Sick Leave      #F5A200
▣ Annual Leave    #7090C9
♡ Carer’s Leave   #3EBCB6
… Misc Leave      #727B98
```

Use Flutter Material icons in actual code.

---

## 7. Appearance / Theme Selector Screen

Create a theme selector screen with bird palette rows.

Each row should show:

- Bird palette name
- Short personality description
- A row of colour swatches
- Radio button for selection

### Theme Row Example

```text
Rainbow Bee-eater
Bright, focused, professional

[ #00346E ] [ #007CBF ] [ #06ABDF ] [ #EDD03E ] [ #F5A200 ] [ #6D8600 ] [ #424D0C ]
```

### Add Preview

When selecting a theme, show a small preview card:

```text
App bar
Primary button
Info message
Status chip
```

This helps the user understand what the selected palette will look like.

---

## 8. Bird Palette List

Include these palettes.

### Rainbow Bee-eater

Description:

> Bright, focused, professional

```text
#00346E
#007CBF
#06ABDF
#EDD03E
#F5A200
#6D8600
#424D0C
```

### Spotted Pardalote

Description:

> Bold, alert, high contrast

```text
#FECA00
#D36328
#CB0300
#B4B9B3
#424847
#000100
```

### Plains-wanderer

Description:

> Calm, warm, earthy

```text
#EDD8C5
#D09A5E
#E7AA01
#AC570F
#73481B
#442C0E
#0D0403
```

### Rose-crowned Fruit Dove

Description:

> Friendly, soft, colourful

```text
#BD338F
#EB8252
#F5DC83
#CDD4DC
#8098A2
#8FA33F
#5F7929
#014820
```

### Eastern Rosella

Description:

> Natural, bright, balanced

```text
#CD3122
#F4C623
#BEE183
#6C8CC7
```

### Galah

Description:

> Soft, relaxed, playful

```text
#D05478
#E599AC
#AABDC5
#6C6B75
```

### Cassowary

Description:

> Bold, dark, dramatic

```text
#061522
#0B2236
#243B63
#F26A21
#2E706C
```

---

## 9. Dark Mode

Do not just invert the light colours.

Create a proper dark version of the Rainbow Bee-eater theme.

### Rainbow Bee-eater Dark Mode

```text
Background:    #061522
Surface:       #0B2236
Primary:       #06ABDF
Secondary:     #EDD03E
Success:       #6D8600
Text:          #F5F7FA
Muted text:    #B8C4CC
```

### Dark Mode Rules

- Use `#061522` for main app background.
- Use `#0B2236` for cards/surfaces.
- Use `#06ABDF` for primary highlights.
- Use `#EDD03E` sparingly for target/warning accents.
- Use `#F5F7FA` for main text.
- Use `#B8C4CC` for secondary text.
- Keep borders subtle.
- Keep status colours visible but not too bright.
- Avoid large bright white blocks in dark mode.

---

## 10. Flutter Implementation Requirements

Create a central theme system.

### Recommended Files

```text
lib/theme/feathers_palettes.dart
lib/theme/app_theme.dart
lib/theme/attendance_status_colors.dart
```

### Required Model

Create a model called `BirdPalette`.

It should include:

```text
name
description
colors
primary
secondary
background
surface
textColor
```

Example:

```dart
import 'package:flutter/material.dart';

class BirdPalette {
  const BirdPalette({
    required this.name,
    required this.description,
    required this.colors,
    required this.primary,
    required this.secondary,
    required this.background,
    required this.surface,
    required this.textColor,
  });

  final String name;
  final String description;
  final List<Color> colors;
  final Color primary;
  final Color secondary;
  final Color background;
  final Color surface;
  final Color textColor;
}
```

### Palette Example

```dart
const rainbowBeeEaterPalette = BirdPalette(
  name: 'Rainbow Bee-eater',
  description: 'Bright, focused, professional',
  colors: [
    Color(0xFF00346E),
    Color(0xFF007CBF),
    Color(0xFF06ABDF),
    Color(0xFFEDD03E),
    Color(0xFFF5A200),
    Color(0xFF6D8600),
    Color(0xFF424D0C),
  ],
  primary: Color(0xFF00346E),
  secondary: Color(0xFF007CBF),
  background: Color(0xFFF4F9FC),
  surface: Colors.white,
  textColor: Color(0xFF102033),
);
```

### ThemeData Requirement

Create `ThemeData` from the selected `BirdPalette`.

Important:

- Use `ColorScheme.fromSeed` only if it does not override the exact colours too much.
- Prefer explicit `ColorScheme` values.
- Make sure the actual app bar, buttons, cards, navigation, chips, and calendar markers use the exact colours.

Example:

```dart
ThemeData buildAppTheme(BirdPalette palette) {
  return ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: palette.background,
    colorScheme: ColorScheme(
      brightness: Brightness.light,
      primary: palette.primary,
      onPrimary: Colors.white,
      secondary: palette.secondary,
      onSecondary: Colors.white,
      error: const Color(0xFFF5A200),
      onError: const Color(0xFF102033),
      surface: palette.surface,
      onSurface: palette.textColor,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: palette.primary,
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: false,
    ),
    cardTheme: CardThemeData(
      color: palette.surface,
      elevation: 2,
      margin: const EdgeInsets.all(12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: palette.secondary,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
    ),
  );
}
```

---

## 11. Persistence

The user should be able to change the theme from the Appearance screen.

### Suggested Palette Keys

```text
rainbow_bee_eater
spotted_pardalote
plains_wanderer
rose_crowned_fruit_dove
eastern_rosella
galah
cassowary
```

---

## 12. Accessibility Rules

Keep accessibility in mind.

Rules:

- Do not rely only on colour.
- Every attendance status must have icon + label + colour.
- Use good contrast for text.
- Do not put yellow text on white.
- Use yellow/orange mostly as background tint or warning accent.
- Use dark navy text on light backgrounds.
- Use white text on deep navy app bars.
- Use clear selected states.
- Keep legends visible.
- Avoid overly tiny status dots without labels.

---

## 16. Final Implementation Checklist

Use this checklist to review the final Flutter implementation.

```text
[ ] Rainbow Bee-eater is the default theme.
[ ] Exact hex colours are used.
[ ] No random Material colours replaced the palette.
[ ] All status types have colour, icon, and text.
[ ] Calendar markers use status colours.
[ ] Calendar has a compact legend.
[ ] Insights card shows return-to-office percentage clearly.
[ ] 50% target is visually obvious.
[ ] Below-target state uses yellow/orange warning style.
[ ] Success state uses green.
[ ] Appearance screen shows bird palette rows.
[ ] Each palette row has name, description, swatches, and selected state.
[ ] Theme selection is persisted locally.
[ ] App supports dark mode.
[ ] Dark mode uses dark navy surfaces, not simple inverted colours.
[ ] App bar uses #00346E in light mode.
[ ] Buttons use #007CBF.
[ ] Attended uses #6D8600.
[ ] WFH uses #BD338F.
[ ] Public holiday uses #007CBF.
[ ] Sick leave uses #F5A200.
[ ] Annual leave uses #7090C9.
[ ] Carer’s leave uses #3EBCB6.
[ ] Misc leave uses #727B98.
[ ] Yellow text is not used on white backgrounds.
[ ] UI looks like a clean field guide, not a generic corporate app.
```

---

## 17. Source / Attribution Notes

Suggested note for the app or blog:

```text
Bird-inspired colour palettes are based on the Feathers palette style.
Feathers source:
https://github.com/shandiya/feathers/blob/main/R/feathers.R
```

Suggested blog note:

```text
Design note:
The Attendance Register app supports bird-inspired colour themes using palettes from the Feathers palette style.
The screenshots use the Rainbow Bee-eater theme.
```


