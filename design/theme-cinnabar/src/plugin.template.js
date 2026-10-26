/* Pastable · 中国潮色（朱砂）— Figma generator
 * Injected with tokens.json by build.mjs. Run via Plugins → Development.
 */

const TOKENS = /*__TOKENS__*/;

const PAGE_NAME = 'Pastable / UI 2026 · 中国潮色';
const W = 1512;
const H = 325;

const CAT = TOKENS.global.color.category;
const ACCENT_SCALE = TOKENS.global.color.accent;

const hexOf = (token) => (token && typeof token === 'object' && '$value' in token ? token.$value : token);
const CAT_HEX = {
  all: hexOf(CAT.all),
  text: hexOf(CAT.text),
  code: hexOf(CAT.code),
  link: hexOf(CAT.link),
  media: hexOf(CAT.media),
  color: hexOf(CAT.color)
};

function rgb(hex) {
  const h = String(hex).replace('#', '');
  return {
    r: parseInt(h.slice(0, 2), 16) / 255,
    g: parseInt(h.slice(2, 4), 16) / 255,
    b: parseInt(h.slice(4, 6), 16) / 255
  };
}

function solid(hex, opacity = 1) {
  return { type: 'SOLID', color: rgb(hex), opacity };
}

function rgba(hex, a) {
  return Object.assign(rgb(hex), { a });
}

function mix(a, b, ratio) {
  const A = String(a).replace('#', '');
  const B = String(b).replace('#', '');
  const out = [0, 2, 4].map((i) => {
    const x = parseInt(A.slice(i, i + 2), 16);
    const y = parseInt(B.slice(i, i + 2), 16);
    return Math.round(x * ratio + y * (1 - ratio)).toString(16).padStart(2, '0');
  });
  return '#' + out.join('').toUpperCase();
}

/* Top-to-bottom linear gradient. Figma maps gradient space (0,0)→(1,0)
 * through the transform, so this matrix turns it into (0,0)→(0,1). */
function gradient(stops, vertical = true) {
  return {
    type: 'GRADIENT_LINEAR',
    gradientTransform: vertical ? [[0, 1, 0], [1, 0, 0]] : [[1, 0, 0], [0, 1, 0]],
    gradientStops: stops.map((stop) => ({
      position: stop[0],
      color: rgba(stop[1], stop[2] === undefined ? 1 : stop[2])
    }))
  };
}

function shadow(hex, alpha, radius, x = 0, y = 0) {
  return {
    type: 'DROP_SHADOW',
    color: rgba(hex, alpha),
    offset: { x, y },
    radius,
    spread: 0,
    visible: true,
    blendMode: 'NORMAL'
  };
}

/* ---------- fonts ---------- */

let FONT = {};

async function resolveFonts() {
  const available = await figma.listAvailableFontsAsync();
  const find = (families, styles) => {
    for (const family of families) {
      for (const style of styles) {
        const hit = available.find(
          (entry) => entry.fontName.family === family && entry.fontName.style === style
        );
        if (hit) return hit.fontName;
      }
    }
    return null;
  };

  const uiFamilies = ['PingFang SC', 'SF Pro Text', 'SF Pro', 'Noto Sans SC', 'Inter'];
  const monoFamilies = ['SF Mono', 'Menlo', 'Roboto Mono', 'Inter'];
  const displayFamilies = ['Songti SC', 'STSong', 'Noto Serif SC', 'PingFang SC'];

  const fallback = find(['Inter'], ['Regular']) ||
    (available[0] && available[0].fontName) || { family: 'Inter', style: 'Regular' };

  FONT = {
    regular: find(uiFamilies, ['Regular', 'Normal']) || fallback,
    medium: find(uiFamilies, ['Medium', 'Regular']) || fallback,
    semibold: find(uiFamilies, ['Semibold', 'SemiBold', 'Bold', 'Medium']) || fallback,
    bold: find(uiFamilies, ['Bold', 'Semibold', 'Medium']) || fallback,
    mono: find(monoFamilies, ['Regular', 'Medium']) || fallback,
    monoMedium: find(monoFamilies, ['Medium', 'Semibold', 'Regular']) || fallback,
    display: find(displayFamilies, ['Bold', 'Semibold', 'Regular']) || fallback
  };

  const loaded = {};
  for (const key of Object.keys(FONT)) {
    const font = FONT[key];
    const id = font.family + '|' + font.style;
    if (loaded[id]) continue;
    loaded[id] = true;
    await figma.loadFontAsync(font);
  }
}

/* ---------- primitives ---------- */

function makeFrame(parent, name, x, y, w, h, opts = {}) {
  const frame = figma.createFrame();
  parent.appendChild(frame);
  frame.name = name;
  frame.resize(w, h);
  frame.x = x;
  frame.y = y;
  frame.fills = opts.fill ? [opts.fill] : [];
  if (opts.radius !== undefined) frame.cornerRadius = opts.radius;
  if (opts.stroke) {
    frame.strokes = [solid(opts.stroke)];
    frame.strokeWeight = opts.strokeWeight || 1;
    frame.strokeAlign = 'INSIDE';
  }
  frame.clipsContent = opts.clip !== false;
  return frame;
}

