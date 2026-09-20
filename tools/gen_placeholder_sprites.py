"""Deterministic, code-only 8-direction idle sprites. Requires Python 3.10+, Pillow."""

from pathlib import Path
import argparse

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
DIRECTIONS = ('s', 'se', 'e', 'ne', 'n', 'nw', 'w', 'sw')
PETS = ('eggshell_dragon', 'flame_cat', 'diving_snake')
INK = '#24333d'


class PixelArt:
    """Draw on an integer 32px grid, then enlarge with nearest sampling."""

    def __init__(self):
        self.image = Image.new('RGBA', (32, 32))
        self.draw = ImageDraw.Draw(self.image)

    def oval(self, box, color):
        self.draw.ellipse(box, fill=color, outline=INK, width=1)

    def poly(self, points, color):
        self.draw.polygon(points, fill=color, outline=INK)

    def line(self, points, color=INK, width=1):
        self.draw.line(points, fill=color, width=width)

    def rect(self, box, color):
        self.draw.rectangle(box, fill=color)


def eye(a, x, y):
    a.rect((x, y, x + 1, y + 2), '#f7bc43')
    a.rect((x + 1, y + 1, x + 1, y + 2), INK)
    a.rect((x, y, x, y), '#ffffff')


def dragon(view, breath):
    a = PixelArt()
    green, light, dark = '#80a65c', '#afc779', '#4c7047'
    shell, spot = '#edddba', '#72965a'
    y = breath
    # The tail projects sideways in profile and points down the back in rear view.
    tails = {
        's': [(8, 24), (3, 21), (4, 26), (10, 28)],
        'se': [(10, 25), (2, 22), (4, 27), (12, 28)],
        'e': [(13, 24), (2, 20), (3, 25), (15, 28)],
        'ne': [(17, 24), (5, 19), (4, 24), (14, 28)],
        'n': [(13, 24), (15, 29), (19, 26), (19, 23)],
    }
    a.poly(tails[view], green)
    for x in ([9, 20] if view in ('s', 'n') else [11, 21]):
        a.oval((x - 2, 26, x + 4, 29), dark)
    cx = {'s': 16, 'se': 18, 'e': 19, 'ne': 18, 'n': 16}[view]
    a.oval((cx - 8, 9 + y, cx + 6, 24), green)
    if view in ('e', 'se'):
        a.poly([(cx - 7, 12 + y), (cx - 9, 8 + y), (cx - 4, 10 + y)], '#d59b4d')
        a.poly([(cx - 7, 17 + y), (cx - 10, 13 + y), (cx - 5, 15 + y)], '#d59b4d')
    if view in ('s', 'se', 'e'):
        a.oval((cx - 4, 15 + y, cx + 4, 24), '#e3d49e')
        # Three genuinely different muzzle projections, not shifted front faces.
        box = {'s': (8, 9+y, 24, 17+y), 'se': (13, 9+y, 27, 17+y),
               'e': (17, 10+y, 30, 17+y)}[view]
        a.oval(box, light)
        if view == 's':
            eye(a, 10, 10+y)
            eye(a, 20, 10+y)
            a.line([(11, 15+y), (21, 15+y)])
            a.rect((13, 13+y, 13, 13+y), dark)
            a.rect((19, 13+y, 19, 13+y), dark)
        elif view == 'se':
            eye(a, 15, 10+y)
            eye(a, 23, 11+y)
            a.line([(20, 15+y), (26, 15+y)])
        else:
            eye(a, 21, 10+y)
            a.line([(24, 15+y), (29, 15+y)])
    else:
        a.oval((cx - 7, 8+y, cx + 5, 18+y), green)
        # Rear diagonal: asymmetric head contour and off-center dorsal ridge.
        ridge = 12 if view == 'ne' else 16
        for dy in (9, 13, 17):
            a.poly([(ridge, dy-2+y), (ridge+2, dy+y),
                    (ridge, dy+3+y), (ridge-2, dy+y)], '#d59b4d')
        a.rect((cx+3, 12+y, cx+4, 14+y), dark)
    a.poly([(6, 19), (9, 21), (11, 18), (14, 21), (17, 19),
            (20, 21), (24, 18), (26, 22), (25, 26), (21, 28),
            (11, 28), (7, 26)], shell)
    for box in ((8, 22, 12, 25), (19, 23, 23, 27)):
        a.oval(box, spot)
    if view in ('n', 'ne'):
        x = 16 if view == 'n' else 12
        a.line([(x, 20), (x+1, 23), (x-1, 26)], dark, 2)
    else:
        a.line([(14, 22), (16, 24), (15, 26)], '#bba783')
    # Vine and leaf remain readable against the cream shell.
    x = 6 if view in ('s', 'se', 'e') else 24
    a.line([(x, 26), (x-1, 23), (x+1, 21)], dark)
    a.poly([(x, 23), (x-3, 20), (x-3, 23), (x, 24)], light)
    return a.image


