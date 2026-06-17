#!/usr/bin/env python3
"""Round 3 — Apple-flavoured icon concepts for Attendance Register.

Design language: one bold idea per icon, premium multi-stop gradients, a soft
top-left sheen, gentle depth from drop shadows — restraint over decoration.
Each concept maps to one of the app's truths: it tracks office days (progress),
by location (geofence), on a calendar (date).
"""
import os, math
import cairosvg
from PIL import Image, ImageDraw, ImageFont

OUT = os.path.dirname(os.path.abspath(__file__))
ICONS = os.path.join(OUT, "icons_v3")
os.makedirs(ICONS, exist_ok=True)
S = 512
R = 112  # squircle corner

# iOS system-ish palette
def sheen():
    return '''
    <radialGradient id="sheen" cx="0.3" cy="0.12" r="0.95">
      <stop offset="0" stop-color="#ffffff" stop-opacity="0.22"/>
      <stop offset="0.55" stop-color="#ffffff" stop-opacity="0"/>
    </radialGradient>'''

def grad(id_, c1, c2, c3=None, vertical=True):
    x2, y2 = ("0", "1") if vertical else ("1", "1")
    stops = f'<stop offset="0" stop-color="{c1}"/>'
    if c3:
        stops += f'<stop offset="0.5" stop-color="{c2}"/><stop offset="1" stop-color="{c3}"/>'
    else:
        stops += f'<stop offset="1" stop-color="{c2}"/>'
    return f'<linearGradient id="{id_}" x1="0" y1="0" x2="{x2}" y2="{y2}">{stops}</linearGradient>'

def soft_shadow(id_="sh", dy=8, blur=14, op=0.28):
    return (f'<filter id="{id_}" x="-40%" y="-40%" width="180%" height="180%">'
            f'<feDropShadow dx="0" dy="{dy}" stdDeviation="{blur}" '
            f'flood-color="#000" flood-opacity="{op}"/></filter>')

def frame(defs, bg_fill, body):
    return (f'<svg xmlns="http://www.w3.org/2000/svg" width="{S}" height="{S}" '
            f'viewBox="0 0 {S} {S}"><defs>{defs}{sheen()}</defs>'
            f'<rect width="{S}" height="{S}" rx="{R}" fill="{bg_fill}"/>'
            f'{body}'
            f'<rect width="{S}" height="{S}" rx="{R}" fill="url(#sheen)"/></svg>')

def arc_path(cx, cy, r, a0, a1):
    """Clockwise arc from a0 to a1 (degrees, y-down)."""
    p0 = (cx + r*math.cos(math.radians(a0)), cy + r*math.sin(math.radians(a0)))
    p1 = (cx + r*math.cos(math.radians(a1)), cy + r*math.sin(math.radians(a1)))
    large = 1 if (a1 - a0) % 360 > 180 else 0
    return f'M {p0[0]:.2f} {p0[1]:.2f} A {r} {r} 0 {large} 1 {p1[0]:.2f} {p1[1]:.2f}'

concepts = {}

# 1 — ACTIVITY RING: office-days progress closing toward your goal + a check.
a0, a1 = -52, 232
ring = arc_path(256, 256, 150, a0, a1)
head_x = 256 + 150*math.cos(math.radians(a0)); head_y = 256 + 150*math.sin(math.radians(a0))
concepts["1_progress_ring"] = frame(
    grad("bg", "#2C2C2E", "#1C1C1E") + grad("ring", "#5BE584", "#34C759", "#16A34A")
    + soft_shadow("sh", 6, 10, 0.45),
    "url(#bg)", f'''
    <circle cx="256" cy="256" r="150" fill="none" stroke="#3A3A3C" stroke-width="46"/>
    <g filter="url(#sh)">
      <path d="{ring}" fill="none" stroke="url(#ring)" stroke-width="46" stroke-linecap="round"/>
    </g>
    <circle cx="{head_x:.1f}" cy="{head_y:.1f}" r="23" fill="#5BE584"/>
    <path d="M206 260 l34 36 l72 -84" fill="none" stroke="#fff"
          stroke-width="30" stroke-linecap="round" stroke-linejoin="round"/>''')

# 2 — LOCATION DOT: Maps-style "you're here", pure geofence metaphor.
concepts["2_location_dot"] = frame(
    grad("bg", "#F5F7FB", "#E4E9F2") + grad("dot", "#3AA0FF", "#0A6CFF")
    + soft_shadow("sh", 8, 16, 0.30),
    "url(#bg)", '''
    <circle cx="256" cy="256" r="176" fill="#0A6CFF" opacity="0.07"/>
    <circle cx="256" cy="256" r="120" fill="#0A6CFF" opacity="0.10"/>
    <g filter="url(#sh)">
      <circle cx="256" cy="256" r="70" fill="#ffffff"/>
      <circle cx="256" cy="256" r="52" fill="url(#dot)"/>
    </g>''')

