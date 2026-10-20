#!/usr/bin/env python3
# gen.py: writes the import fidelity corpus, deliberately hard PSD and SVG
# files, and manifest.json, what each one must open as. Python 3 stdlib only
# (no install): `python3 Tests/import_fidelity/gen.py` rewrites psd/, svg/ and
# manifest.json byte for byte the same, so a diff after a run means the
# generator changed. Read by Tests/PhotoModelTests/ImportFidelityPSDTests.swift
# and Tests/FlareModelTests/ImportFidelitySVGTests.swift.
#
# The reference render: a PSD's merged image is what this script composites
# from the layer tree the way the authoring app does (8-bit, blended in the
# encoded sRGB values), so a reader that keeps every layer flattens back to
# it. An SVG's probes are points with the paint the SVG spec puts there,
# worked out here from the geometry this script wrote.
#
# Gate rule the tests apply: each feature opens, or the import says it didn't
# (a thrown reason, or an entry in the SVG report). A file with a known gap
# names its finding issue in GAPS; its test runs under withKnownIssue.
import json, os, struct, zlib

ROOT = os.path.dirname(os.path.abspath(__file__))
# Finding issues on qbtrix/creative-apps, by gap key.
GAPS = {
    "psd-adjustment": 3494, "psd-fill": 3495, "psd-effects": 3496, "psd-blend-keys": 3497,
    "psd-kinds": 3498, "psd-gamma": 3500, "svg-groups": 3501, "svg-dash": 3502,
    "svg-fill-rule": 3503, "svg-hidden": 3504, "svg-nested-svg": 3505, "svg-text-style": 3506,
}

# ---------------------------------------------------------------- PSD


def packbits(row):
    out, i, n = bytearray(), 0, len(row)
    while i < n:
        j = i
        while j + 1 < n and row[j + 1] == row[i] and j - i < 127:
            j += 1
        if j > i:
            out += bytes([257 - (j - i + 1), row[i]])
            i = j + 1
            continue
        j = i
        while j < n and j - i < 128 and not (j + 2 < n and row[j] == row[j + 1] == row[j + 2]):
            j += 1
        out += bytes([j - i - 1]) + bytes(row[i:j])
        i = j
    return bytes(out)


def channel(plane, w, h, bytes_per, compression=1):
    """One layer channel: compression, then its data (RLE rows or zip)."""
    if w == 0 or h == 0:
        return struct.pack(">H", 0)
    stride = w * bytes_per
    if compression == 2:
        return struct.pack(">H", 2) + zlib.compress(bytes(plane))
    rows = [packbits(plane[y * stride:(y + 1) * stride]) for y in range(h)]
    return struct.pack(">H", 1) + b"".join(struct.pack(">H", len(r)) for r in rows) + b"".join(rows)


def pascal4(name):
    raw = name.encode("utf-8")[:255]
    data = bytes([len(raw)]) + raw
    return data + b"\0" * ((4 - len(data) % 4) % 4)


def block(key, data):
    data += b"\0" * (len(data) % 2)
    return b"8BIM" + key.encode() + struct.pack(">I", len(data)) + data