function makeRect(parent, name, x, y, w, h, fill, radius = 0) {
  const rect = figma.createRectangle();
  parent.appendChild(rect);
  rect.name = name;
  rect.resize(w, h);
  rect.x = x;
  rect.y = y;
  rect.fills = fill ? [fill] : [];
  if (radius) rect.cornerRadius = radius;
  return rect;
}

function addText(parent, chars, x, y, opts = {}) {
  const text = figma.createText();
  parent.appendChild(text);
  text.fontName = opts.font || FONT.regular;
  text.characters = String(chars);
  text.fontSize = opts.size || 13;
  text.fills = [solid(opts.color || '#FFFDFB', opts.opacity === undefined ? 1 : opts.opacity)];
  if (opts.lineHeight) text.lineHeight = { unit: 'PIXELS', value: opts.lineHeight };
  if (opts.letterSpacing) text.letterSpacing = { unit: 'PIXELS', value: opts.letterSpacing };
  text.textAlignHorizontal = opts.align || 'LEFT';
  if (opts.width) {
    text.textAutoResize = 'HEIGHT';
    text.resize(Math.max(1, opts.width), Math.max(1, text.height));
  } else {
    text.textAutoResize = 'WIDTH_AND_HEIGHT';
  }
  text.x = x;
  text.y = y;
  return text;
}

function makeDot(parent, color, size, x, y) {
  const dot = figma.createEllipse();
  parent.appendChild(dot);
  dot.name = 'dot';
  dot.resize(size, size);
  dot.x = x;
  dot.y = y;
  dot.fills = [solid(color)];
  return dot;
}

function makePill(parent, label, tint, bg, textColor, x, y) {
  const pill = figma.createFrame();
  parent.appendChild(pill);
  pill.name = 'Pill / ' + label;
  pill.layoutMode = 'HORIZONTAL';
  pill.counterAxisAlignItems = 'CENTER';
  pill.itemSpacing = 5;
  pill.paddingLeft = 8;
  pill.paddingRight = 8;
  pill.paddingTop = 4;
  pill.paddingBottom = 4;
  pill.fills = [solid(bg)];
  pill.cornerRadius = 11;
  pill.clipsContent = false;

  const dot = figma.createEllipse();
  pill.appendChild(dot);
  dot.resize(6, 6);
  dot.fills = [solid(tint)];

  const text = figma.createText();
  pill.appendChild(text);
  text.fontName = FONT.medium;
  text.characters = label;
  text.fontSize = 11;
  text.lineHeight = { unit: 'PIXELS', value: 14 };
  text.fills = [solid(textColor)];
  text.textAutoResize = 'WIDTH_AND_HEIGHT';

  pill.primaryAxisSizingMode = 'AUTO';
  pill.counterAxisSizingMode = 'AUTO';
  pill.x = x;
  pill.y = y;
  return pill;
}

function makeTab(parent, t, label, dotColor, selected, x, y) {
  const bg = selected ? hexOf(t.control.tab.selectedBackground) : hexOf(t.control.tab.background);
  const border = selected ? hexOf(t.accent.base) : hexOf(t.control.tab.border);
  const textColor = selected ? hexOf(t.control.tab.textSelected) : hexOf(t.control.tab.text);

  const tab = figma.createFrame();
  parent.appendChild(tab);
  tab.name = 'Tab / ' + label;
  tab.layoutMode = 'HORIZONTAL';
  tab.counterAxisAlignItems = 'CENTER';
  tab.itemSpacing = 6;
  tab.paddingLeft = 13;
  tab.paddingRight = 13;
  tab.paddingTop = 0;
  tab.paddingBottom = 0;
  tab.fills = [solid(bg)];
  tab.strokes = [solid(border)];
  tab.strokeWeight = 1;
  tab.strokeAlign = 'INSIDE';
  tab.cornerRadius = 9;
  tab.clipsContent = false;

  const dot = figma.createEllipse();
  tab.appendChild(dot);
  dot.resize(5, 5);
  dot.fills = [solid(selected ? hexOf(t.accent.base) : dotColor)];

  const text = figma.createText();
  tab.appendChild(text);
  text.fontName = selected ? FONT.semibold : FONT.regular;
  text.characters = label;
  text.fontSize = 13.5;
  text.lineHeight = { unit: 'PIXELS', value: 16 };
  text.fills = [solid(textColor)];
  text.textAutoResize = 'WIDTH_AND_HEIGHT';

  tab.primaryAxisSizingMode = 'AUTO';
  tab.counterAxisSizingMode = 'FIXED';
  tab.resize(tab.width, 32);
  tab.x = x;
  tab.y = y;
  return tab;
}

