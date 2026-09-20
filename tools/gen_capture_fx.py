"""Deterministic Pillow capture placeholders. Run with Python 3.10+."""

from pathlib import Path
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
INK = '#24333d'
WHITE = '#fff9e8'


def canvas(size=32):
    image = Image.new('RGBA', (size, size))
    return image, ImageDraw.Draw(image)


def ball(kind, frame):
    image, d = canvas(16)
    dark, base, light = (('#932d42', '#cc4050', '#f78283') if kind == 'basic'
                         else ('#224d91', '#327cbd', '#7cc8ec'))
    d.ellipse((2, 2, 13, 13), fill=INK)
    d.ellipse((3, 3, 12, 12), fill='#dce5ec')
    d.rectangle((3, 5, 12, 7), fill=dark)
    d.pieslice((3, 3, 12, 12), 180, 360, fill=base)
    d.line((4, 5, 5, 4, 8, 4), fill=light)
    d.line((10, 5, 11, 6, 11, 7), fill=dark)
    d.rectangle((3, 7, 12, 8), fill=INK)
    d.line((4, 10, 5, 11, 9, 11), fill='#ffffff')
    d.ellipse((6, 6, 10, 10), fill=INK)
    d.ellipse((7, 7, 9, 9), fill=('#f7bc43' if kind == 'great' else '#ffffff'))
    d.point((8, 7), fill=WHITE)
    # Integer row shear: about 9 degrees, anchored at the lower shell.
    # Bottom rows never move; no rotation, filtering, or fractional pixels.
    tilt = (0, -1, 0, 1)[frame]
    shifted, _ = canvas(16)
    for y in range(16):
        dx = tilt * ((13 - y + 3) // 6) if y <= 13 else 0
        shifted.paste(image.crop((0, y, 16, y + 1)), (dx, y))
    return shifted.resize((32, 32), Image.Resampling.NEAREST)


def star(d, x, y, radius, color):
    arm = max(1, radius // 3)
    d.polygon([(x, y-radius), (x+arm, y-arm), (x+radius, y),
               (x+arm, y+arm), (x, y+radius), (x-arm, y+arm),
               (x-radius, y), (x-arm, y-arm)], fill=color)


def success(frame):
    image, d = canvas()
    if frame == 0:
        star(d, 16, 16, 3, '#f7bc43')
        star(d, 16, 16, 1, WHITE)
    else:
        radius = (0, 6, 10, 12, 14, 14)[frame]
        color = ('', '#ffc94f', '#ffe486', '#e4bd64', '#c6aa70', '#b6a17b')[frame]
        box = (16-radius, 16-radius, 16+radius, 16+radius)
        if frame <= 2:
            d.ellipse(box, outline=color, width=2)
            star(d, 16, 16, 5 if frame == 1 else 7, '#ffcc4d')
            star(d, 16, 16, 3 if frame == 1 else 4, WHITE)
        else:
            # Broken arcs become shorter, sparser, and less luminous.
            span = {3: 48, 4: 24, 5: 8}[frame]
            for angle in (12, 105, 196, 286):
                d.arc(box, angle, angle+span, fill=color, width=1)
        if frame <= 4:
            offset = (0, 6, 9, 11, 12)[frame]
            for sx, sy in ((-1, -1), (1, -1), (-1, 1), (1, 1)):
                x, y = 16+sx*offset, 16+sy*(offset-2)
                star(d, x, y, 2 if frame <= 3 else 1, color)
                if frame <= 2:
                    d.point((x, y), fill=WHITE)
        else:
            d.point((7, 25), fill=color)
            d.point((25, 27), fill=color)
    return image.resize((64, 64), Image.Resampling.NEAREST)


def puff(d, x, y, radius, faded=False):
    shade = '#9daebc' if faded else '#acc5d6'
    fill = '#becbd4' if faded else '#e1edf4'
    d.ellipse((x-radius, y-radius, x+radius, y+radius), fill=shade)
    d.ellipse((x-radius, y-radius, x+radius-1, y+radius-1), fill=fill)
    if not faded and radius >= 2:
        d.line((x-radius+1, y-1, x, y-2), fill='#ffffff')


def fail(frame):
    image, d = canvas()
    if frame == 0:
        d.ellipse((11, 11, 21, 21), fill=INK)
        d.ellipse((12, 12, 20, 20), fill='#dce5ec')
        d.line((12, 16, 20, 16), fill=INK)
        d.line((16, 11, 15, 14, 17, 16, 15, 18, 16, 21), fill=INK)
        d.line((10, 12, 8, 10), fill='#d8efff')
        d.line((22, 12, 24, 10), fill='#d8efff')
    else:
        # Smoke expands around the break, then falls and thins out.
        centers = {
            1: [(5, 15, 3), (9, 10, 3), (16, 8, 3), (23, 10, 3),
                (27, 15, 3), (23, 21, 4), (16, 23, 3), (8, 21, 4)],
            2: [(4, 18, 2), (8, 17, 3), (24, 17, 3), (28, 19, 2),
                (7, 25, 3), (14, 25, 3), (21, 26, 3), (27, 25, 2)],
            3: [(4, 24, 1), (8, 27, 2), (14, 28, 2), (21, 28, 2), (27, 27, 2)],
            4: [(6, 29, 1), (14, 30, 0), (22, 29, 1), (27, 30, 0)],
        }
        for x, y, radius in centers[frame]:
            if radius:
                puff(d, x, y, radius, faded=frame >= 3)
            else:
                d.point((x, y), fill='#aebbc6')
        if frame <= 2:
            drop = (frame-1)*5
            # Two jagged hollow shell halves, separated by the burst.
            for points in (
                [(7, 13+drop), (10, 12+drop), (13, 14+drop),
                 (11, 16+drop), (13, 18+drop), (9, 18+drop)],
                [(19, 14+drop), (23, 12+drop), (25, 14+drop),
                 (23, 18+drop), (19, 18+drop), (21, 16+drop)],
            ):
                d.polygon(points, fill='#ecf5fa', outline=INK)
            d.line((8, 14+drop, 10, 16+drop), fill='#91b9d0')
            d.line((23, 14+drop, 22, 16+drop), fill='#91b9d0')
    return image.resize((64, 64), Image.Resampling.NEAREST)


def main():
    rows = [('ball_basic', 'ball', [ball('basic', f) for f in range(4)]),
            ('ball_great', 'ball', [ball('great', f) for f in range(4)]),
            ('success', 'success', [success(f) for f in range(6)]),
            ('fail', 'fail', [fail(f) for f in range(5)])]
    sheet = Image.new('RGB', (740, 440), '#808080')
    d = ImageDraw.Draw(sheet)
    d.text((12, 10), 'CAPTURE FX / native size / frames left to right', fill='#ffffff')
    count = 0
    for row, (name, folder, frames) in enumerate(rows):
        dest = ROOT / 'assets' / 'fx' / folder
        dest.mkdir(parents=True, exist_ok=True)
        y = 36 + row*100
        d.text((12, y+24), name, fill='#ffffff')
        d.text((12, y+40), f'{frames[0].width}px / {len(frames)} frames', fill='#eeeeee')
        for frame, sprite in enumerate(frames):
            sprite.save(dest / f'{name}_{frame}.png')
            x = 140 + frame*100
            d.rectangle((x, y, x+94, y+94), outline='#a0a0a0')
            sheet.paste(sprite, (x+(94-sprite.width)//2, y+4+(64-sprite.height)), sprite)
            d.text((x+42, y+76), str(frame), fill='#ffffff')
            count += 1
    sheet.save(ROOT / 'tools' / 'capture_fx_contact_sheet.png')
    print(f'Generated {count} RGBA sprites and tools/capture_fx_contact_sheet.png')


if __name__ == '__main__':
    main()
