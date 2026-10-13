// Numbers the site states about the app, read from the app's own source at
// build time so the page can't drift from the code. Cloudflare builds from a
// full checkout with `site/` as the working directory, so the repo root is
// one level up. A missing file fails the build instead of printing a guess.
import { readFileSync, readdirSync } from 'node:fs';
import { resolve } from 'node:path';

const root = resolve(process.cwd(), '..');
const read = (p: string) => readFileSync(resolve(root, p), 'utf8');

/** MARKETING_VERSION from version.env, e.g. "2.11.2". */
export const version = (() => {
  const m = read('version.env').match(/^MARKETING_VERSION=(\S+)/m);
  if (!m) throw new Error('facts: MARKETING_VERSION missing from version.env');
  return m[1];
})();

/** Bundled themes: one JSON file each. */
export const themeCount = readdirSync(resolve(root, 'Sources/Runic/Resources/Themes')).filter((f) => f.endsWith('.json')).length;

/** Skins: one folder per kit, not counting the standard kit. */
export const skinCount = readdirSync(resolve(root, 'Sources/Runic/Skins'), { withFileTypes: true })
  .filter((d) => d.isDirectory() && d.name !== 'Standard').length;

/** Providers: cases of `UsageProvider`, with the China-region twins (zaiCN, kimiCN, …) counted once. */
export const providerCount = (() => {
  const src = read('Sources/RunicCore/Providers/Providers.swift');
  const start = src.indexOf('public enum UsageProvider');
  if (start < 0) throw new Error('facts: UsageProvider enum not found');
  const cases: string[] = [];
  for (const line of src.slice(start).split('\n').slice(1)) {
    const t = line.trim();
    if (!t || t.startsWith('//')) continue;
    const m = t.match(/^case (\w+)/);
    if (!m) break;
    cases.push(m[1]);
  }
  if (cases.length < 10) throw new Error(`facts: only ${cases.length} provider cases parsed`);
  return cases.filter((c) => !c.endsWith('CN')).length;
})();

/** Provider display names as the app shows them, China-region twins left out. */
export const providerNames = (() => {
  const names = new Set<string>();
  const walk = (dir: string) => {
    for (const d of readdirSync(dir, { withFileTypes: true })) {
      const p = resolve(dir, d.name);
      if (d.isDirectory()) walk(p);
      else if (d.name.endsWith('.swift')) {
        for (const m of readFileSync(p, 'utf8').matchAll(/displayName: "([^"]+)"/g)) names.add(m[1]);
      }
    }
  };
  walk(resolve(root, 'Sources/RunicCore/Providers'));
  const list = [...names].filter((n) => !n.includes('(China)'));
  if (list.length !== providerCount) throw new Error(`facts: ${list.length} provider names vs ${providerCount} providers`);
  return list.sort((a, b) => a.localeCompare(b, 'en', { sensitivity: 'base' }));
})();