function makeSearchIcon(parent, color, x, y) {
  const icon = figma.createNodeFromSvg(
    '<svg xmlns="http://www.w3.org/2000/svg" width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="' +
    color +
    '" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">' +
    '<circle cx="11" cy="11" r="8"/><path d="m21 21-4.3-4.3"/></svg>'
  );
  parent.appendChild(icon);
  icon.name = 'icon / search';
  icon.x = x;
  icon.y = y;
  return icon;
}

/* ---------- panel ---------- */

function addFooter(card, t, spec) {
  const footer = makeFrame(card, 'Footer', 12, 207, 236, 22, { clip: false });

  const icon = makeFrame(footer, 'App icon', 0, 3, 16, 16, {
    fill: gradient([[0, hexOf(t.accent.base)], [1, '#8C281C']], false),
    radius: 4
  });
  addText(icon, 'P', 0, 3, {
    font: FONT.bold,
    size: 9,
    color: '#FFFDFB',
    width: 16,
    align: 'CENTER',
    lineHeight: 10
  });

  addText(footer, '21 分钟前', 22, 4, {
    size: 11.5,
    color: hexOf(t.text.secondary),
    lineHeight: 14
  });

  const pill = makePill(
    footer,
    spec.label,
    spec.tint,
    hexOf(t.control.pill.background),
    hexOf(t.control.pill.text),
    0,
    0
  );
  pill.x = 236 - pill.width;

  addText(footer, spec.detail, pill.x - 8 - 80, 4, {
    size: 11.5,
    color: hexOf(t.text.tertiary),
    width: 80,
    align: 'RIGHT',
    lineHeight: 14
  });
}

function addCardContent(card, t, spec) {
  const content = makeFrame(card, 'Content', 12, 12, 236, 185, { clip: true });

  if (spec.kind === 'image') {
    const photo = makeFrame(content, 'Photo', 0, 0, 236, 185, {
      fill: gradient([
        [0, '#E0523B'],
        [0.36, '#8C281C'],
        [0.7, '#2A1512'],
        [1, '#14110F']
      ]),
      radius: 6,
      stroke: hexOf(t.surface.card.imageBorder)
    });
    photo.clipsContent = true;
    const mountain = figma.createNodeFromSvg(
      '<svg xmlns="http://www.w3.org/2000/svg" width="236" height="185" viewBox="0 0 236 185">' +
      '<path d="M0 148 L58 92 L106 130 L158 70 L236 138 L236 185 L0 185 Z" fill="#14110F" fill-opacity="0.55"/>' +
      '<path d="M0 166 L46 128 L94 158 L152 112 L236 166 L236 185 L0 185 Z" fill="#0E0C0B" fill-opacity="0.72"/>' +
      '</svg>'
    );
    photo.appendChild(mountain);
    mountain.x = 0;
    mountain.y = 0;

    addText(content, 'SCREENSHOT · 3024 × 650', 10, 168, {
      font: FONT.mono,
      size: 9,
      color: '#FFFDFB',
      opacity: 0.55,
      letterSpacing: 0.7,
      lineHeight: 10
    });
  } else if (spec.kind === 'color') {
    makeRect(content, 'Swatch', 0, 0, 236, 185, solid(CAT_HEX.color), 6);
    makeRect(content, 'Chip', 68, 75, 100, 34, solid('#14110F'), 8);
    addText(content, CAT_HEX.color.toUpperCase(), 68, 82, {
      font: FONT.monoMedium,
      size: 16,
      color: '#FFFDFB',
      width: 100,
      align: 'CENTER',
      lineHeight: 20
    });
  } else if (spec.kind === 'code') {
    addText(content, '{"name":"Pastable",\n "theme":"cinnabar",\n "accent":"#C8402E"}', 0, 0, {
      font: FONT.mono,
      size: 13,
      color: hexOf(t.text.body),
      width: 236,
      lineHeight: 18
    });
  } else if (spec.kind === 'code2') {
    addText(content, 'func greet(name: String) {\n  print("你好，\\(name)")\n}', 0, 0, {
      font: FONT.mono,
      size: 13,
      color: hexOf(t.text.body),
      width: 236,
      lineHeight: 18
    });
  } else if (spec.kind === 'link') {
    addText(content, 'https://github.com/QiuZHsGitHub/Pastable', 0, 0, {
      size: 13,
      color: hexOf(t.text.body),
      width: 236,
      lineHeight: 18
    });
  } else {
    addText(content, '下午三点评审「中国潮色」主题，\n记得带上色卡和充电器。', 0, 0, {
      size: 13,
      color: hexOf(t.text.body),
      width: 236,
      lineHeight: 18
    });
  }
}

