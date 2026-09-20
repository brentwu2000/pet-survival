"""Deterministic final-form monster idle placeholders; Python 3.10+ and Pillow."""

import argparse
import hashlib
from io import BytesIO
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
DIRECTIONS = ('s', 'se', 'e', 'ne', 'n', 'nw', 'w', 'sw')
PETS = ('container_beast', 'earth_armor_dragon', 'storm_bat',
        'mech_kid', 'island_tentacle')
MIRRORS = {'sw': 'se', 'w': 'e', 'nw': 'ne'}
INK = '#24333d'


class Art:
    def __init__(self):
        self.image = Image.new('RGBA', (32, 32))
        self.draw = ImageDraw.Draw(self.image)

    def poly(self, points, color):
        self.draw.polygon(points, fill=color, outline=INK)

    def oval(self, box, color):
        self.draw.ellipse(box, fill=color, outline=INK)

    def box(self, box, color, outline=False):
        self.draw.rectangle(box, fill=color, outline=INK if outline else None)

    def line(self, points, color=INK, width=1):
        self.draw.line(points, fill=color, width=width)


def eye(a, x, y, color='#f5c347'):
    a.box((x, y, x+2, y+2), color)
    a.box((x+1, y, x+1, y+2), INK)
    a.box((x, y, x, y), '#ffffff')


def container(view, b):
    a = Art()
    white, shade, blue = '#edfaff', '#9acbdf', '#258bd4'
    rear = view in ('n', 'ne')
    # The coil and jar foot are fixed. The dorsal crown stays at y=3 while
    # the head/neck compress underneath it, preserving the content height.
    a.oval((7, 24, 25, 29), shade)
    a.oval((7, 13, 24, 28), '#207cbe')
    a.oval((9, 15, 22, 26), '#29b6e8')
    a.poly([(10,19),(14,18),(18,20),(22,18),(22,23),(18,26),(12,25)], '#168fde')
    a.line([(10,20),(14,19),(18,21),(21,20)], '#8cecff')
    for x, y in ((12,22),(19,23),(17,17)):
        a.oval((x,y,x+2,y+2), '#83e6ff')
        a.box((x,y,x,y), white)
    a.line([(10,16),(9,19)], white, 2)
    if not rear:
        a.oval((8,12,23,16), shade)
        a.oval((10,13,21,15), '#174e77')
        a.line([(11,15),(20,15)], '#59d6f4')
    spine = 17 if view == 'n' else (11 if view == 'ne' else 24)
    for y in (10,15,20,24):
        a.poly([(spine-1,y-2),(spine+5,y),(spine,y+4)], blue)
        a.line([(spine+1,y),(spine+3,y)], '#a5e9ff')
    if rear:
        a.poly([(14,7+b),(20,8+b),(23,16),(21,24),(17,28),
                (12,27),(16,22),(17,15)], white)
        a.line([(18,11+b),(20,17),(18,24)], shade, 2)
        a.poly([(15,10+b),(16,3),(19,8+b),(20,23),(17,27),(15,22)], blue)
        a.line([(17,7),(18,20),(17,24)], '#b9f5ff')
        a.oval((11 if view == 'ne' else 13,6+b,20,12+b), shade)
        a.poly([(15,9+b),(16,3),(19,8+b)], blue)
    else:
        a.poly([(19,8+b),(25,11+b),(27,18),(25,24),(20,28),
                (10,29),(6,27),(16,25),(20,21),(21,16),(17,12+b)], white)
        a.line([(23,13+b),(24,19),(21,24),(12,27)], shade, 2)
        hx = {'s':14, 'se':19, 'e':23}[view]
        a.poly([(hx-5,8+b),(hx-2,3),(hx+1,7+b)], blue)
        if view == 's':
            a.poly([(9,8+b),(14,6+b),(20,8+b),(21,12+b),
                    (17,15+b),(11,14+b),(8,12+b)], white)
            eye(a,10,9+b,'#4cbdec')
            eye(a,17,9+b,'#4cbdec')
            a.line([(12,13+b),(17,13+b)])
        else:
            a.poly([(hx-7,8+b),(hx-2,6+b),(hx+3,9+b),(hx+6,12+b),
                    (hx+3,14+b),(hx-3,13+b),(hx-6,15+b)], white)
            eye(a,hx,9+b,'#4cbdec')
            a.line([(hx+2,13+b),(hx+5,12+b)])
    return a.image


