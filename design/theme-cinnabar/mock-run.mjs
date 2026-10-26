import fs from 'node:fs';
import vm from 'node:vm';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const root = path.dirname(fileURLToPath(import.meta.url));
const code = fs.readFileSync(path.join(root, 'figma-plugin', 'code.js'), 'utf8');

function node(type) {
  return {
    type,
    name: '',
    children: [],
    parent: null,
    x: 0,
    y: 0,
    width: 100,
    height: 100,
    fills: [],
    strokes: [],
    strokeWeight: 1,
    strokeAlign: 'INSIDE',
    cornerRadius: 0,
    topLeftRadius: 0,
    topRightRadius: 0,
    bottomLeftRadius: 0,
    bottomRightRadius: 0,
    clipsContent: false,
    effects: [],
    rotation: 0,
    characters: '',
    fontName: { family: 'Inter', style: 'Regular' },
    fontSize: 12,
    lineHeight: null,
    letterSpacing: null,
    textAlignHorizontal: 'LEFT',
    textAutoResize: 'WIDTH_AND_HEIGHT',
    layoutMode: 'NONE',
    primaryAxisSizingMode: 'AUTO',
    counterAxisSizingMode: 'AUTO',
    counterAxisAlignItems: 'MIN',
    itemSpacing: 0,
    paddingLeft: 0,
    paddingRight: 0,
    paddingTop: 0,
    paddingBottom: 0,
    backgrounds: [],
    appendChild(child) {
      this.children.push(child);
      child.parent = this;
      return child;
    },
    resize(w, h) {
      this.width = w;
      this.height = h;
    }
  };
}

const rootChildren = [node('PAGE')];
rootChildren[0].name = 'Page 1';

const figma = {
  root: { children: rootChildren },
  currentPage: rootChildren[0],
  async loadAllPagesAsync() {},
  async setCurrentPageAsync(page) { this.currentPage = page; },
  async listAvailableFontsAsync() {
    const names = [
      ['PingFang SC', 'Regular'], ['PingFang SC', 'Medium'], ['PingFang SC', 'Semibold'],
      ['SF Mono', 'Regular'], ['SF Mono', 'Medium'], ['Songti SC', 'Bold'],
      ['Inter', 'Regular']
    ];
    return names.map(([family, style]) => ({ fontName: { family, style } }));
  },
  async loadFontAsync() {},
  createPage() {
    const page = node('PAGE');
    rootChildren.push(page);
    return page;
  },
  createFrame: () => node('FRAME'),
  createRectangle: () => node('RECTANGLE'),
  createEllipse: () => node('ELLIPSE'),
  createText: () => node('TEXT'),
  createNodeFromSvg: () => node('FRAME'),
  async getLocalPaintStylesAsync() { return []; },
  createPaintStyle() { return { name: '', paints: [] }; },
  notify(message, options) { console.log('notify:', message, options || ''); },
  closePlugin() { console.log('closePlugin'); },
  viewport: { scrollAndZoomIntoView() {} }
};

const context = vm.createContext({ figma, console });
vm.runInContext(code, context);
await new Promise((resolve) => setTimeout(resolve, 200));

const page = rootChildren.find((child) => child.name.includes('中国潮色'));
console.log('page:', page ? page.name : 'MISSING');
console.log('top-level frames:', page ? page.children.map((child) => child.name).join(' | ') : 'none');
const count = (n) => 1 + (n.children || []).reduce((sum, child) => sum + count(child), 0);
console.log('total nodes:', page ? count(page) : 0);