function addCard(parent, t, spec, x, index) {
  const base = hexOf(t.surface.card.base);
  const ratio = spec.selected ? hexOf(t.card.tint.selected) : hexOf(t.card.tint.normal);
  const top = mix(spec.tint, base, ratio);
  const border = spec.selected ? hexOf(t.accent.base) : hexOf(t.surface.card.border);

  const card = makeFrame(parent, 'Card / ' + spec.kind + ' / ' + index, x, 68, 260, 241, {
    fill: gradient([[0, top], [1, base]]),
    radius: 14,
    stroke: border,
    strokeWeight: spec.selected ? 1.5 : 1
  });

  const effects = [];
  if (spec.selected) effects.push(shadow(hexOf(t.accent.base), hexOf(t.accent.glow), 10));
  effects.push(shadow('#000000', t === TOKENS.themes.dark ? 0.26 : 0.09, 18, 0, 10));
  effects.push(shadow('#000000', t === TOKENS.themes.dark ? 0.14 : 0.05, 6, 0, 4));
  card.effects = effects;

  addCardContent(card, t, spec);
  addFooter(card, t, spec);
  return card;
}

function addPanel(mode, x, y) {
  const t = TOKENS.themes[mode];
  const panel = makeFrame(figma.currentPage, '潮色 / 01 Panel · ' + (mode === 'dark' ? 'Dark' : 'Light'), x, y, W, H, {
    fill: gradient([
      [0, hexOf(t.surface.panel.top)],
      [0.16, hexOf(t.surface.panel.mid)],
      [1, hexOf(t.surface.panel.bottom)]
    ]),
    stroke: hexOf(t.surface.panel.border)
  });
  panel.cornerRadius = 0;
  panel.topLeftRadius = 24;
  panel.topRightRadius = 24;
  panel.clipsContent = true;

  const header = makeFrame(panel, 'Header', 24, 16, W - 48, 36, { clip: false });

  const tabRow = figma.createFrame();
  header.appendChild(tabRow);
  tabRow.name = 'Tabs';
  tabRow.layoutMode = 'HORIZONTAL';
  tabRow.itemSpacing = 8;
  tabRow.paddingLeft = 0;
  tabRow.paddingRight = 0;
  tabRow.paddingTop = 0;
  tabRow.paddingBottom = 0;
  tabRow.fills = [];
  tabRow.clipsContent = false;
  tabRow.x = 0;
  tabRow.y = 2;

  const tabs = [
    ['全部', hexOf(t.accent.base), true],
    ['文本', CAT_HEX.text, false],
    ['代码', CAT_HEX.code, false],
    ['链接', CAT_HEX.link, false],
    ['媒体', CAT_HEX.media, false]
  ];
  for (const [label, dot, selected] of tabs) {
    makeTab(tabRow, t, label, dot, selected, 0, 0);
  }
  tabRow.primaryAxisSizingMode = 'AUTO';
  tabRow.counterAxisSizingMode = 'AUTO';

  const search = makeFrame(header, 'Search', W - 48 - 800, 0, 800, 36, {
    fill: solid(hexOf(t.control.search.background)),
    radius: 10,
    stroke: hexOf(t.accent.base)
  });
  search.effects = [shadow(hexOf(t.accent.base), 0.12, 8)];

  makeSearchIcon(search, hexOf(t.text.tertiary), 14, 11);
  addText(search, '搜索', 40, 10, {
    size: 13,
    color: hexOf(t.text.placeholder),
    lineHeight: 16
  });
  makeRect(search, 'Caret', 68, 11, 1, 15, solid(hexOf(t.accent.base)));
  addText(search, '⌘⇧F', 682, 12, {
    font: FONT.mono,
    size: 10,
    color: hexOf(t.text.tertiary),
    width: 60,
    align: 'RIGHT',
    lineHeight: 12
  });
  makeRect(search, 'Divider', 749, 9, 1, 18, solid(hexOf(t.control.search.divider)));
  addText(search, '⋯', 758, 8, {
    size: 14,
    color: hexOf(t.text.secondary),
    width: 32,
    align: 'CENTER',
    lineHeight: 20
  });

  const cards = [
    { kind: 'image', tint: CAT_HEX.media, label: '图片', detail: '8 KB', selected: true },
    { kind: 'code', tint: CAT_HEX.code, label: '代码', detail: '73 字' },
    { kind: 'color', tint: CAT_HEX.color, label: '颜色', detail: '7 字' },
    { kind: 'link', tint: CAT_HEX.link, label: '链接', detail: '40 字' },
    { kind: 'text', tint: CAT_HEX.text, label: '文本', detail: '21 字' },
    { kind: 'code2', tint: CAT_HEX.code, label: '代码', detail: '24 字' }
  ];
  cards.forEach((spec, index) => {
    addCard(panel, t, spec, 24 + index * 276, index);
  });

  return panel;
}

/* ---------- cover ---------- */