def luni(name):
    units = name.encode("utf-16-be")
    return block("luni", struct.pack(">I", len(units) // 2) + units)


class L:
    """A layer: rect (l, t, r, b), paint(x, y) -> (r, g, b, a) 0...255."""

    def __init__(self, name, rect=(0, 0, 0, 0), paint=None, blend="norm", opacity=255, hidden=False,
                 clip=False, mask=None, extra=(), kind="pixels", effect=None, adjust=None, fill=None):
        self.__dict__.update(locals())
        del self.__dict__["self"]


class G:
    def __init__(self, name, children, blend="pass", hidden=False, closed=False):
        self.__dict__.update(locals())
        del self.__dict__["self"]


def solid(c, stripe=None):
    """A flat colour; `stripe` = (colour, x) paints a 2 px column so a misplaced layer shows."""
    def paint(x, y):
        return (stripe[0] + (255,)) if stripe and stripe[1] <= x < stripe[1] + 2 else c + (255,)
    return paint


def bands(w):
    def paint(x, y):
        return ((x * 4 // w) * 60 + 30, 90, 200 - (y * 4 // w) * 40, 255)
    return paint


BLEND = {"norm": lambda b, s: s, "mul ": lambda b, s: b * s, "scrn": lambda b, s: b + s - b * s,
         "over": lambda b, s: 2 * b * s if b <= 0.5 else 1 - 2 * (1 - b) * (1 - s),
         "diff": lambda b, s: abs(b - s), "lddg": lambda b, s: min(1, b + s), "lbrn": lambda b, s: max(0, b + s - 1)}
SWIFT_BLEND = {"norm": "normal", "mul ": "multiply", "scrn": "screen", "over": "overlay", "diff": "difference",
               "lddg": "linearDodge", "lbrn": "linearBurn"}


def mask_at(m, x, y):
    if not m or m.get("disabled"):
        return 1.0
    l, t, r, b = m["rect"]
    return (m["paint"](x, y) if l <= x < r and t <= y < b else m["default"]) / 255


def composite(nodes, canvas, w, h):
    """The authoring app's flatten onto an opaque canvas of [r, g, b] 0...1 lists."""
    base = None
    for n in nodes:
        if isinstance(n, G):
            if not n.hidden:
                composite(n.children, canvas, w, h)
            continue
        if n.hidden:
            continue
        if n.adjust == "invert":
            for y in range(h):
                for x in range(w):
                    k = mask_at(n.mask, x, y)
                    canvas[y][x] = [c + k * ((1 - c) - c) for c in canvas[y][x]]
            continue
        if n.fill:
            for y in range(h):
                for x in range(w):
                    k = mask_at(n.mask, x, y)
                    canvas[y][x] = [c + k * (f / 255 - c) for c, f in zip(canvas[y][x], n.fill)]
            continue
        l, t, r, b = n.rect
        for y in range(max(t, 0), min(b, h)):
            for x in range(max(l, 0), min(r, w)):
                p = n.paint(x, y)
                a = p[3] / 255 * n.opacity / 255 * mask_at(n.mask, x, y)
                if n.clip:
                    a *= base(x, y)
                cb = canvas[y][x]
                canvas[y][x] = [c + a * (BLEND[n.blend](c, s / 255) - c) for c, s in zip(cb, p)]
        if n.effect:  # a 1 px outside stroke in the effect colour
            for y in range(t - 1, b + 1):
                for x in range(l - 1, r + 1):
                    if 0 <= x < w and 0 <= y < h and not (l <= x < r and t <= y < b):
                        canvas[y][x] = [c / 255 for c in n.effect]
        if not n.clip:
            base = (lambda n: lambda x, y: (n.paint(x, y)[3] / 255 * mask_at(n.mask, x, y))
                    if n.rect[0] <= x < n.rect[2] and n.rect[1] <= y < n.rect[3] else 0.0)(n)


def records(nodes):
    """Layer records bottom to top: a group is its divider, its children, then its folder record."""
    out = []
    for n in nodes:
        if isinstance(n, G):
            out.append(L("</Layer group>", extra=[block("lsct", struct.pack(">I", 3))]))
            out += records(n.children)
            out.append(L(n.name, hidden=n.hidden, extra=[luni(n.name), block("lsct", struct.pack(">I", 2 if n.closed else 1)
                                                                                + b"8BIM" + n.blend.encode())]))
        else:
            out.append(n)
    return out


def psd(name, w, h, nodes, bits=8, mode=3, version=1, zip_layers=False):
    bp = bits // 8
    color = 1 if mode == 1 else 3 if mode == 3 else 4

    def sample(v):
        v = max(0, min(255, int(round(v))))
        return struct.pack(">H", v * 257) if bp == 2 else bytes([v])

    recs, data = b"", b""
    for n in records(nodes):
        l, t, r, b = n.rect
        lw, lh = r - l, b - t
        chans = []
        ids = [-1] + list(range(color))
        for cid in ids:
            plane = bytearray()
            for y in range(t, b):
                for x in range(l, r):
                    p = n.paint(x, y)
                    plane += sample(p[3] if cid == -1 else (p[0] * 0.299 + p[1] * 0.587 + p[2] * 0.114) if color == 1 else p[cid])
            chans.append((cid, channel(plane, lw, lh, bp, 2 if zip_layers else 1)))
        maskdata = b""
        if n.mask:
            ml, mt, mr, mb = n.mask["rect"]
            plane = bytearray()
            for y in range(mt, mb):
                for x in range(ml, mr):
                    plane += sample(n.mask["paint"](x, y))
            chans.append((-2, channel(plane, mr - ml, mb - mt, bp)))
            maskdata = struct.pack(">iiiiBBH", mt, ml, mb, mr, n.mask["default"], 2 if n.mask.get("disabled") else 0, 0)
        extra = struct.pack(">I", len(maskdata)) + maskdata + struct.pack(">I", 0) + pascal4(n.name)
        extra += b"".join(n.extra) + (luni(n.name) if not any(e[4:8] == b"luni" for e in n.extra) else b"")
        recs += struct.pack(">iiiiH", t, l, b, r, len(chans))
        recs += b"".join(struct.pack(">hI", cid, len(d)) for cid, d in chans)
        recs += b"8BIM" + n.blend.encode() + bytes([n.opacity, 1 if n.clip else 0, 2 if n.hidden else 0, 0])
        recs += struct.pack(">I", len(extra)) + extra
        data += b"".join(d for _, d in chans)
    info = struct.pack(">h", len(records(nodes))) + recs + data
    info += b"\0" * (len(info) % 2)
    inner = struct.pack(">I", len(info)) + info + struct.pack(">I", 0)  # layer info, then an empty global mask
    layer_section = struct.pack(">I", len(inner)) + inner

    canvas = [[[1.0, 1.0, 1.0] for _ in range(w)] for _ in range(h)]
    composite(nodes, canvas, w, h)
    merged = b""
    planes = [bytearray() for _ in range(color)]
    for row in canvas:
        for px in row:
            vals = [(px[0] * 0.299 + px[1] * 0.587 + px[2] * 0.114) * 255] if color == 1 else [c * 255 for c in px] + [0] * (color - 3)
            for i, v in enumerate(vals):
                planes[i] += sample(v)
    rows = [packbits(bytes(p[y * w * bp:(y + 1) * w * bp])) for p in planes for y in range(h)]
    merged = struct.pack(">H", 1) + b"".join(struct.pack(">H", len(r)) for r in rows) + b"".join(rows)

    header = b"8BPS" + struct.pack(">H", version) + b"\0" * 6 + struct.pack(">HIIHH", color, h, w, bits, mode)
    body = header + struct.pack(">I", 0) + struct.pack(">I", 0) + layer_section + merged
    with open(os.path.join(ROOT, "psd", name), "wb") as f:
        f.write(body)


def tree(nodes):
    out = []
    for n in nodes:
        if isinstance(n, G):
            out.append({"name": n.name, "kind": "group", "hidden": n.hidden,
                        "blend": None if n.blend == "pass" else SWIFT_BLEND[n.blend], "children": tree(n.children)})
        else:
            out.append({"name": n.name, "kind": n.kind, "hidden": n.hidden, "blend": SWIFT_BLEND[n.blend],
                        "opacity": n.opacity, "clip": n.clip, "mask": bool(n.mask)})
    return out


def psd_cases():
    W = 64
    bg = lambda: L("Background", (0, 0, W, W), bands(W))
    box = lambda name, rect, c, **k: L(name, rect, solid(c, ((255, 255, 255), rect[0] + 3)), **k)
    hard = lambda rect, default=0: {"rect": rect, "default": default, "paint": lambda x, y: 255 if (x // 4 + y // 4) % 2 else 0}
    cases = [
        ("flat_background.psd", "one Background layer", [bg()], {}),
        ("normal_stack.psd", "offset layers, one hanging off the canvas, a Unicode name",
         [bg(), box("Red", (4, 4, 30, 30), (220, 40, 40)), box("Café ☕", (20, 20, 50, 44), (40, 180, 90)),
          box("Off canvas", (-10, 50, 20, 74), (30, 60, 220))], {}),
        ("nested_groups.psd", "groups three deep, one closed",
         [bg(), G("Outer", [box("Outer leaf", (2, 2, 20, 20), (200, 120, 30)),
                            G("Middle", [G("Inner", [box("Deep leaf", (24, 24, 40, 40), (90, 30, 160))])], closed=True)]),
          G("Empty group", [])], {}),
        ("hidden_layers.psd", "a hidden layer and a hidden group",
         [bg(), box("Shown", (4, 4, 24, 24), (220, 220, 30)), box("Hidden", (30, 30, 60, 60), (255, 0, 0), hidden=True),
          G("Hidden group", [box("Inside hidden", (0, 40, 20, 60), (0, 255, 0))], hidden=True)], {}),
        ("masks.psd", "hard masks: default hide, default show, disabled",
         [bg(), box("Masked", (4, 4, 30, 30), (230, 60, 60), mask=hard((8, 8, 24, 24))),
          box("Holed", (34, 4, 60, 30), (60, 200, 60), mask=hard((40, 10, 52, 22), 255)),
          box("Mask off", (4, 34, 30, 60), (60, 60, 230), mask=dict(hard((8, 40, 20, 52)), disabled=True))], {}),
        ("clipping.psd", "a layer clipped to the one below",
         [bg(), L("Base", (10, 10, 40, 40), lambda x, y: (250, 250, 250, 255 if (x - 25) ** 2 + (y - 25) ** 2 < 150 else 0)),
          box("Clipped", (0, 0, 32, 64), (200, 30, 120), clip=True)], {}),
        ("blend_opacity.psd", "multiply, screen, overlay, difference and 50% opacity",
         [bg(), box("Multiply", (2, 2, 30, 30), (128, 200, 60), blend="mul "), box("Screen", (34, 2, 62, 30), (90, 40, 160), blend="scrn"),
          box("Overlay", (2, 34, 30, 62), (200, 200, 40), blend="over"), box("Difference", (34, 34, 62, 62), (255, 128, 0), blend="diff"),
          box("Half", (16, 16, 48, 48), (255, 0, 0), opacity=128)], {"gap": "psd-gamma"}),
        ("blend_extended.psd", "linear dodge and linear burn keys",
         [bg(), box("Linear dodge", (4, 4, 30, 60), (100, 60, 20), blend="lddg"),
          box("Linear burn", (34, 4, 60, 60), (200, 160, 230), blend="lbrn")], {"gap": "psd-blend-keys"}),
        ("adjustment_layer.psd", "an Invert adjustment layer over the picture",
         [bg(), box("Square", (10, 10, 40, 40), (240, 200, 20)),
          L("Invert", kind="adjustment", adjust="invert", extra=[block("nvrt", b"")])], {"gap": "psd-adjustment"}),
        ("fill_layer.psd", "a solid colour fill layer shown through its mask",
         [bg(), L("Color Fill", kind="fill", fill=(20, 160, 200), mask={"rect": (12, 12, 52, 52), "default": 0, "paint": lambda x, y: 255},
                  extra=[block("SoCo", struct.pack(">I", 16) + b"\0" * 40)])], {"gap": "psd-fill"}),
        ("text_layer.psd", "a type layer (TySh) with its rendered pixels",
         [bg(), L("Headline", (6, 20, 58, 34), lambda x, y: (20, 20, 20, 255 if (x // 3) % 2 else 0), kind="text",
                  extra=[block("TySh", struct.pack(">H", 1) + b"\0" * 48)])], {"gap": "psd-kinds"}),
        ("smart_object.psd", "a placed smart object (SoLd) with its rendered pixels",
         [bg(), box("Placed logo", (14, 14, 50, 50), (250, 120, 180), kind="smartObject",
                    extra=[block("SoLd", b"soLD" + struct.pack(">II", 4, 16) + b"\0" * 16)])], {"gap": "psd-kinds"}),
        ("layer_effects.psd", "a layer with a stroke effect (lfx2)",
         [bg(), box("Badge", (16, 16, 48, 48), (240, 240, 240), effect=(220, 20, 60), extra=[block("lfx2", b"\0" * 24)])],
         {"gap": "psd-effects"}),
        ("rgb16.psd", "16 bits per channel with a group and a mask",
         [bg(), G("Deep", [box("Sixteen", (8, 8, 56, 56), (180, 90, 45), mask=hard((16, 16, 48, 48)))])], {"bits": 16}),
        ("gray8.psd", "grayscale with two layers",
         [bg(), box("Gray box", (10, 10, 50, 50), (160, 160, 160))], {"mode": 1}),
        ("large_canvas.psd", "a 2400 x 300 banner with no Background, small layers at the far edges",
         [box("Left edge", (0, 0, 40, 40), (40, 160, 40)), box("Far corner", (2360, 260, 2400, 300), (200, 40, 40)),
          box("Middle", (1180, 130, 1220, 170), (40, 40, 200))], {"w": 2400, "h": 300}),
        ("zip_channels.psd", "layer channels zip-compressed", [bg(), box("Zipped", (4, 4, 30, 30), (10, 200, 10))],
         {"zip": True, "refuse": "zip"}),
        ("cmyk.psd", "CMYK colour mode", [bg()], {"mode": 4, "refuse": "colour mode 4"}),
        ("large_document.psb", "large document format (PSB)", [bg()], {"version": 2, "refuse": "large document format"}),
    ]
    out = []
    for name, what, nodes, o in cases:
        w, h = o.get("w", W), o.get("h", W)
        psd(name, w, h, nodes, bits=o.get("bits", 8), mode=o.get("mode", 3), version=o.get("version", 1),
            zip_layers=o.get("zip", False))
        entry = {"file": "psd/" + name, "what": what, "width": w, "height": h, "bits": o.get("bits", 8)}
        if "refuse" in o:
            entry["refuse"] = o["refuse"]
        else:
            entry["tree"] = tree(nodes)
        if "gap" in o:
            entry["gap"] = GAPS[o["gap"]]
        out.append(entry)
    return out

# ---------------------------------------------------------------- SVG


def rgba(hexcolor, a=1.0):
    return [round(int(hexcolor[i:i + 2], 16) / 255, 4) for i in (1, 3, 5)] + [a]


PNG_1PX = ("iVBORw0KGgoAAAANSUhEUgAAAAIAAAACCAYAAABytg0kAAAAFklEQVR4nGP4z8DwnwEIGBkZGRgYAAAtBgMBWcSaVQAAAABJRU5ErkJggg==")


def svg_cases():
    S = lambda body, box="0 0 100 100", extra="": (
        f'<?xml version="1.0" encoding="UTF-8"?>\n<svg xmlns="http://www.w3.org/2000/svg" '
        f'xmlns:xlink="http://www.w3.org/1999/xlink" viewBox="{box}"{extra}>\n{body}\n</svg>\n')
    P = lambda x, y, c, excuse=None: {"x": x, "y": y, "rgba": c, **({"excuse": excuse} if excuse else {})}
    red, green, blue, ink = rgba("#e02020"), rgba("#20a040"), rgba("#2040e0"), rgba("#202020")
    cases = [
        ("basic_shapes.svg", "every basic shape and a curved path", S(
            '<rect id="rect" x="5" y="5" width="20" height="15" fill="#e02020"/>\n'
            '<rect id="rounded" x="30" y="5" width="20" height="15" rx="5" fill="#20a040"/>\n'
            '<circle id="circle" cx="65" cy="12" r="8" fill="#2040e0"/>\n'
            '<ellipse id="ellipse" cx="88" cy="12" rx="10" ry="5" fill="#e02020"/>\n'
            '<line id="line" x1="5" y1="35" x2="45" y2="35" stroke="#202020" stroke-width="4"/>\n'
            '<polyline id="polyline" points="55,30 70,40 85,30" fill="none" stroke="#2040e0" stroke-width="4"/>\n'
            '<polygon id="polygon" points="10,60 30,60 20,80" fill="#20a040"/>\n'
            '<path id="path" d="M50 60 C50 50 70 50 70 60 S90 70 90 60 L90 90 A20 20 0 0 1 50 90 Z" fill="#202020"/>'),
         {"layers": ["rect", "rounded", "circle", "ellipse", "line", "polyline", "polygon", "path"],
          "probes": [P(15, 12, red), P(31, 6, None), P(40, 12, green), P(65, 12, blue), P(88, 12, red), P(25, 35, ink),
                     P(70, 40, blue), P(70, 33, None), P(20, 65, green), P(70, 80, ink), P(5, 95, None)]}),
        ("nested_groups.svg", "groups four deep under two top-level groups", S(
            '<g id="toolbar">\n  <g id="row-1"><rect x="5" y="5" width="30" height="10" fill="#e02020"/></g>\n'
            '  <g id="row-2">\n    <g id="icon-a"><g id="icon-a-glyph"><circle cx="20" cy="30" r="6" fill="#20a040"/></g></g>\n'
            '    <rect x="40" y="25" width="10" height="10" fill="#2040e0"/>\n  </g>\n</g>\n'
            '<g id="footer"><rect x="5" y="80" width="90" height="15" fill="#202020"/></g>'),
         {"layers": ["toolbar", "footer"], "groups": ["row-1", "row-2", "icon-a", "icon-a-glyph"],
          "probes": [P(20, 10, red), P(20, 30, green), P(45, 30, blue), P(50, 88, ink)], "gap": "svg-groups"}),
        ("transforms.svg", "translate, rotate about a point, scale, matrix, skewX, nested", S(
            '<rect id="moved" width="10" height="10" fill="#e02020" transform="translate(5 5)"/>\n'
            '<rect id="turned" x="40" y="0" width="20" height="4" fill="#20a040" transform="rotate(90 50 10)"/>\n'
            '<g id="scaled" transform="scale(2)"><rect x="35" y="2" width="5" height="5" fill="#2040e0"/></g>\n'
            '<rect id="matrix" width="10" height="10" fill="#202020" transform="matrix(1 0 0 1 10 60)"/>\n'
            '<rect id="skewed" x="0" y="0" width="10" height="10" fill="#e02020" transform="translate(40 60) skewX(45)"/>\n'
            '<g id="nested" transform="translate(70 70)"><g transform="rotate(45)"><rect x="-2" y="-2" width="4" height="20" fill="#20a040"/></g></g>'),
         {"layers": ["moved", "turned", "scaled", "matrix", "skewed", "nested"],
          "probes": [P(10, 10, red), P(2, 2, None), P(58, 15, green), P(55, 2, None), P(75, 10, blue), P(15, 65, ink),
                     P(55, 68, red), P(41, 68, None), P(63, 77, green)]}),
        ("gradients.svg", "linear and radial gradients, an href chain, gradientTransform", S(
            '<defs>\n  <linearGradient id="lin"><stop offset="0" stop-color="#ff0000"/><stop offset="1" stop-color="#0000ff"/></linearGradient>\n'
            '  <linearGradient id="chained" href="#lin" x1="0" y1="0" x2="0" y2="1"/>\n'
            '  <radialGradient id="rad" gradientUnits="userSpaceOnUse" cx="75" cy="25" r="20"><stop offset="0" stop-color="#ffffff"/>'
            '<stop offset="1" stop-color="#000000"/></radialGradient>\n'
            '  <linearGradient id="turned" xlink:href="#lin" gradientUnits="userSpaceOnUse" x1="0" y1="0" x2="40" y2="0" '
            'gradientTransform="translate(50 50) rotate(90)"/>\n</defs>\n'
            '<rect id="horizontal" x="0" y="0" width="40" height="40" fill="url(#lin)"/>\n'
            '<rect id="vertical" x="0" y="50" width="40" height="40" fill="url(#chained)"/>\n'
            '<rect id="radial" x="55" y="5" width="40" height="40" fill="url(#rad)"/>\n'
            '<rect id="transformed" x="50" y="50" width="40" height="40" fill="url(#turned)"/>'),
         {"layers": ["horizontal", "vertical", "radial", "transformed"],
          "probes": [P(0.5, 20, [0.9875, 0, 0.0125, 1]), P(20, 20, [0.5, 0, 0.5, 1]), P(30, 5, [0.25, 0, 0.75, 1]),
                     P(20, 60, [0.75, 0, 0.25, 1]), P(75, 25, [1, 1, 1, 1]), P(75, 35, [0.5, 0.5, 0.5, 1]),
                     P(70, 60, [0.75, 0, 0.25, 1]), P(70, 80, [0.25, 0, 0.75, 1])]}),
        ("clip_paths.svg", "a clip path on a shape, and one inside a group", S(
            '<defs><clipPath id="round"><circle cx="25" cy="25" r="15"/></clipPath>'
            '<clipPath id="half"><rect x="50" y="50" width="20" height="40"/></clipPath></defs>\n'
            '<rect id="clipped" x="0" y="0" width="50" height="50" fill="#e02020" clip-path="url(#round)"/>\n'
            '<g id="group"><rect x="50" y="50" width="40" height="40" fill="#2040e0" clip-path="url(#half)"/></g>'),
         {"layers": ["clipped", "group"], "reported": ["nested clip-path"],
          "probes": [P(25, 25, red), P(3, 3, None), P(60, 70, blue), P(80, 70, None, "nested clip-path")]}),
        ("masks.svg", "a luminance mask", S(
            '<defs><mask id="fade"><rect x="0" y="0" width="50" height="100" fill="#ffffff"/></mask></defs>\n'
            '<rect id="masked" x="0" y="0" width="100" height="100" fill="#20a040" mask="url(#fade)"/>'),
         {"layers": ["masked"], "reported": ["mask"], "probes": [P(25, 50, green), P(75, 50, None, "mask")]}),
        ("dashed_strokes.svg", "dashed strokes with an offset", S(
            '<line id="dashed" x1="0" y1="20" x2="100" y2="20" stroke="#202020" stroke-width="4" stroke-dasharray="10 10"/>\n'
            '<line id="offset" x1="0" y1="60" x2="100" y2="60" stroke="#e02020" stroke-width="4" stroke-dasharray="10 10" stroke-dashoffset="5"/>'),
         {"layers": ["dashed", "offset"],
          "probes": [P(5, 20, ink), P(15, 20, None, "stroke-dasharray"), P(10, 60, None, "stroke-dasharray"), P(20, 60, red)],
          "gap": "svg-dash"}),
        ("text.svg", "plain text, tspans, centred and bold text", S(
            '<text id="plain" x="5" y="20" font-family="Helvetica" font-size="12" fill="#202020">Hello</text>\n'
            '<text id="spans" x="5" y="45" font-size="10">Two <tspan fill="#e02020">styled</tspan> words</text>\n'
            '<text id="centred" x="50" y="70" text-anchor="middle" font-weight="bold" font-size="14">Title</text>'),
         {"layers": ["plain", "spans", "centred"], "reported": ["tspan"],
          "texts": [{"string": "Hello"}, {"string": "Two styled words"},
                    {"string": "Title", "anchor": "center", "weight": 700}], "gap": "svg-text-style"}),
        ("embedded_raster.svg", "an embedded PNG next to vector art", S(
            f'<image id="photo" x="0" y="0" width="50" height="50" href="data:image/png;base64,{PNG_1PX}"/>\n'
            '<circle id="dot" cx="75" cy="75" r="20" fill="#2040e0"/>'),
         {"layers": ["dot"], "reported": ["image"], "probes": [P(75, 75, blue), P(25, 25, None)]}),
        ("viewbox_offset.svg", "a viewBox with a negative origin, scaled 2x by width and height", S(
            '<rect id="origin" x="-100" y="-50" width="20" height="20" fill="#e02020"/>\n'
            '<circle id="centre" cx="0" cy="0" r="10" fill="#20a040"/>', box="-100 -50 200 100", extra=' width="400" height="200"'),
         {"layers": ["origin", "centre"], "size": [200, 100], "probes": [P(10, 10, red), P(100, 50, green), P(150, 80, None)]}),
        ("units_no_viewbox.svg", "no viewBox, a size in mm, lengths in % and pt", S(
            '<rect id="half" x="0" y="0" width="50%" height="50%" fill="#2040e0"/>\n'
            '<rect id="points" x="150pt" y="75pt" width="15pt" height="15pt" fill="#e02020"/>',
            box="", extra=' width="80mm" height="40mm"').replace(' viewBox=""', ''),
         {"layers": ["half", "points"], "size": [302.3622, 151.1811],
          "probes": [P(75, 37, blue), P(160, 40, None), P(207, 107, red)]}),
        ("nested_svg.svg", "an inner svg viewport with its own viewBox", S(
            '<rect id="frame" x="0" y="0" width="40" height="40" fill="#202020"/>\n'
            '<svg id="inner" x="50" y="50" width="40" height="40" viewBox="0 0 10 10"><rect width="5" height="5" fill="#e02020"/></svg>'),
         {"layers": ["frame", "inner"], "probes": [P(20, 20, ink), P(55, 55, red, "svg"), P(2, 2, ink), P(85, 85, None)],
          "gap": "svg-nested-svg"}),
        ("fill_rule.svg", "an even-odd path with a hole", S(
            '<path id="ring" fill-rule="evenodd" fill="#20a040" d="M10 10 H90 V90 H10 Z M30 30 H70 V70 H30 Z"/>'),
         {"layers": ["ring"], "probes": [P(20, 20, green), P(50, 50, None, "fill-rule")], "gap": "svg-fill-rule"}),
        ("hidden_content.svg", "display none, visibility hidden, a hidden group", S(
            '<rect id="shown" x="0" y="0" width="30" height="30" fill="#20a040"/>\n'
            '<rect id="none" x="35" y="0" width="30" height="30" fill="#e02020" display="none"/>\n'
            '<rect id="invisible" x="70" y="0" width="30" height="30" fill="#e02020" style="visibility:hidden"/>\n'
            '<g id="hidden-group" style="display:none"><rect x="0" y="50" width="30" height="30" fill="#e02020"/></g>'),
         {"layers": ["shown"], "probes": [P(15, 15, green), P(50, 15, None, "display"), P(85, 15, None, "visibility"),
                                          P(15, 65, None, "display")], "gap": "svg-hidden"}),
        ("use_symbols.svg", "a symbol drawn twice by use", S(
            '<defs><symbol id="star" viewBox="0 0 10 10"><rect width="10" height="10" fill="#2040e0"/></symbol></defs>\n'
            '<use id="first" href="#star" x="10" y="10" width="20" height="20"/>\n'
            '<use id="second" xlink:href="#star" x="60" y="60" width="20" height="20"/>'),
         {"layers": [], "reported": ["use"], "probes": [P(20, 20, blue, "use"), P(70, 70, blue, "use")]}),
        ("css_classes.svg", "fills from a style sheet, as design tools export", S(
            '<style>.warm { fill: #e02020; } #cool { fill: #2040e0; }</style>\n'
            '<rect id="classed" class="warm" x="5" y="5" width="40" height="40"/>\n'
            '<rect id="cool" x="55" y="5" width="40" height="40"/>'),
         {"layers": ["classed", "cool"], "reported": ["style"], "probes": [P(25, 25, red, "style"), P(75, 25, blue, "style")]}),
        ("opacity_strokes.svg", "group opacity, fill and stroke opacity, joins and caps", S(
            '<g id="faded" opacity="0.5"><rect x="5" y="5" width="40" height="40" fill="#e02020"/></g>\n'
            '<rect id="see-through" x="55" y="5" width="40" height="40" fill="#2040e0" fill-opacity="0.25"/>\n'
            '<polyline id="joined" points="10,60 50,90 90,60" fill="none" stroke="#20a040" stroke-width="6" '
            'stroke-linejoin="round" stroke-linecap="round" stroke-opacity="0.8"/>'),
         {"layers": ["faded", "see-through", "joined"],
          "probes": [P(25, 25, red[:3] + [0.5]), P(75, 25, blue[:3] + [0.25]), P(50, 90, green[:3] + [0.8])]}),
    ]
    out = []
    for name, what, text, o in cases:
        with open(os.path.join(ROOT, "svg", name), "w") as f:
            f.write(text)
        entry = {"file": "svg/" + name, "what": what, **{k: v for k, v in o.items() if k != "gap"}}
        if "gap" in o:
            entry["gap"] = GAPS[o["gap"]]
        out.append(entry)
    return out


if __name__ == "__main__":
    for d in ("psd", "svg"):
        os.makedirs(os.path.join(ROOT, d), exist_ok=True)
    manifest = {"psd": psd_cases(), "svg": svg_cases()}
    with open(os.path.join(ROOT, "manifest.json"), "w") as f:
        json.dump(manifest, f, indent=1, ensure_ascii=False)
        f.write("\n")