def plate(a, x, y, height, color):
    a.poly([(x-3,y),(x-1,y-height),(x+2,y-2),(x+1,y+3)], color)
    a.line([(x-1,y-height+2),(x-1,y)], '#e5af69')


def dragon(view, b):
    a = Art()
    sand, pale, dark = '#b18c5f', '#e2c99a', '#79573c'
    rear = view in ('n','ne')
    side = view == 'e'
    # Low four-legged silhouette; tail projects opposite the head.
    tail = ([(19,22),(30,20),(27,25),(19,27)] if rear else
            [(12,23),(2,20),(5,26),(15,27)])
    a.poly(tail, sand)
    for x in ((8,20) if view in ('s','n') else (7,21)):
        a.oval((x-2,23,x+4,29), dark)
        a.line([(x-1,28),(x+2,28)], pale)
    a.oval((4,12+b,27,26), sand)
    a.oval((7,16+b,25,25), '#c9a370')
    # Two overlapping rows; the highest rock is anchored, not a moving bbox.
    rows = ((9,7),(15,10),(22,7)) if view in ('s','n') else ((7,6),(13,10),(20,7))
    for x,h in rows:
        plate(a,x,14+b,h,'#be542d')
    a.poly([(12,13+b),(15,3),(19,12+b),(17,18+b)], '#db6a30')
    a.line([(15,5),(15,13+b)], '#ffaf4e')
    for x in (7,13,20,25):
        plate(a,x,19+b,7 if x in (13,20) else 4,'#95623b')
    for x,y in ((7,22),(20,21),(24,23)):
        a.poly([(x-2,y),(x,y-2),(x+2,y),(x+1,y+2)], '#e7bf79')
    for x in ((7,21) if view in ('s','n') else (9,22)):
        a.oval((x-2,23,x+4,29), sand)
        for dx in (0,2):
            a.poly([(x+dx-1,29),(x+dx,27),(x+dx+1,29)], '#f5edd7')
    if rear:
        a.oval((11,20+b,21,27), dark)
        a.poly([(13,23),(18,24),(22,28),(16,27)], sand)
        plate(a,16,22+b,4,'#aa6f3d')
    else:
        hx = 15 if view == 's' else (23 if side else 20)
        a.poly([(hx-6,17+b),(hx-3,14+b),(hx+3,16+b),(hx+6,21+b),
                (hx+4,25+b),(hx-3,25+b),(hx-6,22+b)], pale)
        for dx in (-5,4):
            a.poly([(hx+dx,18+b),(hx+dx-1,13+b),(hx+dx+3,16+b)], '#f2e7ce')
        if view == 's':
            eye(a,hx-4,19+b,'#e98d37')
            eye(a,hx+2,19+b,'#e98d37')
            a.line([(hx-3,23+b),(hx+3,23+b)])
        else:
            eye(a,hx+1,18+b,'#e98d37')
            a.line([(hx+2,23+b),(hx+6,22+b)])
        a.poly([(hx+2,23+b),(hx+4,23+b),(hx+3,26+b)], '#ffffff')
    return a.image