def flame(a, x, y, small=False):
    if small:
        a.poly([(x-3,y+6), (x-3,y+3), (x,y), (x,y+3),
                (x+3,y+1), (x+2,y+6)], '#f16830')
        a.poly([(x-1,y+5), (x,y+2), (x+1,y+5)], '#ffe46d')
    else:
        a.poly([(x-3,y+13), (x-5,y+8), (x-3,y+3), (x-1,y+6),
                (x+2,y), (x+2,y+6), (x+4,y+4), (x+3,y+10), (x,y+14)], '#e9502e')
        a.poly([(x-2,y+11), (x-2,y+7), (x,y+8), (x+1,y+4),
                (x+2,y+9), (x,y+12)], '#ffcd51')


def cat(view, breath):
    a = PixelArt()
    cream, orange, red = '#fff0d2', '#e78043', '#b94332'
    y = breath
    tx = {'s': 24, 'se': 8, 'e': 7, 'ne': 9, 'n': 16}[view]
    if view != 'n':
        flame(a, tx, 12+y)
    a.oval((10, 18+y, 22, 28), cream if view in ('s','se','e') else orange)
    for x in ([11,18] if view in ('s','n') else [12,21]):
        a.oval((x-1, 25, x+3, 29), cream)
        a.line([(x,28), (x+2,28)], orange)
    hx = {'s':16, 'se':18, 'e':21, 'ne':18, 'n':16}[view]
    # Ear spacing compresses in profile; rear diagonal shows the nearer ear back.
    span = 4 if view == 'e' else 7
    a.poly([(hx-span,15+y), (hx-span-1,7+y), (hx-1,11+y)], red)
    a.poly([(hx+1,11+y), (hx+span,7+y), (hx+span,16+y)], red)
    a.oval((hx-7, 11+y, hx+6, 22+y), cream if view in ('s','se','e') else orange)
    a.poly([(hx-6,16+y), (hx-9,19+y), (hx-4,20+y)], cream if view=='s' else orange)
    if view in ('s','se','e'):
        if view == 's':
            eye(a, hx-4, 15+y)
            eye(a, hx+3, 15+y)
            a.rect((hx,18+y,hx+1,18+y), red)
            a.line([(hx-3,20+y),(hx,21+y),(hx+3,20+y)])
        elif view == 'se':
            eye(a, hx-3, 15+y)
            eye(a, hx+4, 16+y)
            a.poly([(hx+2,18+y),(hx+8,18+y),(hx+5,21+y),(hx+1,21+y)], cream)
            a.rect((hx+7,18+y,hx+8,18+y), red)
        else:
            a.poly([(hx+2,17+y),(30,18+y),(29,20+y),(hx+1,21+y)], cream)
            eye(a,hx+1,15+y)
            a.rect((29,18+y,30,18+y), red)
        a.poly([(hx-3,12+y),(hx,15+y),(hx+2,12+y)], orange)
        a.oval((16,22+y,19,25+y), '#ffca48')
    else:
        a.line([(hx-3,12+y),(hx-1,15+y),(hx-2,17+y)], red, 2)
        a.line([(hx+2,12+y),(hx+3,15+y)], red, 2)
        if view == 'ne':
            a.poly([(hx+5,16+y),(hx+8,19+y),(hx+3,21+y)], orange)
    flame(a,hx-1,5+y,small=True)
    if view == 'n':
        # Central tail overlays the back, rather than resembling a frontal bib.
        flame(a,16,14+y)
    else:
        a.line([(11,22),(13,23),(12,24)], red, 2)
    return a.image


