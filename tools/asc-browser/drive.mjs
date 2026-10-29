#!/usr/bin/env node
/**
 * drive.mjs — 连接「独立配置」Chrome(CDP),驱动 App Store Connect 页面。
 *
 * 前提:先跑 ./open.sh 让 Chrome 带调试端口启动。
 *
 * 常用命令:
 *   node drive.mjs pages                      列出标签页
 *   node drive.mjs open <url>                 复用/新建标签页并打开
 *   node drive.mjs goto <url>                 当前页跳转
 *   node drive.mjs snapshot                   页面交互元素清单(拿到 @序号 / 选择器)
 *   node drive.mjs text [selector]            取页面/元素文本
 *   node drive.mjs shot [path.png]            截图(默认 build/asc/shot.png)
 *   node drive.mjs click <selector>           点击
 *   node drive.mjs fill <selector> <value>    填输入框
 *   node drive.mjs type <selector> <value>    逐字输入(触发键盘事件)
 *   node drive.mjs press <selector> <key>     按键(selector 写 - 表示全局)
 *   node drive.mjs select <selector> <value>  下拉选择
 *   node drive.mjs check|uncheck <selector>   勾选/取消勾选
 *   node drive.mjs upload <selector> <file…>  文件上载(可多个)
 *   node drive.mjs hover <selector>           悬停
 *   node drive.mjs wait <ms|选择器>           等待
 *   node drive.mjs eval <表达式>              在页面里执行 JS 并打印结果
 *   node drive.mjs url                        当前页 URL / 标题
 *
 * 选择器可写:
 *   @12                    — snapshot 输出的序号(页面未刷新时有效)
 *   #id / input[name=x]    — 普通 CSS
 *   text=提交              — Playwright 文本选择器
 *   role=button[name="添加"] — Playwright role 选择器
 * 全局选项: --page N(按 pages 序号指定标签页)、--timeout ms、--any-page(不限定 ASC 页)
 */
import { chromium } from 'playwright-core';
import { mkdirSync } from 'node:fs';
import { dirname, resolve } from 'node:path';

const ENDPOINT = `http://127.0.0.1:${process.env.ASC_CDP_PORT || '9223'}`;

function parseArgs(argv) {
  const opts = { page: null, timeout: 25000, anyPage: false };
  const rest = [];
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i];
    if (a === '--page') opts.page = Number(argv[++i]);
    else if (a === '--timeout') opts.timeout = Number(argv[++i]);
    else if (a === '--any-page') opts.anyPage = true;
    else rest.push(a);
  }
  return { opts, rest };
}

function allPages(browser) {
  return browser.contexts().flatMap((c) => c.pages());
}

function pickPage(browser, opts) {
  const pages = allPages(browser);
  if (pages.length === 0) throw new Error('Chrome 里没有可操作的标签页');
  if (opts.page !== null && !Number.isNaN(opts.page)) {
    const p = pages[opts.page];
    if (!p) throw new Error(`没有第 ${opts.page} 个标签页(共 ${pages.length} 个)`);
    return p;
  }
  const asc = pages.filter((p) => (p.url() || '').includes('appstoreconnect.apple.com'));
  return (opts.anyPage ? pages[pages.length - 1] : (asc[asc.length - 1] ?? pages[pages.length - 1]));
}

const selectorOf = (raw) => (/^@\d+$/.test(raw) ? `[data-dsh-idx="${raw.slice(1)}"]` : raw);