def bat(view, b):
    a = Art()
    body, lit = '#252d53', '#414777'
    rear = view in ('n','ne')
    # A narrow side projection and asymmetrical diagonal wing spans.
    spans = {'s':(2,29),'se':(5,29),'e':(10,27),'ne':(3,26),'n':(2,29)}
    left,right = spans[view]
    for tip,root,sign in ((left,13,1),(right,19,-1)):
        a.poly([(root,16+b),(tip+sign*3,7+b),(tip,11+b),
                (tip,20+b),(tip+sign*3,18+b),(tip+sign*5,22+b),
                (tip+sign*8,21+b),(root,24+b)], '#61367e')
        a.poly([(root,18+b),(tip+sign*3,10+b),(tip+sign,18+b),
                (tip+sign*3,17+b),(tip+sign*5,20+b),(root,23+b)], '#a94a96')
        a.line([(tip+sign,18+b),(tip+sign*3,17+b),(tip+sign*5,20+b)], '#e78a9f')
        a.line([(root,18+b),(tip+sign*3,8+b),(tip,11+b)], body, 2)
        a.line([(tip+sign*3,9+b),(tip+sign*5,20+b)], body)
    for x in (13,19):
        a.line([(x,24),(x,28),(x-1,29)], '#cc873b', 2)
        a.line([(x+1,27),(x+1,29)], '#f2b64d')
    cx = 18 if view in ('e','se') else 16
    a.oval((cx-5,14+b,cx+4,26), body)
    a.line([(cx-3,19+b),(cx-3,23)], lit, 2)
    a.poly([(cx-5,12+b),(cx-6,3),(cx-1,8+b)], body)
    a.poly([(cx+1,8+b),(cx+6,3),(cx+5,13+b)], body)
    a.line([(cx-5,6),(cx-3,10+b)], '#98549c')
    a.line([(cx+4,6),(cx+3,10+b)], '#98549c')
    a.oval((cx-6,8+b,cx+5,17+b), body)
    if not rear:
        for x in ([cx-4,cx+2] if view == 's' else [cx+1]):
            eye(a,x,11+b,'#ffe047')
        a.line([(cx,15+b),(cx+2,15+b)], '#ed85a7')
        a.poly([(cx,18+b),(cx+3,18+b),(cx+1,21+b),
                (cx+3,21+b),(cx-1,25),(cx,22+b),(cx-2,22+b)], '#ffda39')
    else:
        a.line([(cx-2,18+b),(cx,21+b),(cx,24)], lit)
    return a.image


def mech(view, b):
    a = Art()
    white, gray, dark = '#f3f0e5', '#969ea4', '#46505d'
    rear = view in ('n','ne')
    side = view == 'e'
    cx = 18 if view in ('se','e') else 16
    # Fixed soles and head crown, with compression at neck and waist.
    for x in ((12,18) if not side else (13,19)):
        a.box((x-2,23,x+3,28), dark, True)
        a.box((x-2,25,x+3,29), white, True)
        a.line([(x-1,28),(x+2,28)], '#c5c9c9')
    a.box((cx-5,13+b,cx+5,23+b), dark, True)
    a.box((cx-5,15+b,cx+3,21+b), gray, True)
    a.box((cx-4,16+b,cx-3,17+b), '#dce2df')
    if rear:
        a.box((cx-2,17+b,cx+2,20+b), dark)
        a.line([(cx-1,18+b),(cx+1,18+b)], '#67a4b5')
    for x in ((cx-4,cx+2)):
        a.box((x,20+b,x,20+b), white)
    arms = [(cx-10,'#20b9e2'),(cx+6,'#20b9e2')]
    if side:
        arms = [(cx-8,'#ce4e9a'),(cx+1,'#20b9e2')]
    for x,color in arms:
        a.oval((x,14+b,x+4,18+b), gray)
        a.box((x,18+b,x+4,26+b), color, True)
        a.line([(x+1,19+b),(x+1,23+b)], '#96e9f3' if color=='#20b9e2' else '#f18bc6')
        a.box((x+2,25+b,x+3,26+b), dark)
    if not side:
        for x in (cx-6,cx+4):
            a.box((x,20+b,x+2,26+b), '#d45ba7', True)
    a.box((cx-5,12+b,cx+5,14+b), '#efb82e', True)
    a.line([(cx-3,13+b),(cx+2,13+b)], '#ffe885')
    a.box((cx-6,3,cx+5,11+b), dark, True)
    a.box((cx-5,4,cx+4,10+b), white)
    if view in ('se','ne','e'):
        # Expose a side plane rather than translating the frontal face.
        edge = cx-1 if side else cx-3
        a.poly([(cx-6,4),(edge,3),(edge,11+b),(cx-6,10+b)], '#bac3c6')
        a.line([(edge,5),(edge,9+b)], '#e0e6e5')
    a.line([(cx-4,5),(cx+2,5)], '#ffffff')
    for x in ((cx-7,cx+5) if not side else (cx-5,)):
        a.oval((x,6,x+2,10+b), dark)
        a.line([(x+1,7),(x+1,9+b)], gray)
    if not rear:
        for x in ([cx-3,cx+2] if view == 's' else ([cx,cx+3] if view == 'se' else [cx+3])):
            a.box((x,7,x,8+b), INK)
        a.line([(cx-1 if not side else cx+2,10+b),(cx+2,10+b)])
    else:
        a.box((cx-2,7,cx+2,9+b), '#cbd0cf')
    return a.image


