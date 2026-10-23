# makes the two opening pictures of one scene: Gandalf on the Bridge of Khazad-dum, seen from behind him, the bridge
# running away from us to the Balrog, winged and crowned with fire, whose whip curls across the whole hall...
#   python tools/make-splash.py <out dir> [<preview dir>]
# writes <out dir>/splash.scr, a ZX Spectrum 48K screen (6912 bytes: the bitmap in the Spectrum's interleaved order,
# then the 768 attributes), and <out dir>/splash-l2.bin, the same scene for the Next's Layer 2 at 320 x 256 in 256
# colours (81920 bytes, a column at a time, as that mode keeps it: +1 is the pixel below, +256 the next column)...
# ...and, given a preview dir, splash-48k.png and splash-next.png there, three times the size, to look at on the PC
#
# the scene is drawn once, in full colour, at 320 x 256; the Spectrum's 256 x 192 is its middle, the Next's border is
# the 32 pixels round it (so the Next picture shows a little more of the hall)...
#   for the Next it is put into the 256 colours of Layer 2's own palette (RRRGGGBB) with a fine ordered dither
#   for the 48K each 8 x 8 cell gets the one ink and one paper (both bright or both not) that, dithered between them,
#   come nearest to the drawing, which is all a Spectrum attribute allows: the colour clash is hidden by laying the
#   scene out in big areas of one colour on black, and by dithering the glows, which a cell's two colours do well
# N.B: the picture is our own, only the scene is Tolkien's, from The Fellowship of the Ring
import math, struct, sys, zlib, os

W, H = 320, 256
OX, OY = 32, 32                 # where the Spectrum's screen is in the drawing
cv = [[(8.0, 6.0, 12.0)] * W for _ in range(H)]

def S(x, y):
    # a point in the Spectrum's coordinates, 0 to 255 and 0 to 191, in the drawing's
    return (x + OX, y + OY)

def mix(a, b, t):
    t = max(0.0, min(1.0, t))
    return tuple(p + (q - p) * t for p, q in zip(a, b))

def ramp(stops, t):
    # a colour from a list of (position, colour), position 0 to 1
    t = max(0.0, min(1.0, t))
    for (p0, c0), (p1, c1) in zip(stops, stops[1:]):
        if t <= p1:
            return mix(c0, c1, (t - p0) / (p1 - p0) if p1 > p0 else 0)
    return stops[-1][1]

def put(x, y, c):
    if 0 <= x < W and 0 <= y < H:
        cv[y][x] = c

def add(x, y, c, a):
    if 0 <= x < W and 0 <= y < H:
        cv[y][x] = tuple(min(255.0, p + q * a) for p, q in zip(cv[y][x], c))

def fill_poly(pts, colour):
    # colour is a colour, or a function of (x, y) giving a colour or None (leave the pixel as it is)
    ys = [p[1] for p in pts]
    n = len(pts)
    for y in range(max(0, int(min(ys))), min(H, int(max(ys)) + 1)):
        xs = []
        for i in range(n):
            (x1, y1), (x2, y2) = pts[i], pts[(i + 1) % n]
            if (y1 <= y + 0.5 < y2) or (y2 <= y + 0.5 < y1):
                xs.append(x1 + (y + 0.5 - y1) * (x2 - x1) / (y2 - y1))
        xs.sort()
        for a, b in zip(xs[0::2], xs[1::2]):
            for x in range(max(0, int(round(a))), min(W, int(round(b)))):
                c = colour(x, y) if callable(colour) else colour
                if c is not None:
                    cv[y][x] = c

def fill_ellipse(cx, cy, rx, ry, colour):
    for y in range(int(cy - ry) - 1, int(cy + ry) + 2):
        for x in range(int(cx - rx) - 1, int(cx + rx) + 2):
            if ((x + 0.5 - cx) / rx) ** 2 + ((y + 0.5 - cy) / ry) ** 2 <= 1:
                c = colour(x, y) if callable(colour) else colour
                if c is not None:
                    put(x, y, c)

