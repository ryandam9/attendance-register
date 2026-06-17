#!/usr/bin/env python3
"""Export the chosen icon (Office-Days Ring) into the Android resource tree.

Full icon  : graphite squircle + green progress ring (rounded cap + head) + check.
Foreground : same ring+check, scaled into the adaptive 66% safe zone, transparent.
Monochrome : single-tone ring+check silhouette for Android 13+ themed icons.
The graphite gradient is also written to drawable/ic_launcher_background.xml.
"""
import os, math
import cairosvg

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RES = os.path.join(ROOT, "android", "app", "src", "main", "res")
DESIGN = os.path.dirname(os.path.abspath(__file__))

DENSITIES = {"mdpi": (48, 108), "hdpi": (72, 162), "xhdpi": (96, 216),
             "xxhdpi": (144, 324), "xxxhdpi": (192, 432)}

CX = CY = 256
Rr, SW = 150, 46          # ring radius / stroke width
A0, A1 = -52, 232          # clockwise sweep, gap at top

def arc_path(cx, cy, r, a0, a1):
    p0 = (cx + r*math.cos(math.radians(a0)), cy + r*math.sin(math.radians(a0)))
    p1 = (cx + r*math.cos(math.radians(a1)), cy + r*math.sin(math.radians(a1)))
    large = 1 if (a1 - a0) % 360 > 180 else 0
    return f'M {p0[0]:.2f} {p0[1]:.2f} A {r} {r} 0 {large} 1 {p1[0]:.2f} {p1[1]:.2f}'

RING = arc_path(CX, CY, Rr, A0, A1)
HX = CX + Rr*math.cos(math.radians(A0))
HY = CY + Rr*math.sin(math.radians(A0))
CHECK = "M206 260 l34 36 l72 -84"

DEFS = '''
  <linearGradient id="bg" x1="0" y1="0" x2="0" y2="1">
    <stop offset="0" stop-color="#2C2C2E"/><stop offset="1" stop-color="#1C1C1E"/>
  </linearGradient>
  <linearGradient id="ring" x1="0" y1="0" x2="0" y2="1">
    <stop offset="0" stop-color="#5BE584"/><stop offset="0.5" stop-color="#34C759"/>
    <stop offset="1" stop-color="#16A34A"/>
  </linearGradient>
  <radialGradient id="sheen" cx="0.3" cy="0.12" r="0.95">
    <stop offset="0" stop-color="#ffffff" stop-opacity="0.16"/>
    <stop offset="0.55" stop-color="#ffffff" stop-opacity="0"/>
  </radialGradient>
  <filter id="sh" x="-40%" y="-40%" width="180%" height="180%">
    <feDropShadow dx="0" dy="6" stdDeviation="10" flood-color="#000" flood-opacity="0.45"/>
  </filter>'''

def ring_and_check(track=True):
    track_ring = (f'<circle cx="{CX}" cy="{CY}" r="{Rr}" fill="none" '
                  f'stroke="#3A3A3C" stroke-width="{SW}"/>') if track else ''
    return f'''{track_ring}
    <g filter="url(#sh)">
      <path d="{RING}" fill="none" stroke="url(#ring)" stroke-width="{SW}" stroke-linecap="round"/>
    </g>
    <circle cx="{HX:.1f}" cy="{HY:.1f}" r="{SW/2:.0f}" fill="#5BE584"/>
    <path d="{CHECK}" fill="none" stroke="#fff" stroke-width="30"
          stroke-linecap="round" stroke-linejoin="round"/>'''

def svg_full():
    return (f'<svg xmlns="http://www.w3.org/2000/svg" width="512" height="512" '
            f'viewBox="0 0 512 512"><defs>{DEFS}</defs>'
            f'<rect width="512" height="512" rx="112" fill="url(#bg)"/>'
            f'{ring_and_check(track=True)}'
            f'<rect width="512" height="512" rx="112" fill="url(#sheen)"/></svg>')

def svg_foreground():
    # No track ring (reads cleaner small), scaled to 0.80 so the ring's outer
    # edge stays inside the adaptive safe zone, transparent ground.
    return (f'<svg xmlns="http://www.w3.org/2000/svg" width="512" height="512" '
            f'viewBox="0 0 512 512"><defs>{DEFS}</defs>'
            f'<g transform="translate({CX},{CY}) scale(0.80) translate(-{CX},-{CY})">'
            f'{ring_and_check(track=False)}</g></svg>')

def svg_monochrome():
    return (f'<svg xmlns="http://www.w3.org/2000/svg" width="512" height="512" '
            f'viewBox="0 0 512 512">'
            f'<g transform="translate({CX},{CY}) scale(0.80) translate(-{CX},-{CY})" '
            f'fill="none" stroke="#000">'
            f'<path d="{RING}" stroke-width="{SW}" stroke-linecap="round"/>'
            f'<circle cx="{HX:.1f}" cy="{HY:.1f}" r="{SW/2:.0f}" fill="#000" stroke="none"/>'
            f'<path d="{CHECK}" stroke-width="30" stroke-linecap="round" stroke-linejoin="round"/>'
            f'</g></svg>')

full, fg, mono = svg_full(), svg_foreground(), svg_monochrome()

for d, (legacy_px, adaptive_px) in DENSITIES.items():
    folder = os.path.join(RES, f"mipmap-{d}")
    os.makedirs(folder, exist_ok=True)
    cairosvg.svg2png(bytestring=full.encode(),
                     write_to=os.path.join(folder, "ic_launcher.png"),
                     output_width=legacy_px, output_height=legacy_px)
    cairosvg.svg2png(bytestring=fg.encode(),
                     write_to=os.path.join(folder, "ic_launcher_foreground.png"),
                     output_width=adaptive_px, output_height=adaptive_px)
    cairosvg.svg2png(bytestring=mono.encode(),
                     write_to=os.path.join(folder, "ic_launcher_monochrome.png"),
                     output_width=adaptive_px, output_height=adaptive_px)
    print(f"mipmap-{d}: ic_launcher={legacy_px}px  fg/mono={adaptive_px}px")

# Graphite adaptive background to match the icon ground.
with open(os.path.join(RES, "drawable", "ic_launcher_background.xml"), "w") as f:
    f.write('''<?xml version="1.0" encoding="utf-8"?>
<!-- Adaptive-icon background: graphite gradient matching the ring icon. -->
<shape xmlns:android="http://schemas.android.com/apk/res/android"
    android:shape="rectangle">
    <gradient
        android:startColor="#2C2C2E"
        android:endColor="#1C1C1E"
        android:angle="270" />
</shape>
''')
print("wrote drawable/ic_launcher_background.xml (graphite)")

cairosvg.svg2png(bytestring=full.encode(),
                 write_to=os.path.join(DESIGN, "ic_launcher_master_512.png"),
                 output_width=512, output_height=512)
print("master 512px -> design/ic_launcher_master_512.png")
