#!/usr/bin/env python3
"""Assemble the 15s demo GIF + poster from render.mjs frames.

    python3 tools/marketing/make_gif.py

Reads .build/marketing/frames/{zh,en}/0000.png … and writes
docs/assets/site/demo-{zh,en}.gif plus -poster.webp.
"""
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
FRAMES = ROOT / ".build/marketing/frames"
OUT = ROOT / "docs/assets/site"
SIZE = (960, 600)
FPS = 12
POSTER_FRAME = 72  # 6.0s: panel open, card selected, focus callout visible


def frames_for(lang: str):
    folder = FRAMES / lang
    paths = sorted(folder.glob("*.png"))
    if not paths:
        raise SystemExit(f"no frames in {folder}; run: node tools/marketing/render.mjs demo")
    return paths


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    for lang in ("zh", "en"):
        paths = frames_for(lang)
        images = []
        for path in paths:
            image = Image.open(path).convert("RGB").resize(SIZE, Image.Resampling.LANCZOS)
            images.append(image.convert("P", palette=Image.Palette.ADAPTIVE, colors=160))

        gif = OUT / f"demo-{lang}.gif"
        images[0].save(
            gif,
            save_all=True,
            append_images=images[1:],
            duration=84,
            loop=0,
            optimize=True,
            disposal=1,
            comment="Pastable 15s interaction demo",
        )
        poster = Image.open(paths[POSTER_FRAME]).convert("RGB").resize(SIZE, Image.Resampling.LANCZOS)
        poster.save(OUT / f"demo-{lang}-poster.webp", "WEBP", quality=88, method=6)
        print(f"✓ {gif.relative_to(ROOT)}  {gif.stat().st_size / 1024 / 1024:.2f} MB")
        print(f"✓ demo-{lang}-poster.webp")


if __name__ == "__main__":
    main()
