"""Deterministic Pillow-only yellow brick robot; Python 3.10+.

Draw parts on a 32px grid, enlarge NEAREST, then translate the torso by
integer output pixels for breathing. No resampling, randomness or downloads.
"""
from pathlib import Path
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'assets/player/yellow_robot'
DIRS = ('s', 'se', 'e', 'ne', 'n', 'nw', 'w', 'sw')
INK = '#433c32'
YELLOW, LIGHT, SHADE = '#ffc619', '#ffe775', '#d88c09'
GRAY, SILVER = '#85877c', '#d4d3bd'


class Art:
    def __init__(self):
        self.im = Image.new('RGBA', (32, 32))
        self.d = ImageDraw.Draw(self.im)

    def box(self, b, color, outline=INK):
        self.d.rectangle(b, fill=color, outline=outline)

    def oval(self, b, color):
        self.d.ellipse(b, fill=color, outline=INK)

    def line(self, p, color=INK, width=1):
        self.d.line(p, fill=color, width=width)

    def brick(self, x, y, w, h, side=1):
        self.box((x, y, x+w-1, y+h-1), YELLOW)
        self.line([(x+1,y+1),(x+w-2,y+1)], LIGHT)
        sx = x+w-2 if side > 0 else x+1
        self.line([(sx,y+2),(sx,y+h-2)], SHADE)
        self.line([(x+1,y+h-2),(x+w-2,y+h-2)], SHADE)

    def large(self):
        return self.im.resize((64,64), Image.Resampling.NEAREST)


