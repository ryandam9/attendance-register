#!/usr/bin/env python3
"""Round 2 — more creative app-icon concepts for Attendance Register.

Keeps the calendar/check DNA the user liked but explores fresh ideas that
lean on the app's three pillars: a calendar, geolocation/geofencing, and the
Australian-bird theming. Palette from the default bird theme.
"""
import os
import cairosvg
from PIL import Image, ImageDraw, ImageFont

OUT = os.path.dirname(os.path.abspath(__file__))
ICONS = os.path.join(OUT, "icons_v2")
os.makedirs(ICONS, exist_ok=True)

BLUE = "#1A73E8"
BLUE_DK = "#0B57D0"
GREEN = "#34A853"
GREEN_DK = "#1E8E3E"
GREEN_LT = "#5BD27A"
AMBER = "#F4C623"
WHITE = "#FFFFFF"
INK = "#0A2540"
S = 512

def defs():
    return f'''
  <defs>
    <linearGradient id="bgBlue" x1="0" y1="0" x2="0.4" y2="1">
      <stop offset="0" stop-color="{BLUE}"/><stop offset="1" stop-color="{BLUE_DK}"/>
    </linearGradient>
    <linearGradient id="bgGreen" x1="0" y1="0" x2="0.4" y2="1">
      <stop offset="0" stop-color="{GREEN}"/><stop offset="1" stop-color="{GREEN_DK}"/>
    </linearGradient>
    <linearGradient id="bgInk" x1="0" y1="0" x2="0.4" y2="1">
      <stop offset="0" stop-color="#16386B"/><stop offset="1" stop-color="#0A2540"/>
    </linearGradient>
    <linearGradient id="chk" x1="0" y1="0" x2="1" y2="1">
      <stop offset="0" stop-color="{GREEN_LT}"/><stop offset="1" stop-color="{GREEN_DK}"/>
    </linearGradient>
    <filter id="sh" x="-30%" y="-30%" width="160%" height="160%">
      <feDropShadow dx="0" dy="7" stdDeviation="12" flood-color="#000" flood-opacity="0.20"/>
    </filter>
  </defs>'''

def bg(grad):
    return f'<rect x="0" y="0" width="{S}" height="{S}" rx="115" ry="115" fill="url(#{grad})"/>'

def wrap(body):
    return (f'<svg xmlns="http://www.w3.org/2000/svg" width="{S}" height="{S}" '
            f'viewBox="0 0 {S} {S}">{defs()}{body}</svg>')

concepts = {}

# A. Calendar whose checkmark sweeps off the page (energetic evolution of #1)
concepts["A_calendar_swoosh"] = wrap(bg("bgBlue") + f'''
  <g filter="url(#sh)">
    <rect x="120" y="150" width="272" height="258" rx="38" fill="{WHITE}"/>
  </g>
  <rect x="120" y="150" width="272" height="58" rx="38" fill="{BLUE_DK}"/>
  <rect x="120" y="180" width="272" height="28" fill="{BLUE_DK}"/>
  <rect x="166" y="128" width="24" height="58" rx="12" fill="{BLUE_DK}"/>
  <rect x="322" y="128" width="24" height="58" rx="12" fill="{BLUE_DK}"/>
  <!-- check that breaks out of the calendar frame -->
  <path d="M170 300 l52 54 l132 -150" fill="none" stroke="url(#chk)"
        stroke-width="40" stroke-linecap="round" stroke-linejoin="round"/>
''')

# B. Geofence radar — concentric "you're in the zone" rings + check dot
concepts["B_geofence_radar"] = wrap(bg("bgBlue") + f'''
  <circle cx="256" cy="256" r="180" fill="none" stroke="{WHITE}" stroke-width="6" opacity="0.30"/>
  <circle cx="256" cy="256" r="180" fill="none" stroke="{WHITE}" stroke-width="6"
          stroke-dasharray="30 26" opacity="0.55"/>
  <circle cx="256" cy="256" r="120" fill="none" stroke="{WHITE}" stroke-width="6" opacity="0.45"/>
  <g filter="url(#sh)">
    <circle cx="256" cy="256" r="86" fill="{WHITE}"/>
  </g>
  <path d="M214 256 l30 32 l64 -74" fill="none" stroke="url(#chk)"
        stroke-width="28" stroke-linecap="round" stroke-linejoin="round"/>
''')

# C. Office building inside a location pin (geolocation + workplace)
concepts["C_office_pin"] = wrap(bg("bgBlue") + f'''
  <g filter="url(#sh)">
    <path d="M256 92 C166 92 100 158 100 246 C100 352 256 452 256 452
             C256 452 412 352 412 246 C412 158 346 92 256 92 Z" fill="{WHITE}"/>
  </g>
  <rect x="206" y="176" width="100" height="132" rx="8" fill="{BLUE}"/>
  <g fill="{WHITE}">
    <rect x="222" y="194" width="20" height="20" rx="3"/>
    <rect x="270" y="194" width="20" height="20" rx="3"/>
    <rect x="222" y="230" width="20" height="20" rx="3"/>
    <rect x="270" y="230" width="20" height="20" rx="3"/>
    <rect x="244" y="270" width="24" height="38" rx="3"/>
  </g>
  <circle cx="316" cy="172" r="40" fill="{GREEN}"/>
  <path d="M298 172 l12 13 l24 -28" fill="none" stroke="{WHITE}"
        stroke-width="12" stroke-linecap="round" stroke-linejoin="round"/>
''')