def rock(a, x, y, color='#a88a5d'):
    a.poly([(x,y-2),(x+2,y),(x+1,y+3),(x-1,y+2),(x-2,y)], color)
    a.line([(x,y-1),(x,y+1)], '#d4b889')


def island(view, b):
    a = Art()
    rear = view in ('n','ne')
    # Stationary lower fragments give a shared baseline without a 2D shadow.
    rock(a,12,26)
    rock(a,23,25,'#806e57')
    rock(a,4,22)
    rock(a,28,19)
    a.poly([(5,19),(26,19),(23,24),(16,28),(9,24)], '#826749')
    a.poly([(7,20),(15,21),(16,27),(11,24)], '#c0a075')
    a.poly([(16,21),(24,20),(21,24),(17,27)], '#655747')
    a.line([(9,21),(11,23),(10,24)], '#efd29b')
    # Three necks with different overlap/projection, all visibly rooted in turf.
    heads = {
        's': [(8,10,10),(24,9,21),(16,3,16)],
        'se':[(10,10,10),(22,8,21),(18,3,16)],
        'e': [(13,10,10),(25,8,21),(21,3,16)],
        'ne':[(22,10,21),(9,8,10),(15,3,16)],
        'n': [(24,10,21),(8,9,10),(16,3,16)],
    }[view]
    for hx,top,root in heads:
        a.poly([(root-2,20),(root-3,14+b),(hx-3,top+4),
                (hx-3,top+1),(hx,top),(hx+3,top+2),
                (hx+3,top+5),(root+2,15+b),(root+2,20)], '#c29b6c')
        a.line([(hx-1,top+4),(root,14+b),(root,18)], '#e4c598', 2)
        for x,y in ((hx+1,top+3),(root+1,13+b),(root-1,17)):
            a.box((x,y,x+1,y+1), '#8d6745')
        if not rear:
            ex = hx if view == 's' else hx+1
            eye(a,ex,top+2,'#f4b451')
            a.line([(hx-2,top+5),(hx+1,top+6)])
        else:
            a.line([(hx-1,top+1),(hx+1,top+2)], '#efd0a0')
    # Angled turf edge makes the diagonals distinct from front and back.
    y = 18+b
    a.poly([(4,y+1),(7,y-1),(10,y),(12,y-2),(16,y-1),
            (20,y-2 if view in ('e','ne') else y-1),(25,y),
            (27,y+2),(24,y+2),(23,y+4),(20,y+3),(17,y+4),
            (14,y+3),(11,y+4),(9,y+2),(5,y+3)], '#6e963b')
    a.line([(6,y+1),(10,y+1),(12,y),(16,y+1),(21,y),(24,y+1)], '#b3cf55', 2)
    return a.image


DRAW = dict(zip(PETS, (container, dragon, bat, mech, island)))


def render(pet, direction, frame):
    sprite = DRAW[pet](MIRRORS.get(direction, direction), (1,0,-1,0)[frame])
    if direction in MIRRORS:
        sprite = sprite.transpose(Image.Transpose.FLIP_LEFT_RIGHT)
    return sprite.resize((64,64), Image.Resampling.NEAREST)


def png_bytes(sprite):
    stream = BytesIO()
    sprite.save(stream, format='PNG')
    return stream.getvalue()


def generate():
    return {(pet,direction,frame): render(pet,direction,frame)
            for pet in PETS for direction in DIRECTIONS for frame in range(4)}