def arm(a, shoulder, hand, side):
    x,y = shoulder
    hx,hy = hand
    elbow = ((x+hx)//2 + side, (y+hy)//2)
    a.line([shoulder, elbow, hand], INK, 3)
    a.line([shoulder, elbow, hand], SILVER)
    for cx,cy in (shoulder, elbow):
        a.oval((cx-1,cy-1,cx+1,cy+1), GRAY)
        a.box((cx,cy,cx,cy), SILVER, SILVER)
    a.brick(hx-3,hy,6,6,side)


def round_eye(a, x, y):
    a.oval((x-3,y-3,x+3,y+3), GRAY)
    a.oval((x-3,y-3,x+2,y+2), '#d8dedc')
    a.oval((x-1,y-1,x+1,y+1), '#303942')
    a.box((x-1,y-2,x-1,y-2), '#ffffff', '#ffffff')


def blue_eye(a, x, y, facing):
    # The blue beam is a physical lateral attachment, never a mirrored gray eye.
    end = x + facing*6
    a.box((min(x,end),y-2,max(x,end),y+2), '#1499b7')
    a.line([(min(x,end)+1,y-1),(max(x,end)-1,y-1)], '#62d5e2')
    a.oval((end-1,y-1,end+1,y+1), '#40bed1')
    a.oval((x-3,y-3,x+3,y+3), '#285b9f')
    a.oval((x-2,y-2,x+2,y+2), '#7354a0')
    a.oval((x-1,y-1,x+1,y+1), '#443471')


def sprite(direction, action, frame):
    side = 1 if direction in ('se','e','ne') else -1
    straight = direction in ('s','n')
    profile = direction in ('e','w')
    rear = direction in ('n','ne','nw')
    stride = (1,0,-1,0)[frame] if action == 'walk' else 0
    swing = (1,2,-1,-2)[frame] if action == 'walk' else (0,1,0,-1)[frame]
    bob = (0,1,0,1)[frame] if action == 'idle' else (0,-2,0,-2)[frame]
    feet, body, head = Art(), Art(), Art()
    # Feet retain the common bottom anchor. Passing poses lift alternating feet.
    xs = [11,18] if straight else [12,18]
    for i,x in enumerate(xs):
        sign = 1 if i == 0 else -1
        dx = stride*sign*(2 if not straight else 1)
        lift = 2 if action == 'walk' and frame in (1,3) and i == (frame//2) else 0
        feet.brick(x+dx,24-lift,4,6,side)
        if action == 'walk':
            feet.line([(x+dx+1,27-lift),(x+dx+2,27-lift)], LIGHT)
    body.box((14,15,19,18), '#5c5544')
    body.line([(15,16),(18,16)], SILVER)
    shoulder_x = (9,23) if straight else (11,22)
    # Profile arm depth is encoded by different heights and widths of the stance.
    for i,x in enumerate(shoulder_x):
        sign = -1 if i == 0 else 1
        hx = x + sign*3 + (swing if i == 0 else -swing)
        hy = 23 + (swing if i == 0 else -swing)
        hy = min(hy,23)
        arm(body,(x,18),(max(3,min(28,hx)),hy),sign)
    bx = 10 if straight else 12
    bw = 12 if straight else 10
    body.brick(bx,17,bw,9,side)
    body.line([(bx+1,22),(bx+bw-2,22)], SHADE)
    if rear:
        body.box((bx+3,19,bx+bw-4,21), SHADE)
    else:
        body.line([(bx+2,18),(bx+bw-3,18)], LIGHT)
    # Tall, squat brick head with actual studs; top is always source y=1.
    hx = 8 if straight else (11 if side > 0 else 8)
    hw = 15 if straight else 13
    for x in range(hx+2,hx+hw-2,4):
        head.box((x,1,x+2,3), SHADE)
        head.line([(x,1),(x+2,1)], LIGHT)
    head.brick(hx,3,hw,13,side)
    edge = hx+hw-4 if side > 0 else hx+3
    if not straight:
        head.line([(edge,4),(edge,14)], SHADE)
        head.line([(edge+side,5),(edge+side,13)], LIGHT)
    if direction == 's':
        head.box((11,14,20,16), '#2d3030')
        round_eye(head,10,9)
        blue_eye(head,21,9,1)
    elif direction in ('se','sw'):
        front = hx+hw-5 if side > 0 else hx+4
        head.box((front-3,14,front+3,16), '#2d3030')
        if side > 0:
            blue_eye(head,24,8,1)
            round_eye(head,17,10)
        else:
            round_eye(head,8,8)
            blue_eye(head,15,10,-1)
    elif profile:
        if side > 0:
            round_eye(head,22,10)
            head.box((22,14,24,15), '#2d3030')
        else:
            blue_eye(head,10,10,-1)
            head.box((7,14,9,15), '#2d3030')
    elif direction == 'ne':
        # Only the side-mounted gray cylinder rim peeks beyond the rear corner.
        head.oval((22,8,24,12), GRAY)
    elif direction == 'nw':
        head.box((4,8,9,11), '#1499b7')
        head.line([(5,9),(8,9)], '#62d5e2')
    result = feet.large()
    result.alpha_composite(body.large(), (0,bob))
    result.alpha_composite(head.large())
    return result


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    sheet = Image.new('RGB',(8*96+72,2*4*88+30),'#858585')
    labels = ImageDraw.Draw(sheet)
    for col,direction in enumerate(DIRS):
        labels.text((72+col*96+36,10),direction,fill='white')
    for ai,action in enumerate(('idle','walk')):
        for frame in range(4):
            row = ai*4+frame
            labels.text((5,30+row*88+28),f'{action} {frame}',fill='white')
            for col,direction in enumerate(DIRS):
                im = sprite(direction,action,frame)
                bbox = im.getbbox()
                assert im.mode == 'RGBA' and im.size == (64,64)
                assert bbox[3] == 60 and bbox[3]-bbox[1] == 58, (direction,action,frame,bbox)
                assert set(im.getchannel('A').tobytes()) == {0,255}
                im.save(OUT / f'{action}_{direction}_{frame}.png')
                sheet.paste(im,(72+col*96+16,30+row*88+8),im)
    sheet.save(ROOT / 'tools/player_contact_sheet.png')
    print('Generated and validated 64 sprites (58px tall, bottom y=59) and contact sheet.')


if __name__ == '__main__':
    main()