function addCover() {
  const t = TOKENS.themes.dark;
  const cover = makeFrame(figma.currentPage, '潮色 / 00 Cover', 0, 0, W, 460, {
    fill: gradient([[0, '#2C2A29'], [0.55, '#1B1918'], [1, '#141211']])
  });

  addText(cover, 'PASTABLE · UI 2026 / THEME PROPOSAL', 64, 56, {
    font: FONT.mono,
    size: 11,
    color: hexOf(t.text.tertiary),
    letterSpacing: 1.2,
    lineHeight: 14
  });

  addText(cover, '朱砂', 60, 82, {
    font: FONT.display,
    size: 128,
    color: hexOf(t.text.primary),
    lineHeight: 144
  });

  addText(cover, 'CINNABAR', 66, 238, {
    font: FONT.monoMedium,
    size: 20,
    color: hexOf(t.accent.base),
    letterSpacing: 4,
    lineHeight: 24
  });

  addText(cover, '中国潮色 · 把传统颜料译成界面 Token', 66, 272, {
    size: 17,
    color: hexOf(t.text.secondary),
    lineHeight: 24
  });

  addText(cover, '以美图「中国潮色」的朱砂红为锚点，重映射 Pastable 的语义色、卡片底色与分类色。', 66, 306, {
    size: 12.5,
    color: hexOf(t.text.tertiary),
    lineHeight: 18
  });

  addText(cover, 'v0.1 · 2026.10', W - 64 - 140, 56, {
    font: FONT.mono,
    size: 11,
    color: hexOf(t.text.tertiary),
    width: 140,
    align: 'RIGHT',
    lineHeight: 14
  });

  const seal = makeFrame(cover, 'Seal', 1230, 126, 160, 160, {
    fill: solid(hexOf(t.accent.base)),
    radius: 6
  });
  seal.effects = [shadow(hexOf(t.accent.base), 0.3, 30, 0, 14)];
  seal.rotation = -6;
  addText(seal, '朱', 0, 18, {
    font: FONT.display,
    size: 96,
    color: '#FFFDFB',
    width: 160,
    align: 'CENTER',
    lineHeight: 116
  });

  const chips = [
    ['朱砂', ACCENT_SCALE['500'].$value],
    ['晓山青', CAT_HEX.text],
    ['青花蓝', CAT_HEX.code],
    ['木槿紫', CAT_HEX.link],
    ['黛子粉', CAT_HEX.media]
  ];
  chips.forEach(([name, hex], index) => {
    const chip = makeFrame(cover, 'Palette / ' + name, 64 + index * 162, 356, 150, 56, {
      fill: solid('#1B1918'),
      radius: 8,
      stroke: '#302C2A'
    });
    makeRect(chip, 'Bar', 0, 0, 6, 56, solid(hex), 0);
    addText(chip, name, 18, 10, {
      size: 12,
      color: hexOf(t.text.primary),
      lineHeight: 15
    });
    addText(chip, hex, 18, 30, {
      font: FONT.mono,
      size: 10,
      color: hexOf(t.text.tertiary),
      lineHeight: 12
    });
  });

  return cover;
}

/* ---------- tokens ---------- */

