#!/usr/bin/env python3
"""
Generate the app icon: the test pattern caught mid-sort.

Not an abstraction of what the app does. This is the actual image the app
sorts, scrambled and then partially put back, so the icon is a real frame of
the thing running.

The pattern is the Python twin of PixelCanvas.testPattern, which is itself a
port of SortablePicture::CreateGradientPattern. The overlay reserve is dropped
here: 50 rows of black is right in the app, where algorithm text sits on top,
and wasted space in a 1024 square.

Partial state is exactly what selection sort looks like after k steps: the
first k slots hold the k smallest indices in order, everything after them is
still shuffled. Cheap to construct and honest about what it depicts.

Deterministic: seeded SplitMix64, the same generator the Swift package uses.

Usage: python3 create_app_icon.py [--progress 0.45] [--out DIR]
"""
import argparse, json, math, os, pathlib
from PIL import Image

MASTER = 1024


class SplitMix64:
    def __init__(self, seed): self.s = seed & 0xFFFFFFFFFFFFFFFF
    def next(self):
        self.s = (self.s + 0x9E3779B97F4A7C15) & 0xFFFFFFFFFFFFFFFF
        z = self.s
        z = ((z ^ (z >> 30)) * 0xBF58476D1CE4E5B9) & 0xFFFFFFFFFFFFFFFF
        z = ((z ^ (z >> 27)) * 0x94D049BB133111EB) & 0xFFFFFFFFFFFFFFFF
        return z ^ (z >> 31)


def test_pattern(w, h, reserved=0):
    """Twin of PixelCanvas.testPattern. Returns a flat list of (r, g, b)."""
    out = [(0, 0, 0)] * (w * h)
    cx, cy = w / 2, h / 2
    for i in range(w * h):
        x, y = i % w, i // w
        if y < reserved:
            continue
        ay = y - reserved
        diagonal = (x + y) // 20
        ring = int(math.dist((x, y), (cx, cy)) / (15 * w / 640)) % 7
        band = (ay * 6) // max(h - reserved, 1)

        if band == 0:   r, g, b = 255, 0, (ring % 2) * 255
        elif band == 1: r, g, b = 255, 255, ((x // 20) % 2) * 255
        elif band == 2: r, g, b = (ring % 2) * 255, 255, 0
        elif band == 3: r, g, b = 255, (165 if diagonal % 2 == 0 else 0), 0
        elif band == 4: r, g, b = 0, (ring % 3) * 127, 255
        else:
            c = ((x // 15) + (y // 15)) % 2 * 255
            r = g = b = c

        ah = h - reserved
        if w // 3 < x < w * 2 // 3 and ah // 3 < ay < ah * 2 // 3:
            kx, ky = (x - w // 3) // 15, (ay - ah // 3) // 15
            if (kx + ky) % 2 == 0:
                r, g, b = (r + 100) // 2, (g + 100) // 2, (b + 100) // 2
        out[i] = (min(r, 255), min(g, 255), min(b, 255))
    return out


def partially_sorted_order(n, progress, seed=0x5EED_1234):
    """The permutation after k selection-sort steps: first k correct, rest shuffled."""
    rng = SplitMix64(seed)
    k = int(n * progress)
    rest = list(range(k, n))
    for i in range(len(rest) - 1, 0, -1):
        j = rng.next() % (i + 1)
        rest[i], rest[j] = rest[j], rest[i]
    return list(range(k)) + rest


def render(size=MASTER, progress=0.45):
    # The pattern's features are sized for a 640 wide canvas, so build it there
    # and scale up: at 1024 the rings and checks would be far too fine.
    src_w, src_h = 640, 640
    colors = test_pattern(src_w, src_h)
    order = partially_sorted_order(src_w * src_h, progress)

    img = Image.new("RGB", (src_w, src_h))
    img.putdata([colors[o] for o in order])
    return img.resize((size, size), Image.NEAREST)


MAC_SIZES = [16, 32, 128, 256, 512]


def write_iconset(master, out: pathlib.Path):
    out.mkdir(parents=True, exist_ok=True)
    images = []
    master.save(out / "icon-1024.png")
    images.append({"filename": "icon-1024.png", "idiom": "universal",
                   "platform": "ios", "size": "1024x1024"})
    for s in MAC_SIZES:
        for scale in (1, 2):
            name = f"mac-{s}x{s}@{scale}x.png"
            master.resize((s * scale, s * scale), Image.LANCZOS).save(out / name)
            images.append({"filename": name, "idiom": "mac",
                           "scale": f"{scale}x", "size": f"{s}x{s}"})
    (out / "Contents.json").write_text(json.dumps(
        {"images": images, "info": {"author": "xcode", "version": 1}}, indent=2))
    return len(images)


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--progress", type=float, default=0.45,
                   help="fraction already sorted, 0 is scrambled and 1 is finished")
    p.add_argument("--out", default="SortVisualizer/Assets.xcassets/AppIcon.appiconset")
    a = p.parse_args()
    here = pathlib.Path(os.path.dirname(os.path.abspath(__file__)))
    master = render(progress=a.progress)
    n = write_iconset(master, here / a.out)
    master.save(here / "icon-preview.png")
    print(f"wrote {n} entries, {a.progress:.0%} sorted")


if __name__ == "__main__":
    main()
