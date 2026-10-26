import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const root = path.dirname(fileURLToPath(import.meta.url));
const tokens = JSON.parse(fs.readFileSync(path.join(root, 'tokens.json'), 'utf8'));
const tokenJSON = JSON.stringify(tokens, null, 2);

function build(templatePath, outputPath) {
  if (!fs.existsSync(templatePath)) {
    console.log(`skip ${path.relative(root, templatePath)} (not found)`);
    return;
  }
  const template = fs.readFileSync(templatePath, 'utf8');
  const output = template.replace(/\/\*__TOKENS__\*\//g, tokenJSON);
  fs.writeFileSync(outputPath, output);
  console.log(`built ${path.relative(root, outputPath)}`);
}

build(
  path.join(root, 'src', 'preview.template.html'),
  path.join(root, 'preview', 'index.html')
);
build(
  path.join(root, 'src', 'plugin.template.js'),
  path.join(root, 'figma-plugin', 'code.js')
);
