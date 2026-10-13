// @ts-check
import { defineConfig } from 'astro/config';
import { satteri } from '@astrojs/markdown-satteri';

// Wrap every markdown table in a scroll box, so a wide table scrolls inside
// the article instead of pushing the page sideways at tablet widths.
const wrapTables = {
  name: 'runic-wrap-tables',
  element: {
    filter: ['table'],
    /** @param {any} node @param {any} ctx */
    visit(node, ctx) {
      ctx.wrapNode(node, {
        type: 'element', tagName: 'div', children: [],
        properties: { className: ['table-wrap'], tabIndex: 0, role: 'region', ariaLabel: 'Table, scrolls sideways' },
      });
    },
  },
};

export default defineConfig({
  site: 'https://runic.srinivas.dev',
  markdown: {
    shikiConfig: { theme: 'github-dark-high-contrast' },
    processor: satteri({ hastPlugins: [wrapTables] }),
  },
  security: {
    // Astro hashes its own scripts and styles into a CSP <meta>. Style
    // attributes (per-card accent colours, Shiki's token colours) stay allowed.
    csp: {
      directives: ["default-src 'self'", "img-src 'self' data:", "object-src 'none'", "base-uri 'self'", "form-action 'none'"],
      styleDirective: { resources: ["'self'", { resource: "'unsafe-inline'", kind: 'attribute' }] },
    },
  },
});
