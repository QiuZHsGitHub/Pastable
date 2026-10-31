# Marketing assets

Reproducible App Store screenshots and the 15-second site demo. Everything is
local: no network, no third-party services, and no fonts beyond macOS.

## Requirements

- Google Chrome at `/Applications/Google Chrome.app`
- `playwright-core` (install with `cd tools/asc-browser && npm install`, or provide it locally)
- Pillow (`python3 -m pip install pillow` if your Python does not have it)

## Commands

```bash
# 2880×1800 App Store screenshots (deviceScaleFactor 2)
node tools/marketing/render.mjs shots

# 15s demo frames, 1440×900 @ 12fps, both languages
node tools/marketing/render.mjs demo

# GIF + poster, 960×600, ~1.8 MB each
python3 tools/marketing/make_gif.py
```

Outputs:

| Path | Purpose |
|---|---|
| `docs/appstore/screenshots/01-hero-2880x1800.png` | First App Store shot: 3-second story (Chinese) |
| `docs/appstore/screenshots/02-collection-2880x1800.png` | Content types + search (Chinese) |
| `docs/appstore/screenshots/01-hero-en-2880x1800.png` | English first shot |
| `docs/appstore/screenshots/02-collection-en-2880x1800.png` | English content types + search |
| `docs/appstore/screenshots/01-hero-hant-2880x1800.png` | Traditional Chinese first shot |
| `docs/appstore/screenshots/02-collection-hant-2880x1800.png` | Traditional Chinese content types + search |
| `docs/appstore/screenshots/01-hero-ja-2880x1800.png` | Japanese first shot |
| `docs/appstore/screenshots/02-collection-ja-2880x1800.png` | Japanese content types + search |
| `docs/assets/site/demo-zh.gif` / `demo-en.gif` | Website hero demo |
| `docs/assets/site/demo-zh-poster.webp` / `demo-en-poster.webp` | Reduced-motion fallback |

## First screenshot rule

The first image must communicate **full-width bottom shelf + does not interrupt
the current work** within three seconds. It is not a panel-only screenshot:

- headline: 呼出即贴，不打断手头工作。
- subline: 全屏宽的底部浮层 / 打开时不抢键盘焦点
- a real-looking document behind the shelf, with a visible caret
- a callout pointing at the caret: 键盘焦点还在这里
- the actual panel capture at the bottom

Before uploading, show it to someone for three seconds and ask them to repeat
the message. If they only say "a clipboard screenshot", redo it.

## English panel captures

The English screenshots use real panel captures, not the Chinese bitmap:

```bash
PASTABLE_STORAGE_DIR=/tmp/PastableEN \
  .build/.../Pastable.app/Contents/MacOS/Pastable \
  --show-panel -AppleLanguages '(en)' -AppleLocale en_US

# find the panel window number, then:
screencapture -x -o -l <window-number> \
  docs/appstore/screenshots/raw/panel-en-dark.png
```

Add `--ui-appearance light` for `panel-en-light.png`. Seed a temporary store with
text/code/link/image samples first; do not point this at the real clipboard
database.

## Notes

- The panel itself is the real capture from `docs/appstore/screenshots/raw/`.
  The English panels were captured from the Debug app running with
  `-AppleLanguages '(en)'` and a seeded temporary store, then saved as
  `raw/panel-en-{dark,light}.png`.
- The document window and annotations are marketing composition, not app UI.
- The demo GIF is an interaction illustration; it is labelled "交互示意" on the
  site. Do not present it as a screen recording.
- The GIF uses `disposal=1` and a 160-colour adaptive palette. `disposal=2`
  produces a much larger file; keep the current settings unless the visual
  quality regresses.
- The GIF intentionally has no app icon: a tiny orange raster icon is the first
  thing an adaptive GIF palette drops, and it turns into a muddy square.
