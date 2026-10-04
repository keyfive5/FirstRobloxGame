# Game icon (512x512): prismatic brilliant gem sprouting from a soil mound.
from PIL import Image, ImageDraw, ImageFont, ImageFilter
import math, os, glob, colorsys
ROOT = os.path.join(os.path.dirname(__file__), '..')
FONTS = glob.glob(os.path.join(os.environ['LOCALAPPDATA'], 'Roblox', 'Versions', '*', 'content', 'fonts'))[0]
LUCKIEST = os.path.join(FONTS, 'LuckiestGuy-Regular.ttf')
SS = 4
S = 512 * SS

def hsv(h, s, v):
    r, g, b = colorsys.hsv_to_rgb(h % 1, s, v)
    return (int(r * 255), int(g * 255), int(b * 255))

def background(img):
    px = img.load()
    for y in range(S):
        for x in range(S):
            d = math.hypot(x - S * 0.5, y - S * 0.42) / (S * 0.72)
            t = min(1, d)
            c1, c2 = (120, 220, 255), (40, 70, 190)
            px[x, y] = tuple(int(c1[i] + (c2[i] - c1[i]) * t) for i in range(3)) + (255,)
    # light rays
    rays = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(rays)
    cx, cy = S * 0.5, S * 0.42
    for i in range(16):
        a0 = i / 16 * math.tau
        a1 = a0 + math.tau / 40
        d.polygon([(cx, cy), (cx + math.cos(a0) * S, cy + math.sin(a0) * S), (cx + math.cos(a1) * S, cy + math.sin(a1) * S)], fill=(255, 255, 255, 34))
    img.alpha_composite(rays)

def sparkle(d, x, y, r, a=230):
    d.polygon([(x, y - r), (x + r * 0.22, y - r * 0.22), (x + r, y), (x + r * 0.22, y + r * 0.22), (x, y + r), (x - r * 0.22, y + r * 0.22), (x - r, y), (x - r * 0.22, y - r * 0.22)], fill=(255, 255, 255, a))

def fill_grad(img, poly, c1, c2):
    xs = [p[0] for p in poly]; ys = [p[1] for p in poly]
    x0, y0, x1, y1 = int(min(xs)), int(min(ys)), int(max(xs)) + 1, int(max(ys)) + 1
    h = max(1, y1 - y0)
    grad = Image.new('RGBA', (x1 - x0, h))
    gd = ImageDraw.Draw(grad)
    for yy in range(h):
        t = yy / h
        gd.line([(0, yy), (x1 - x0, yy)], fill=tuple(int(c1[i] + (c2[i] - c1[i]) * t) for i in range(3)) + (255,))
    mask = Image.new('L', (x1 - x0, h), 0)
    ImageDraw.Draw(mask).polygon([(p[0] - x0, p[1] - y0) for p in poly], fill=255)
    img.paste(grad, (x0, y0), mask)

def gem_glow(img, cx, cy, w):
    glow = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    ImageDraw.Draw(glow).ellipse([cx - w * 1.5, cy - w * 1.1, cx + w * 1.5, cy + w * 1.3], fill=(255, 255, 255, 150))
    glow = glow.filter(ImageFilter.GaussianBlur(S * 0.05))
    img.alpha_composite(glow)

