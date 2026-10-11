// Copies the GitHub wiki into site/src/content, rewriting wiki links.
// Usage: npm run sync -- /path/to/Runic.wiki
import { readdirSync, readFileSync, writeFileSync, mkdirSync, copyFileSync, existsSync } from 'node:fs';
import { join, basename } from 'node:path';

const src = process.argv[2];
if (!src || !existsSync(src)) {
  console.error('usage: npm run sync -- /path/to/Runic.wiki');
  process.exit(1);
}
const out = new URL('../src/content/', import.meta.url).pathname;
mkdirSync(out, { recursive: true });

const slug = (name) => name.toLowerCase().replace(/\.md$/, '');
const RAW = 'https://raw.githubusercontent.com/wiki/sriinnu/Runic/images/';

for (const file of readdirSync(src)) {
  if (!file.endsWith('.md') || file.startsWith('_')) continue;
  let text = readFileSync(join(src, file), 'utf8');
  // [[Label|Target]] and [[Target]] -> site links
  text = text.replace(/\[\[([^\]|]+)\|([^\]]+)\]\]/g, (_, label, target) => `[${label}](/${slug(target)}/)`);
  text = text.replace(/\[\[([^\]]+)\]\]/g, (_, target) => `[${target}](/${slug(target.replace(/ /g, '-'))}/)`);
  // wiki images are served from the site itself
  text = text.split(RAW).join('/images/');
  const title = (text.match(/^#\s+(.+)$/m) || [null, basename(file, '.md')])[1];
  const front = `---\ntitle: ${JSON.stringify(title)}\n---\n\n`;
  writeFileSync(join(out, file.toLowerCase()), front + text);
  console.log('synced', file);
}
