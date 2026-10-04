# Builds 1920x1080 thumbnails from in-game captures + title text.
from PIL import Image, ImageDraw, ImageFont, ImageFilter, ImageEnhance
import os, glob
ROOT = os.path.join(os.path.dirname(__file__), '..')
FONTS = glob.glob(os.path.join(os.environ['LOCALAPPDATA'], 'Roblox', 'Versions', '*', 'content', 'fonts'))[0]
LUCKIEST = os.path.join(FONTS, 'LuckiestGuy-Regular.ttf')
CAP = os.path.join(ROOT, 'scratch', 'captures')
OUT = os.path.join(ROOT, 'marketing')

def base(name, shift=0.5, boost=1.12):
    im = Image.open(os.path.join(CAP, name)).convert('RGB')
    w, h = im.size
    cw = int(h * 16 / 9)
    x0 = int((w - cw) * shift)
    im = im.crop((x0, 0, x0 + cw, h)).resize((1920, 1080), Image.LANCZOS)
    im = ImageEnhance.Color(im).enhance(boost)
    im = ImageEnhance.Contrast(im).enhance(1.05)
    return im.convert('RGBA')

def text(im, xy, s, size, fill, stroke=(40, 18, 70), sw=None, anchor='mm', shadow=True):
    f = ImageFont.truetype(LUCKIEST, size)
    sw = sw or max(6, size // 11)
    if shadow:
        layer = Image.new('RGBA', im.size, (0, 0, 0, 0))
        ImageDraw.Draw(layer).text((xy[0] + size * 0.05, xy[1] + size * 0.07), s, font=f, anchor=anchor, fill=(0, 0, 0, 150), stroke_width=sw, stroke_fill=(0, 0, 0, 150))
        im.alpha_composite(layer.filter(ImageFilter.GaussianBlur(size * 0.04)))
    ImageDraw.Draw(im).text(xy, s, font=f, anchor=anchor, fill=fill, stroke_width=sw, stroke_fill=stroke)

def gradient_text(im, xy, s, size, top, bottom, stroke=(40, 18, 70)):
    f = ImageFont.truetype(LUCKIEST, size)
    sw = max(6, size // 11)
    text(im, xy, s, size, top, stroke, sw)  # outline + shadow pass
    mask = Image.new('L', im.size, 0)
    ImageDraw.Draw(mask).text(xy, s, font=f, anchor='mm', fill=255)
    grad = Image.new('RGBA', im.size)
    bbox = mask.getbbox()
    gd = ImageDraw.Draw(grad)
    for y in range(bbox[1], bbox[3]):
        t = (y - bbox[1]) / max(1, bbox[3] - bbox[1])
        gd.line([(bbox[0], y), (bbox[2], y)], fill=tuple(int(top[i] + (bottom[i] - top[i]) * t) for i in range(3)) + (255,))
    im.paste(grad, (0, 0), mask)

def vignette(im, strength=110):
    v = Image.new('L', im.size, 0)
    d = ImageDraw.Draw(v)
    d.rectangle([0, 0, 1920, 260], fill=strength)
    v = v.filter(ImageFilter.GaussianBlur(120))
    dark = Image.new('RGBA', im.size, (10, 5, 30, 255))
    im.paste(dark, (0, 0), v)

def ribbon(im, y, s, color):
    d = ImageDraw.Draw(im)
    f = ImageFont.truetype(LUCKIEST, 64)
    w = d.textlength(s, font=f) + 120
    x0 = (1920 - w) / 2
    d.rounded_rectangle([x0, y - 52, x0 + w, y + 52], radius=52, fill=color, outline=(40, 18, 70), width=8)
    text(im, (960, y + 4), s, 64, (255, 255, 255), shadow=False)

# 1: daytime close-up
t1 = base('g2.jpg', 0.42)
vignette(t1)
gradient_text(t1, (960, 150), 'GROW A GEM GARDEN', 150, (255, 246, 160), (255, 170, 40))
ribbon(t1, 960, 'PLANT  •  HARVEST  •  GET RICH!', (60, 170, 80))
t1.convert('RGB').save(os.path.join(OUT, 'thumb_1.png'))

# 2: thunderstorm
t2 = base('storm_g1b.jpg', 0.5)
vignette(t2, 90)
gradient_text(t2, (960, 140), 'WEATHER MUTATIONS!', 140, (220, 240, 255), (120, 170, 255))
text(t2, (1500, 880), 'x100', 230, (255, 220, 70), shadow=True)
ribbon(t2, 980, 'LIGHTNING  •  METEORS  •  AURORA', (80, 90, 220))
t2.convert('RGB').save(os.path.join(OUT, 'thumb_2.png'))

# 3: aurora night
t3 = base('aurora3.jpg', 0.45)
gradient_text(t3, (960, 150), 'RAINBOW GEMS', 160, (190, 255, 230), (110, 200, 255))
ribbon(t3, 960, 'CAN YOU GROW A PRISM LOTUS?', (150, 70, 220))
t3.convert('RGB').save(os.path.join(OUT, 'thumb_3.png'))
print('thumbs saved')
