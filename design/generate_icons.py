#!/usr/bin/env python3
"""Generate app-icon concepts for the Attendance Register app.

Produces one 512x512 PNG per concept plus a labelled contact sheet.
Palette is drawn from the app's default bird theme:
  primary   #1A73E8 (Google blue)
  tertiary  #34A853 (green)  -> used for the "present / checked-in" accent
"""
import os
import cairosvg
from PIL import Image, ImageDraw, ImageFont

OUT = os.path.dirname(os.path.abspath(__file__))
ICONS = os.path.join(OUT, "icons")
os.makedirs(ICONS, exist_ok=True)

BLUE = "#1A73E8"
BLUE_DK = "#0B57D0"
GREEN = "#34A853"
GREEN_DK = "#1E8E3E"
AMBER = "#F4C623"
WHITE = "#FFFFFF"
S = 512  # canvas

def squircle_bg(c1, c2):
    """A rounded-square gradient background, iOS-superellipse-ish corners."""
    return f'''
  <defs>
    <linearGradient id="bg" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0" stop-color="{c1}"/>
      <stop offset="1" stop-color="{c2}"/>
    </linearGradient>
    <filter id="sh" x="-20%" y="-20%" width="140%" height="140%">
      <feDropShadow dx="0" dy="6" stdDeviation="10" flood-color="#000" flood-opacity="0.18"/>
    </filter>
  </defs>
  <rect x="0" y="0" width="{S}" height="{S}" rx="115" ry="115" fill="url(#bg)"/>'''

def wrap(body):
    return f'<svg xmlns="http://www.w3.org/2000/svg" width="{S}" height="{S}" viewBox="0 0 {S} {S}">{body}</svg>'

concepts = {}

# 1. Calendar + check  -------------------------------------------------------
concepts["1_calendar_check"] = wrap(squircle_bg(BLUE, BLUE_DK) + f'''
  <g filter="url(#sh)">
    <rect x="116" y="138" width="280" height="262" rx="34" fill="{WHITE}"/>
  </g>
  <rect x="116" y="138" width="280" height="64" rx="34" fill="{BLUE_DK}"/>
  <rect x="116" y="170" width="280" height="32" fill="{BLUE_DK}"/>
  <rect x="160" y="116" width="26" height="62" rx="13" fill="{BLUE_DK}"/>
  <rect x="326" y="116" width="26" height="62" rx="13" fill="{BLUE_DK}"/>
  <!-- check -->
  <path d="M188 296 l44 46 l92 -104" fill="none" stroke="{GREEN}"
        stroke-width="34" stroke-linecap="round" stroke-linejoin="round"/>
''')

# 2. Location pin + check ----------------------------------------------------
concepts["2_pin_check"] = wrap(squircle_bg(BLUE, BLUE_DK) + f'''
  <g filter="url(#sh)">
    <path d="M256 96 C168 96 104 160 104 246
             C104 350 256 446 256 446
             C256 446 408 350 408 246
             C408 160 344 96 256 96 Z" fill="{WHITE}"/>
  </g>
  <path d="M214 250 l30 32 l66 -76" fill="none" stroke="{GREEN}"
        stroke-width="30" stroke-linecap="round" stroke-linejoin="round"/>
''')

# 3. Bird in pin (geolocation + the bird theme) ------------------------------
concepts["3_bird_pin"] = wrap(squircle_bg(GREEN, GREEN_DK) + f'''
  <g filter="url(#sh)">
    <path d="M256 96 C168 96 104 160 104 246
             C104 350 256 446 256 446
             C256 446 408 350 408 246
             C408 160 344 96 256 96 Z" fill="{WHITE}"/>
  </g>
  <!-- simple swift/martin silhouette -->
  <path d="M168 214
           C212 200 244 206 268 228
           C286 200 318 196 348 206
           C322 214 308 230 304 250
           C326 252 340 264 348 282
           C312 270 286 274 268 292
           C250 274 214 270 180 282
           C190 258 200 244 224 238
           C200 230 182 226 168 214 Z"
        fill="{BLUE}"/>
''')

# 4. Calendar grid with a present-day pin ------------------------------------
def day(x, y, fill, r=15):
    return f'<rect x="{x}" y="{y}" width="{2*r}" height="{2*r}" rx="7" fill="{fill}"/>'

grid = ""
gx0, gy0, step = 150, 250, 56
cells = [(0,0),(1,0),(2,0),(3,0),
         (0,1),(1,1),(2,1),(3,1),
         (0,2),(1,2),(2,2),(3,2)]
present = {(2,1),(0,0),(3,2),(1,2)}
for (cx, cy) in cells:
    x = gx0 + cx*step
    y = gy0 + cy*step
    grid += day(x, y, GREEN if (cx,cy) in present else "#C9D7F0")
concepts["4_calendar_grid"] = wrap(squircle_bg(BLUE, BLUE_DK) + f'''
  <g filter="url(#sh)">
    <rect x="116" y="150" width="280" height="250" rx="34" fill="{WHITE}"/>
  </g>
  <rect x="150" y="186" width="180" height="22" rx="11" fill="{BLUE}"/>
  <circle cx="364" cy="197" r="13" fill="{AMBER}"/>
  {grid}
''')

# 5. Monogram "A" + check ----------------------------------------------------
concepts["5_monogram_a"] = wrap(squircle_bg(BLUE, BLUE_DK) + f'''
  <g filter="url(#sh)">
    <path d="M256 130 L356 382 L300 382 L282 332 L230 332 L212 382 L156 382 Z
             M247 286 L265 286 L256 232 Z"
          fill="{WHITE}"/>
  </g>
  <circle cx="356" cy="150" r="58" fill="{GREEN}"/>
  <path d="M332 150 l16 18 l34 -40" fill="none" stroke="{WHITE}"
        stroke-width="16" stroke-linecap="round" stroke-linejoin="round"/>
''')

# render each to PNG
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

# contact sheet -------------------------------------------------------------
labels = {
    "1_calendar_check": "1. Calendar + Check",
    "2_pin_check": "2. Location Pin + Check",
    "3_bird_pin": "3. Bird in Pin",
    "4_calendar_grid": "4. Attendance Grid",
    "5_monogram_a": "5. Monogram A",
}
tile, pad, label_h = 256, 40, 46
cols = 3
rows = (len(rendered) + cols - 1) // cols
W = cols * tile + (cols + 1) * pad
H = rows * (tile + label_h) + (rows + 1) * pad
sheet = Image.new("RGB", (W, H), "#F1F3F4")
draw = ImageDraw.Draw(sheet)
try:
    font = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", 22)
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

sheet_path = os.path.join(OUT, "icon_concepts.png")
sheet.save(sheet_path)
print("contact sheet:", sheet_path)
