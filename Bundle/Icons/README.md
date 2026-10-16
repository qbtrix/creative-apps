# Placeholder app icons

Real icon art is pending. These six PNGs are placeholders (bundle packet
BU-5c, Q4) so each bundle has the `CFBundleIconFile` its plist in
`Bundle/Info/` names. `IconFilesTests` checks every one exists at 1024 x 1024.

Each icon is a 1024 x 1024 RGBA PNG: a flat coloured rounded square (inset
100 px from each edge, corner radius 185 px) on a transparent background,
with the app's initial in white, drawn from a 5 x 7 block font scaled to
80 px cells and centred. Flat colours keep each file near 10 KB.

| File | Initial | Colour |
|---|---|---|
| `AfterGlow.png` | A | `#E86A33` orange |
| `Flare.png` | F | `#E03E52` red |
| `Design.png` | D | `#3D7BE0` blue |
| `Photo.png` | P | `#2EA86B` green |
| `Library.png` | L | `#8A5CD6` purple |
| `Halo.png` | H | `#D9A41E` gold |

## Regenerate

The generator uses the Python standard library only (`zlib`, `struct`) and is
not part of the repo's tooling. Save the script below outside the repo as
`gen_icons.py` and run `python3 gen_icons.py Bundle/Icons` from the repo
root; it overwrites the six files.

```python
import os, struct, sys, zlib

SIZE, INSET, RADIUS, CELL = 1024, 100, 185, 80
APPS = {  # name: (initial, RGB)
    "AfterGlow": ("A", (0xE8, 0x6A, 0x33)),
    "Flare":     ("F", (0xE0, 0x3E, 0x52)),
    "Design":    ("D", (0x3D, 0x7B, 0xE0)),
    "Photo":     ("P", (0x2E, 0xA8, 0x6B)),
    "Library":   ("L", (0x8A, 0x5C, 0xD6)),
    "Halo":      ("H", (0xD9, 0xA4, 0x1E)),
}
GLYPHS = {
    "A": ["01110", "10001", "10001", "11111", "10001", "10001", "10001"],
    "F": ["11111", "10000", "10000", "11110", "10000", "10000", "10000"],
    "D": ["11110", "10001", "10001", "10001", "10001", "10001", "11110"],
    "P": ["11110", "10001", "10001", "11110", "10000", "10000", "10000"],
    "L": ["10000", "10000", "10000", "10000", "10000", "10000", "11111"],
    "H": ["10001", "10001", "10001", "11111", "10001", "10001", "10001"],
}

def inside(x, y):
    lo, hi = INSET, SIZE - INSET - 1
    if not (lo <= x <= hi and lo <= y <= hi):
        return False
    cx = min(max(x, lo + RADIUS), hi - RADIUS)
    cy = min(max(y, lo + RADIUS), hi - RADIUS)
    return (x - cx) ** 2 + (y - cy) ** 2 <= RADIUS ** 2

def chunk(tag, data):
    crc = zlib.crc32(tag + data) & 0xFFFFFFFF
    return struct.pack(">I", len(data)) + tag + data + struct.pack(">I", crc)

def icon(letter, rgb):
    glyph = GLYPHS[letter]
    gx, gy = (SIZE - 5 * CELL) // 2, (SIZE - 7 * CELL) // 2
    bg = bytes(rgb) + b"\xff"
    rows = []
    for y in range(SIZE):
        row = bytearray(b"\x00")  # filter type None
        for x in range(SIZE):
            if not inside(x, y):
                row += b"\x00\x00\x00\x00"
                continue
            c, r = (x - gx) // CELL, (y - gy) // CELL
            on = 0 <= c < 5 and 0 <= r < 7 and glyph[r][c] == "1"
            row += b"\xff\xff\xff\xff" if on else bg
        rows.append(bytes(row))
    ihdr = struct.pack(">IIBBBBB", SIZE, SIZE, 8, 6, 0, 0, 0)  # 8-bit RGBA
    return (b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", ihdr)
            + chunk(b"IDAT", zlib.compress(b"".join(rows), 9)) + chunk(b"IEND", b""))

out = sys.argv[1]
os.makedirs(out, exist_ok=True)
for name, (letter, rgb) in APPS.items():
    with open(os.path.join(out, name + ".png"), "wb") as f:
        f.write(icon(letter, rgb))
```