def snake(view, breath):
    a = PixelArt()
    blue, light, dark = '#369dd7', '#d9f1f4', '#2163a1'
    white, shade, gray = '#ffffff', '#dce5ec', '#9bafbf'
    y = breath

    def tank(rear=False):
        # Fixed porcelain cistern; rear views put it in front of the snake.
        if view in ('s', 'n'):
            a.poly([(9,12),(23,12),(22,25),(10,25)], shade)
            a.rect((11,14,20,23), white if not rear else '#edf2f6')
            a.poly([(8,11),(24,11),(24,13),(8,13)], white)
            if rear:
                a.line([(12,15),(12,22)], white)
        else:
            x = 5 if view in ('e', 'se') else 16
            a.poly([(x,12),(x+8,11),(x+9,23),(x+1,25)], shade)
            a.poly([(x,12),(x+5,12),(x+6,23),(x+1,24)], white)
            a.poly([(x-1,11),(x+7,10),(x+9,11),(x+9,13),(x,14)], white)
            a.line([(x+6,14),(x+7,21)], gray)
        if not rear:
            a.rect((10 if view == 's' else 7,15,
                    12 if view == 's' else 8,15), gray)

    # The toilet foot alone reaches y=29 in every view and frame.
    if view in ('s', 'n'):
        a.poly([(11,23),(21,23),(20,27),(22,29),(10,29),(12,27)], shade)
        a.rect((13,25,18,28), white)
        bowl = (6,18,26,24)
    elif view == 'e':
        a.poly([(9,22),(23,22),(20,26),(21,29),(9,29),(10,26)], shade)
        a.poly([(11,24),(18,25),(17,28),(11,28)], white)
        bowl = (9,18,28,23)
    else:
        a.poly([(10,22),(24,22),(21,26),(23,29),(10,29),(12,26)], shade)
        a.poly([(13,25),(19,25),(19,28),(12,28)], white)
        bowl = (7,18,27,24) if view == 'se' else (5,18,25,24)
    if view in ('s', 'se', 'e'):
        tank()
    left, top, right, bottom = bowl
    a.poly([(left,21),(right,21),(right-3,25),(right-6,27),
            (left+5,26),(left+2,24)], shade)
    a.line([(left+3,23),(left+6,25),(right-6,25)], white, 2)
    a.oval(bowl, white)
    a.oval((left+2,top+1,right-2,bottom-2), dark)
    a.line([(left+4,top+2),(right-4,top+2)], '#87def4')

    # Neck remains inside the opening; only the head and upper neck breathe.
    cx = {'s':16, 'se':18, 'e':20, 'ne':13, 'n':16}[view]
    a.poly([(cx-5,21),(cx-4,14+y),(cx-6,10+y),
            (cx+3,9+y),(cx+5,15+y),(cx+3,21)], blue)
    if view in ('s', 'se', 'e'):
        a.poly([(cx,13+y),(cx+3,14+y),(cx+3,20),(cx-1,21),
                (cx-2,18+y)], light)
        for yy in (17,19):
            a.line([(cx,yy),(cx+2,yy)], '#91bccd')
    ridge = cx-4 if view in ('e','se','ne') else cx
    for yy in (8,12,16):
        a.poly([(ridge,yy-2+y),(ridge-3,yy+y),(ridge,yy+2+y)], dark)

    if view == 's':
        a.oval((9,6+y,23,16+y), blue)
        a.oval((11,11+y,21,18+y), INK)
        a.oval((13,14+y,19,17+y), '#c96577')
        for x in (11,19):
            a.rect((x,8+y,x+2,10+y), white)
            a.rect((x+1,9+y,x+1,10+y), INK)
        for x in (12,18):
            a.poly([(x,12+y),(x+2,12+y),(x+1,14+y)], white)
        a.line([(13,18+y),(19,18+y)], light)
        a.rect((14,10+y,14,10+y), dark)
        a.rect((18,10+y,18,10+y), dark)
    elif view in ('se', 'e'):
        hx = 14 if view == 'se' else 16
        a.poly([(hx,8+y),(hx+4,6+y),(hx+9,8+y),(hx+12,11+y),
                (hx+11,13+y),(hx+5,12+y),(hx+6,15+y),
                (hx+10,15+y),(hx+7,19+y),(hx+2,17+y)], blue)
        a.poly([(hx+4,12+y),(hx+11,12+y),(hx+8,17+y),
                (hx+4,17+y)], INK)
        a.line([(hx+5,16+y),(hx+7,16+y)], '#c96577')
        a.line([(hx+3,17+y),(hx+6,19+y),(hx+9,17+y)], light)
        a.rect((hx+4,8+y,hx+6,10+y), white)
        a.rect((hx+6,9+y,hx+6,10+y), INK)
        if view == 'se':
            a.rect((hx+10,10+y,hx+10,11+y), white)
        for x in (hx+5,hx+9):
            a.line([(x,12+y),(x,13+y)], white)
    else:
        # No eyes, mouth, or pale facial markings on either rear projection.
        a.oval((cx-6,6+y,cx+5,16+y), blue)
        a.line([(cx+3,9+y),(cx+4,13+y)], '#68c4e4', 2)
        for yy in (7,11,15):
            a.poly([(ridge,yy+y),(ridge+2,yy+2+y),
                    (ridge,yy+4+y),(ridge-1,yy+2+y)], dark)

    # Foreground lip hides the neck's lower edge, without moving the porcelain.
    a.line([(left+2,22),(left+5,23),(right-5,23),(right-2,22)], INK)
    a.line([(left+3,21),(left+6,22),(right-6,22),(right-3,21)], white)
    if view in ('n', 'ne'):
        tank(rear=True)

    # Pale blue splashes stay above the foot and outside the fixed toilet.
    for x, yy, sign in ((3,22,1),(29,24,-1),(4,16,-1),(28,17,1)):
        sy = yy + y * sign
        a.line([(x,sy),(x+sign,sy+1)], '#72ccef')
        a.rect((x,sy,x,sy), '#c7f4ff')
    a.line([(3,27),(5,26),(7,27)], '#9ce8fa')
    a.line([(25,27),(27,26-y),(29,27)], '#9ce8fa')
    return a.image