function addTokens() {
  const t = TOKENS.themes.dark;
  const board = makeFrame(figma.currentPage, '潮色 / 03 Tokens', 0, 1300, W, 980, {
    fill: solid('#141211')
  });

  addText(board, 'DESIGN TOKENS', 64, 52, {
    font: FONT.mono,
    size: 11,
    color: hexOf(t.accent.base),
    letterSpacing: 1.2,
    lineHeight: 14
  });
  addText(board, '色彩与语义', 64, 72, {
    font: FONT.display,
    size: 36,
    color: hexOf(t.text.primary),
    lineHeight: 46
  });
  addText(board, '全部为实色；透明度只用于阴影、聚焦光晕与选中 glow，不用于文字。', 64, 126, {
    size: 12,
    color: hexOf(t.text.tertiary),
    lineHeight: 16
  });

  addText(board, '朱砂色阶 / CINNABAR SCALE', 64, 176, {
    font: FONT.mono,
    size: 10,
    color: hexOf(t.text.tertiary),
    letterSpacing: 1,
    lineHeight: 12
  });

  const scale = ['50', '100', '200', '300', '400', '500', '600', '700', '800', '900'];
  scale.forEach((key, index) => {
    const hex = ACCENT_SCALE[key].$value;
    const x = 64 + index * 135;
    makeRect(board, 'Accent / ' + key, x, 202, 123, 56, solid(hex), 8);
    if (key === '500') {
      const outline = makeRect(board, 'Accent / base outline', x - 2, 200, 127, 60, null, 10);
      outline.strokes = [solid('#FFFDFB')];
      outline.strokeWeight = 1.5;
    }
    addText(board, key, x, 264, {
      font: FONT.mono,
      size: 9,
      color: hexOf(t.text.tertiary),
      lineHeight: 11
    });
    addText(board, hex, x, 278, {
      font: FONT.mono,
      size: 9,
      color: hexOf(t.text.secondary),
      lineHeight: 11
    });
  });

  addText(board, 'SEMANTIC / DARK + LIGHT', 64, 322, {
    font: FONT.mono,
    size: 10,
    color: hexOf(t.text.tertiary),
    letterSpacing: 1,
    lineHeight: 12
  });

  const dark = TOKENS.themes.dark;
  const light = TOKENS.themes.light;
  const rows = [
    ['Panel top', dark.surface.panel.top, light.surface.panel.top, '面板顶部'],
    ['Panel mid', dark.surface.panel.mid, light.surface.panel.mid, '面板中段'],
    ['Panel bottom', dark.surface.panel.bottom, light.surface.panel.bottom, '面板底部'],
    ['Panel border', dark.surface.panel.border, light.surface.panel.border, '面板描边'],
    ['Card base', dark.surface.card.base, light.surface.card.base, '卡片底色'],
    ['Card border', dark.surface.card.border, light.surface.card.border, '卡片描边'],
    ['Search bg', dark.control.search.background, light.control.search.background, '搜索框'],
    ['Tab selected', dark.control.tab.selectedBackground, light.control.tab.selectedBackground, '选中 Tab'],
    ['Text primary', dark.text.primary, light.text.primary, '主文字'],
    ['Text secondary', dark.text.secondary, light.text.secondary, '次文字'],
    ['Text tertiary', dark.text.tertiary, light.text.tertiary, '辅助文字']
  ];

  const headerY = 352;
  addText(board, 'Token', 64, headerY, { font: FONT.mono, size: 9, color: hexOf(t.text.tertiary) });
  addText(board, 'DARK', 300, headerY, { font: FONT.mono, size: 9, color: hexOf(t.text.tertiary) });
  addText(board, 'LIGHT', 580, headerY, { font: FONT.mono, size: 9, color: hexOf(t.text.tertiary) });
  addText(board, '用途', 860, headerY, { font: FONT.mono, size: 9, color: hexOf(t.text.tertiary) });

  rows.forEach((row, index) => {
    const y = 376 + index * 34;
    if (index % 2 === 0) {
      makeRect(board, 'Row bg', 64, y - 6, 1384, 34, solid('#1B1918'));
    }
    addText(board, row[0], 76, y, {
      font: FONT.mono,
      size: 10,
      color: hexOf(t.text.primary)
    });
    makeRect(board, 'Dark swatch', 300, y - 3, 36, 20, solid(row[1].$value), 4);
    addText(board, row[1].$value, 344, y + 1, {
      font: FONT.mono,
      size: 9,
      color: hexOf(t.text.secondary)
    });
    makeRect(board, 'Light swatch', 580, y - 3, 36, 20, solid(row[2].$value), 4);
    addText(board, row[2].$value, 624, y + 1, {
      font: FONT.mono,
      size: 9,
      color: hexOf(t.text.secondary)
    });
    addText(board, row[3], 860, y, {
      size: 10.5,
      color: hexOf(t.text.tertiary)
    });
  });

  addText(board, 'CATEGORY / 分类色', 64, 800, {
    font: FONT.mono,
    size: 10,
    color: hexOf(t.text.tertiary),
    letterSpacing: 1,
    lineHeight: 12
  });

  const categories = [
    ['烟雨灰 / All', CAT_HEX.all],
    ['晓山青 / Text', CAT_HEX.text],
    ['青花蓝 / Code', CAT_HEX.code],
    ['木槿紫 / Link', CAT_HEX.link],
    ['黛子粉 / Media', CAT_HEX.media],
    ['落暖橘 / Color', CAT_HEX.color]
  ];
  categories.forEach(([name, hex], index) => {
    const chip = makeFrame(board, 'Category / ' + name, 64 + index * 228, 828, 216, 56, {
      fill: solid('#1B1918'),
      radius: 8,
      stroke: '#302C2A'
    });
    makeRect(chip, 'Bar', 0, 0, 6, 56, solid(hex), 0);
    addText(chip, name, 18, 10, {
      size: 11.5,
      color: hexOf(t.text.primary),
      lineHeight: 14
    });
    addText(chip, hex, 18, 30, {
      font: FONT.mono,
      size: 10,
      color: hexOf(t.text.tertiary),
      lineHeight: 12
    });
  });

  addText(board, '圆角 Tab / Search 9–10 · Card 14 · Panel 24    字号 15 / 13 / 11.5 / 11    卡片混合 Dark 18% / 24% · Light 12% / 20%', 64, 910, {
    font: FONT.mono,
    size: 10,
    color: hexOf(t.text.tertiary),
    lineHeight: 14
  });

  return board;
}

/* ---------- handoff ---------- */