def stroke(points, colour, width=1.0):
    # a thick line through the points, the colour may be a function of (x, y, t), t running 0 to 1 along it
    pts = list(points)
    total = sum(math.hypot(b[0] - a[0], b[1] - a[1]) for a, b in zip(pts, pts[1:])) or 1
    run = 0.0
    for (x0, y0), (x1, y1) in zip(pts, pts[1:]):
        seg = math.hypot(x1 - x0, y1 - y0)
        n = int(seg * 2) + 1
        for i in range(n + 1):
            f = i / n
            x, y = x0 + (x1 - x0) * f, y0 + (y1 - y0) * f
            t = (run + seg * f) / total
            w = width(t) if callable(width) else width
            r = w / 2
            for yy in range(int(y - r), int(y + r) + 1):
                for xx in range(int(x - r), int(x + r) + 1):
                    if (xx + 0.5 - x) ** 2 + (yy + 0.5 - y) ** 2 <= r * r + 0.25:
                        c = colour(xx, yy, t) if callable(colour) else colour
                        if c is not None:
                            put(xx, yy, c)
        run += seg

def glow(cx, cy, radius, colour, strength, power=2.0):
    for y in range(int(cy - radius), int(cy + radius) + 1):
        for x in range(int(cx - radius), int(cx + radius) + 1):
            d = math.hypot(x + 0.5 - cx, y + 0.5 - cy) / radius
            if d < 1:
                add(x, y, colour, strength * (1 - d) ** power)

def bezier(p0, p1, p2, steps=80):
    return [((1 - t) ** 2 * p0[0] + 2 * (1 - t) * t * p1[0] + t * t * p2[0],
             (1 - t) ** 2 * p0[1] + 2 * (1 - t) * t * p1[1] + t * t * p2[1]) for t in (i / steps for i in range(steps + 1))]

def noise(x, y):
    return (math.sin(x * 0.173 + y * 0.051) * math.sin(x * 0.067 - y * 0.29) + math.sin(x * 0.031 + y * 0.11) * 0.5) / 1.5

# --- the scene, laid out as in the picture sdo liked: the bridge running away from us to the Balrog, who stands on
# it, huge, wings spread and crowned with fire, in the middle of the hall; its whip curling up, round and down across
# the whole picture; Gandalf small at the lower right, seen from behind, Glamdring raised and his staff's light high;
# the hall's columns blue on the left, green cliffs and a far dwarf-hall on the right, fire coming up out of the abyss
P = lambda pts: [S(*p) for p in pts]
FIRE = [(0, (60, 0, 0)), (0.25, (150, 16, 4)), (0.5, (225, 60, 8)), (0.75, (255, 160, 24)), (1, (255, 245, 190))]
PINKFIRE = [(0, (60, 0, 30)), (0.3, (150, 10, 80)), (0.6, (245, 50, 180)), (0.85, (255, 170, 140)), (1, (255, 245, 190))]
WHITE_GLOW = (200, 220, 255)

def catmull(pts, steps=24):
    # a smooth curve through all the points
    out = []
    p = [pts[0]] + list(pts) + [pts[-1]]
    for i in range(1, len(p) - 2):
        p0, p1, p2, p3 = p[i - 1], p[i], p[i + 1], p[i + 2]
        for k in range(steps):
            t = k / steps
            out.append(tuple(0.5 * ((2 * p1[j]) + (-p0[j] + p2[j]) * t + (2 * p0[j] - 5 * p1[j] + 4 * p2[j] - p3[j]) * t * t
                                    + (-p0[j] + 3 * p1[j] - 3 * p2[j] + p3[j]) * t ** 3) for j in range(2)))
    out.append(pts[-1])
    return out

def tongue(bx, by, h, w, sway, palette, seed=0.0, hot=1.0):
    # one tongue of fire: wide at its foot, licking up to a point, its edges ragged, white hot at the foot and red at the tip
    left, right = [], []
    n = 24
    for k in range(n + 1):
        t = k / n
        cx = bx + sway * math.sin(t * 2.8 + seed) * t
        cy = by - h * t
        half = w * (1 - t) ** 0.9 * (1 + 0.28 * math.sin(t * 17 + seed * 3))
        left.append((cx - half, cy)); right.append((cx + half, cy))
    pts = P(left + right[::-1])
    def col(x, y):
        t = max(0.0, min(1.0, (by + OY - y) / h))
        mid = bx + OX + sway * math.sin(t * 2.8 + seed) * t
        edge = min(1.0, abs(x + 0.5 - mid) / max(1.0, w * (1 - t) ** 0.9))
        return ramp(palette, hot * (1 - 0.7 * t) * (1 - 0.45 * edge))
    fill_poly(pts, col)