# 3 — CALENDAR TILE: iOS Calendar homage, typographic, brand-coloured weekday.
concepts["3_calendar_tile"] = frame(
    grad("bg", "#FFFFFF", "#F1F2F6") + grad("hdr", "#FF5A6E", "#E11D48")
    + soft_shadow("sh", 0, 1, 0.0),
    "url(#bg)", '''
    <rect x="64" y="96" width="384" height="92" rx="34" fill="url(#hdr)"/>
    <rect x="64" y="150" width="384" height="40" fill="url(#hdr)"/>
    <text x="256" y="160" text-anchor="middle" fill="#ffffff"
          font-family="DejaVu Sans, Arial, sans-serif" font-weight="700"
          font-size="46" letter-spacing="6">MON</text>
    <text x="256" y="392" text-anchor="middle" fill="#1C1C1E"
          font-family="DejaVu Sans, Arial, sans-serif" font-weight="800"
          font-size="208" letter-spacing="-8">12</text>''')

# 4 — REFINED PIN: a single dimensional pin on a sunrise gradient.
concepts["4_refined_pin"] = frame(
    grad("bg", "#6D5BF0", "#9B5BE4", "#E2557E") + grad("pin", "#FFFFFF", "#E9ECF5")
    + soft_shadow("sh", 10, 18, 0.30),
    "url(#bg)", '''
    <g filter="url(#sh)">
      <path d="M256 92 C181 92 120 153 120 228
               C120 322 256 430 256 430 C256 430 392 322 392 228
               C392 153 331 92 256 92 Z" fill="url(#pin)"/>
    </g>
    <circle cx="256" cy="226" r="52" fill="#6D5BF0"/>''')

# 5 — SUNRISE: the morning you head in. Horizon + rising sun, warm and calm.
concepts["5_sunrise"] = frame(
    grad("bg", "#1B2A6B", "#3B5BD6", "#FF9E5E") + grad("sun", "#FFE39A", "#FF8A5B")
    + soft_shadow("sh", 0, 22, 0.0)
    + '<clipPath id="below"><rect x="0" y="0" width="512" height="330"/></clipPath>',
    "url(#bg)", '''
    <g clip-path="url(#below)">
      <circle cx="256" cy="330" r="120" fill="url(#sun)"/>
    </g>
    <g stroke="#ffffff" stroke-width="14" stroke-linecap="round" opacity="0.9">
      <line x1="96" y1="330" x2="190" y2="330"/>
      <line x1="322" y1="330" x2="416" y2="330"/>
    </g>
    <g stroke="#FFE39A" stroke-width="10" stroke-linecap="round" opacity="0.85">
      <line x1="256" y1="150" x2="256" y2="186"/>
      <line x1="146" y1="196" x2="170" y2="224"/>
      <line x1="366" y1="196" x2="342" y2="224"/>
    </g>''')

# 6 — PURE CHECK: one confident mark, deep negative space (most minimal).
concepts["6_pure_check"] = frame(
    grad("bg", "#34C759", "#1E9E4A", "#0E7A38") + soft_shadow("sh", 10, 16, 0.30),
    "url(#bg)", '''
    <g filter="url(#sh)">
      <path d="M150 270 l74 78 l140 -160" fill="none" stroke="#ffffff"
            stroke-width="46" stroke-linecap="round" stroke-linejoin="round"/>
    </g>''')

rendered = {}
for name, svg in concepts.items():
    with open(os.path.join(ICONS, name + ".svg"), "w") as f:
        f.write(svg)
    png = os.path.join(ICONS, name + ".png")
    cairosvg.svg2png(bytestring=svg.encode(), write_to=png, output_width=512, output_height=512)
    rendered[name] = png
    print("rendered", png)

labels = {
    "1_progress_ring": "1. Office-Days Ring",
    "2_location_dot": "2. Location Dot",
    "3_calendar_tile": "3. Calendar Tile",
    "4_refined_pin": "4. Refined Pin",
    "5_sunrise": "5. Sunrise / RTO Morning",
    "6_pure_check": "6. Pure Check",
}
tile, pad, lh, cols = 256, 40, 46, 3
rows = (len(rendered)+cols-1)//cols
W = cols*tile+(cols+1)*pad
H = rows*(tile+lh)+(rows+1)*pad
sheet = Image.new("RGB", (W, H), "#DCDFE5")
draw = ImageDraw.Draw(sheet)
try:
    font = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", 21)
except Exception:
    font = ImageFont.load_default()
for i, (name, png) in enumerate(rendered.items()):
    r, c = divmod(i, cols)
    x = pad + c*(tile+pad); y = pad + r*(tile+lh+pad)
    icon = Image.open(png).convert("RGBA").resize((tile, tile), Image.LANCZOS)
    sheet.paste(icon, (x, y), icon)
    draw.text((x+tile/2, y+tile+10), labels[name], fill="#1C1C1E", font=font, anchor="ma")
sheet_path = os.path.join(OUT, "icon_concepts_v3.png")
sheet.save(sheet_path)
print("contact sheet:", sheet_path)
