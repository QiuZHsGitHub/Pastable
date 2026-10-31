# Pastable · English (U.S.) App Store listing

> Complete copy/paste set for the English localization. The Chinese listing stays in
> [submission-checklist.md](submission-checklist.md); this file only covers the
> English storefront. App name, bundle ID and SKU do not change.

---

## 1. App Store Connect fields

### Name
```
Pastable
```

### Subtitle (≤30 characters)
```
Paste without losing focus.
```
27 characters. This is the short hook; the screenshots and website use the longer
`Paste without breaking your flow.` (33 characters), which does not fit the subtitle limit.

Alternative if you want the subtitle to match the screenshot more literally:
```
Paste without breaking flow.
```
28 characters, but slightly less idiomatic.

### Promotional text (≤170 characters, editable without a new version)
```
A full-width shelf that opens without stealing keyboard focus. Keep typing in your document, pick a card, and paste it back, without breaking your flow.
```
153 characters. No Command/Shift glyphs, so App Store Connect will not reject it.

### Keywords (≤100 characters, comma-separated, no app name)
```
clipboard,paste,history,copy,menubar,shortcut,focus,productivity,snippets
```
73 characters.

### Description
```
Pastable is a full-width clipboard shelf at the bottom of your Mac screen. Summon it, pick a card, and paste it back — without breaking your flow.

[FOCUS NEVER LEAVES YOUR DOCUMENT]
· A global shortcut (Command-Shift-V by default) opens the shelf over any app.
· Opening the shelf does not steal keyboard focus: your cursor and typing stay in the document.
· Pick a card or press Return to paste into the current app; the shelf closes and you keep going.
· The shelf stays put when you switch Spaces or go fullscreen.

[FIND ANYTHING IN SECONDS]
· Exact or fuzzy search across titles and full content; multiple tokens must match.
· Text, code, links, images and files are classified automatically; matches are highlighted.
· Cards preview their content; images get thumbnails so scrolling stays smooth.

[STORAGE WITH MANNERS]
· History stays on your Mac; optional sync uses your own private iCloud CloudKit database.
· Set a retention window and capacity limit; the first time you exceed it, Pastable asks before cleaning up.
· No account, no ads, no tracking, no analytics SDK.

[DETAILS THAT MATTER]
· Auto paste (requires Accessibility; falls back to copy-only).
· Command-1…9 / Fn-1…9 quick paste; configurable global shortcut.
· China Trend "Cinnabar" theme follows system light / dark.
· Launch at login optional.

Requires macOS 15.5 or later.
```

### What's New

1.2.0 (current submission):
```
1.2.0
· Refined panel layout and search field.
· Fixed shelf positioning and cross-Space display issues.
· Theme polish and performance improvements.
```

1.2.1 (next submission):
```
1.2.1
· Added a "Rate on the Mac App Store" link in Settings → About.
· Small performance and stability improvements.
```

### Copyright
```
Copyright © 2026 Qiu ZH
```

---

## 2. English screenshots

Upload these under the **English (U.S.)** localization, in this order:

1. `docs/appstore/screenshots/01-hero-en-2880x1800.png`
2. `docs/appstore/screenshots/02-collection-en-2880x1800.png`

Both are 2880×1800 (16:10), RGB, no alpha. The first one is the 3-second story:

- **Paste without breaking your flow.**
- A full-width shelf at the bottom of the screen.
- It never steals keyboard focus, so the cursor stays in the document.
- A live-looking document with the caret and a “Keyboard focus stays here” callout.
- The actual app shelf at the bottom, captured in English.

The Chinese set stays at:

1. `docs/appstore/screenshots/01-hero-2880x1800.png`
2. `docs/appstore/screenshots/02-collection-2880x1800.png`

Do not mix the Chinese panel into the English screenshots, or vice versa.

---

## 3. URLs and compliance

| Field | Value |
|---|---|
| Privacy Policy URL | `https://qiuzhsgithub.github.io/Pastable/privacy.html` |
| Support URL | `https://qiuzhsgithub.github.io/Pastable/support.html` |
| Marketing URL | `https://qiuzhsgithub.github.io/Pastable/en/` |
| Category | Utilities (primary) / Productivity (secondary) |
| Age rating | 4+ |
| App Privacy | Data Not Collected |
| Price | $1.99 US (¥12 China) |

### App Review Notes
```
Thank you for reviewing Pastable, a local-first macOS clipboard manager.

1. No account or login is required. All history is stored locally (SwiftData);
   optional iCloud sync uses the reviewer-visible private CloudKit database of
   the user's own iCloud account, which we cannot access.
2. "Auto Paste" simulates Command-V into the frontmost app and therefore needs
   the Accessibility permission. The app guides the user to System Settings →
   Privacy & Security → Accessibility. If it is not granted, the app still
   works normally (copy to clipboard instead). This is not a private API; it
   uses CGEvent + AXIsProcessTrusted, which is standard for MAS clipboard
   managers.
3. No private APIs, no analytics, no third-party SDKs, no adult content.

If you need any help, please contact us at the phone/email below.
```

---

## 4. How to add the English localization

1. App Store Connect → Pastable → **App Information** → **Localizations** → add
   **English (U.S.)**.
2. Paste the fields above into the English version page.
3. Upload the two `*-en-2880x1800.png` screenshots under the English localization.
4. Keep the Chinese screenshots under Simplified Chinese; do not replace the
   primary-language set.
5. If the English listing is not added, English storefronts fall back to the
   Chinese primary listing. Adding it is recommended for US/UK search and
   conversion.

> The app itself already ships with English UI strings. The English screenshots
> were captured from the real app in English; the document window and annotations
> are marketing composition, as with the Chinese set.
