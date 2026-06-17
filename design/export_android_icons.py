#!/usr/bin/env python3
"""Export the chosen icon (Concept A — Calendar Breakout Check) into the
Android resource tree.

Produces:
  * Legacy square launcher icons        mipmap-<d>/ic_launcher.png
  * Adaptive foreground (safe-zone art)  mipmap-<d>/ic_launcher_foreground.png
  * Monochrome layer (themed icons)      mipmap-<d>/ic_launcher_monochrome.png
The gradient background + adaptive XML are written as resource files by the
caller; this script only renders the PNGs.
"""
import os
import cairosvg

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RES = os.path.join(ROOT, "android", "app", "src", "main", "res")

BLUE = "#1A73E8"
BLUE_DK = "#0B57D0"
GREEN_LT = "#5BD27A"
GREEN_DK = "#1E8E3E"
WHITE = "#FFFFFF"

# Density buckets: legacy launcher px, adaptive foreground px (108dp base).
DENSITIES = {
    "mdpi":    (48, 108),
    "hdpi":    (72, 162),
    "xhdpi":   (96, 216),
    "xxhdpi":  (144, 324),
    "xxxhdpi": (192, 432),
}

COMMON_DEFS = f'''
  <defs>
    <linearGradient id="bgBlue" x1="0" y1="0" x2="0.4" y2="1">
      <stop offset="0" stop-color="{BLUE}"/><stop offset="1" stop-color="{BLUE_DK}"/>
    </linearGradient>
    <linearGradient id="chk" x1="0" y1="0" x2="1" y2="1">
      <stop offset="0" stop-color="{GREEN_LT}"/><stop offset="1" stop-color="{GREEN_DK}"/>
    </linearGradient>
    <filter id="sh" x="-30%" y="-30%" width="160%" height="160%">
      <feDropShadow dx="0" dy="7" stdDeviation="12" flood-color="#000" flood-opacity="0.20"/>
    </filter>
  </defs>'''

# Calendar + breakout check artwork, authored in a 512 viewBox. The artwork
# spans roughly the centre 55% of the canvas, so it already sits inside the
# adaptive-icon 66% safe zone when drawn on a transparent ground.
def calendar_check(shadow=True):
    sh = ' filter="url(#sh)"' if shadow else ''
    return f'''
  <g{sh}>
    <rect x="120" y="150" width="272" height="258" rx="38" fill="{WHITE}"/>
  </g>
  <rect x="120" y="150" width="272" height="58" rx="38" fill="{BLUE_DK}"/>
  <rect x="120" y="180" width="272" height="28" fill="{BLUE_DK}"/>
  <rect x="166" y="128" width="24" height="58" rx="12" fill="{BLUE_DK}"/>
  <rect x="322" y="128" width="24" height="58" rx="12" fill="{BLUE_DK}"/>
  <path d="M170 300 l52 54 l132 -150" fill="none" stroke="url(#chk)"
        stroke-width="40" stroke-linecap="round" stroke-linejoin="round"/>'''

def svg_full():
    return (f'<svg xmlns="http://www.w3.org/2000/svg" width="512" height="512" '
            f'viewBox="0 0 512 512">{COMMON_DEFS}'
            f'<rect x="0" y="0" width="512" height="512" rx="115" ry="115" fill="url(#bgBlue)"/>'
            f'{calendar_check(shadow=True)}</svg>')

def svg_foreground():
    # Transparent ground; artwork already within the safe zone. No drop shadow
    # (the system applies its own elevation) and no calendar-header reliance on
    # the blue plate, since the adaptive background supplies the blue.
    return (f'<svg xmlns="http://www.w3.org/2000/svg" width="512" height="512" '
            f'viewBox="0 0 512 512">{COMMON_DEFS}'
            f'{calendar_check(shadow=False)}</svg>')

def svg_monochrome():
    # Single-tone silhouette: a solid calendar with the check knocked out, so
    # it stays legible when the launcher tints it for themed icons.
    return f'''<svg xmlns="http://www.w3.org/2000/svg" width="512" height="512" viewBox="0 0 512 512">
  <defs>
    <mask id="knock">
      <rect x="120" y="150" width="272" height="258" rx="38" fill="#fff"/>
      <rect x="166" y="128" width="24" height="58" rx="12" fill="#fff"/>
      <rect x="322" y="128" width="24" height="58" rx="12" fill="#fff"/>
      <path d="M170 300 l52 54 l132 -150" fill="none" stroke="#000"
            stroke-width="44" stroke-linecap="round" stroke-linejoin="round"/>
    </mask>
  </defs>
  <g mask="url(#knock)" fill="#000">
    <rect x="120" y="150" width="272" height="258" rx="38"/>
    <rect x="166" y="128" width="24" height="58" rx="12"/>
    <rect x="322" y="128" width="24" height="58" rx="12"/>
  </g>
</svg>'''

full = svg_full()
fg = svg_foreground()
mono = svg_monochrome()

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
    print(f"mipmap-{d}: ic_launcher={legacy_px}px  foreground/mono={adaptive_px}px")

# A 512px Play-Store / preview master next to the design assets.
cairosvg.svg2png(bytestring=full.encode(),
                 write_to=os.path.join(os.path.dirname(os.path.abspath(__file__)),
                                       "ic_launcher_master_512.png"),
                 output_width=512, output_height=512)
print("master 512px written to design/ic_launcher_master_512.png")
