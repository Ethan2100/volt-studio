from PIL import Image
import math, random
OUT = (24, 16, 36, 255)
def hexc(h):
    h = h.lstrip('#')
    return tuple(int(h[i:i+2], 16) for i in (0, 2, 4)) + (255,)
class C:
    def __init__(s, w, h):
        s.w, s.h = w, h
        s.im = Image.new('RGBA', (w, h), (0, 0, 0, 0))
        s.p = s.im.load()
    def px(s, x, y, c):
        x = int(x); y = int(y)
        if c and 0 <= x < s.w and 0 <= y < s.h:
            s.p[x, y] = hexc(c) if isinstance(c, str) else c
    def get(s, x, y):
        if 0 <= x < s.w and 0 <= y < s.h: return s.p[x, y]
        return (0, 0, 0, 0)
    def rect(s, x0, y0, x1, y1, c):
        for y in range(int(y0), int(y1) + 1):
            for x in range(int(x0), int(x1) + 1):
                s.px(x, y, c)
    def ell(s, cx, cy, rx, ry, c, keep=None):
        for y in range(int(cy - ry - 1), int(cy + ry + 2)):
            for x in range(int(cx - rx - 1), int(cx + rx + 2)):
                if ((x + .5 - cx) / rx) ** 2 + ((y + .5 - cy) / ry) ** 2 <= 1:
                    if keep is None or keep(x, y):
                        s.px(x, y, c)
    def line(s, x0, y0, x1, y1, c, t=1):
        n = int(max(abs(x1 - x0), abs(y1 - y0))) + 1
        for i in range(n + 1):
            x = x0 + (x1 - x0) * i / max(n, 1)
            y = y0 + (y1 - y0) * i / max(n, 1)
            for dx in range(t):
                for dy in range(t):
                    s.px(round(x) + dx, round(y) + dy, c)
    def tri(s, x0, y0, x1, y1, x2, y2, c):
        def sign(ax, ay, bx, by, cx, cy): return (ax - cx) * (by - cy) - (bx - cx) * (ay - cy)
        for y in range(s.h):
            for x in range(s.w):
                px_, py_ = x + .5, y + .5
                d1 = sign(px_, py_, x0, y0, x1, y1); d2 = sign(px_, py_, x1, y1, x2, y2); d3 = sign(px_, py_, x2, y2, x0, y0)
                neg = d1 < 0 or d2 < 0 or d3 < 0; pos = d1 > 0 or d2 > 0 or d3 > 0
                if not (neg and pos): s.px(x, y, c)
    def outline(s, col=OUT):
        add = []
        for y in range(s.h):
            for x in range(s.w):
                if s.p[x, y][3] == 0:
                    for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                        if s.get(x + dx, y + dy)[3] > 0:
                            add.append((x, y)); break
        for x, y in add: s.p[x, y] = col
        return s
def strip(frames):
    w = sum(f.w for f in frames); h = frames[0].h
    im = Image.new('RGBA', (w, h), (0, 0, 0, 0)); x = 0
    for f in frames:
        im.paste(f.im, (x, 0)); x += f.w
    return im