async function main() {
  const { opts, rest } = parseArgs(process.argv.slice(2));
  const [cmd, ...args] = rest;
  if (!cmd || cmd === 'help' || cmd === '--help') {
    console.log('见文件头部注释。命令: pages open goto snapshot text shot click fill type press select check uncheck upload hover wait eval url');
    return;
  }

  let browser;
  try {
    browser = await chromium.connectOverCDP(ENDPOINT);
  } catch (e) {
    throw new Error(`连不上 Chrome 调试端口 ${ENDPOINT} — 先运行 ./open.sh(${e.message})`);
  }

  try {
    const ctx = browser.contexts()[0];
    const page = pickPage(browser, opts);
    page.setDefaultTimeout(opts.timeout);

    switch (cmd) {
      case 'pages': {
        const pages = allPages(browser);
        const titles = await Promise.all(pages.map((p) => p.title().catch(() => '')));
        pages.forEach((p, i) => console.log(`[${i}] ${p.url()}\n     ${titles[i]}`));
        console.log(`\n当前目标: [${pages.indexOf(page)}] ${page.url()}`);
        break;
      }
      case 'url': {
        console.log(JSON.stringify({ url: page.url(), title: await page.title() }, null, 2));
        break;
      }
      case 'open': {
        const url = args[0];
        if (!url) throw new Error('用法: open <url>');
        const origin = new URL(url).origin;
        const existing = allPages(browser).find((p) => (p.url() || '').startsWith(origin));
        const target = existing ?? await ctx.newPage();
        target.setDefaultTimeout(opts.timeout);
        await target.goto(url, { waitUntil: 'domcontentloaded', timeout: opts.timeout });
        await target.bringToFront();
        console.log(`✔ ${target.url()}\n  ${await target.title()}`);
        break;
      }
      case 'goto': {
        if (!args[0]) throw new Error('用法: goto <url>');
        await page.goto(args[0], { waitUntil: 'domcontentloaded', timeout: opts.timeout });
        await page.waitForTimeout(800);
        console.log(`✔ ${page.url()}\n  ${await page.title()}`);
        break;
      }
      case 'back':
        await page.goBack({ waitUntil: 'domcontentloaded' });
        console.log(`✔ ${page.url()}`);
        break;
      case 'close': {
        const target = page;
        const u = target.url();
        await target.close();
        console.log(`✔ 已关闭标签页: ${u}`);
        break;
      }
      case 'shot': {
        const out = resolve(args[0] || 'build/asc/shot.png');
        mkdirSync(dirname(out), { recursive: true });
        await page.waitForTimeout(300);
        await page.screenshot({ path: out, fullPage: args.includes('--full') });
        console.log(resolve(out));
        break;
      }
      case 'snapshot': {
        const data = await page.evaluate(() => {
          const esc = (s) => s.replace(/"/g, '\\"');
          const cssEscape = (s) => (window.CSS?.escape ? CSS.escape(s) : esc(s));
          const vis = (el) => !!(el.getClientRects().length && getComputedStyle(el).visibility !== 'hidden');
          const labelOf = (el) => {
            const aria = el.getAttribute('aria-label');
            if (aria) return aria.trim();
            const by = el.getAttribute('aria-labelledby');
            if (by) {
              const t = by.split(/\s+/).map((id) => document.getElementById(id)?.textContent || '').join(' ').trim();
              if (t) return t;
            }
            if (el.id) {
              const lab = document.querySelector(`label[for="${cssEscape(el.id)}"]`);
              if (lab?.textContent.trim()) return lab.textContent.trim();
            }
            const wrap = el.closest('label');
            if (wrap?.textContent.trim()) return wrap.textContent.trim();
            const ph = el.getAttribute('placeholder') || el.getAttribute('title');
            if (ph) return ph.trim();
            return (el.innerText || el.textContent || '').trim().replace(/\s+/g, ' ').slice(0, 60);
          };
          const pathOf = (el) => {
            const parts = [];
            let node = el;
            for (let d = 0; node && node.nodeType === 1 && d < 6; d++, node = node.parentElement) {
              if (node.id) { parts.unshift(`#${cssEscape(node.id)}`); break; }
              const tag = node.tagName.toLowerCase();
              const sib = node.parentElement ? [...node.parentElement.children].filter((c) => c.tagName === node.tagName) : [node];
              parts.unshift(sib.length > 1 ? `${tag}:nth-of-type(${sib.indexOf(node) + 1})` : tag);
            }
            return parts.join(' > ');
          };
          const selOf = (el) => {
            const tid = el.getAttribute('data-testid') || el.getAttribute('data-test');
            if (tid) return `[data-testid="${esc(tid)}"]`;
            const name = el.getAttribute('name');
            if (name) return `${el.tagName.toLowerCase()}[name="${esc(name)}"]`;
            const aria = el.getAttribute('aria-label');
            if (aria) return `${el.tagName.toLowerCase()}[aria-label="${esc(aria)}"]`;
            const idv = el.getAttribute('id');
            if (idv) return `#${cssEscape(idv)}`;
            return pathOf(el);
          };
          const roleOf = (el) => {
            const explicit = el.getAttribute('role');
            if (explicit) return explicit;
            const tag = el.tagName;
            if (tag === 'A') return 'link';
            if (tag === 'BUTTON') return 'button';
            if (tag === 'SELECT') return 'combobox';
            if (tag === 'TEXTAREA') return 'textbox';
            if (tag === 'INPUT') {
              const t = (el.getAttribute('type') || 'text').toLowerCase();
              return ({ checkbox: 'checkbox', radio: 'radio', submit: 'button', button: 'button', file: 'file', range: 'slider' })[t] || 'textbox';
            }
            return tag.toLowerCase();
          };
          const picked = [...document.querySelectorAll(
            'a[href],button,input:not([type=hidden]),select,textarea,[role=button],[role=link],[role=tab],[role=menuitem],[role=checkbox],[role=radio],[role=switch],[role=combobox],[role=textbox],[role=option],[contenteditable="true"]'
          )].filter(vis);
          const lines = picked.slice(0, 400).map((el, i) => {
            el.setAttribute('data-dsh-idx', String(i));
            const role = roleOf(el);
            const label = labelOf(el);
            const state = el.tagName === 'INPUT' && ['checkbox', 'radio'].includes((el.getAttribute('type') || '').toLowerCase())
              ? (el.checked ? ' [✓]' : ' [ ]')
              : el.tagName === 'INPUT' || el.tagName === 'TEXTAREA'
                ? (el.value ? ` = ${JSON.stringify(String(el.value).slice(0, 40))}` : '')
                : el.tagName === 'SELECT'
                  ? ` = ${JSON.stringify(el.selectedOptions?.[0]?.text || '')}`
                  : el.disabled || el.getAttribute('aria-disabled') === 'true' ? ' [禁用]' : '';
            return `[@${i}] ${role} "${label}"${state}  =>  ${selOf(el)}`;
          });
          return {
            url: location.href,
            title: document.title,
            headings: [...document.querySelectorAll('h1,h2,h3')].filter(vis).slice(0, 25).map((h) => `${h.tagName}: ${h.innerText.trim().slice(0, 70)}`),
            lines,
            total: picked.length,
          };
        });
        console.log(`# ${data.title}\n# ${data.url}\n`);
        if (data.headings.length) console.log(data.headings.join('\n') + '\n');
        console.log(data.lines.join('\n'));
        if (data.total > data.lines.length) console.log(`\n… 还有 ${data.total - data.lines.length} 个元素未列出`);
        break;
      }
      case 'text': {
        const sel = args[0] ? selectorOf(args[0]) : 'body';
        const t = await page.locator(sel).first().innerText({ timeout: opts.timeout });
        console.log(t.trim().slice(0, 20000));
        break;
      }
      case 'eval': {
        const expr = args.join(' ');
        if (!expr) throw new Error('用法: eval <JS表达式>');
        const v = await page.evaluate(expr);
        console.log(typeof v === 'string' ? v : JSON.stringify(v, null, 2));
        break;
      }
      case 'click': case 'dblclick': case 'hover': {
        const sel = selectorOf(args[0] || '');
        if (!sel) throw new Error(`用法: ${cmd} <selector>`);
        const loc = page.locator(sel).first();
        await loc.waitFor({ state: 'visible', timeout: opts.timeout });
        if (cmd === 'click') await loc.click({ timeout: opts.timeout });
        else if (cmd === 'dblclick') await loc.dblclick({ timeout: opts.timeout });
        else await loc.hover({ timeout: opts.timeout });
        await page.waitForTimeout(500);
        console.log(`✔ ${cmd} ${sel}`);
        break;
      }
      case 'fill': case 'type': {
        const sel = selectorOf(args[0] || '');
        const value = args.slice(1).join(' ');
        if (!sel) throw new Error(`用法: ${cmd} <selector> <value>`);
        const loc = page.locator(sel).first();
        await loc.waitFor({ state: 'visible', timeout: opts.timeout });
        if (cmd === 'fill') await loc.fill(value, { timeout: opts.timeout });
        else await loc.pressSequentially(value, { delay: 25, timeout: opts.timeout });
        console.log(`✔ ${cmd} ${sel} = ${JSON.stringify(value.slice(0, 60))}`);
        break;
      }
      case 'press': {
        const [s, key] = args;
        if (!s || !key) throw new Error('用法: press <selector|-> <key>');
        if (s === '-') await page.keyboard.press(key);
        else await page.locator(selectorOf(s)).first().press(key, { timeout: opts.timeout });
        await page.waitForTimeout(400);
        console.log(`✔ press ${key}`);
        break;
      }
      case 'select': {
        const sel = selectorOf(args[0] || '');
        const values = args.slice(1);
        await page.locator(sel).first().selectOption(values, { timeout: opts.timeout });
        console.log(`✔ select ${sel} -> ${JSON.stringify(values)}`);
        break;
      }
      case 'check': case 'uncheck': {
        const sel = selectorOf(args[0] || '');
        const loc = page.locator(sel).first();
        if (cmd === 'check') await loc.check({ timeout: opts.timeout });
        else await loc.uncheck({ timeout: opts.timeout });
        console.log(`✔ ${cmd} ${sel}`);
        break;
      }
      case 'upload': {
        const sel = selectorOf(args[0] || '');
        const files = args.slice(1).map((f) => resolve(f));
        if (!sel || files.length === 0) throw new Error('用法: upload <selector> <file…>');
        await page.locator(sel).first().setInputFiles(files, { timeout: opts.timeout });
        console.log(`✔ upload ${sel} <- ${files.join(', ')}`);
        break;
      }
      case 'wait': {
        const a = args[0];
        if (!a) throw new Error('用法: wait <ms|selector>');
        if (/^\d+$/.test(a)) await page.waitForTimeout(Number(a));
        else await page.locator(selectorOf(a)).first().waitFor({ state: 'visible', timeout: opts.timeout });
        console.log(`✔ waited ${a}`);
        break;
      }
      default:
        throw new Error(`未知命令: ${cmd}`);
    }
  } finally {
    await browser.close();
  }
}

main().catch((e) => {
  console.error(`✘ ${e.message}`);
  process.exit(1);
});
