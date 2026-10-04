# Cuts recorded gameplay clips into promo videos with captions.
#   vertical  1080x1920 (TikTok / YouTube Shorts / Reels)
#   landscape 1920x1080 (YouTube / Roblox game page)
# Usage: python tools/make_promo.py
import os, subprocess, glob, shutil
from PIL import Image, ImageDraw, ImageFont, ImageFilter

ROOT = os.path.join(os.path.dirname(__file__), '..')
V = os.path.join(ROOT, 'scratch', 'video')
OUT = os.path.join(ROOT, 'marketing', 'video')
TMP = os.path.join(V, 'promo_tmp')
os.makedirs(OUT, exist_ok=True)
os.makedirs(TMP, exist_ok=True)
FONT = os.path.join(V, 'luckiest.ttf')
EMOJI = r'C:\Windows\Fonts\seguiemj.ttf'

# clip, start, duration, big caption, small caption
SEGMENTS = [
    ('s1_day.mp4', 3.4, 3.0, 'THIS GARDEN', 'GROWS GEMS 💎'),
    ('s5_close.mp4', 4.6, 2.6, '15 MAGICAL', 'PLANTS 🌱'),
    ('s6_harvest.mp4', 1.6, 4.6, 'HARVEST & SELL', 'GET RICH 💰'),
    ('s3_storm.mp4', 3.4, 4.2, '⚡ LIGHTNING', 'x30 CHARGED GEMS'),
    ('s2_meteor.mp4', 7.0, 3.2, '☄️ METEORS', 'x60 COSMIC GEMS'),
    ('s4_aurora.mp4', 5.0, 4.6, '🌌 AURORA', 'x100 CELESTIAL!'),
]
END_SECONDS = 3.2


def is_emoji(ch):
    o = ord(ch)
    return o >= 0x2190 and not (0x2000 <= o <= 0x206F)


def draw_mixed(img, center, text, size, fill, stroke, sw, max_w=None):
    """Draw text mixing LuckiestGuy + color emoji, centered at `center`.
    Shrinks the font until the line fits within max_w (default: 92% of image width)."""
    text = text.replace('️', '')
    max_w = max_w or img.width * 0.92
    while size > 20:
        f = ImageFont.truetype(FONT, size)
        fe = ImageFont.truetype(EMOJI, int(size * 0.92))
        d = ImageDraw.Draw(img)
        total = sum(d.textlength(ch, font=fe if is_emoji(ch) else f) for ch in text) + sw * 2
        if total <= max_w:
            break
        size = int(size * 0.94)
    f = ImageFont.truetype(FONT, size)
    fe = ImageFont.truetype(EMOJI, int(size * 0.92))
    runs, cur, cur_e = [], '', None
    for ch in text:
        e = is_emoji(ch) or (ch == '\ufe0f')
        if cur and e != cur_e:
            runs.append((cur, cur_e)); cur = ''
        cur += ch; cur_e = e
    if cur:
        runs.append((cur, cur_e))
    d = ImageDraw.Draw(img)
    widths = []
    for s, e in runs:
        font = fe if e else f
        widths.append(d.textlength(s, font=font) + (0 if e else sw))
    x = center[0] - sum(widths) / 2
    for (s, e), w in zip(runs, widths):
        if e:
            d.text((x, center[1]), s, font=fe, anchor='lm', embedded_color=True)
        else:
            d.text((x + sw / 2, center[1]), s, font=f, anchor='lm', fill=fill, stroke_width=sw, stroke_fill=stroke)
        x += w


def caption_png(path, w, h, big, small, layout):
    img = Image.new('RGBA', (w, h), (0, 0, 0, 0))
    if layout == 'vertical':
        cx, y1, y2, s1, s2 = w / 2, 330, 470, 128, 92
    else:
        cx, y1, y2, s1, s2 = w / 2, h - 230, h - 110, 110, 78
    # soft shadow layer
    shadow = Image.new('RGBA', (w, h), (0, 0, 0, 0))
    draw_mixed(shadow, (cx + 6, y1 + 9), big, s1, (0, 0, 0, 170), (0, 0, 0, 170), 14)
    draw_mixed(shadow, (cx + 5, y2 + 8), small, s2, (0, 0, 0, 170), (0, 0, 0, 170), 11)
    img.alpha_composite(shadow.filter(ImageFilter.GaussianBlur(6)))
    draw_mixed(img, (cx, y1), big, s1, (255, 236, 110), (60, 20, 90), 14)
    draw_mixed(img, (cx, y2), small, s2, (255, 255, 255), (60, 20, 90), 11)
    img.save(path)