# the hall: blue columns of rock on the left, a dark gap, green cliffs on the right, all fading into the abyss below
for y in range(H):
    for x in range(W):
        sx, sy = x - OX, y - OY
        n = noise(sx * 1.7, sy * 0.35)
        strand = 0.5 + 0.5 * math.sin(sx * 0.21 + 2.4 * n + 0.8 * math.sin(sy * 0.05))
        low = max(0.0, min(1.0, (sy - 60) / 140))                      # darker toward the abyss
        if sx < 150:
            c = mix((4, 4, 16), (30, 40, 170), (strand ** 2.2) * (1 - 0.75 * low))
        elif sx < 178:
            c = mix((3, 3, 10), (14, 18, 70), strand ** 3 * 0.5 * (1 - low))
        else:
            c = mix((3, 8, 6), (24, 120, 60), (strand ** 1.8) * (1 - 0.55 * low))
            if sx > 246:
                c = mix(c, (16, 26, 120), 0.6)                           # the far right, in blue shadow
        cv[y][x] = c
# a far dwarf-hall up on the right: arches in the green cliff
for ax, aw, atop in ((188, 10, 8), (202, 10, 4), (216, 10, 8), (230, 9, 14)):
    for y in range(int(atop), 54):
        for x in range(ax, ax + aw):
            r = aw / 2
            if y < atop + r and math.hypot(x + 0.5 - ax - r, y - atop - r) > r:
                continue
            put(x + OX, y + OY, (3, 12, 8) if 1 < x - ax < aw - 2 and y > atop + 2 else (40, 140, 80))
fill_poly(P([(184, 52), (246, 52), (246, 56), (184, 56)]), (40, 140, 80))
# the Balrog's glare, red, about the middle of the hall
glow(*S(98, 50), 110, (150, 26, 8), 0.5, 1.8)

# fire coming up out of the abyss on the left, pink and yellow, and the dark green cliff it climbs
fill_poly(P([(-32, 116), (12, 110), (44, 130), (70, 150), (62, 230), (-32, 230)]), lambda x, y: mix((4, 26, 18), (24, 100, 60), 0.5 + 0.5 * noise(x * 2.3, y * 1.3)))
glow(*S(16, 160), 70, (220, 30, 140), 0.45, 1.5)
for i, (bx, by, h, w, sw) in enumerate(((-14, 200, 84, 11, 12), (6, 204, 104, 13, -14), (26, 198, 76, 10, 16), (46, 202, 58, 8, -10), (-26, 166, 54, 8, 9))):
    tongue(bx, by, h, w, sw, PINKFIRE, seed=i * 1.3)
for i, (bx, by, h, w, sw) in enumerate(((14, 204, 62, 7, -8), (34, 202, 46, 6, 9))):
    tongue(bx, by, h, w, sw, FIRE, seed=i + 0.4)

# --- the bridge: a causeway of flagstones from the bottom of the picture away to the Balrog's feet, pale stones and
# dark joints, which a Spectrum shows cleanly
FAR_Y, NEAR_Y = 124, 224
def edges(sy):
    t = (sy - FAR_Y) / (NEAR_Y - FAR_Y)
    return 112 + (60 - 112) * t, 172 + (330 - 172) * t
def deck(x, y):
    sx, sy = x - OX, y - OY
    l, r = edges(sy)
    t = (sy - FAR_Y) / (NEAR_Y - FAR_Y)
    k = (max(0.0, t) ** 0.62) * 12                                       # rows of flags, nearer rows deeper
    row = int(k)
    f = (sx - l) / max(1.0, r - l) * 5 + (0.5 if row % 2 else 0)
    joint = (k - row) < 0.10 + 0.06 * (1 - t) or (f - int(f)) < 0.04 + 0.02 * (1 - t)
    lit = max(0.0, min(1.0, (sx - 110) / 110)) * 0.6 + t * 0.4         # Gandalf's light on the near flags
    stone = mix((150, 146, 152), (205, 207, 214), lit)
    stone = mix(stone, (220, 80, 30), max(0.0, 1 - t * 3.2) * 0.55)     # the far end red in the Balrog's fire
    return (14, 14, 20) if joint else stone
