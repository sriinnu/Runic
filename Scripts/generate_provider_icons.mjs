#!/usr/bin/env node
import { mkdirSync, writeFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const root = join(dirname(fileURLToPath(import.meta.url)), "..");
const resourceDir = join(root, "Sources", "Runic", "Resources");

const attrs = `fill="none" stroke="black" stroke-width="6.5" stroke-linecap="round" stroke-linejoin="round"`;
const svg = (body) => `<?xml version="1.0" encoding="UTF-8"?>
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64">
${body}
</svg>
`;

const icons = {
  antigravity: `
  <path d="M12 48 32 12l20 36" ${attrs}/>
  <path d="M23 36h18" ${attrs}/>
  <circle cx="32" cy="32" r="7" fill="black"/>`,
  auggie: `
  <path d="M14 50 32 13l18 37" ${attrs}/>
  <path d="M22 38h20" ${attrs}/>
  <path d="M32 13v37" stroke="black" stroke-width="5.5" stroke-linecap="round"/>`,
  azure: `
  <path d="M30 10 10 46h20l8-14 8 14h8L38 10h-8Z" fill="black"/>
  <path d="M30 46h18L38 32Z" fill="black" opacity=".72"/>`,
  bedrock: `
  <path d="M32 9 52 20v24L32 55 12 44V20L32 9Z" ${attrs}/>
  <path d="M12 20 32 31l20-11M32 31v24" ${attrs}/>` ,
  cerebras: `
  <rect x="15" y="15" width="34" height="34" rx="7" ${attrs}/>
  <path d="M40 24c-3-3-12-3-16 3-4 7 1 15 9 15 3 0 6-1 8-3" ${attrs}/>
  <path d="M10 24h6M10 40h6M48 24h6M48 40h6M24 10v6M40 10v6M24 48v6M40 48v6" stroke="black" stroke-width="4" stroke-linecap="round"/>`,
  claude: `
  <path d="M32 8 38 26 56 32 38 38 32 56 26 38 8 32 26 26 32 8Z" fill="black"/>
  <circle cx="32" cy="32" r="5" fill="white"/>`,
  codex: `
  <defs>
    <linearGradient id="runic-codex-mark" x1="13" x2="51" y1="53" y2="11" gradientUnits="userSpaceOnUse">
      <stop offset="0" stop-color="#43F2D2"/>
      <stop offset=".52" stop-color="#55B8FF"/>
      <stop offset="1" stop-color="#8D7CFF"/>
    </linearGradient>
  </defs>
  <g transform="scale(2.6666667)">
    <path fill="url(#runic-codex-mark)" d="M9.064 3.344a4.578 4.578 0 0 1 2.285-.312c1 .115 1.891.54 2.673 1.275.01.01.024.017.037.021a.09.09 0 0 0 .043 0 4.55 4.55 0 0 1 3.046.275l.047.022.116.057a4.581 4.581 0 0 1 2.188 2.399c.209.51.313 1.041.315 1.595a4.24 4.24 0 0 1-.134 1.223.123.123 0 0 0 .03.115c.594.607.988 1.33 1.183 2.17.289 1.425-.007 2.71-.887 3.854l-.136.166a4.548 4.548 0 0 1-2.201 1.388.123.123 0 0 0-.081.076c-.191.551-.383 1.023-.74 1.494-.9 1.187-2.222 1.846-3.711 1.838-1.187-.006-2.239-.44-3.157-1.302a.107.107 0 0 0-.105-.024c-.388.125-.78.143-1.204.138a4.441 4.441 0 0 1-1.945-.466 4.544 4.544 0 0 1-1.61-1.335c-.152-.202-.303-.392-.414-.617a5.81 5.81 0 0 1-.37-.961 4.582 4.582 0 0 1-.014-2.298.124.124 0 0 0 .006-.056.085.085 0 0 0-.027-.048 4.467 4.467 0 0 1-1.034-1.651 3.896 3.896 0 0 1-.251-1.192 5.189 5.189 0 0 1 .141-1.6c.337-1.112.982-1.985 1.933-2.618.212-.141.413-.251.601-.33.215-.089.43-.164.646-.227a.098.098 0 0 0 .065-.066 4.51 4.51 0 0 1 .829-1.615 4.535 4.535 0 0 1 1.837-1.388zm3.482 10.565a.637.637 0 0 0 0 1.272h3.636a.637.637 0 1 0 0-1.272h-3.636zM8.462 9.23a.637.637 0 0 0-1.106.631l1.272 2.224-1.266 2.136a.636.636 0 1 0 1.095.649l1.454-2.455a.636.636 0 0 0 .005-.64L8.462 9.23z"/>
  </g>` ,
  cohere: `
  <circle cx="24" cy="24" r="11" fill="black"/>
  <circle cx="40" cy="25" r="9" fill="black" opacity=".82"/>
  <circle cx="33" cy="42" r="10" fill="black" opacity=".9"/>`,
  copilot: `
  <path d="M16 34c0-13 7-21 16-21s16 8 16 21v10c0 6-5 10-11 10H27c-6 0-11-4-11-10V34Z" ${attrs}/>
  <path d="M20 34h10v8H20zM34 34h10v8H34z" fill="black"/>
  <path d="M26 18 21 9M38 18l5-9" stroke="black" stroke-width="5" stroke-linecap="round"/>`,
  cursor: `
  <path d="M14 9 50 34 34 38 26 54 14 9Z" fill="black"/>
  <path d="M31 37 42 50" stroke="black" stroke-width="7" stroke-linecap="round"/>`,
  deepseek: `
  <path d="M51 29c-1-10-9-17-20-17-12 0-21 9-21 20s9 20 21 20c8 0 15-4 18-11" ${attrs}/>
  <path d="M25 31c4-8 13-9 20-3 4 4 6 9 7 15" ${attrs}/>
  <circle cx="30" cy="33" r="5" fill="black"/>`,
  factory: `
  <path d="M10 50V28l13 8V25l14 9V21l17 11v18H10Z" fill="black"/>
  <path d="M18 44h7M31 44h7M44 44h6" stroke="white" stroke-width="3" stroke-linecap="round"/>`,
  fireworks: `
  <circle cx="32" cy="32" r="5" fill="black"/>
  <path d="M32 8v14M32 42v14M8 32h14M42 32h14M15 15l10 10M39 39l10 10M49 15 39 25M25 39 15 49" ${attrs}/>` ,
  gemini: `
  <path d="M32 7c4 14 11 21 25 25-14 4-21 11-25 25-4-14-11-21-25-25 14-4 21-11 25-25Z" fill="black"/>`,
  groq: `
  <path d="M36 8 14 36h17l-3 20 22-30H33l3-18Z" fill="black"/>`,
  kimi: `
  <path d="M45 11c-10 2-18 11-18 22 0 9 5 16 13 20-3 1-6 2-9 2-13 0-23-10-23-23S18 9 31 9c5 0 10 2 14 5v-3Z" fill="black"/>
  <circle cx="42" cy="27" r="5" fill="white"/>`,
  minimax: `
  <path d="M10 50V16l14 18 8-12 8 12 14-18v34" ${attrs}/>
  <path d="M10 50h44" ${attrs}/>` ,
  mistral: `
  <path d="M13 13h14v10h10v10h14v18H37V41H27v10H13V13Z" fill="black"/>
  <path d="M27 13h10v20H27Z" fill="white" opacity=".9"/>`,
  openrouter: `
  <circle cx="14" cy="32" r="7" fill="black"/>
  <circle cx="50" cy="18" r="7" fill="black"/>
  <circle cx="50" cy="46" r="7" fill="black"/>
  <path d="M21 32h12c7 0 8-14 17-14M21 32h12c7 0 8 14 17 14" ${attrs}/>` ,
  perplexity: `
  <path d="M32 8 52 28 32 56 12 28 32 8Z" ${attrs}/>
  <path d="M32 8v48M12 28h40" ${attrs}/>`,
  qwen: `
  <circle cx="32" cy="30" r="20" ${attrs}/>
  <path d="M42 42 53 53" ${attrs}/>
  <path d="M23 31c4 5 14 5 18 0" ${attrs}/>` ,
  sambanova: `
  <path d="M13 40c8 8 18 8 25 1 5-5 1-10-8-12-9-2-13-7-8-12 6-6 17-5 26 2" ${attrs}/>
  <path d="M14 24c6-4 12-5 18-2M32 43c6 1 12-1 18-6" stroke="black" stroke-width="4.5" stroke-linecap="round"/>`,
  together: `
  <circle cx="23" cy="32" r="13" ${attrs}/>
  <circle cx="41" cy="32" r="13" ${attrs}/>
  <path d="M23 19c7 7 7 19 0 26M41 19c-7 7-7 19 0 26" stroke="black" stroke-width="4.5" stroke-linecap="round"/>`,
  vercelai: `
  <path d="M32 9 58 54H6L32 9Z" fill="black"/>`,
  vertexai: `
  <path d="M32 8 55 48H9L32 8Z" ${attrs}/>
  <circle cx="32" cy="31" r="7" fill="black"/>
  <path d="M32 8v16M23 48l7-11M41 48l-7-11" ${attrs}/>` ,
  xai: `
  <path d="M13 13 51 51M51 13 13 51" ${attrs}/>
  <path d="M20 51h31" ${attrs}/>`,
  zai: `
  <path d="M14 15h36L18 49h34" ${attrs}/>
  <path d="M43 15 18 49" stroke="black" stroke-width="4.5" stroke-linecap="round"/>`,
};

mkdirSync(resourceDir, { recursive: true });
for (const [name, body] of Object.entries(icons)) {
  writeFileSync(join(resourceDir, `ProviderIcon-${name}.svg`), svg(body));
}

console.log(`Generated ${Object.keys(icons).length} provider icons.`);