def gem(img, cx, cy, w):
    def P(x, y):
        return (cx + x * w, cy + y * w)
    ty, cu = -0.36, 0.95
    girdle = [-1.0, -0.75, -0.5, -0.25, 0.0, 0.25, 0.5, 0.75, 1.0]
    table = [-0.52, -0.26, 0.0, 0.26, 0.52]
    facets = []
    # crown: kite/star facets between table and girdle
    for i in range(8):
        gx0, gx1 = girdle[i], girdle[i + 1]
        tx = table[min(4, max(0, round((gx0 + gx1) / 2 / 0.26) + 2))]
        tx = max(-0.52, min(0.52, (gx0 + gx1) / 2 * 0.52))
        hue = 0.0 + i / 8
        light = 1.0 if i % 2 == 0 else 0.85
        facets.append(([(gx0, 0), (tx, ty), (gx1, 0)], hsv(hue, 0.35, light), hsv(hue, 0.7, light * 0.95)))
        if i < 7:
            tx2 = max(-0.52, min(0.52, gx1 * 0.52))
            facets.append(([(tx, ty), (tx2 + 0.0, ty), (gx1, 0)], hsv(hue + 0.06, 0.25, 1.0), hsv(hue + 0.06, 0.6, 0.9)))
    # table
    facets.append(([(-0.52, ty), (0.52, ty), (0.52, ty - 0.001), (-0.52, ty - 0.001)], (230, 250, 255), (200, 240, 255)))
    # pavilion
    for i in range(8):
        hue = 0.55 + i / 8
        dark = 0.95 - 0.1 * abs(i - 3.5) / 3.5
        facets.append(([(girdle[i], 0), (girdle[i + 1], 0), (0, cu)], hsv(hue, 0.6, dark), hsv(hue, 0.9, dark * 0.6)))
    for poly, c1, c2 in facets:
        fill_grad(img, [P(*p) for p in poly], c1, c2)
    d = ImageDraw.Draw(img)
    for poly, _, _ in facets:
        d.line([P(*p) for p in poly] + [P(*poly[0])], fill=(255, 255, 255), width=int(S * 0.003))
    d.line([P(-1, 0), P(-0.52, ty), P(0.52, ty), P(1, 0), P(0, cu), P(-1, 0)], fill=(40, 20, 80), width=int(S * 0.014), joint='curve')
    d.line([P(-1, 0), P(1, 0)], fill=(40, 20, 80), width=int(S * 0.006))
    d.polygon([P(-0.47, -0.31), P(-0.3, -0.31), P(-0.6, -0.03), P(-0.8, -0.03)], fill=(255, 255, 255, 190))
    sparkle(d, P(0.55, -0.45)[0], P(0.55, -0.45)[1], S * 0.035)
    sparkle(d, P(-0.2, 0.45)[0], P(-0.2, 0.45)[1], S * 0.02)

img = Image.new('RGBA', (S, S))
background(img)
d = ImageDraw.Draw(img)
# soil mound + grass
d.ellipse([S * 0.08, S * 0.74, S * 0.92, S * 1.12], fill=(110, 196, 80), outline=(40, 90, 30), width=int(S * 0.012))
d.ellipse([S * 0.25, S * 0.76, S * 0.75, S * 0.9], fill=(110, 74, 50), outline=(60, 38, 24), width=int(S * 0.01))
gem_glow(img, S * 0.5, S * 0.38, S * 0.3)
d = ImageDraw.Draw(img)
# stem + leaves
d.line([(S * 0.5, S * 0.82), (S * 0.5, S * 0.6)], fill=(70, 160, 60), width=int(S * 0.04))
d.ellipse([S * 0.5, S * 0.62, S * 0.75, S * 0.71], fill=(80, 190, 70), outline=(30, 90, 30), width=int(S * 0.009))
d.ellipse([S * 0.25, S * 0.67, S * 0.5, S * 0.76], fill=(70, 175, 60), outline=(30, 90, 30), width=int(S * 0.009))
gem(img, S * 0.5, S * 0.38, S * 0.3)
d = ImageDraw.Draw(img)
for (x, y, r) in [(0.18, 0.2, 0.05), (0.84, 0.28, 0.04), (0.8, 0.12, 0.025), (0.14, 0.52, 0.03), (0.88, 0.58, 0.03), (0.3, 0.08, 0.02)]:
    sparkle(d, S * x, S * y, S * r)
# title
f = ImageFont.truetype(LUCKIEST, int(S * 0.13))
d.text((S * 0.5, S * 0.885), 'GEM GARDEN', font=f, anchor='mm', fill=(255, 236, 120), stroke_width=int(S * 0.016), stroke_fill=(70, 30, 100))
# rounded mask
mask = Image.new('L', (S, S), 0)
ImageDraw.Draw(mask).rounded_rectangle([0, 0, S, S], radius=int(S * 0.0), fill=255)
img.putalpha(mask)
out = img.resize((512, 512), Image.LANCZOS)
os.makedirs(os.path.join(ROOT, 'marketing'), exist_ok=True)
out.convert('RGB').save(os.path.join(ROOT, 'marketing', 'game_icon.png'))
print('icon saved')