# D. Bird wingstroke that doubles as a checkmark (theme + attendance fused)
concepts["D_bird_check"] = wrap(bg("bgInk") + f'''
  <!-- the green "check" is a bird's flight stroke; a swift lifts off its tip -->
  <path d="M150 296 l66 70 l150 -176" fill="none" stroke="url(#chk)"
        stroke-width="42" stroke-linecap="round" stroke-linejoin="round"/>
  <g filter="url(#sh)">
    <path d="M360 184
             C338 176 322 178 308 190
             C300 176 282 172 264 176
             C282 184 290 196 290 210
             C300 200 316 196 332 200
             C322 206 318 216 320 226
             C336 210 354 202 372 204
             C360 198 356 190 360 184 Z"
          fill="{AMBER}"/>
  </g>
''')

# E. Big-number day — the app says its bold tabular numbers ARE its identity
def number_face(n):
    return f'''
  <g filter="url(#sh)">
    <rect x="116" y="150" width="280" height="248" rx="40" fill="{WHITE}"/>
  </g>
  <rect x="116" y="150" width="280" height="56" rx="40" fill="{GREEN}"/>
  <rect x="116" y="182" width="280" height="24" fill="{GREEN}"/>
  <circle cx="170" cy="178" r="9" fill="{WHITE}"/>
  <circle cx="200" cy="178" r="9" fill="{WHITE}"/>
  <text x="256" y="356" text-anchor="middle" fill="{INK}"
        font-family="DejaVu Sans, Arial, sans-serif" font-weight="800"
        font-size="150" letter-spacing="-6">{n}</text>'''
concepts["E_big_number"] = wrap(bg("bgBlue") + number_face("18"))

# F. Streak — calendar days igniting into an upward flame/arrow of present days
concepts["F_streak"] = wrap(bg("bgGreen") + f'''
  <g filter="url(#sh)">
    <rect x="120" y="150" width="272" height="248" rx="38" fill="{WHITE}"/>
  </g>
  <rect x="120" y="150" width="272" height="52" rx="38" fill="{GREEN_DK}"/>
  <rect x="120" y="178" width="272" height="24" fill="{GREEN_DK}"/>
  <!-- rising bars: a growing return-to-office streak -->
  <g>
    <rect x="156" y="330" width="40" height="40" rx="8" fill="#CDE9D5"/>
    <rect x="212" y="296" width="40" height="74" rx="8" fill="#8FD8A4"/>
    <rect x="268" y="262" width="40" height="108" rx="8" fill="{GREEN}"/>
    <rect x="324" y="228" width="40" height="142" rx="8" fill="{GREEN_DK}"/>
  </g>
  <path d="M168 252 l60 -8 l60 -16 l64 -22" fill="none" stroke="{AMBER}"
        stroke-width="14" stroke-linecap="round" stroke-linejoin="round"/>
  <path d="M340 196 l30 6 l-8 30" fill="none" stroke="{AMBER}"
        stroke-width="14" stroke-linecap="round" stroke-linejoin="round"/>
''')

# render
rendered = {}
for name, svg in concepts.items():
    svg_path = os.path.join(ICONS, name + ".svg")
    png_path = os.path.join(ICONS, name + ".png")
    with open(svg_path, "w") as f:
        f.write(svg)
    cairosvg.svg2png(bytestring=svg.encode(), write_to=png_path,
                     output_width=512, output_height=512)
    rendered[name] = png_path
    print("rendered", png_path)

labels = {
    "A_calendar_swoosh": "A. Calendar Breakout Check",
    "B_geofence_radar": "B. Geofence Radar",
    "C_office_pin": "C. Office in a Pin",
    "D_bird_check": "D. Bird Flight Check",
    "E_big_number": "E. Big-Number Day",
    "F_streak": "F. Attendance Streak",
}
tile, pad, label_h = 256, 40, 46
cols = 3
rows = (len(rendered) + cols - 1) // cols
W = cols * tile + (cols + 1) * pad
H = rows * (tile + label_h) + (rows + 1) * pad
sheet = Image.new("RGB", (W, H), "#F1F3F4")
draw = ImageDraw.Draw(sheet)
try:
    font = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", 21)
except Exception:
    font = ImageFont.load_default()
for i, (name, png) in enumerate(rendered.items()):
    r, c = divmod(i, cols)
    x = pad + c * (tile + pad)
    y = pad + r * (tile + label_h + pad)
    icon = Image.open(png).convert("RGBA").resize((tile, tile), Image.LANCZOS)
    sheet.paste(icon, (x, y), icon)
    draw.text((x + tile/2, y + tile + 10), labels[name], fill="#202124",
              font=font, anchor="ma")
sheet_path = os.path.join(OUT, "icon_concepts_v2.png")
sheet.save(sheet_path)
print("contact sheet:", sheet_path)
