# Generates 512x512 store icons for game passes / developer products.
from PIL import Image, ImageDraw, ImageFont, ImageFilter
import math, os, sys
OUT = os.path.join(os.path.dirname(__file__), '..', 'marketing', 'icons')
EMOJI = ImageFont.truetype(r'C:\Windows\Fonts\seguiemj.ttf', 260)
BOLD = r'C:\Windows\Fonts\impact.ttf'

def lerp(a, b, t): return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))

def icon(name, emoji, c1, c2, label=None):
    S = 512
    img = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    bg = Image.new('RGBA', (S, S))
    px = bg.load()
    for y in range(S):
        for x in range(S):
            d = math.hypot(x - S * 0.5, y - S * 0.38) / (S * 0.75)
            px[x, y] = lerp(c1, c2, min(1, d)) + (255,)
    mask = Image.new('L', (S, S), 0)
    ImageDraw.Draw(mask).rounded_rectangle([8, 8, S - 8, S - 8], radius=96, fill=255)
    img.paste(bg, (0, 0), mask)
    d = ImageDraw.Draw(img)
    d.rounded_rectangle([8, 8, S - 8, S - 8], radius=96, outline=lerp(c2, (0, 0, 0), 0.5) + (255,), width=14)
    # sparkles
    for (sx, sy, r) in [(400, 110, 22), (110, 400, 16), (420, 380, 12), (96, 120, 10)]:
        d.polygon([(sx, sy - r), (sx + r * 0.3, sy - r * 0.3), (sx + r, sy), (sx + r * 0.3, sy + r * 0.3), (sx, sy + r), (sx - r * 0.3, sy + r * 0.3), (sx - r, sy), (sx - r * 0.3, sy - r * 0.3)], fill=(255, 255, 255, 220))
    # emoji with soft shadow
    layer = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    ImageDraw.Draw(layer).text((S / 2, S * 0.47), emoji, font=EMOJI, anchor='mm', embedded_color=True)
    shadow = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    alpha = layer.split()[3].point(lambda a: int(a * 0.55))
    shadow.putalpha(alpha)
    shadow = shadow.filter(ImageFilter.GaussianBlur(10))
    img.alpha_composite(shadow, (8, 14))
    img.alpha_composite(layer)
    if label:
        f = ImageFont.truetype(BOLD, 74)
        d.text((S / 2, S * 0.86), label, font=f, anchor='mm', fill=(255, 255, 255), stroke_width=8, stroke_fill=lerp(c2, (0, 0, 0), 0.6))
    img.save(os.path.join(OUT, name + '.png'))

G = lambda h: tuple(int(h[i:i + 2], 16) for i in (1, 3, 5))
specs = [
    ('pass_VIP', '👑', G('#ffe27a'), G('#c97a00'), 'VIP'),
    ('pass_LuckyGardener', '🍀', G('#9dffa0'), G('#1f8a34'), 'LUCKY'),
    ('pass_SpeedyGrowth', '⚡', G('#a8dcff'), G('#2457c9'), 'SPEED'),
    ('pass_SuperGarden', '🌿', G('#d4ff9a'), G('#3f8f1a'), '+40'),
    ('pass_BigBag', '🎒', G('#ffc98a'), G('#c2541a'), '+300'),
    ('pass_SellAnywhere', '💰', G('#fff1a8'), G('#b8860b'), 'SELL'),
    ('dev_Coins1', '💰', G('#fff3b0'), G('#d29a10'), None),
    ('dev_Coins2', '💰', G('#ffe08a'), G('#c47f00'), 'x14'),
    ('dev_Coins3', '💎', G('#c9f1ff'), G('#2b78c9'), 'x65'),
    ('dev_Coins4', '👑', G('#ffd27a'), G('#8f3fd1'), 'x280'),
    ('dev_Restock', '🔄', G('#d7c2ff'), G('#5b2bb8'), None),
    ('dev_GrowAll', '⏩', G('#b9ffd0'), G('#138a5a'), None),
    ('dev_LuckPotion', '🔮', G('#f2c2ff'), G('#7a1fa8'), '30m'),
    ('dev_Weather_glimmer_rain', '🌧️', G('#cfe9ff'), G('#2f6fb8'), None),
    ('dev_Weather_blizzard', '❄️', G('#ecf7ff'), G('#5a8fc4'), None),
    ('dev_Weather_heatwave', '🔥', G('#ffd1a1'), G('#c2361a'), None),
    ('dev_Weather_thunderstorm', '⚡', G('#c9c9ff'), G('#2d2d7a'), None),
    ('dev_Weather_meteor_shower', '🌠', G('#e3c2ff'), G('#3b1470'), None),
    ('dev_Weather_aurora', '🌌', G('#b7fff0'), G('#1a6b7a'), None),
    ('dev_Tier_Common', '🌱', G('#e6e9ee'), G('#6a7280'), None),
    ('dev_Tier_Uncommon', '🌱', G('#c8ffc0'), G('#2c8a30'), None),
    ('dev_Tier_Rare', '🌱', G('#bfe0ff'), G('#1f5fbf'), None),
    ('dev_Tier_Epic', '🌱', G('#e6c8ff'), G('#6b22b5'), None),
    ('dev_Tier_Legendary', '🌱', G('#fff0b0'), G('#c27a00'), None),
    ('dev_Tier_Mythic', '🌱', G('#ffc2d8'), G('#b5124f'), None),
    ('dev_Tier_Divine', '🌱', G('#d6fbff'), G('#1a8ca8'), None),
    ('dev_Tier_Prismatic', '🌈', G('#ffffff'), G('#7a4fd1'), None),
]
for s in specs:
    icon(*s)
print('made', len(specs))