def render(pet, direction, frame):
    # Frames 1/3 are the same middle pose; 0 -> 1 -> 2 -> 3 -> 0 is smooth.
    breath = (1, 0, -1, 0)[frame]
    canonical = {'sw':'se','w':'e','nw':'ne'}.get(direction,direction)
    sprite = {'eggshell_dragon':dragon,'flame_cat':cat,'diving_snake':snake}[pet](canonical,breath)
    if direction in ('sw','w','nw'):
        sprite = sprite.transpose(Image.Transpose.FLIP_LEFT_RIGHT)
    return sprite.resize((64,64),Image.Resampling.NEAREST)


def contact_sheet():
    """Optional review image lives in tools, never in game asset directories."""
    sheet = Image.new('RGB',(8*100,12*88+24),'#28303e')
    d = ImageDraw.Draw(sheet)
    for col,direction in enumerate(DIRECTIONS):
        d.text((col*100+40,6),direction,fill='white')
    for p,pet in enumerate(PETS):
        for frame in range(4):
            row = p*4+frame
            for col,direction in enumerate(DIRECTIONS):
                x,y = col*100,24+row*88
                d.rectangle((x,y,x+99,y+87),fill=('#374152' if p%2==0 else '#455044'))
                d.line((x,y+61,x+99,y+61),fill='#798393')
                sprite = render(pet,direction,frame)
                sheet.paste(sprite,(x+18,y+2),sprite)
                d.text((x+2,y+68),f'{pet.split("_")[-1]} {frame}',fill='white')
    dest = ROOT/'tools'/'placeholder_contact_sheet.png'
    sheet.save(dest)
    print(dest)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--contact-sheet',action='store_true',help='Also create a labeled review sheet in tools/')
    args = parser.parse_args()
    count = 0
    for pet in PETS:
        folder = ROOT/'assets'/'pets'/pet
        folder.mkdir(parents=True,exist_ok=True)
        for direction in DIRECTIONS:
            for frame in range(4):
                render(pet,direction,frame).save(folder/f'idle_{direction}_{frame}.png')
                count += 1
    print(f'Generated {count} sprites (64x64 RGBA) in {ROOT / "assets" / "pets"}')
    if args.contact_sheet:
        contact_sheet()


if __name__ == '__main__':
    main()