fill_poly(P([(112, FAR_Y), (172, FAR_Y), (330, NEAR_Y), (60, NEAR_Y)]), deck)
# its side, falling away into the abyss on the left, courses of dark blue stone
fill_poly(P([(112, FAR_Y), (60, NEAR_Y), (34, NEAR_Y), (100, FAR_Y + 6)]),
          lambda x, y: (6, 10, 40) if int((y - OY) * 0.5) % 2 else (30, 50, 150))

# --- the Balrog, standing on the far end of the bridge: a man-shape of shadow and flame, hunched, horned, winged
BODY = (60, 10, 14)
EDGE = (240, 70, 14)
def closed(pts, steps=10):
    # a smooth closed outline through the points
    c = catmull(list(pts) + [pts[0], pts[1]], steps)
    return c[steps:-steps]
def limb(pts, w0, w1, rim=True):
    # an arm or a leg: thick at the body, thinner at the end, red where the fire behind it catches its edge
    curve = P(catmull(pts, 12))
    if rim:
        stroke(curve, EDGE, lambda t: w0 + 1.6 - (w0 - w1) * t)
    stroke(curve, lambda x, y, t: mix(BODY, (120, 24, 18), 0.3 + 0.3 * math.sin((x + y) * 0.8)), lambda t: w0 - (w0 - w1) * t)