function addHandoff() {
  const t = TOKENS.themes.dark;
  const board = makeFrame(figma.currentPage, '潮色 / 04 Handoff', 0, 2330, W, 800, {
    fill: solid('#141211')
  });

  addText(board, 'HANDOFF', 64, 52, {
    font: FONT.mono,
    size: 11,
    color: hexOf(t.accent.base),
    letterSpacing: 1.2,
    lineHeight: 14
  });
  addText(board, '从旧版到朱砂', 64, 72, {
    font: FONT.display,
    size: 36,
    color: hexOf(t.text.primary),
    lineHeight: 46
  });
  addText(board, '只替换语义 Token，不改布局、不改字号、不加主题选择器。', 64, 126, {
    size: 12,
    color: hexOf(t.text.tertiary),
    lineHeight: 16
  });

  addText(board, 'TOKEN 对照', 64, 180, {
    font: FONT.mono,
    size: 10,
    color: hexOf(t.text.tertiary),
    letterSpacing: 1,
    lineHeight: 12
  });

  const rows = [
    ['品牌主色', '#F56300', '#C8402E', 'Light · Dark 用 #E0523B'],
    ['面板 Dark', '#2B2C31', '#2C2A29', '暖墨，不是纯灰'],
    ['面板 Light', '#EDF0F4', '#F5F0E9', '宣纸底色'],
    ['卡片 Dark', '#111214', '#131110', '与面板分离 1 级'],
    ['卡片 Light', '#FFFFFF', '#FFFDFB', '避免纯白刺眼'],
    ['主文字 Dark', '#F3F4F6', '#F6F1EA', '纸白，实色'],
    ['主文字 Light', '#101216', '#1B1816', '墨黑，实色'],
    ['选中 Tab Dark', '#3A2418', '#3B201B', '朱砂 18% 混底'],
    ['选中 Tab Light', '#FFE8D6', '#FBE3DC', '朱砂 12% 混底'],
    ['Text 分类', '#10B981', '#4E8F7C', '晓山青'],
    ['Code 分类', '#3B82F6', '#4A7DB2', '青花蓝'],
    ['Link 分类', '#A855F7', '#9A72A8', '木槿紫'],
    ['Media 分类', '#EC4899', '#C46F88', '黛子粉'],
    ['Color 分类', '#FF8800', '#D9824B', '落暖橘']
  ];

  addText(board, 'Token', 64, 210, { font: FONT.mono, size: 9, color: hexOf(t.text.tertiary) });
  addText(board, 'OLD', 230, 210, { font: FONT.mono, size: 9, color: hexOf(t.text.tertiary) });
  addText(board, 'NEW', 360, 210, { font: FONT.mono, size: 9, color: hexOf(t.text.tertiary) });
  addText(board, '备注', 500, 210, { font: FONT.mono, size: 9, color: hexOf(t.text.tertiary) });

  rows.forEach((row, index) => {
    const y = 238 + index * 34;
    if (index % 2 === 0) {
      makeRect(board, 'Row bg', 64, y - 6, 820, 34, solid('#1B1918'));
    }
    addText(board, row[0], 76, y, { size: 11, color: hexOf(t.text.primary), lineHeight: 14 });
    addText(board, row[1], 230, y, { font: FONT.mono, size: 9.5, color: hexOf(t.text.tertiary), lineHeight: 14 });
    addText(board, '→', 330, y, { size: 11, color: hexOf(t.accent.base), lineHeight: 14 });
    addText(board, row[2], 360, y, { font: FONT.mono, size: 9.5, color: hexOf(t.text.primary), lineHeight: 14 });
    addText(board, row[3], 500, y, { size: 10, color: hexOf(t.text.tertiary), lineHeight: 14 });
  });

  addText(board, '落地规则', 940, 180, {
    font: FONT.mono,
    size: 10,
    color: hexOf(t.text.tertiary),
    letterSpacing: 1,
    lineHeight: 12
  });

  const rules = [
    '朱砂只做强调：选中描边、聚焦环、Logo、关键词。',
    '不要用朱砂大面积铺底；面板仍是墨色 / 宣纸色。',
    '文字全部实色，禁止 white.opacity / black.opacity。',
    '卡片底色 = 分类色与卡片底色的混合，不是纯分类色。',
    'Dark 18% / 选中 24%；Light 12% / 选中 20%。',
    'Dark 主色 #E0523B 保证在 #2C2A29 上 ≥ 3:1。',
    '分类色只出现在 5–6px 圆点、Badge 与卡片 tint。',
    'Figma 是视觉基线，SwiftUI 的 ThemeManager 是最终源。'
  ];
  rules.forEach((rule, index) => {
    makeDot(board, hexOf(t.accent.base), 4, 940, 218 + index * 30 + 6);
    addText(board, rule, 956, 218 + index * 30, {
      size: 12,
      color: hexOf(t.text.secondary),
      width: 500,
      lineHeight: 18
    });
  });

  makeRect(board, 'Divider', 940, 486, 1, 120, solid('#302C2A'));
  addText(board, '交付物', 964, 486, {
    font: FONT.mono,
    size: 10,
    color: hexOf(t.text.tertiary),
    letterSpacing: 1,
    lineHeight: 12
  });
  addText(board, 'Token JSON：design/theme-cinnabar/tokens.json', 964, 508, {
    font: FONT.mono,
    size: 10.5,
    color: hexOf(t.text.secondary),
    lineHeight: 16
  });
  addText(board, '生成器：design/theme-cinnabar/figma-plugin', 964, 530, {
    font: FONT.mono,
    size: 10.5,
    color: hexOf(t.text.secondary),
    lineHeight: 16
  });
  addText(board, '实现入口：ThemeManager.swift / Color+Extensions.swift', 964, 552, {
    font: FONT.mono,
    size: 10.5,
    color: hexOf(t.text.secondary),
    lineHeight: 16
  });

  addText(board, '美图「中国潮色」原始 13 色：朱砂红、藤枝黄、墨油绿、青花蓝、烟雨灰、暮檐褐、黛子粉、落暖橘、木槿紫、晓山青、水墨黑、素晖银、圣鎏金。', 64, 740, {
    size: 10,
    color: hexOf(t.text.tertiary),
    width: 900,
    lineHeight: 14
  });

  return board;
}

