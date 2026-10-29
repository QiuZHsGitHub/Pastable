#!/usr/bin/env node
/**
 * render.mjs — reproducible App Store screenshots and the 15s site demo.
 *
 * Uses the Chrome that already ships on macOS through the playwright-core copy
 * in tools/asc-browser. No browser download, no network.
 *
 *   node tools/marketing/render.mjs shots
 *   node tools/marketing/render.mjs demo
 *
 * Outputs:
 *   docs/appstore/screenshots/01-hero-2880x1800.png
 *   docs/appstore/screenshots/02-collection-2880x1800.png
 *   .build/marketing/frames/*.png   (intermediate GIF frames)
 */
import { chromium } from '../asc-browser/node_modules/playwright-core/index.mjs';
import { mkdirSync, writeFileSync, rmSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';

const HERE = dirname(fileURLToPath(import.meta.url));
const ROOT = resolve(HERE, '../..');
const OUT = join(ROOT, 'docs/appstore/screenshots');
const FRAMES = join(ROOT, '.build/marketing/frames');
const CHROME = '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome';

const shot = async (browser, file, output, width = 1440, height = 900) => {
  const page = await browser.newPage({
    viewport: { width, height },
    deviceScaleFactor: 2,
  });
  await page.goto(pathToFileURL(join(HERE, file)).href, { waitUntil: 'load' });
  await page.evaluate(() => document.fonts.ready);
  await page.waitForTimeout(250);
  await page.screenshot({ path: output, type: 'png' });
  console.log(`✓ ${output.replace(ROOT + '/', '')}`);
  await page.close();
};

const shots = async (browser) => {
  mkdirSync(OUT, { recursive: true });
  await shot(browser, 'shot-hero.html', join(OUT, '01-hero-2880x1800.png'));
  await shot(browser, 'shot-collection.html', join(OUT, '02-collection-2880x1800.png'));
};

/* --------------------------------------------------------------------------
 * 15s demo: two language tracks, 1440x900 @1x, downscaled by make_gif.py.
 * The page exposes window.renderDemo(t) where t is seconds (0…15).
 * ------------------------------------------------------------------------ */

const demoScript = (lang) => `(() => {
  const lang = ${JSON.stringify(lang)};
  const copy = lang === 'zh' ? null : {
    file: 'Q4 launch plan.md',
    saved: 'Saved',
    title: 'Launch plan',
    summary: 'Cut the clipboard round-trip down to one summon. Press the shortcut and the last thing you copied appears at the bottom of the screen.',
    typed: 'Note: run the 3-second test once more before shipping.',
    pasted: 'Paste without breaking your flow.',
    week: 'This week',
    li1: 'Homepage: paste without breaking flow',
    li2: 'Ship 1.2.1 by Thursday'
  };
  if (copy) {
    document.querySelector('.doc-name').textContent = copy.file;
    document.querySelector('#doc-state-text').textContent = copy.saved;
    document.querySelector('#doc-title').textContent = copy.title;
    document.querySelector('#doc-week').textContent = copy.week;
    document.querySelector('#doc-li-1').textContent = copy.li1;
    document.querySelector('#doc-li-2').textContent = copy.li2;
    document.querySelector('.pasted').textContent = copy.pasted;
  }
  const typedText = copy ? copy.typed : '备注：发布前再跑一遍 3 秒测试。';
  const captions = lang === 'zh' ? [
    [0.7, 4.2, '① 随手呼出，工作没停'],
    [4.2, 8.2, '② 键盘焦点始终留在文档'],
    [8.2, 12.2, '③ Enter 回贴，接着写'],
    [12.2, 15.0, '呼出即贴，不打断手头工作']
  ] : [
    [0.7, 4.2, '① Summon without switching apps'],
    [4.2, 8.2, '② Focus stays in your document'],
    [8.2, 12.2, '③ Hit Enter. Keep writing.'],
    [12.2, 15.0, 'Paste without breaking your flow']
  ];
  const cap = document.querySelector('.demo-caption');
  const keys = document.querySelector('.demo-keys');
  const panel = document.querySelector('.panel');
  const selection = document.querySelector('.selection');
  const enter = document.querySelector('.enter-key');
  const callout = document.querySelector('.callout');
  const caret = document.querySelector('.caret');
  const typed = document.querySelector('.typed');
  const pasted = document.querySelector('.pasted');
  const docP = document.querySelector('.demo .doc-p:last-of-type');

  const setOpacity = (el, v) => { el.style.opacity = String(Math.max(0, Math.min(1, v))); };

  window.renderDemo = (t) => {
    // Document and panel states.
    panel.style.display = (t >= 2.0 && t < 8.8) ? 'block' : 'none';
    selection.style.opacity = (t >= 5.2 && t < 8.8) ? '1' : '0';
    enter.style.opacity = (t >= 7.2 && t < 8.8) ? '1' : '0';
    keys.style.opacity = (t >= 1.45 && t < 2.0) ? '1' : '0';
    keys.style.transform = 'translateX(-50%) scale(' + (t >= 1.45 && t < 2.0 ? 1 : 0.94) + ')';
    callout.style.opacity = (t >= 2.6 && t < 8.8) ? '1' : '0';

    // Panel visibility is instantaneous, like the app; the short fade only
    // softens the cut between GIF frames.
    if (t >= 2.0 && t < 2.25) setOpacity(panel, (t - 2.0) / 0.25);
    else if (t >= 8.8 && t < 9.05) setOpacity(panel, 1 - (t - 8.8) / 0.25);
    else setOpacity(panel, 1);

    // Typing continues while the panel is open: this is the whole point.
    if (t < 8.8) {
      typed.textContent = typedText;
      pasted.style.display = 'none';
      caret.style.display = 'inline-block';
    } else {
      typed.style.display = 'none';
      pasted.style.display = 'inline';
      caret.style.display = 'none';
    }

    // Caption text + fade at the edges.
    const line = captions.find(([a, b]) => t >= a && t < b) || captions[captions.length - 1];
    cap.textContent = '';
    const dot = document.createElement('i');
    cap.appendChild(dot);
    cap.appendChild(document.createTextNode(line[2]));
    if (t >= line[0] && t < line[0] + 0.25) setOpacity(cap, (t - line[0]) / 0.25);
    else if (t >= line[1] - 0.25 && t < line[1]) setOpacity(cap, (line[1] - t) / 0.25);
    else setOpacity(cap, 1);
  };
  window.renderDemo(0);
  document.fonts.ready.then(() => { window.__fontsReady = true; });
})();`;

const demo = async (browser) => {
  mkdirSync(FRAMES, { recursive: true });
  rmSync(FRAMES, { recursive: true, force: true });
  for (const lang of ['zh', 'en']) {
    const langDir = join(FRAMES, lang);
    mkdirSync(langDir, { recursive: true });
    const page = await browser.newPage({
      viewport: { width: 1440, height: 900 },
      deviceScaleFactor: 1,
    });
    await page.goto(pathToFileURL(join(HERE, 'demo.html')).href + `?lang=${lang}`, {
      waitUntil: 'load',
    });
    await page.evaluate(() => document.fonts.ready);
    await page.waitForTimeout(300);
    await page.evaluate(demoScript(lang));
    await page.waitForTimeout(200);
    const fps = 12;
    const total = 15;
    const count = fps * total;
    for (let i = 0; i < count; i++) {
      const t = i / fps;
      await page.evaluate((time) => window.renderDemo(time), t);
      await page.screenshot({
        path: join(langDir, `${String(i).padStart(4, '0')}.png`),
        type: 'png',
      });
      if (i % 24 === 0) process.stdout.write(`  ${lang} ${i}/${count}\r`);
    }
    writeFileSync(join(langDir, `meta.json`), JSON.stringify({ fps, total, count }));
    console.log(`✓ frames ${lang}`);
    await page.close();
  }
};

const main = async () => {
  const cmd = process.argv[2] || 'shots';
  const browser = await chromium.launch({ executablePath: CHROME, headless: true });
  try {
    if (cmd === 'shots') await shots(browser);
    else if (cmd === 'demo') await demo(browser);
    else throw new Error(`unknown command: ${cmd}`);
  } finally {
    await browser.close();
  }
};

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