# its wings, spread wide behind it: a long arm up to the wrist, fingers fanning out from there, skin between them
# whose edge curves in from finger to finger
def wing(root, wrist, tips):
    out = [root, wrist]
    for i, tip in enumerate(tips):
        out.append(tip)
        if i + 1 < len(tips):
            nxt = tips[i + 1]
            mx, my = (tip[0] + nxt[0]) / 2, (tip[1] + nxt[1]) / 2
            out.append((mx + (wrist[0] - mx) * 0.24, my + (wrist[1] - my) * 0.24))
    out.append(root)
    edge = catmull(out, 8)
    fill_poly(P(edge), lambda x, y: mix((24, 3, 8), (96, 16, 26), max(0.0, 1 - math.hypot(x - OX - wrist[0], y - OY - wrist[1]) / 90) * (0.7 + 0.3 * noise(x * 4, y * 4))))
    stroke(P(edge[len(edge) // 8:]), lambda x, y, t: ramp(FIRE, 0.55), 1.0)                     # the edge, lit by its fire
    for tip in tips:                                                                              # the fingers, bone, curving
        mx, my = (wrist[0] + tip[0]) / 2, (wrist[1] + tip[1]) / 2
        bend = 6 if tip[0] < wrist[0] else -6
        stroke([S(*p) for p in bezier(wrist, (mx, my - bend), tip, 30)], lambda x, y, t: mix((210, 60, 16), (90, 14, 10), t), lambda t: 2.4 - 1.6 * t)
wing((84, 60), (50, 16), [(18, -4), (-8, 18), (-10, 50), (8, 78), (42, 92)])
wing((116, 60), (150, 16), [(182, -4), (208, 18), (210, 50), (192, 78), (158, 92)])

# the mane of fire, rising from behind its head and shoulders, drawn before them so that they stand in front of it
glow(*S(100, 26), 40, (255, 190, 90), 0.55, 1.7)
for i, (fx, by, h, w, sw) in enumerate(((100, 52, 50, 9, 3), (90, 54, 40, 7, -10), (110, 54, 40, 7, 10), (82, 58, 30, 6, -13), (118, 58, 30, 6, 13),
                                        (95, 50, 46, 5, -6), (105, 50, 46, 5, 6), (74, 64, 20, 5, -10), (126, 64, 20, 5, 10))):
    tongue(fx, by, h, w, sw, FIRE, seed=i * 0.9)

# legs, bent, wide apart on the bridge, clawed feet
limb([(90, 100), (80, 112), (86, 121), (78, 127)], 8, 4)
limb([(110, 100), (122, 112), (116, 121), (126, 127)], 8, 4)
for fx, d in ((78, -1), (126, 1)):
    for k in (-1, 0, 1):
        stroke(P([(fx, 127), (fx + d * 4 + k * 2, 129)]), (230, 120, 40), 1)
# the body, hunched forward, broad in the shoulders, its chest and belly ridged and lit by the fire within
TORSO = closed([(100, 56), (116, 58), (128, 64), (126, 76), (118, 88), (114, 102), (100, 105), (86, 102), (82, 88), (74, 76), (72, 64), (84, 58)])
fill_poly(P(TORSO), lambda x, y: mix(BODY, (190, 44, 22), max(0.0, 1 - abs((x - OX) - 100) / 18) * (0.75 + 0.25 * noise(x * 5, y * 5)) * 0.8))
stroke(P(TORSO), EDGE, 1.0)
# arms: its left down and out, claws spread; its right bent, the fist raised, the whip's handle in it
limb([(76, 64), (62, 80), (60, 96)], 8, 5)
for k in (-2, 0, 2):
    stroke(P([(60, 96), (58 + k * 2, 103)]), (240, 130, 40), 1)
limb([(124, 64), (140, 76), (148, 64)], 8, 5)
fill_ellipse(*S(149, 63), 4, 4, (110, 22, 14))
# the head: a long skull thrust forward, horns curling out and down beside it like a ram's
HEAD = closed([(100, 40), (108, 43), (111, 51), (107, 60), (100, 64), (93, 60), (89, 51), (92, 43)], 8)
fill_poly(P(HEAD), lambda x, y: mix(BODY, (130, 30, 20), max(0.0, 1 - abs((x - OX) - 100) / 8) * 0.6))
stroke(P(HEAD), EDGE, 1.0)
for side in (-1, 1):
    horn = P(catmull([(100 + side * 7, 45), (100 + side * 18, 37), (100 + side * 24, 46), (100 + side * 19, 56), (100 + side * 13, 52)], 12))
    stroke(horn, (230, 110, 50), lambda t: 6.0 - 4.0 * t)
    stroke(horn, (100, 50, 34), lambda t: 4.4 - 3.0 * t)
# eyes, slanting, and the open mouth, burning
for side in (-1, 1):
    fill_poly(P([(100 + side * 2, 49), (100 + side * 7, 46), (100 + side * 6, 50)]), (255, 240, 110))
    glow(*S(100 + side * 5, 48), 6, (255, 150, 20), 0.6)
fill_ellipse(*S(100, 58), 3.6, 3.0, (255, 150, 30)); glow(*S(100, 58), 10, (255, 110, 20), 0.8)
fill_ellipse(*S(100, 58), 1.6, 1.4, (255, 240, 170))
# fire at its feet, on the bridge
for i, (fx, h, sw) in enumerate(((72, 18, -4), (132, 22, 6), (142, 14, 3), (92, 10, 2), (108, 12, -2))):
    tongue(fx, 130, h, 4, sw, FIRE, seed=i * 2.1, hot=0.95)

# --- the whip: from its fist up and round over the gap, down past Gandalf and back across the bridge, away to the
# lower left, glowing; yellow at its heart, not white, so that a Spectrum shows it as fire
WHIP = P(catmull([(149, 62), (170, 28), (208, 16), (236, 40), (232, 78), (198, 104), (150, 116), (112, 140), (88, 168), (72, 196)], 30))
for i in range(0, len(WHIP), 6):
    glow(WHIP[i][0], WHIP[i][1], 10, (255, 110, 10), 0.16, 1.6)
stroke(WHIP, (200, 30, 6), lambda t: 6.5 - 3.0 * t)
stroke(WHIP, (255, 150, 20), lambda t: 4.0 - 1.8 * t)
stroke(WHIP, (255, 240, 90), lambda t: 1.9 - 0.8 * t)
for i in range(8, len(WHIP) - 20, 26):                                  # wisps of flame curling off it
    (x0, y0), (x1, y1) = WHIP[i], WHIP[i + 10]
    nx, ny = -(y1 - y0), (x1 - x0)
    d = math.hypot(nx, ny) or 1
    s = 9 if (i // 26) % 2 else -8
    stroke([(px, py) for px, py in bezier((x0, y0), (x0 + nx / d * s, y0 + ny / d * s), (x1 + nx / d * s * 1.4, y1 + ny / d * s * 1.4), 20)],
           lambda x, y, t: ramp(FIRE, 0.72 - 0.3 * t), lambda t: 2.2 - 1.8 * t)

# --- Gandalf, small at the lower right, seen from behind: grey cloak, his long white hair, Glamdring raised toward the
# Balrog in his right hand, the staff high in his left with its light
FX, FY = 212, 180                       # where he stands
glow(*S(FX, FY - 40), 46, WHITE_GLOW, 0.32, 1.7)
def cloak(x, y, t=0):
    sx, sy = x - OX, y - OY
    fold = 0.5 + 0.5 * math.sin((sx - FX) * 0.8 + (sy - FY) * 0.08)
    shade = max(0.0, min(1.0, (sy - (FY - 44)) / 50))                 # darker toward the hem
    return mix(mix((96, 98, 108), (176, 178, 188), 0.4 + 0.6 * fold), (60, 60, 70), shade * 0.5)
fill_poly(P([(FX - 7, FY - 44), (FX + 7, FY - 44), (FX + 15, FY), (FX - 15, FY)]), cloak)         # his back, the cloak to the ground
fill_poly(P([(FX - 7, FY - 44), (FX - 12, FY - 36), (FX - 9, FY - 30)]), cloak)                   # shoulders
fill_poly(P([(FX + 7, FY - 44), (FX + 12, FY - 36), (FX + 9, FY - 30)]), cloak)
fill_ellipse(*S(FX, FY - 49), 5.5, 6, (200, 200, 206))                                             # the back of his head
fill_poly(P([(FX - 5, FY - 49), (FX + 5, FY - 49), (FX + 6, FY - 30), (FX, FY - 25), (FX - 6, FY - 30)]),
          lambda x, y: mix((236, 236, 242), (170, 170, 180), 0.5 + 0.5 * math.sin((x - OX) * 2.2)))   # white hair down his back
stroke(P([(FX - 6, FY - 20), (FX + 6, FY - 20)]), (70, 70, 80), 1)                                 # his belt
# his right arm up and forward, and Glamdring, white and glittering
stroke(P([(FX - 8, FY - 40), (FX - 16, FY - 46), (FX - 20, FY - 52)]), cloak, 4)
stroke(P([(FX - 21, FY - 53), (FX - 40, FY - 82)]), (245, 250, 255), 2.0)
stroke(P([(FX - 25, FY - 50), (FX - 17, FY - 56)]), (150, 160, 200), 1.6)
glow(*S(FX - 32, FY - 70), 14, WHITE_GLOW, 0.6)
# his left arm up, the staff, and its light
stroke(P([(FX + 8, FY - 40), (FX + 14, FY - 50), (FX + 15, FY - 58)]), cloak, 4)
stroke(P([(FX + 16, FY + 2), (FX + 15, FY - 70)]), (150, 120, 80), 1.8)
glow(*S(FX + 15, FY - 72), 26, WHITE_GLOW, 1.0, 2.0)
fill_ellipse(*S(FX + 15, FY - 72), 3, 3.5, (255, 255, 255))

# the 48K's pairs of colours: black with any one, and pairs that go together in this scene, fire, stone, rock and light
PAIRS = [(0, k) for k in range(1, 16) if k != 8] + [(2, 6), (1, 7), (4, 5), (1, 3), (4, 6), (2, 3),
                                                       (10, 14), (10, 11), (11, 15), (14, 15), (9, 15), (9, 13), (13, 15), (12, 13), (12, 14), (9, 11)]

# ================================================================================================================
# the Next: Layer 2, 320 x 256, 256 colours, the palette's own RRRGGGBB
BAYER = [[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]
def to332(x, y, c):
    th = (BAYER[y & 3][x & 3] + 0.5) / 16
    r = min(7, int(c[0] / 255 * 7 + th))
    g = min(7, int(c[1] / 255 * 7 + th))
    b = min(3, int(c[2] / 255 * 3 + th))
    v = (r << 5) | (g << 2) | b
    return 0xE7 if v == 0xE3 else v            # $E3 is the colour Layer 2 shows as see-through, never use it
def from332(v):
    return (((v >> 5) & 7) * 255 // 7, ((v >> 2) & 7) * 255 // 7, (v & 3) * 255 // 3)
l2 = [[to332(x, y, cv[y][x]) for x in range(W)] for y in range(H)]
l2bin = bytearray(W * H)
for x in range(W):
    for y in range(H):
        l2bin[x * 256 + y] = l2[y][x]

# ================================================================================================================
# the 48K: the middle 256 x 192, an ink and a paper for each 8 x 8 cell
SPECCY = {}
for i in range(16):
    if i == 8:
        continue
    v = 255 if i >= 8 else 205
    SPECCY[i] = ((v if i & 2 else 0), (v if i & 4 else 0), (v if i & 1 else 0))
def d2(a, b):
    return (a[0] - b[0]) ** 2 + (a[1] - b[1]) ** 2 + (a[2] - b[2]) ** 2
RB, YB, BB, WB, CB = 10, 14, 9, 15, 13
def compatible(a, b):
    return a == 0 or b == 0 or (a >= 8) == (b >= 8)
bitmap = bytearray(6144)
attrs = bytearray(768)
spec = [[0] * 256 for _ in range(192)]
FLASH = set()                                   # cells that flash, as only a Spectrum can: none, for now
for cy in range(24):
    for cx in range(32):
        pix = [(x, y, cv[OY + cy * 8 + y][OX + cx * 8 + x]) for y in range(8) for x in range(8)]
        # the pairs worth trying, as a Spectrum artist would keep them, see PAIRS with the scene
        best = None
        for (a, b) in PAIRS:
            if True:
                ca, cb = SPECCY[a], SPECCY[b]
                ab = d2(ca, cb) or 1
                err = 0
                for (x, y, c) in pix:
                    # how far the pixel is along the way from a to b, and so how often, dithered, it should be b
                    t = max(0, min(1, sum((c[k] - ca[k]) * (cb[k] - ca[k]) for k in range(3)) / ab))
                    m = mix(ca, cb, t)
                    err += d2(m, c)
                if best is None or err < best[0]:
                    best = (err, a, b)
        _, a, b = best
        paper, ink = (a, b) if sum(SPECCY[a]) <= sum(SPECCY[b]) else (b, a)
        cp, ci = SPECCY[paper], SPECCY[ink]
        pi = d2(cp, ci) or 1
        for y in range(8):
            row = 0
            for x in range(8):
                c = cv[OY + cy * 8 + y][OX + cx * 8 + x]
                t = max(0, min(1, sum((c[k] - cp[k]) * (ci[k] - cp[k]) for k in range(3)) / pi))
                if paper == 0:
                    t = max(0.0, (t - 0.22) / 0.78)      # a black floor: faint glow is left black, not scattered with dots
                isink = t > (BAYER[y & 3][x & 3] + 0.5) / 16
                row = (row << 1) | isink
                spec[cy * 8 + y][cx * 8 + x] = ink if isink else paper
            py = cy * 8 + y
            bitmap[((py & 0xC0) << 5) | ((py & 7) << 8) | ((py & 0x38) << 2) | cx] = row
        bright = 1 if (paper >= 8 or ink >= 8) else 0
        attrs[cy * 32 + cx] = (0x80 if (cx, cy) in FLASH else 0) | (bright << 6) | ((paper & 7) << 3) | (ink & 7)

out = sys.argv[1]
os.makedirs(out, exist_ok=True)
open(os.path.join(out, 'splash.scr'), 'wb').write(bytes(bitmap) + bytes(attrs))
open(os.path.join(out, 'splash-l2.bin'), 'wb').write(bytes(l2bin))

# --- previews, three times the size
def png(path, w, h, pixel):
    S3 = 3
    raw = bytearray()
    for yy in range(h * S3):
        raw.append(0)
        for xx in range(w * S3):
            raw.extend(pixel(xx // S3, yy // S3))
    def chunk(t, d):
        return struct.pack('>I', len(d)) + t + d + struct.pack('>I', zlib.crc32(t + d) & 0xFFFFFFFF)
    open(path, 'wb').write(b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', struct.pack('>IIBBBBB', w * S3, h * S3, 8, 2, 0, 0, 0))
                           + chunk(b'IDAT', zlib.compress(bytes(raw), 6)) + chunk(b'IEND', b''))
if len(sys.argv) > 2:
    pv = sys.argv[2]
    os.makedirs(pv, exist_ok=True)
    png(os.path.join(pv, 'splash-next.png'), W, H, lambda x, y: from332(l2[y][x]))
    png(os.path.join(pv, 'splash-48k.png'), W, H, lambda x, y: SPECCY.get(spec[y - OY][x - OX], (0, 0, 0)) if 0 <= x - OX < 256 and 0 <= y - OY < 192 else (0, 0, 0))