/* ---------- styles ---------- */

async function ensureStyles() {
  let existing = [];
  try {
    existing = figma.getLocalPaintStylesAsync
      ? await figma.getLocalPaintStylesAsync()
      : figma.getLocalPaintStyles();
  } catch (error) {
    existing = [];
  }

  const styles = [
    ['潮色 / 朱砂 / 500', ACCENT_SCALE['500'].$value],
    ['潮色 / 朱砂 / Dark', TOKENS.themes.dark.accent.base.$value],
    ['潮色 / 朱砂 / Light', TOKENS.themes.light.accent.base.$value],
    ['潮色 / 分类 / 烟雨灰', CAT_HEX.all],
    ['潮色 / 分类 / 晓山青', CAT_HEX.text],
    ['潮色 / 分类 / 青花蓝', CAT_HEX.code],
    ['潮色 / 分类 / 木槿紫', CAT_HEX.link],
    ['潮色 / 分类 / 黛子粉', CAT_HEX.media],
    ['潮色 / 分类 / 落暖橘', CAT_HEX.color],
    ['潮色 / Dark / 面板', TOKENS.themes.dark.surface.panel.top.$value],
    ['潮色 / Dark / 卡片', TOKENS.themes.dark.surface.card.base.$value],
    ['潮色 / Dark / 主文字', TOKENS.themes.dark.text.primary.$value],
    ['潮色 / Dark / 次文字', TOKENS.themes.dark.text.secondary.$value],
    ['潮色 / Dark / 选中底', TOKENS.themes.dark.control.tab.selectedBackground.$value],
    ['潮色 / Light / 面板', TOKENS.themes.light.surface.panel.top.$value],
    ['潮色 / Light / 卡片', TOKENS.themes.light.surface.card.base.$value],
    ['潮色 / Light / 主文字', TOKENS.themes.light.text.primary.$value],
    ['潮色 / Light / 次文字', TOKENS.themes.light.text.secondary.$value],
    ['潮色 / Light / 选中底', TOKENS.themes.light.control.tab.selectedBackground.$value]
  ];

  for (const [name, hex] of styles) {
    if (existing.some((style) => style.name === name)) continue;
    const style = figma.createPaintStyle();
    style.name = name;
    style.paints = [solid(hex)];
  }
}

/* ---------- main ---------- */

(async () => {
  try {
    await figma.loadAllPagesAsync();
    await resolveFonts();

    const existingPage = figma.root.children.find(
      (page) => page.type === 'PAGE' && page.name === PAGE_NAME
    );

    let page;
    if (existingPage) {
      // 复用已存在的主题页：只清掉本插件生成过的 Frame / 标签，
      // 保留用户后来手动加的内容。
      if (figma.setCurrentPageAsync) {
        await figma.setCurrentPageAsync(existingPage);
      } else {
        figma.currentPage = existingPage;
      }
      for (const child of [...existingPage.children]) {
        if (
          child.name.startsWith('潮色 /') ||
          child.name.startsWith('Label /') ||
          child.name.startsWith('__')
        ) {
          child.remove();
        }
      }
      page = existingPage;
    } else {
      page = figma.createPage();
      page.name = PAGE_NAME;
      if (figma.setCurrentPageAsync) {
        await figma.setCurrentPageAsync(page);
      } else {
        figma.currentPage = page;
      }
    }
    page.backgrounds = [solid('#0B0A09')];

    try {
      await ensureStyles();
    } catch (styleError) {
      // Styles are a convenience; the page must still build.
    }

    const cover = addCover();
    const darkLabel = addText(figma.currentPage, 'DARK · 墨色', 64, 506, {
      font: FONT.mono,
      size: 11,
      color: '#8E867D',
      letterSpacing: 1,
      lineHeight: 14
    });
    darkLabel.name = 'Label / Dark';
    const darkPanel = addPanel('dark', 0, 540);
    const lightLabel = addText(figma.currentPage, 'LIGHT · 宣纸', 64, 901, {
      font: FONT.mono,
      size: 11,
      color: '#8E867D',
      letterSpacing: 1,
      lineHeight: 14
    });
    lightLabel.name = 'Label / Light';
    const lightPanel = addPanel('light', 0, 935);
    const tokensBoard = addTokens();
    const handoff = addHandoff();

    figma.currentPage.selection = [cover];
    figma.viewport.scrollAndZoomIntoView([cover]);
    figma.notify('已生成「' + PAGE_NAME + '」：封面、明暗面板、Token、Handoff。');
    figma.closePlugin();
  } catch (error) {
    figma.notify('生成失败：' + (error && error.message ? error.message : String(error)), { error: true });
    figma.closePlugin();
  }
})();