def end_card(path, w, h):
    thumb = Image.open(os.path.join(ROOT, 'marketing', 'thumb_3.png')).convert('RGB')
    # background: blurred thumbnail filling the frame
    scale = max(w / thumb.width, h / thumb.height)
    bg = thumb.resize((int(thumb.width * scale) + 1, int(thumb.height * scale) + 1))
    bg = bg.crop(((bg.width - w) // 2, (bg.height - h) // 2, (bg.width - w) // 2 + w, (bg.height - h) // 2 + h))
    bg = bg.filter(ImageFilter.GaussianBlur(18)).convert('RGBA')
    bg.alpha_composite(Image.new('RGBA', (w, h), (10, 5, 35, 120)))
    icon = Image.open(os.path.join(ROOT, 'marketing', 'game_icon.png')).convert('RGBA')
    isz = int(min(w, h) * (0.5 if h > w else 0.42))
    icon = icon.resize((isz, isz), Image.LANCZOS)
    mask = Image.new('L', (isz, isz), 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, isz, isz], radius=isz // 6, fill=255)
    cy = int(h * (0.36 if h > w else 0.36))
    bg.paste(icon, ((w - isz) // 2, cy - isz // 2), mask)
    big = 120 if h > w else 100
    draw_mixed(bg, (w / 2, cy + isz / 2 + big * 0.95), 'GROW A GEM GARDEN', big, (255, 236, 110), (60, 20, 90), 14)
    draw_mixed(bg, (w / 2, cy + isz / 2 + big * 2.05), 'PLAY FREE ON ROBLOX', int(big * 0.7), (255, 255, 255), (60, 20, 90), 10)
    draw_mixed(bg, (w / 2, cy + isz / 2 + big * 2.95), 'code: RELEASE 🎁', int(big * 0.62), (150, 255, 180), (20, 60, 30), 9)
    bg.convert('RGB').save(path)


def run(cmd):
    r = subprocess.run(cmd, capture_output=True, text=True)
    if r.returncode != 0:
        print(r.stderr[-2000:])
        raise SystemExit(1)


def build(layout):
    w, h = (1080, 1920) if layout == 'vertical' else (1920, 1080)
    parts = []
    for i, (clip, start, dur, big, small) in enumerate(SEGMENTS):
        cap = os.path.join(TMP, f'{layout}_cap{i}.png')
        caption_png(cap, w, h, big, small, layout)
        out = os.path.join(TMP, f'{layout}_{i}.mp4')
        if layout == 'vertical':
            fg_h = 900
            filt = (f'[0:v]trim=start={start}:duration={dur},setpts=PTS-STARTPTS,fps=30,split[a][b];'
                    f'[a]scale=-2:{h},crop={w}:{h},boxblur=24:2,eq=brightness=-0.12:saturation=1.15[bg];'
                    f'[b]scale=-2:{fg_h},crop={w}:{fg_h},eq=saturation=1.12[fg];'
                    f'[bg][fg]overlay=0:{(h - fg_h) // 2 + 120}[v];[v][1:v]overlay=0:0,format=yuv420p[out]')
        else:
            filt = (f'[0:v]trim=start={start}:duration={dur},setpts=PTS-STARTPTS,fps=30,'
                    f'scale=-2:{h},crop={w}:{h},eq=saturation=1.12[v];[v][1:v]overlay=0:0,format=yuv420p[out]')
        run(['ffmpeg', '-hide_banner', '-loglevel', 'error', '-y', '-i', os.path.join(V, clip), '-i', cap,
             '-filter_complex', filt, '-map', '[out]', '-c:v', 'libx264', '-preset', 'medium', '-crf', '18', '-r', '30', out])
        parts.append(out)
    card = os.path.join(TMP, f'{layout}_end.png')
    end_card(card, w, h)
    end = os.path.join(TMP, f'{layout}_end.mp4')
    run(['ffmpeg', '-hide_banner', '-loglevel', 'error', '-y', '-loop', '1', '-i', card, '-t', str(END_SECONDS),
         '-vf', f"scale={w*1.06:.0f}:-2,zoompan=z='min(1+on/400,1.06)':d={int(END_SECONDS*30)}:s={w}x{h}:fps=30,format=yuv420p",
         '-c:v', 'libx264', '-preset', 'medium', '-crf', '18', end])
    parts.append(end)
    lst = os.path.join(TMP, f'{layout}_list.txt')
    with open(lst, 'w') as fh:
        for p in parts:
            fh.write("file '%s'\n" % p.replace('\\', '/'))
    final = os.path.join(OUT, f'promo_{layout}.mp4')
    run(['ffmpeg', '-hide_banner', '-loglevel', 'error', '-y', '-f', 'concat', '-safe', '0', '-i', lst,
         '-f', 'lavfi', '-i', 'anullsrc=r=44100:cl=stereo', '-shortest',
         '-c:v', 'libx264', '-preset', 'medium', '-crf', '19', '-pix_fmt', 'yuv420p', '-c:a', 'aac', '-b:a', '96k',
         '-movflags', '+faststart', final])
    print('built', final)


if __name__ == '__main__':
    build('vertical')
    build('landscape')