def validate(sprites):
    if len(sprites) != 160:
        raise ValueError('Expected 160 sprites')
    for pet in PETS:
        heights = set()
        for direction in DIRECTIONS:
            poses = [sprites[pet,direction,f] for f in range(4)]
            for frame,sprite in enumerate(poses):
                tag = f'{pet}/{direction}/{frame}'
                if sprite.mode != 'RGBA' or sprite.size != (64,64):
                    raise ValueError(f'{tag}: invalid format')
                alpha = sprite.getchannel('A')
                if set(alpha.tobytes()) != {0,255}:
                    raise ValueError(f'{tag}: invalid alpha')
                box = alpha.getbbox()
                if box is None or box[3] != 60:
                    raise ValueError(f'{tag}: baseline {box}, expected y=59')
                heights.add(box[3]-box[1])
                if direction in MIRRORS:
                    mirror = sprites[pet,MIRRORS[direction],frame].transpose(Image.Transpose.FLIP_LEFT_RIGHT)
                    if sprite.tobytes() != mirror.tobytes():
                        raise ValueError(f'{tag}: mirror mismatch')
                if sprite.crop((0,56,64,64)).tobytes() != poses[0].crop((0,56,64,64)).tobytes():
                    raise ValueError(f'{tag}: moving ground contact')
            if poses[1].tobytes() != poses[3].tobytes():
                raise ValueError(f'{pet}/{direction}: middle poses differ')
            if len({p.tobytes() for p in poses}) != 3:
                raise ValueError(f'{pet}/{direction}: missing breathing poses')
        if len(heights) != 1:
            raise ValueError(f'{pet}: inconsistent bbox heights {heights}')


def contact_sheet(sprites):
    sheet = Image.new('RGB', (8*100, len(PETS)*4*88+24), '#28303e')
    d = ImageDraw.Draw(sheet)
    labels = ('Container','Armor dragon','Storm bat','Mech kid','Island')
    for col,direction in enumerate(DIRECTIONS):
        d.text((col*100+40,6),direction,fill='white')
    for p,pet in enumerate(PETS):
        for frame in range(4):
            for col,direction in enumerate(DIRECTIONS):
                x,y = col*100,24+(p*4+frame)*88
                d.rectangle((x,y,x+99,y+87),fill=('#374152' if p%2==0 else '#455044'))
                d.line((x,y+61,x+99,y+61),fill='#798393')
                sprite = sprites[pet,direction,frame]
                sheet.paste(sprite,(x+18,y+2),sprite)
                d.text((x+2,y+68),f'{labels[p]} {frame}',fill='white')
    return sheet


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--contact-sheet',action='store_true',help='Also write tools/monster_contact_sheet.png')
    args = parser.parse_args()
    first = generate()
    validate(first)
    second = generate()
    validate(second)
    for key,sprite in first.items():
        pet,direction,frame = key
        data = png_bytes(sprite)
        if hashlib.sha256(data).digest() != hashlib.sha256(png_bytes(second[key])).digest():
            raise ValueError(f'{key}: nondeterministic PNG')
        dest = ROOT/'assets'/'pets'/pet/f'idle_{direction}_{frame}.png'
        dest.parent.mkdir(parents=True,exist_ok=True)
        dest.write_bytes(data)
        if dest.read_bytes() != data:
            raise ValueError(f'{dest}: disk verification failed')
        with Image.open(dest) as saved:
            if saved.mode != 'RGBA' or saved.size != (64,64) or saved.tobytes() != sprite.tobytes():
                raise ValueError(f'{dest}: decoded PNG mismatch')
    if args.contact_sheet:
        data = png_bytes(contact_sheet(first))
        if data != png_bytes(contact_sheet(second)):
            raise ValueError('Nondeterministic contact sheet')
        dest = ROOT/'tools'/'monster_contact_sheet.png'
        dest.write_bytes(data)
        print(dest)
    print('Generated and verified 160 PNGs: RGBA, 64x64, binary alpha, y=59,')
    print('constant per-pet height, fixed feet, mirrors, breathing, repeat SHA-256, disk decode.')


if __name__ == '__main__':
    main()
