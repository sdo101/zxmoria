# draws the Next's text screen as a PNG, from what the hardware shows: the 80 x 32 cells (page 11, a character and an
# attribute byte each), the font (page 10, 8 bytes a character) and the tilemap palette (the screen's own 16 pairs as
# load.bas writes them, and the colours' pairs from 16 up as the game tables page holds them, see colours.txt)
# usage: python render-screen.py <cells.bin> <font.bin> <load.bas> <gametables.bin> <out.png> [scale]
# N.B: written 22 October 2026, ZEsarUX's remote commands have no way to save the screen as a picture
import sys, re, struct, zlib

cells = open(sys.argv[1], 'rb').read()
font = open(sys.argv[2], 'rb').read()
load = open(sys.argv[3], encoding='latin-1').read()
tables = open(sys.argv[4], 'rb').read()
out = sys.argv[5]
scale = int(sys.argv[6]) if len(sys.argv) > 6 else 2

def rgb8(v):                       # RRRGGGBB
    r, g, b = v >> 5, (v >> 2) & 7, v & 3
    b9 = (b << 1) | (1 if b else 0)
    return (r * 255 // 7, g * 255 // 7, b9 * 255 // 7)

def rgb9(hi, lo):                  # RRRGGGBB and the lowest blue bit
    r, g, b = hi >> 5, (hi >> 2) & 7, ((hi & 3) << 1) | (lo & 1)
    return (r * 255 // 7, g * 255 // 7, b * 255 // 7)

# the screen's own 16 pairs, in the order load.bas writes them
part = load[load.index('Sub s_load_4_set_palette'):]
part = part[:part.index('End Sub')]
values = [int(v, 16) for v in re.findall(r'nextreg NEXTREG_PALETTE_VALUE,\s*\$([0-9A-Fa-f]{2})', part)]
palette = [rgb8(v) for v in values]
while len(palette) < 256: palette.append((0, 0, 0))
count = tables[1792]
for i in range(count):
    palette[2 * (16 + i)] = (0, 0, 0)
    palette[2 * (16 + i) + 1] = rgb9(tables[1793 + 2 * i], tables[1794 + 2 * i])

w, h = 80 * 8, 32 * 8
rows = []
for y in range(h):
    row = bytearray()
    for x in range(w):
        c = cells[((y // 8) * 80 + x // 8) * 2]
        a = cells[((y // 8) * 80 + x // 8) * 2 + 1]
        bit = (font[c * 8 + (y % 8)] >> (7 - x % 8)) & 1
        pair = a >> 1
        r, g, b = palette[2 * pair + bit]
        row += bytes((r, g, b)) * scale
    for _ in range(scale): rows.append(bytes(row))

raw = b''.join(b'\x00' + r for r in rows)
def chunk(t, d): return struct.pack('>I', len(d)) + t + d + struct.pack('>I', zlib.crc32(t + d) & 0xffffffff)
png = b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', struct.pack('>IIBBBBB', w * scale, h * scale, 8, 2, 0, 0, 0)) + chunk(b'IDAT', zlib.compress(raw, 9)) + chunk(b'IEND', b'')
open(out, 'wb').write(png)
print(out, w * scale, 'x', h * scale, f'{count} colour pairs')
