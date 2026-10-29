#!/usr/bin/env python3
"""Generate the static-site image assets for docs/ (GitHub Pages).

Sources:
  docs/appstore/screenshots/raw/panel-{dark,light}.png
  Pastable/Assets.xcassets/AppIcon.appiconset/icon_1024x1024.png

Outputs:
  docs/assets/site/panel-{dark,light}.webp
  docs/assets/site/icon-*.png, apple-touch-icon.png
  docs/assets/site/og-cover.png
"""

from __future__ import annotations

import os
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "docs" / "assets" / "site"
OUT.mkdir(parents=True, exist_ok=True)

INK = (27, 24, 22)
MUTED = (92, 85, 76)
INK_2 = (74, 68, 61)
PAPER = (245, 240, 233)
CINNABAR = (200, 64, 46)
CINNABAR_DARK = (224, 82, 59)
WHITE = (255, 253, 251)

SONGTI = "/System/Library/Fonts/Supplemental/Songti.ttc"
PINGFANG = "/System/Library/Fonts/PingFang.ttc"
HELVETICA = "/System/Library/Fonts/Helvetica.ttc"
GEORGIA = "/System/Library/Fonts/Supplemental/Georgia.ttf"


def font(path: str, size: int, index: int = 0) -> ImageFont.FreeTypeFont:
    try:
        return ImageFont.truetype(path, size=size, index=index)
    except OSError:
        return ImageFont.truetype(HELVETICA, size=size, index=0)


def build_panels() -> None:
    for name in ("panel-dark", "panel-light"):
        src = ROOT / "docs" / "appstore" / "screenshots" / "raw" / f"{name}.png"
        im = Image.open(src).convert("RGBA")
        width = 2400
        im = im.resize((width, round(im.height * width / im.width)), Image.LANCZOS)
        im.save(OUT / f"{name}.webp", "WEBP", quality=90, method=6)
        print("wrote", OUT / f"{name}.webp")


def build_icons() -> None:
    icon = Image.open(
        ROOT / "Pastable" / "Assets.xcassets" / "AppIcon.appiconset" / "icon_1024x1024.png"
    ).convert("RGBA")
    for size in (512, 192, 180, 64, 32):
        im = icon.resize((size, size), Image.LANCZOS)
        name = "apple-touch-icon.png" if size == 180 else f"icon-{size}.png"
        im.save(OUT / name, optimize=True)
        print("wrote", OUT / name)


def _og_shell() -> Image.Image:
    """1200x630 paper card with the cinnabar wash and watermark."""
    W, H = 1200, 630
    img = Image.new("RGB", (W, H), PAPER)
    glow = Image.new("RGB", (W, H), PAPER)
    gd = ImageDraw.Draw(glow)
    for radius in range(520, 0, -8):
        alpha = int(26 * (1 - radius / 520) ** 2)
        gd.ellipse(
            (W - 250 - radius, -230 - radius, W - 250 + radius, -230 + radius),
            fill=(PAPER[0] + alpha // 3, PAPER[1] - alpha // 8, PAPER[2] - alpha // 4),
        )
    img = Image.blend(img, glow, 0.55)
    d = ImageDraw.Draw(img)
    wm = font(SONGTI, 640, index=0)
    d.text((W - 20, H - 210), "P", font=wm, fill=(238, 229, 219), anchor="rs")
    icon = Image.open(OUT / "icon-512.png").convert("RGBA").resize((96, 96), Image.LANCZOS)
    img.paste(icon, (80, 74), icon)
    d.text((196, 84), "Pastable", font=font(HELVETICA, 46, index=1), fill=INK)
    d.text((198, 140), "macOS CLIPBOARD MANAGER", font=font(HELVETICA, 15, 0), fill=(142, 134, 125))
    d.line((80, 536, W - 80, 536), fill=(216, 205, 192), width=1)
    d.text((80, 558), "PASTABLE  ·  FOR macOS 15.5+", font=font(HELVETICA, 14, 0), fill=(142, 134, 125))
    d.text((W - 80, 552), "Mac App Store", font=font(HELVETICA, 20, 0), fill=CINNABAR, anchor="ra")
    return img


def build_og() -> None:
    """Chinese and English social cards."""
    zh = _og_shell()
    d = ImageDraw.Draw(zh)
    d.text((80, 236), "复制过的，", font=font(SONGTI, 78, index=0), fill=INK)
    d.text((80, 340), "随时召回来。", font=font(SONGTI, 78, index=0), fill=CINNABAR)
    d.text(
        (84, 462),
        "轻巧、快速的剪贴板管理器  ·  本地优先，无账号，无追踪",
        font=font(SONGTI, 25, 0),
        fill=MUTED,
    )
    zh.save(OUT / "og-cover.png", optimize=True)
    print("wrote", OUT / "og-cover.png")

    en = _og_shell()
    d = ImageDraw.Draw(en)
    d.text((80, 228), "Everything you copied,", font=font(GEORGIA, 58, index=0), fill=INK)
    d.text((80, 312), "one shortcut away.", font=font(GEORGIA, 70, index=0), fill=CINNABAR)
    d.text(
        (84, 432),
        "A lightweight, fast clipboard manager for macOS.",
        font=font(GEORGIA, 28, 0),
        fill=INK_2,
    )
    d.text(
        (84, 476),
        "Local-first  ·  No account  ·  No tracking",
        font=font(HELVETICA, 20, 0),
        fill=MUTED,
    )
    en.save(OUT / "og-cover-en.png", optimize=True)
    print("wrote", OUT / "og-cover-en.png")


if __name__ == "__main__":
    build_panels()
    build_icons()
    build_og()
