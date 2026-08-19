# MineLink Design System v2 — Phase 1–2 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Stand up the new standalone `minelink-design-system` repo (React + TS + Vite) with the token bridge to Flutter, the preview/build pipeline, the auth screen templates, and the first sync to a brand-new claude.ai/design project.

**Architecture:** One `tokens/tokens.json` source generates both `src/tokens.css` (CSS custom properties, light+dark) and `dart/ml_tokens_v2.g.dart` (drop-in for the Flutter app). Components are presentational React; a JSON preview registry drives both the generated preview HTML cards (`@dsCard`) and the happy-dom render tests. `npm run build` emits `dist/design-project/` — the exact tree `/design-sync` pushes to the new cloud project.

**Tech Stack:** React 18, TypeScript 5, Vite 5 (lib-mode IIFE bundle), Vitest + happy-dom, plain Node ESM scripts for generators. No CSS framework, no runtime deps beyond React.

**Spec:** `docs/superpowers/specs/2026-08-07-minelink-design-system-v2-design.md` (in the Flutter repo). This plan covers spec Phases 1–2 only; Phases 3–8 (driver, mine, transporter, buyer, super-admin, shared screens) each get their own follow-up plan on top of this foundation.

## Global Constraints

- **Working directory for ALL tasks:** `C:\Users\Somebody Someone\Music\minelink-design-system\` (created in Task 1). NOT the Flutter repo. The Flutter repo is never modified by this plan (Task 9 writes only to the agent memory directory).
- **Brand anchors (verbatim, never change):** accent cyan ramp `#E6FBFF #CBF3FB #9FE7F4 #5FD6EA #22C2DE #00B5D8 #0496B6 #0A7791` (50–700, accent = 500); navy chrome `#0B2545 #0B192E #060F20 #020617` (700/800/900/950); fonts Plus Jakarta Sans (sans), JetBrains Mono (mono), Fraunces (serif).
- **Everything else is designed FRESH** — do not copy values from the Flutter repo's `ml_tokens.dart` or the old design snapshot. The values in Task 2 are the new design; use them exactly.
- **No raw colors/sizes in components** — every component style reads `var(--ml-*)` custom properties only.
- Components are **presentational only**: no fetch, no Supabase, no routing libraries.
- Colors in `tokens.json` are `#RRGGBB` or `#RRGGBBAA` hex strings only (no rgb()/hsl()).
- Package name: `@minelink/design-system`. Package manager: **npm**.
- The old cloud project `9acfde5e-374e-4e39-9ce9-4026310c1c7c` is **never read from or written to**.
- Generated files (`src/tokens.css`, `dart/ml_tokens_v2.g.dart`) are committed; each has a "GENERATED — do not edit" header.
- Fonts load via Google Fonts `@import` in `tokens.css` (all three families are on Google Fonts).
- Every commit message ends with `Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>`.

---

### Task 1: Repo scaffold & toolchain

**Files:**
- Create: `package.json`, `tsconfig.json`, `vite.config.ts`, `vitest.config.ts`, `eslint.config.js`, `.gitignore`, `README.md`, `src/index.ts`

**Interfaces:**
- Produces: npm scripts `check` (tsc + eslint), `test` (vitest run), `tokens` (Task 3/4 generator), `build` (Task 5 pipeline). Later tasks rely on these exact script names.

- [ ] **Step 1: Create the directory and init git**

```bash
mkdir -p "C:\Users\Somebody Someone\Music\minelink-design-system"
cd "C:\Users\Somebody Someone\Music\minelink-design-system"
git init -b main
```

- [ ] **Step 2: Write `package.json`**

```json
{
  "name": "@minelink/design-system",
  "version": "0.1.0",
  "private": true,
  "type": "module",
  "scripts": {
    "tokens": "node tokens/build-tokens.mjs",
    "tokens:check": "node tokens/build-tokens.mjs --check",
    "build": "vite build && node scripts/build-design-project.mjs",
    "test": "vitest run",
    "check": "tsc --noEmit && eslint src scripts tokens"
  },
  "dependencies": {
    "react": "^18.3.1",
    "react-dom": "^18.3.1"
  },
  "devDependencies": {
    "@types/react": "^18.3.3",
    "@types/react-dom": "^18.3.0",
    "@vitejs/plugin-react": "^4.3.1",
    "eslint": "^9.9.0",
    "typescript-eslint": "^8.2.0",
    "happy-dom": "^15.7.4",
    "typescript": "^5.5.4",
    "vite": "^5.4.2",
    "vitest": "^2.0.5"
  }
}
```

- [ ] **Step 3: Write `tsconfig.json`**

```json
{
  "compilerOptions": {
    "target": "ES2022",
    "lib": ["ES2022", "DOM", "DOM.Iterable"],
    "module": "ESNext",
    "moduleResolution": "bundler",
    "jsx": "react-jsx",
    "strict": true,
    "noEmit": true,
    "skipLibCheck": true,
    "resolveJsonModule": true,
    "allowJs": true
  },
  "include": ["src", "scripts", "tokens", "tests"]
}
```

- [ ] **Step 4: Write `vite.config.ts`** (lib-mode IIFE bundle exposing `MLDS` global; React bundled in)

```ts
import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';

export default defineConfig({
  plugins: [react()],
  define: { 'process.env.NODE_ENV': JSON.stringify('production') },
  build: {
    outDir: 'dist/bundle',
    emptyOutDir: true,
    lib: {
      entry: 'src/index.ts',
      name: 'MLDS',
      formats: ['iife'],
      fileName: () => '_ds_bundle.js',
    },
    rollupOptions: { output: { inlineDynamicImports: true } },
  },
});
```

- [ ] **Step 5: Write `vitest.config.ts`**

```ts
import { defineConfig } from 'vitest/config';
import react from '@vitejs/plugin-react';

export default defineConfig({
  plugins: [react()],
  test: { environment: 'happy-dom', include: ['tests/**/*.test.{ts,tsx}'] },
});
```

- [ ] **Step 6: Write `eslint.config.js`**

```js
import tseslint from 'typescript-eslint';

export default tseslint.config(
  ...tseslint.configs.recommended,
  { ignores: ['dist/**', 'src/tokens.css'] },
  { rules: { '@typescript-eslint/no-explicit-any': 'off' } },
);
```

- [ ] **Step 7: Write `.gitignore` and `README.md` and a placeholder entry**

`.gitignore`:
```
node_modules/
dist/
```

`README.md`:
```markdown
# MineLink Design System v2

Standalone React + TypeScript design system for MineLink. Single token source
(`tokens/tokens.json`) generates `src/tokens.css` (web) and
`dart/ml_tokens_v2.g.dart` (Flutter). `npm run build` emits
`dist/design-project/` — the bundle /design-sync pushes to the
"MineLink Design System v2" claude.ai/design project.

Scripts: `npm run tokens` · `npm run tokens:check` · `npm run build` ·
`npm test` · `npm run check`
```

`src/index.ts` (placeholder until Task 5):
```ts
export const VERSION = '0.1.0';
```

- [ ] **Step 8: Install and verify toolchain**

Run: `npm install && npm run check && npm test`
Expected: install succeeds; `check` passes; vitest reports "no test files found" — that exit code is nonzero, so for this task only run `npx vitest run --passWithNoTests` instead of `npm test`. Expected: PASS.

- [ ] **Step 9: Commit**

```bash
git add -A
git commit -m "chore: scaffold minelink-design-system (vite+react+ts+vitest)"
```

---

### Task 2: `tokens/tokens.json` — the single source of truth

**Files:**
- Create: `tokens/tokens.json`

**Interfaces:**
- Produces: the exact JSON schema the Task 3/4 generator consumes. Sections: `font`, `color` (`brand`, `mist`, `tone`), `semantic` (`light`/`dark` with `{ref}` strings), `typeScale`, `spacing`, `radius`, `shadow`, `motion`, `layout`.

- [ ] **Step 1: Write `tokens/tokens.json`** (complete content — brand anchors kept, every other value is the fresh v2 design)

```json
{
  "$schema": "MineLink DS v2 token source. Colors are #RRGGBB or #RRGGBBAA.",
  "font": {
    "sans": "Plus Jakarta Sans",
    "mono": "JetBrains Mono",
    "serif": "Fraunces"
  },
  "color": {
    "brand": {
      "cyan50": "#E6FBFF", "cyan100": "#CBF3FB", "cyan200": "#9FE7F4",
      "cyan300": "#5FD6EA", "cyan400": "#22C2DE", "cyan500": "#00B5D8",
      "cyan600": "#0496B6", "cyan700": "#0A7791",
      "navy700": "#0B2545", "navy800": "#0B192E",
      "navy900": "#060F20", "navy950": "#020617"
    },
    "mist": {
      "mist50": "#F7FAFB", "mist100": "#EEF3F5", "mist200": "#DCE5E9",
      "mist300": "#C2D0D6", "mist400": "#93A6AF", "mist500": "#647984",
      "mist600": "#48606B", "mist700": "#354A54", "mist800": "#22333C",
      "mist900": "#131F26", "mist950": "#0A1218"
    },
    "tone": {
      "transit": {
        "light": { "fg": "#1E63BC", "bg": "#E8F1FC", "well": "#2F7DE129" },
        "dark":  { "fg": "#6FA9EF", "bg": "#6FA9EF24", "well": "#6FA9EF1F" }
      },
      "atMine": {
        "light": { "fg": "#9A5B03", "bg": "#FBF0DC", "well": "#D97E0629" },
        "dark":  { "fg": "#EFB65C", "bg": "#EFB65C24", "well": "#EFB65C1F" }
      },
      "done": {
        "light": { "fg": "#136F3E", "bg": "#E2F5EA", "well": "#1B9E5729" },
        "dark":  { "fg": "#5ECD90", "bg": "#5ECD9024", "well": "#5ECD901F" }
      },
      "warn": {
        "light": { "fg": "#B23F04", "bg": "#FCEBDF", "well": "#E8590C29" },
        "dark":  { "fg": "#F0904F", "bg": "#F0904F24", "well": "#F0904F1F" }
      },
      "error": {
        "light": { "fg": "#B02A2A", "bg": "#FBE7E7", "well": "#D9383829" },
        "dark":  { "fg": "#EF7D7D", "bg": "#EF7D7D24", "well": "#EF7D7D1F" }
      },
      "neutral": {
        "light": { "fg": "#48606B", "bg": "#EEF3F5", "well": "#93A6AF29" },
        "dark":  { "fg": "#93A6AF", "bg": "#93A6AF24", "well": "#93A6AF1F" }
      },
      "accent": {
        "light": { "fg": "#0496B6", "bg": "#E6FBFF", "well": "#00B5D829" },
        "dark":  { "fg": "#5FD6EA", "bg": "#5FD6EA24", "well": "#5FD6EA1F" }
      }
    }
  },
  "semantic": {
    "light": {
      "surfaceApp": "{color.mist.mist50}",
      "surfaceCard": "#FFFFFF",
      "surfaceSunken": "{color.mist.mist100}",
      "surfaceChrome": "{color.brand.navy800}",
      "textStrong": "{color.mist.mist900}",
      "textBody": "{color.mist.mist700}",
      "textMuted": "{color.mist.mist500}",
      "textFaint": "{color.mist.mist400}",
      "textOnChrome": "#F2F7F9",
      "borderSubtle": "{color.mist.mist200}",
      "borderCard": "{color.mist.mist200}",
      "borderStrong": "{color.mist.mist300}",
      "borderAccent": "{color.brand.cyan200}",
      "accent": "{color.brand.cyan500}",
      "accentHover": "{color.brand.cyan600}",
      "accentPress": "{color.brand.cyan700}",
      "accentSoft": "{color.brand.cyan50}",
      "focusRing": "#00B5D866"
    },
    "dark": {
      "surfaceApp": "{color.mist.mist950}",
      "surfaceCard": "{color.mist.mist900}",
      "surfaceSunken": "#0E181E",
      "surfaceChrome": "{color.brand.navy950}",
      "textStrong": "{color.mist.mist50}",
      "textBody": "{color.mist.mist200}",
      "textMuted": "{color.mist.mist400}",
      "textFaint": "{color.mist.mist500}",
      "textOnChrome": "#F2F7F9",
      "borderSubtle": "#22333C",
      "borderCard": "#22333C",
      "borderStrong": "{color.mist.mist700}",
      "borderAccent": "#0A7791",
      "accent": "{color.brand.cyan400}",
      "accentHover": "{color.brand.cyan300}",
      "accentPress": "{color.brand.cyan500}",
      "accentSoft": "#00B5D81F",
      "focusRing": "#22C2DE66"
    }
  },
  "typeScale": {
    "fsDisplay": 34, "fsH1": 28, "fsH2": 22, "fsH3": 18,
    "fsBody": 15, "fsSmall": 13, "fsCaption": 12, "fsMicro": 11
  },
  "spacing": {
    "sp2": 2, "sp4": 4, "sp6": 6, "sp8": 8, "sp12": 12, "sp16": 16,
    "sp20": 20, "sp24": 24, "sp28": 28, "sp32": 32, "sp40": 40,
    "sp48": 48, "sp64": 64
  },
  "radius": {
    "rXs": 6, "rSm": 10, "rMd": 14, "rLg": 20, "rXl": 28, "rPill": 999
  },
  "shadow": {
    "shadowXs": [ { "x": 0, "y": 1, "blur": 2, "spread": 0, "color": "#0A121814" } ],
    "shadowSm": [ { "x": 0, "y": 2, "blur": 6, "spread": -1, "color": "#0A12181F" } ],
    "shadowMd": [ { "x": 0, "y": 6, "blur": 16, "spread": -2, "color": "#0A121826" } ],
    "shadowLg": [ { "x": 0, "y": 12, "blur": 32, "spread": -4, "color": "#0A121833" } ],
    "shadowDrawer": [ { "x": 0, "y": 16, "blur": 48, "spread": -8, "color": "#0A121847" } ]
  },
  "motion": {
    "durFast": 120, "durBase": 200, "durSlow": 320,
    "easeOut": "cubic-bezier(0.215, 0.61, 0.355, 1)"
  },
  "layout": {
    "sidebarWidth": 276, "sidebarCollapsed": 80, "appBarHeight": 68,
    "contentMaxWidth": 1320, "contentPadding": 28
  }
}
```

- [ ] **Step 2: Sanity-check it parses**

Run: `node -e "JSON.parse(require('fs').readFileSync('tokens/tokens.json','utf8')); console.log('ok')"`
Expected: `ok`

- [ ] **Step 3: Commit**

```bash
git add tokens/tokens.json
git commit -m "feat(tokens): v2 token source — brand anchors kept, fresh mist/tone/scale design"
```

---

### Task 3: Token generator — helpers + CSS emitter (TDD)

**Files:**
- Create: `tokens/lib.mjs` (pure functions), `tokens/build-tokens.mjs` (CLI), `tests/tokens-lib.test.ts`
- Generates: `src/tokens.css`

**Interfaces:**
- Produces from `tokens/lib.mjs`: `resolveRef(tokens, value)` (resolves `"{a.b.c}"` strings, passes plain values through), `kebab(name)` (`surfaceApp` → `surface-app`), `cssColor(hex)` (identity, validates `#RRGGBB`/`#RRGGBBAA`), `dartColor(hex)` (→ `Color(0xAARRGGBB)`), `shadowCss(list)` (→ box-shadow string), `buildCss(tokens)` (→ full tokens.css string). Task 4 adds `buildDart(tokens)`.
- CLI: `node tokens/build-tokens.mjs` writes outputs; `--check` compares and exits 1 on drift.

- [ ] **Step 1: Write the failing tests** — `tests/tokens-lib.test.ts`

```ts
import { describe, it, expect } from 'vitest';
import { resolveRef, kebab, cssColor, dartColor, shadowCss, buildCss } from '../tokens/lib.mjs';
import tokens from '../tokens/tokens.json';

describe('token helpers', () => {
  it('resolves {ref} paths and passes literals through', () => {
    expect(resolveRef(tokens, '{color.brand.cyan500}')).toBe('#00B5D8');
    expect(resolveRef(tokens, '#FFFFFF')).toBe('#FFFFFF');
    expect(() => resolveRef(tokens, '{color.nope.x}')).toThrow();
  });
  it('kebabs camelCase names', () => {
    expect(kebab('surfaceApp')).toBe('surface-app');
    expect(kebab('fsH1')).toBe('fs-h1');
  });
  it('validates and converts colors', () => {
    expect(cssColor('#00B5D8')).toBe('#00B5D8');
    expect(cssColor('#00B5D866')).toBe('#00B5D866');
    expect(() => cssColor('rgb(0,0,0)')).toThrow();
    expect(dartColor('#00B5D8')).toBe('Color(0xFF00B5D8)');
    expect(dartColor('#6FA9EF24')).toBe('Color(0x246FA9EF)');
  });
  it('builds box-shadow strings', () => {
    expect(shadowCss([{ x: 0, y: 2, blur: 6, spread: -1, color: '#0A12181F' }]))
      .toBe('0px 2px 6px -1px #0A12181F');
  });
});

describe('buildCss', () => {
  const css = buildCss(tokens);
  it('emits light vars on :root and dark overrides on [data-theme="dark"]', () => {
    expect(css).toContain(':root {');
    expect(css).toContain('[data-theme="dark"] {');
    expect(css).toContain('--ml-surface-app: #F7FAFB;');
    expect(css).toMatch(/\[data-theme="dark"\][^}]*--ml-surface-app: #0A1218;/s);
  });
  it('emits brand, tone, scale and font vars', () => {
    expect(css).toContain('--ml-cyan500: #00B5D8;');
    expect(css).toContain('--ml-tone-transit-fg: #1E63BC;');
    expect(css).toContain('--ml-sp16: 16px;');
    expect(css).toContain('--ml-r-md: 14px;');
    expect(css).toContain('--ml-fs-body: 15px;');
    expect(css).toContain("--ml-font-sans: 'Plus Jakarta Sans'");
    expect(css).toContain('--ml-shadow-sm: 0px 2px 6px -1px #0A12181F;');
    expect(css).toContain('--ml-dur-base: 200ms;');
    expect(css).toContain('GENERATED');
  });
});
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `npx vitest run tests/tokens-lib.test.ts`
Expected: FAIL — cannot resolve `../tokens/lib.mjs`.

- [ ] **Step 3: Implement `tokens/lib.mjs`**

```js
// Pure token-transform functions. Consumed by build-tokens.mjs and tests.
const HEX = /^#[0-9A-Fa-f]{6}([0-9A-Fa-f]{2})?$/;

export function resolveRef(tokens, value) {
  if (typeof value !== 'string' || !value.startsWith('{')) return value;
  const path = value.slice(1, -1).split('.');
  let cur = tokens;
  for (const key of path) {
    if (cur == null || !(key in cur)) throw new Error(`Unresolvable token ref: ${value}`);
    cur = cur[key];
  }
  return cur;
}

export function kebab(name) {
  return name.replace(/([a-z0-9])([A-Z])/g, '$1-$2').replace(/([A-Z])([A-Z][a-z])/g, '$1-$2').toLowerCase();
}

export function cssColor(hex) {
  if (!HEX.test(hex)) throw new Error(`Not a #RRGGBB[AA] color: ${hex}`);
  return hex;
}

export function dartColor(hex) {
  cssColor(hex);
  const rgb = hex.slice(1, 7).toUpperCase();
  const aa = (hex.length === 9 ? hex.slice(7, 9) : 'FF').toUpperCase();
  return `Color(0x${aa}${rgb})`;
}

export function shadowCss(list) {
  return list.map((s) => `${s.x}px ${s.y}px ${s.blur}px ${s.spread}px ${cssColor(s.color)}`).join(', ');
}

export function buildCss(tokens) {
  const lines = [];
  const put = (name, value) => lines.push(`  --ml-${name}: ${value};`);

  lines.push('/* GENERATED by tokens/build-tokens.mjs — do not edit. Source: tokens/tokens.json */');
  lines.push("@import url('https://fonts.googleapis.com/css2?family=Plus+Jakarta+Sans:wght@400;500;600;700;800&family=JetBrains+Mono:wght@400;500;700&family=Fraunces:opsz,wght@9..144,400;9..144,600&display=swap');");
  lines.push('');
  lines.push(':root {');
  for (const [k, v] of Object.entries(tokens.font)) put(`font-${kebab(k)}`, `'${v}'`);
  for (const ramp of Object.values(tokens.color.brand ? { b: tokens.color.brand, m: tokens.color.mist } : {}))
    for (const [k, v] of Object.entries(ramp)) put(kebab(k), cssColor(v));
  for (const [tone, modes] of Object.entries(tokens.color.tone))
    for (const [k, v] of Object.entries(modes.light)) put(`tone-${kebab(tone)}-${kebab(k)}`, cssColor(v));
  for (const [k, v] of Object.entries(tokens.semantic.light)) put(kebab(k), cssColor(resolveRef(tokens, v)));
  for (const [k, v] of Object.entries(tokens.typeScale)) put(kebab(k), `${v}px`);
  for (const [k, v] of Object.entries(tokens.spacing)) put(kebab(k), `${v}px`);
  for (const [k, v] of Object.entries(tokens.radius)) put(kebab(k), `${v}px`);
  for (const [k, v] of Object.entries(tokens.shadow)) put(kebab(k), shadowCss(v));
  put('dur-fast', `${tokens.motion.durFast}ms`);
  put('dur-base', `${tokens.motion.durBase}ms`);
  put('dur-slow', `${tokens.motion.durSlow}ms`);
  put('ease-out', tokens.motion.easeOut);
  for (const [k, v] of Object.entries(tokens.layout)) put(kebab(k), `${v}px`);
  lines.push('}');
  lines.push('');
  lines.push('[data-theme="dark"] {');
  for (const [tone, modes] of Object.entries(tokens.color.tone))
    for (const [k, v] of Object.entries(modes.dark)) put(`tone-${kebab(tone)}-${kebab(k)}`, cssColor(v));
  for (const [k, v] of Object.entries(tokens.semantic.dark)) put(kebab(k), cssColor(resolveRef(tokens, v)));
  lines.push('}');
  lines.push('');
  return lines.join('\n');
}
```

Note the ramp loop: iterate `tokens.color.brand` then `tokens.color.mist` (the `{ b, m }` object literal shown is exactly that — both ramps, in that order).

- [ ] **Step 4: Run tests to verify they pass**

Run: `npx vitest run tests/tokens-lib.test.ts`
Expected: PASS (all tests).

- [ ] **Step 5: Write the CLI `tokens/build-tokens.mjs`** (Dart emission is added in Task 4; write the file now with only CSS)

```js
import { readFileSync, writeFileSync } from 'node:fs';
import { buildCss } from './lib.mjs';

const tokens = JSON.parse(readFileSync(new URL('./tokens.json', import.meta.url), 'utf8'));
const outputs = [['src/tokens.css', buildCss(tokens)]];

const check = process.argv.includes('--check');
let drift = false;
for (const [path, content] of outputs) {
  if (check) {
    const current = (() => { try { return readFileSync(path, 'utf8'); } catch { return null; } })();
    if (current !== content) { console.error(`DRIFT: ${path}`); drift = true; }
  } else {
    writeFileSync(path, content);
    console.log(`wrote ${path}`);
  }
}
if (check) { console.log(drift ? 'tokens: drift detected' : 'tokens: clean'); process.exit(drift ? 1 : 0); }
```

- [ ] **Step 6: Generate, verify check mode, commit**

Run: `npm run tokens && npm run tokens:check && npm run check`
Expected: `wrote src/tokens.css`, then `tokens: clean` (exit 0), `check` passes.

```bash
git add tokens/lib.mjs tokens/build-tokens.mjs tests/tokens-lib.test.ts src/tokens.css
git commit -m "feat(tokens): generator — tokens.json -> tokens.css with light/dark + check mode"
```

---

### Task 4: Token generator — Dart emitter (TDD)

**Files:**
- Modify: `tokens/lib.mjs` (add `buildDart`), `tokens/build-tokens.mjs` (add output)
- Create: `tests/tokens-dart.test.ts`
- Generates: `dart/ml_tokens_v2.g.dart`

**Interfaces:**
- Consumes: `dartColor`, `resolveRef`, `kebab` from Task 3.
- Produces: `buildDart(tokens)` → complete Dart file string defining `MlTokensV2` (statics), `MlToneColorsV2`, `MlToneV2` enum with `colors(Brightness)`/`well(Brightness)`, `MlSemanticV2` with `light`/`dark` consts.

- [ ] **Step 1: Write the failing tests** — `tests/tokens-dart.test.ts`

```ts
import { describe, it, expect } from 'vitest';
import { buildDart } from '../tokens/lib.mjs';
import tokens from '../tokens/tokens.json';

describe('buildDart', () => {
  const dart = buildDart(tokens);
  it('emits header, imports and classes', () => {
    expect(dart).toContain('// GENERATED by tokens/build-tokens.mjs');
    expect(dart).toContain("import 'package:flutter/material.dart';");
    expect(dart).toContain('class MlTokensV2 {');
    expect(dart).toContain('class MlSemanticV2 {');
    expect(dart).toContain('enum MlToneV2 {');
  });
  it('emits colors, scales, motion, layout', () => {
    expect(dart).toContain('static const cyan500 = Color(0xFF00B5D8);');
    expect(dart).toContain('static const mist950 = Color(0xFF0A1218);');
    expect(dart).toContain('static const sp16 = 16.0;');
    expect(dart).toContain('static const rMd = 14.0;');
    expect(dart).toContain('static const fsBody = 15.0;');
    expect(dart).toContain("static const fontSans = 'Plus Jakarta Sans';");
    expect(dart).toContain('static const durBase = Duration(milliseconds: 200);');
    expect(dart).toContain('static const easeOut = Cubic(0.215, 0.61, 0.355, 1);');
    expect(dart).toContain('static const contentMaxWidth = 1320.0;');
  });
  it('emits shadows as BoxShadow lists', () => {
    expect(dart).toContain('static const shadowSm = [');
    expect(dart).toContain('BoxShadow(offset: Offset(0, 2), blurRadius: 6, spreadRadius: -1, color: Color(0x1F0A1218))');
  });
  it('emits semantic light/dark consts resolved to raw colors', () => {
    expect(dart).toContain('static const light = MlSemanticV2(');
    expect(dart).toContain('surfaceApp: Color(0xFFF7FAFB)');
    expect(dart).toContain('static const dark = MlSemanticV2(');
    expect(dart).toContain('surfaceApp: Color(0xFF0A1218)');
  });
  it('emits tone switch with fg/bg pairs per brightness', () => {
    expect(dart).toContain('case MlToneV2.transit:');
    expect(dart).toContain('MlToneColorsV2(Color(0xFF6FA9EF), Color(0x246FA9EF))');
    expect(dart).toContain('MlToneColorsV2(Color(0xFF1E63BC), Color(0xFFE8F1FC))');
  });
});
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `npx vitest run tests/tokens-dart.test.ts`
Expected: FAIL — `buildDart` is not exported.

- [ ] **Step 3: Implement `buildDart` in `tokens/lib.mjs`** (append)

```js
export function buildDart(tokens) {
  const L = [];
  const dc = (v) => dartColor(resolveRef(tokens, v));
  L.push('// GENERATED by tokens/build-tokens.mjs — do not edit by hand.');
  L.push('// Source of truth: tokens/tokens.json in the minelink-design-system repo.');
  L.push('// ignore_for_file: constant_identifier_names');
  L.push("import 'package:flutter/material.dart';");
  L.push('');
  L.push('class MlTokensV2 {');
  L.push('  MlTokensV2._();');
  for (const ramp of [tokens.color.brand, tokens.color.mist])
    for (const [k, v] of Object.entries(ramp)) L.push(`  static const ${k} = ${dc(v)};`);
  for (const [k, v] of Object.entries(tokens.font)) {
    const name = 'font' + k[0].toUpperCase() + k.slice(1);
    L.push(`  static const ${name} = '${v}';`);
  }
  for (const section of ['typeScale', 'spacing', 'radius', 'layout'])
    for (const [k, v] of Object.entries(tokens[section])) L.push(`  static const ${k} = ${v}.0;`);
  for (const [k, list] of Object.entries(tokens.shadow)) {
    const items = list.map((s) =>
      `BoxShadow(offset: Offset(${s.x}, ${s.y}), blurRadius: ${s.blur}, spreadRadius: ${s.spread}, color: ${dartColor(s.color)})`);
    L.push(`  static const ${k} = [${items.join(', ')}];`);
  }
  for (const k of ['durFast', 'durBase', 'durSlow'])
    L.push(`  static const ${k} = Duration(milliseconds: ${tokens.motion[k]});`);
  const nums = tokens.motion.easeOut.match(/-?[\d.]+/g).slice(1);
  L.push(`  static const easeOut = Cubic(${nums.join(', ')});`);
  L.push('}');
  L.push('');
  L.push('class MlToneColorsV2 {');
  L.push('  final Color fg;');
  L.push('  final Color bg;');
  L.push('  const MlToneColorsV2(this.fg, this.bg);');
  L.push('}');
  L.push('');
  const toneNames = Object.keys(tokens.color.tone);
  L.push(`enum MlToneV2 {`);
  L.push(`  ${toneNames.join(', ')};`);
  L.push('');
  L.push('  MlToneColorsV2 colors(Brightness brightness) {');
  L.push('    final dark = brightness == Brightness.dark;');
  L.push('    switch (this) {');
  for (const [tone, m] of Object.entries(tokens.color.tone)) {
    L.push(`      case MlToneV2.${tone}:`);
    L.push(`        return dark`);
    L.push(`            ? const MlToneColorsV2(${dartColor(m.dark.fg)}, ${dartColor(m.dark.bg)})`);
    L.push(`            : const MlToneColorsV2(${dartColor(m.light.fg)}, ${dartColor(m.light.bg)});`);
  }
  L.push('    }');
  L.push('  }');
  L.push('');
  L.push('  Color well(Brightness brightness) {');
  L.push('    final dark = brightness == Brightness.dark;');
  L.push('    switch (this) {');
  for (const [tone, m] of Object.entries(tokens.color.tone)) {
    L.push(`      case MlToneV2.${tone}:`);
    L.push(`        return dark ? const ${dartColor(m.dark.well)} : const ${dartColor(m.light.well)};`);
  }
  L.push('    }');
  L.push('  }');
  L.push('}');
  L.push('');
  const semKeys = Object.keys(tokens.semantic.light);
  L.push('class MlSemanticV2 {');
  for (const k of semKeys) L.push(`  final Color ${k};`);
  L.push(`  const MlSemanticV2({${semKeys.map((k) => `required this.${k}`).join(', ')}});`);
  for (const mode of ['light', 'dark']) {
    L.push(`  static const ${mode} = MlSemanticV2(`);
    for (const k of semKeys) L.push(`    ${k}: ${dc(tokens.semantic[mode][k])},`);
    L.push('  );');
  }
  L.push('  static MlSemanticV2 of(BuildContext context) =>');
  L.push('      Theme.of(context).brightness == Brightness.dark ? dark : light;');
  L.push('}');
  L.push('');
  return L.join('\n');
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `npx vitest run tests/tokens-dart.test.ts`
Expected: PASS.

- [ ] **Step 5: Wire the output into the CLI**

In `tokens/build-tokens.mjs`: import `buildDart`, add `mkdirSync('dart', { recursive: true })` (import from `node:fs`), and extend outputs:

```js
const outputs = [
  ['src/tokens.css', buildCss(tokens)],
  ['dart/ml_tokens_v2.g.dart', buildDart(tokens)],
];
```

- [ ] **Step 6: Generate, verify, commit**

Run: `npm run tokens && npm run tokens:check && npm test && npm run check`
Expected: both files written, `tokens: clean`, all tests pass, check clean.

```bash
git add -A
git commit -m "feat(tokens): Dart emitter — ml_tokens_v2.g.dart (MlTokensV2/MlSemanticV2/MlToneV2)"
```

---

### Task 5: Preview pipeline — Button, registry, bundle, design-project build, render check

**Files:**
- Create: `src/components/core/Button.tsx`, `src/base.css`, `src/previews/registry.json`, `src/index.ts` (replace placeholder), `scripts/build-design-project.mjs`, `tests/render-previews.test.tsx`

**Interfaces:**
- Produces: `Button` props `{ variant?: 'primary'|'secondary'|'ghost'|'danger'; size?: 'sm'|'md'|'lg'; disabled?: boolean; children }`.
- Registry entry shape (all later tasks add entries in this exact shape): `{ "id": "components/core/button", "group": "Core", "name": "Buttons", "subtitle": "Primary / secondary / ghost / danger", "component": "Button", "width": 720, "variants": [ {props...} ] }` — `id` is the design-project HTML path without extension; `component` must be an export of `src/index.ts`; `variants[i].children` may be a string.
- Bundle global: `window.MLDS = { renderPreviewById(id, mountEl) , registry, ...components }`.
- Build script output tree: `dist/design-project/{_ds_bundle.js, styles.css, components/**.html, templates/**.html}` — each HTML's FIRST line is `<!-- @dsCard group="…" name="…" subtitle="…" width="…" -->`.

- [ ] **Step 1: Write the failing render test** — `tests/render-previews.test.tsx`

```tsx
import { describe, it, expect } from 'vitest';
import { createElement } from 'react';
import { createRoot } from 'react-dom/client';
import { flushSync } from 'react-dom';
import registry from '../src/previews/registry.json';
import * as DS from '../src/index';

function renderHtml(componentName: string, props: Record<string, unknown>): string {
  const Comp = (DS as Record<string, any>)[componentName];
  expect(Comp, `component ${componentName} must be exported from src/index.ts`).toBeTruthy();
  const el = document.createElement('div');
  const root = createRoot(el);
  flushSync(() => root.render(createElement(Comp, props)));
  return el.innerHTML;
}

describe('every registry entry renders', () => {
  for (const entry of registry) {
    it(`${entry.id} renders all variants non-empty and non-identical`, () => {
      const htmls = entry.variants.map((v: Record<string, unknown>) => renderHtml(entry.component, v));
      for (const h of htmls) expect(h.length).toBeGreaterThan(20);
      if (htmls.length > 1) expect(new Set(htmls).size).toBeGreaterThan(1);
    });
  }
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `npx vitest run tests/render-previews.test.tsx`
Expected: FAIL — `registry.json` does not exist.

- [ ] **Step 3: Write `src/base.css`, `Button`, registry, and the bundle entry**

`src/base.css` (component classes; imported by the bundle, concatenated into styles.css by the build script):

```css
/* Component styles. All values via tokens.css custom properties. */
* { box-sizing: border-box; }
body { margin: 0; font-family: var(--ml-font-sans), system-ui, sans-serif; background: var(--ml-surface-app); color: var(--ml-text-body); font-size: var(--ml-fs-body); }

.ml-btn { display: inline-flex; align-items: center; justify-content: center; gap: var(--ml-sp8); border: 1px solid transparent; border-radius: var(--ml-r-sm); font-family: inherit; font-weight: 600; cursor: pointer; transition: background var(--ml-dur-fast) var(--ml-ease-out), border-color var(--ml-dur-fast) var(--ml-ease-out); }
.ml-btn:focus-visible { outline: 3px solid var(--ml-focus-ring); outline-offset: 1px; }
.ml-btn[disabled] { opacity: 0.5; cursor: not-allowed; }
.ml-btn--sm { height: 32px; padding: 0 var(--ml-sp12); font-size: var(--ml-fs-small); }
.ml-btn--md { height: 40px; padding: 0 var(--ml-sp16); font-size: var(--ml-fs-body); }
.ml-btn--lg { height: 48px; padding: 0 var(--ml-sp24); font-size: var(--ml-fs-h3); }
.ml-btn--primary { background: var(--ml-accent); color: #FFFFFF; }
.ml-btn--primary:hover:not([disabled]) { background: var(--ml-accent-hover); }
.ml-btn--secondary { background: var(--ml-surface-card); color: var(--ml-text-strong); border-color: var(--ml-border-strong); }
.ml-btn--secondary:hover:not([disabled]) { border-color: var(--ml-accent); }
.ml-btn--ghost { background: transparent; color: var(--ml-accent); }
.ml-btn--ghost:hover:not([disabled]) { background: var(--ml-accent-soft); }
.ml-btn--danger { background: var(--ml-tone-error-fg); color: #FFFFFF; }
```

`src/components/core/Button.tsx`:

```tsx
import type { ReactNode } from 'react';

export interface ButtonProps {
  variant?: 'primary' | 'secondary' | 'ghost' | 'danger';
  size?: 'sm' | 'md' | 'lg';
  disabled?: boolean;
  children: ReactNode;
}

export function Button({ variant = 'primary', size = 'md', disabled, children }: ButtonProps) {
  return (
    <button type="button" className={`ml-btn ml-btn--${variant} ml-btn--${size}`} disabled={disabled}>
      {children}
    </button>
  );
}
```

`src/previews/registry.json`:

```json
[
  {
    "id": "components/core/button",
    "group": "Core",
    "name": "Buttons",
    "subtitle": "Primary / secondary / ghost / danger · 3 sizes",
    "component": "Button",
    "width": 720,
    "variants": [
      { "variant": "primary", "children": "Dispatch route" },
      { "variant": "secondary", "children": "View recon" },
      { "variant": "ghost", "children": "Cancel" },
      { "variant": "danger", "children": "Reject request" },
      { "variant": "primary", "size": "sm", "children": "Small" },
      { "variant": "primary", "size": "lg", "children": "Large" },
      { "variant": "primary", "disabled": true, "children": "Disabled" }
    ]
  }
]
```

`src/index.ts` (replace placeholder — this is both the library surface and the bundle entry):

```ts
import './tokens.css';
import './base.css';
import { createElement, Fragment } from 'react';
import { createRoot } from 'react-dom/client';
import registryData from './previews/registry.json';

export { Button } from './components/core/Button';
export type { ButtonProps } from './components/core/Button';

export const registry = registryData;

import * as self from './index';

export function renderPreviewById(id: string, mountEl: HTMLElement) {
  const entry = (registryData as any[]).find((e) => e.id === id);
  if (!entry) throw new Error(`No registry entry: ${id}`);
  const Comp = (self as Record<string, any>)[entry.component];
  const section = (theme: string) =>
    createElement(
      'div',
      { key: theme, 'data-theme': theme === 'dark' ? 'dark' : undefined,
        style: { background: 'var(--ml-surface-app)', padding: 24, display: 'flex', flexWrap: 'wrap', gap: 12, alignItems: 'center' } },
      entry.variants.map((v: any, i: number) => createElement(Comp, { ...v, key: i })),
    );
  createRoot(mountEl).render(createElement(Fragment, null, section('light'), section('dark')));
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `npx vitest run tests/render-previews.test.tsx`
Expected: PASS.

- [ ] **Step 5: Write `scripts/build-design-project.mjs`**

```js
import { mkdirSync, writeFileSync, readFileSync, cpSync } from 'node:fs';
import { dirname, join } from 'node:path';

const OUT = 'dist/design-project';
const registry = JSON.parse(readFileSync('src/previews/registry.json', 'utf8'));

mkdirSync(OUT, { recursive: true });
cpSync('dist/bundle/_ds_bundle.js', join(OUT, '_ds_bundle.js'));
// vite lib-mode emits extracted CSS (tokens.css + base.css) next to the bundle
cpSync('dist/bundle/style.css', join(OUT, 'styles.css'));

const manifest = [];
for (const e of registry) {
  const rel = `${e.id}.html`;
  const depth = rel.split('/').length - 1;
  const up = '../'.repeat(depth);
  const html = [
    `<!-- @dsCard group="${e.group}" name="${e.name}" subtitle="${e.subtitle ?? ''}" width="${e.width ?? 800}" -->`,
    '<!doctype html>',
    '<html><head><meta charset="utf-8">',
    `<link rel="stylesheet" href="${up}styles.css">`,
    `<script src="${up}_ds_bundle.js"></script>`,
    '</head><body>',
    '<div id="root"></div>',
    `<script>MLDS.renderPreviewById(${JSON.stringify(e.id)}, document.getElementById('root'));</script>`,
    '</body></html>',
  ].join('\n');
  mkdirSync(join(OUT, dirname(rel)), { recursive: true });
  writeFileSync(join(OUT, rel), html);
  manifest.push({ path: rel, group: e.group, name: e.name, subtitle: e.subtitle ?? '', width: e.width ?? 800 });
}
writeFileSync(join(OUT, '_ds_manifest.json'), JSON.stringify(manifest, null, 2));
console.log(`design-project: ${manifest.length} cards -> ${OUT}`);
```

- [ ] **Step 6: Build and verify the bundle output**

Run: `npm run build`
Expected: vite build succeeds; script prints `design-project: 1 cards -> dist/design-project`. Verify `dist/design-project/` contains `_ds_bundle.js`, `styles.css`, `_ds_manifest.json`, `components/core/button.html`, and that `button.html`'s first line is the `@dsCard` comment. If vite emitted the CSS under a different name than `dist/bundle/style.css`, adjust the `cpSync` source to the actual emitted filename and re-run.

Open `dist/design-project/components/core/button.html` in a browser (`start` on Windows): both light and dark rows of buttons render styled.

- [ ] **Step 7: Full gate + commit**

Run: `npm test && npm run check`
Expected: PASS / clean.

```bash
git add -A
git commit -m "feat(pipeline): preview registry, MLDS bundle, design-project build, render tests, Button"
```

---

### Task 6: Auth primitives — TextField, PasswordField, InlineAlert, AuthShell

**Files:**
- Create: `src/components/forms/TextField.tsx`, `src/components/forms/PasswordField.tsx`, `src/components/feedback/InlineAlert.tsx`, `src/components/core/AuthShell.tsx`
- Modify: `src/index.ts` (exports), `src/base.css` (styles), `src/previews/registry.json` (4 new entries)

**Interfaces:**
- Consumes: registry/test pipeline from Task 5.
- Produces:
  - `TextField` props `{ label: string; placeholder?: string; value?: string; hint?: string; error?: string; type?: string }`
  - `PasswordField` props `{ label: string; placeholder?: string; value?: string; error?: string; revealed?: boolean }`
  - `InlineAlert` props `{ tone: 'transit'|'atMine'|'done'|'warn'|'error'|'neutral'|'accent'; title: string; children?: ReactNode }`
  - `AuthShell` props `{ title: string; subtitle?: string; children; footer?: ReactNode }` — navy brand panel left / form card right, stacking on narrow widths. Task 7 templates compose ONLY these + `Button`.

- [ ] **Step 1: Add the four registry entries (failing tests)** — append to `src/previews/registry.json`:

```json
  {
    "id": "components/forms/text-field",
    "group": "Forms",
    "name": "Text field",
    "subtitle": "Default / hint / error / filled",
    "component": "TextField",
    "width": 640,
    "variants": [
      { "label": "Email address", "placeholder": "you@company.co.za" },
      { "label": "Email address", "placeholder": "you@company.co.za", "hint": "Use your work email" },
      { "label": "Email address", "value": "not-an-email", "error": "Enter a valid email address" },
      { "label": "Company", "value": "Iron Hills Mining" }
    ]
  },
  {
    "id": "components/forms/password-field",
    "group": "Forms",
    "name": "Password field",
    "subtitle": "Masked / revealed / error",
    "component": "PasswordField",
    "width": 640,
    "variants": [
      { "label": "Password", "value": "hunter2secret" },
      { "label": "Password", "value": "hunter2secret", "revealed": true },
      { "label": "Password", "value": "abc", "error": "Minimum 8 characters" }
    ]
  },
  {
    "id": "components/feedback/inline-alert",
    "group": "Feedback",
    "name": "Inline alert",
    "subtitle": "All 7 tones",
    "component": "InlineAlert",
    "width": 640,
    "variants": [
      { "tone": "done", "title": "Password updated", "children": "You can now sign in." },
      { "tone": "error", "title": "Sign-in failed", "children": "Email or password is incorrect." },
      { "tone": "warn", "title": "Link expiring", "children": "This reset link expires in 10 minutes." },
      { "tone": "accent", "title": "OTP sent", "children": "Check WhatsApp for your code." },
      { "tone": "transit", "title": "Request in transit" },
      { "tone": "atMine", "title": "Awaiting approval" },
      { "tone": "neutral", "title": "Signed out" }
    ]
  },
  {
    "id": "components/core/auth-shell",
    "group": "Core",
    "name": "Auth shell",
    "subtitle": "Brand panel + form card",
    "component": "AuthShell",
    "width": 1100,
    "variants": [
      { "title": "Welcome back", "subtitle": "Sign in to MineLink", "children": "…form goes here…" }
    ]
  }
```

Run: `npx vitest run tests/render-previews.test.tsx` — Expected: FAIL (components not exported).

- [ ] **Step 2: Implement the components**

`src/components/forms/TextField.tsx`:

```tsx
export interface TextFieldProps {
  label: string;
  placeholder?: string;
  value?: string;
  hint?: string;
  error?: string;
  type?: string;
}

export function TextField({ label, placeholder, value, hint, error, type = 'text' }: TextFieldProps) {
  return (
    <label className={`ml-field${error ? ' ml-field--error' : ''}`}>
      <span className="ml-field__label">{label}</span>
      <input className="ml-field__input" type={type} placeholder={placeholder} defaultValue={value} />
      {error ? <span className="ml-field__error">{error}</span>
        : hint ? <span className="ml-field__hint">{hint}</span> : null}
    </label>
  );
}
```

`src/components/forms/PasswordField.tsx`:

```tsx
export interface PasswordFieldProps {
  label: string;
  placeholder?: string;
  value?: string;
  error?: string;
  revealed?: boolean;
}

export function PasswordField({ label, placeholder, value, error, revealed }: PasswordFieldProps) {
  return (
    <label className={`ml-field${error ? ' ml-field--error' : ''}`}>
      <span className="ml-field__label">{label}</span>
      <span className="ml-field__wrap">
        <input className="ml-field__input" type={revealed ? 'text' : 'password'} placeholder={placeholder} defaultValue={value} />
        <button type="button" className="ml-field__reveal" aria-label={revealed ? 'Hide password' : 'Show password'}>
          {revealed ? 'Hide' : 'Show'}
        </button>
      </span>
      {error ? <span className="ml-field__error">{error}</span> : null}
    </label>
  );
}
```

`src/components/feedback/InlineAlert.tsx`:

```tsx
import type { ReactNode } from 'react';

export type Tone = 'transit' | 'atMine' | 'done' | 'warn' | 'error' | 'neutral' | 'accent';

export interface InlineAlertProps { tone: Tone; title: string; children?: ReactNode }

const toneVar = (tone: Tone) => tone === 'atMine' ? 'at-mine' : tone;

export function InlineAlert({ tone, title, children }: InlineAlertProps) {
  return (
    <div className="ml-alert" style={{
      background: `var(--ml-tone-${toneVar(tone)}-bg)`,
      color: `var(--ml-tone-${toneVar(tone)}-fg)`,
    }}>
      <strong className="ml-alert__title">{title}</strong>
      {children ? <span className="ml-alert__body">{children}</span> : null}
    </div>
  );
}
```

`src/components/core/AuthShell.tsx`:

```tsx
import type { ReactNode } from 'react';

export interface AuthShellProps { title: string; subtitle?: string; children: ReactNode; footer?: ReactNode }

export function AuthShell({ title, subtitle, children, footer }: AuthShellProps) {
  return (
    <div className="ml-auth">
      <aside className="ml-auth__brand">
        <div className="ml-auth__wordmark">Mine<span>Link</span></div>
        <p className="ml-auth__tag">Mine-to-port logistics, reconciled to the ton.</p>
      </aside>
      <main className="ml-auth__panel">
        <div className="ml-auth__card">
          <h1 className="ml-auth__title">{title}</h1>
          {subtitle ? <p className="ml-auth__subtitle">{subtitle}</p> : null}
          <div className="ml-auth__form">{children}</div>
          {footer ? <div className="ml-auth__footer">{footer}</div> : null}
        </div>
      </main>
    </div>
  );
}
```

Append to `src/base.css`:

```css
.ml-field { display: flex; flex-direction: column; gap: var(--ml-sp6); min-width: 260px; }
.ml-field__label { font-size: var(--ml-fs-small); font-weight: 600; color: var(--ml-text-strong); }
.ml-field__wrap { position: relative; display: flex; }
.ml-field__input { width: 100%; height: 42px; padding: 0 var(--ml-sp12); border: 1px solid var(--ml-border-strong); border-radius: var(--ml-r-sm); background: var(--ml-surface-card); color: var(--ml-text-strong); font: inherit; }
.ml-field__input:focus-visible { outline: 3px solid var(--ml-focus-ring); outline-offset: 0; border-color: var(--ml-accent); }
.ml-field--error .ml-field__input { border-color: var(--ml-tone-error-fg); }
.ml-field__hint { font-size: var(--ml-fs-caption); color: var(--ml-text-muted); }
.ml-field__error { font-size: var(--ml-fs-caption); color: var(--ml-tone-error-fg); }
.ml-field__reveal { position: absolute; right: var(--ml-sp8); top: 50%; transform: translateY(-50%); border: 0; background: none; color: var(--ml-accent); font-size: var(--ml-fs-caption); font-weight: 700; cursor: pointer; }

.ml-alert { display: flex; flex-direction: column; gap: var(--ml-sp2); padding: var(--ml-sp12) var(--ml-sp16); border-radius: var(--ml-r-sm); }
.ml-alert__title { font-size: var(--ml-fs-small); }
.ml-alert__body { font-size: var(--ml-fs-small); opacity: 0.9; }

.ml-auth { display: flex; min-height: 640px; background: var(--ml-surface-app); }
.ml-auth__brand { flex: 1 1 40%; background: linear-gradient(160deg, var(--ml-navy700), var(--ml-navy950)); color: #F2F7F9; display: flex; flex-direction: column; justify-content: center; padding: var(--ml-sp48); }
.ml-auth__wordmark { font-family: var(--ml-font-serif), serif; font-size: var(--ml-fs-display); font-weight: 600; }
.ml-auth__wordmark span { color: var(--ml-cyan400); }
.ml-auth__tag { margin-top: var(--ml-sp12); color: var(--ml-mist300); max-width: 34ch; }
.ml-auth__panel { flex: 1 1 60%; display: flex; align-items: center; justify-content: center; padding: var(--ml-sp32); }
.ml-auth__card { width: min(420px, 100%); background: var(--ml-surface-card); border: 1px solid var(--ml-border-card); border-radius: var(--ml-r-lg); box-shadow: var(--ml-shadow-md); padding: var(--ml-sp32); display: flex; flex-direction: column; gap: var(--ml-sp16); }
.ml-auth__title { margin: 0; font-size: var(--ml-fs-h1); color: var(--ml-text-strong); }
.ml-auth__subtitle { margin: 0; color: var(--ml-text-muted); }
.ml-auth__form { display: flex; flex-direction: column; gap: var(--ml-sp16); }
.ml-auth__footer { font-size: var(--ml-fs-small); color: var(--ml-text-muted); }
@media (max-width: 760px) { .ml-auth { flex-direction: column; } .ml-auth__brand { padding: var(--ml-sp24); } }
```

Add exports to `src/index.ts` (after the Button export):

```ts
export { TextField } from './components/forms/TextField';
export { PasswordField } from './components/forms/PasswordField';
export { InlineAlert } from './components/feedback/InlineAlert';
export { AuthShell } from './components/core/AuthShell';
```

- [ ] **Step 3: Run tests to verify they pass**

Run: `npm test`
Expected: PASS — all registry entries render.

- [ ] **Step 4: Build + visual spot-check + commit**

Run: `npm run build`, open `dist/design-project/components/core/auth-shell.html` and `components/feedback/inline-alert.html` in a browser; verify light + dark sections look right.

```bash
git add -A
git commit -m "feat(components): auth primitives — TextField, PasswordField, InlineAlert, AuthShell"
```

---

### Task 7: Auth screen templates (Phase 2 — five screens)

**Files:**
- Create: `src/templates/auth/LoginScreen.tsx`, `ForgotPasswordScreen.tsx`, `ResetPasswordScreen.tsx`, `WhatsAppOtpScreen.tsx`, `MandatoryPasswordScreen.tsx` (same folder)
- Modify: `src/index.ts` (exports), `src/previews/registry.json` (5 entries), `src/base.css` (OTP boxes)

**Interfaces:**
- Consumes: `AuthShell`, `TextField`, `PasswordField`, `InlineAlert`, `Button` exactly as defined in Tasks 5–6.
- Produces: five zero-prop template components (each accepts optional `{ state?: string }` to preview alternate states).

- [ ] **Step 1: Add the five registry entries (failing tests)** — append to `src/previews/registry.json`:

```json
  {
    "id": "templates/auth/login",
    "group": "Auth screens",
    "name": "Login",
    "subtitle": "Default / error",
    "component": "LoginScreen",
    "width": 1200,
    "variants": [ {}, { "state": "error" } ]
  },
  {
    "id": "templates/auth/forgot-password",
    "group": "Auth screens",
    "name": "Forgot password",
    "subtitle": "Default / sent",
    "component": "ForgotPasswordScreen",
    "width": 1200,
    "variants": [ {}, { "state": "sent" } ]
  },
  {
    "id": "templates/auth/reset-password",
    "group": "Auth screens",
    "name": "Reset password",
    "subtitle": "Default / done",
    "component": "ResetPasswordScreen",
    "width": 1200,
    "variants": [ {}, { "state": "done" } ]
  },
  {
    "id": "templates/auth/whatsapp-otp",
    "group": "Auth screens",
    "name": "WhatsApp OTP",
    "subtitle": "Enter code / invalid",
    "component": "WhatsAppOtpScreen",
    "width": 1200,
    "variants": [ {}, { "state": "invalid" } ]
  },
  {
    "id": "templates/auth/mandatory-password",
    "group": "Auth screens",
    "name": "Mandatory password change",
    "subtitle": "First-login gate",
    "component": "MandatoryPasswordScreen",
    "width": 1200,
    "variants": [ {} ]
  }
```

Run: `npm test` — Expected: FAIL (templates not exported).

- [ ] **Step 2: Implement the five templates**

`src/templates/auth/LoginScreen.tsx`:

```tsx
import { AuthShell } from '../../components/core/AuthShell';
import { TextField } from '../../components/forms/TextField';
import { PasswordField } from '../../components/forms/PasswordField';
import { InlineAlert } from '../../components/feedback/InlineAlert';
import { Button } from '../../components/core/Button';

export function LoginScreen({ state }: { state?: string }) {
  return (
    <AuthShell title="Welcome back" subtitle="Sign in to your MineLink workspace"
      footer={<span>Trouble signing in? <a href="#">Reset your password</a> or <a href="#">use a WhatsApp code</a>.</span>}>
      {state === 'error' ? <InlineAlert tone="error" title="Sign-in failed">Email or password is incorrect.</InlineAlert> : null}
      <TextField label="Email address" placeholder="you@company.co.za" type="email" />
      <PasswordField label="Password" placeholder="Your password" />
      <Button variant="primary" size="lg">Sign in</Button>
    </AuthShell>
  );
}
```

`src/templates/auth/ForgotPasswordScreen.tsx`:

```tsx
import { AuthShell } from '../../components/core/AuthShell';
import { TextField } from '../../components/forms/TextField';
import { InlineAlert } from '../../components/feedback/InlineAlert';
import { Button } from '../../components/core/Button';

export function ForgotPasswordScreen({ state }: { state?: string }) {
  return (
    <AuthShell title="Reset your password" subtitle="We'll email you a secure reset link"
      footer={<a href="#">Back to sign in</a>}>
      {state === 'sent' ? <InlineAlert tone="done" title="Reset link sent">Check your inbox — the link expires in 60 minutes.</InlineAlert> : null}
      <TextField label="Email address" placeholder="you@company.co.za" type="email" />
      <Button variant="primary" size="lg">Send reset link</Button>
    </AuthShell>
  );
}
```

`src/templates/auth/ResetPasswordScreen.tsx`:

```tsx
import { AuthShell } from '../../components/core/AuthShell';
import { PasswordField } from '../../components/forms/PasswordField';
import { InlineAlert } from '../../components/feedback/InlineAlert';
import { Button } from '../../components/core/Button';

export function ResetPasswordScreen({ state }: { state?: string }) {
  return (
    <AuthShell title="Choose a new password" subtitle="Minimum 8 characters">
      {state === 'done' ? <InlineAlert tone="done" title="Password updated">You can now sign in with your new password.</InlineAlert> : null}
      <PasswordField label="New password" />
      <PasswordField label="Confirm new password" />
      <Button variant="primary" size="lg">Update password</Button>
    </AuthShell>
  );
}
```

`src/templates/auth/WhatsAppOtpScreen.tsx`:

```tsx
import { AuthShell } from '../../components/core/AuthShell';
import { InlineAlert } from '../../components/feedback/InlineAlert';
import { Button } from '../../components/core/Button';

export function WhatsAppOtpScreen({ state }: { state?: string }) {
  return (
    <AuthShell title="Enter your code" subtitle="We sent a 6-digit code to your WhatsApp"
      footer={<span>Didn't get it? <a href="#">Resend code</a></span>}>
      {state === 'invalid'
        ? <InlineAlert tone="error" title="Invalid code">That code didn't match — try again.</InlineAlert>
        : <InlineAlert tone="accent" title="OTP sent">Check WhatsApp on +27 •• ••• 4821.</InlineAlert>}
      <div className="ml-otp">
        {[1, 2, 3, 4, 5, 6].map((i) => (
          <input key={i} className="ml-otp__box" maxLength={1} defaultValue={state === 'invalid' ? '' : String(i % 10)} aria-label={`Digit ${i}`} />
        ))}
      </div>
      <Button variant="primary" size="lg">Verify</Button>
    </AuthShell>
  );
}
```

`src/templates/auth/MandatoryPasswordScreen.tsx`:

```tsx
import { AuthShell } from '../../components/core/AuthShell';
import { PasswordField } from '../../components/forms/PasswordField';
import { InlineAlert } from '../../components/feedback/InlineAlert';
import { Button } from '../../components/core/Button';

export function MandatoryPasswordScreen(_props: { state?: string }) {
  return (
    <AuthShell title="Set your own password" subtitle="Your account was created with a temporary password">
      <InlineAlert tone="warn" title="Password change required">For security you must set a new password before continuing.</InlineAlert>
      <PasswordField label="Temporary password" />
      <PasswordField label="New password" />
      <PasswordField label="Confirm new password" />
      <Button variant="primary" size="lg">Save and continue</Button>
    </AuthShell>
  );
}
```

Append to `src/base.css`:

```css
.ml-otp { display: flex; gap: var(--ml-sp8); }
.ml-otp__box { width: 48px; height: 56px; text-align: center; font-family: var(--ml-font-mono), monospace; font-size: var(--ml-fs-h2); border: 1px solid var(--ml-border-strong); border-radius: var(--ml-r-sm); background: var(--ml-surface-card); color: var(--ml-text-strong); }
.ml-otp__box:focus-visible { outline: 3px solid var(--ml-focus-ring); border-color: var(--ml-accent); }
.ml-auth__footer a, .ml-auth__form a { color: var(--ml-accent); font-weight: 600; text-decoration: none; }
```

Add exports to `src/index.ts`:

```ts
export { LoginScreen } from './templates/auth/LoginScreen';
export { ForgotPasswordScreen } from './templates/auth/ForgotPasswordScreen';
export { ResetPasswordScreen } from './templates/auth/ResetPasswordScreen';
export { WhatsAppOtpScreen } from './templates/auth/WhatsAppOtpScreen';
export { MandatoryPasswordScreen } from './templates/auth/MandatoryPasswordScreen';
```

- [ ] **Step 3: Run tests to verify they pass**

Run: `npm test && npm run check`
Expected: PASS / clean.

- [ ] **Step 4: Build + visual check of all five screens**

Run: `npm run build`. Open each `dist/design-project/templates/auth/*.html` in a browser; each renders the full screen in light then dark, no unstyled content, no blank areas.

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "feat(auth): Phase 2 — login, forgot/reset password, WhatsApp OTP, mandatory-password templates"
```

---

### Task 8: Design-sync wiring — new cloud project + first push

> **Run this task in the MAIN session, not a subagent** — the DesignSync tool prompts for user permission on `create_project` and `finalize_plan`.

**Files:**
- Create: `.design-sync/config.json`, `.design-sync/NOTES.md` (in the NEW repo)

**Interfaces:**
- Consumes: `dist/design-project/` from Task 7's build.
- Produces: the new cloud project's `projectId`, recorded in config; remote tree matching local bundle.

- [ ] **Step 1: Create the cloud project**

Call `DesignSync { method: "create_project", name: "MineLink Design System v2" }`. Record the returned `projectId`. Verify with `get_project` that it is `type: PROJECT_TYPE_DESIGN_SYSTEM`.

- [ ] **Step 2: Write `.design-sync/config.json`** (replace `<NEW_PROJECT_ID>` with the real id)

```json
{
  "projectId": "<NEW_PROJECT_ID>",
  "projectName": "MineLink Design System v2",
  "shape": "repo-authored",
  "syncDirection": "push-replace",
  "sourceDir": "dist/design-project",
  "lastPush": null
}
```

- [ ] **Step 3: Write `.design-sync/NOTES.md`**

```markdown
# design-sync notes — MineLink Design System v2

- THIS repo is the source of truth. `npm run build` emits `dist/design-project/`;
  a sync pushes that tree to the cloud project and deletes remote files not in it
  (push-replace). Never pull design files from the remote into src/.
- The OLD project `9acfde5e-374e-4e39-9ce9-4026310c1c7c` ("MineLink Design System")
  is legacy — never read from or write to it from this repo.
- Before every push: `npm run tokens:check && npm test && npm run check && npm run build`.
- API quirks (carried over from the old repo's sync work):
  - `write_files` body limit ≈ several MB — batch by cumulative size (~6 MB raw).
  - Reserved paths refused: any `CLAUDE.md` basename or `.claude/` path segment.
  - Server sanitizes SVGs with a strict XML parser.
  - `delete_files` takes exact file paths only — no directories, no globs.
```

- [ ] **Step 4: Verify the build gate, then push**

Run: `npm run tokens:check && npm test && npm run check && npm run build` — all clean.

Then:
1. `DesignSync { method: "list_files", projectId: <NEW_PROJECT_ID> }` — expect empty.
2. `DesignSync { method: "finalize_plan", projectId: <NEW_PROJECT_ID>, localDir: "<repo>/dist/design-project", writes: ["_ds_bundle.js", "_ds_manifest.json", "styles.css", "components/**/*.html", "templates/**/*.html"] }`.
3. `DesignSync { method: "write_files", planId: <planId>, files: [...] }` — one entry per file in `dist/design-project`, each `{ path, localPath }` with path relative to the bundle root. Batch by cumulative size if needed.
4. `DesignSync { method: "list_files", projectId: <NEW_PROJECT_ID> }` — expect exactly the local bundle's file list (10 files: bundle, styles, manifest, 5 component/template groups → count them locally first with `ls -R dist/design-project`).

- [ ] **Step 5: Stamp `lastPush` (today's date) in `.design-sync/config.json`, commit**

```bash
git add .design-sync
git commit -m "feat(sync): wire repo to new cloud project 'MineLink Design System v2' + first push"
```

- [ ] **Step 6: User verification checkpoint**

Ask the user to open the "MineLink Design System v2" project on claude.ai and confirm the cards render (Buttons, fields, alerts, 5 auth screens). Do not proceed to Task 9 until confirmed.

---

### Task 9: Update agent memory (clean-break record)

> **Main session task** — writes to the agent memory directory, not either repo.

**Files:**
- Modify: `C:\Users\Somebody Someone\.claude\projects\c--Users-Somebody-Someone-Music-SHOWME--worktree-2026-05-05T11-53-29\memory\design-sync-minelink-project.md`
- Modify: same directory's `MEMORY.md` (update the pointer line's hook text)

- [ ] **Step 1: Rewrite the memory file** to record both projects (replace `<NEW_PROJECT_ID>` with the real id):

```markdown
---
name: design-sync-minelink-project
description: "Two design projects exist: v2 (repo-authored from minelink-design-system repo) is current; the old MineLink Design System project is legacy read-only"
metadata:
  type: project
---

**Current (v2):** claude.ai/design project "MineLink Design System v2"
(projectId `<NEW_PROJECT_ID>`) is generated from the standalone repo
`C:\Users\Somebody Someone\Music\minelink-design-system\` — repo-authored,
push-replace. `npm run build` there emits `dist/design-project/` which a
/design-sync run pushes. tokens/tokens.json in that repo also generates
`dart/ml_tokens_v2.g.dart` for the Flutter app's future adoption.

**Legacy:** "MineLink Design System" (projectId
`9acfde5e-374e-4e39-9ce9-4026310c1c7c`) — the old remote-authored project the
Flutter repo's `.design-sync/` still points at. Do not push to or pull from it.

**Why:** User decision 2026-08-07: clean break from the old design project; the
new design system is a fresh design (brand anchors kept) built as a real
React/TS library with full screen parity, phased.

**How to apply:** /design-sync runs for MineLink operate in the NEW repo against
the v2 project. Read that repo's `.design-sync/config.json` + `NOTES.md` first.
The Flutter repo's own `.design-sync/` config is historical — leave it alone.
```

- [ ] **Step 2: Update the `MEMORY.md` pointer line** for this memory to:

```
- [Design-sync: MineLink projects](design-sync-minelink-project.md) — v2 repo-authored from minelink-design-system repo is current; old project 9acfde5e… is legacy read-only
```

- [ ] **Step 3: Done — report**

No git commit (memory dir is not a repo). Report Phase 1–2 complete: repo path, cloud project id, card count pushed, and that Phases 3–8 need their own plans.

---

## Self-Review (completed at authoring)

1. **Spec coverage:** §3 layout → Tasks 1/5; §4 tokens + two outputs → Tasks 2–4; §5 component conventions → Tasks 5–6 (auth subset; remaining vocabulary lands with the phase that first needs it, per phased plan split); §6 Phases 1–2 → Tasks 1–8; §7 clean break + NOTES carry-over + memory → Tasks 8–9; §9 verification (check/test/tokens:check/build gate + list_files) → Tasks 3–8 steps. Phases 3–8: deliberately out of this plan (separate plans), consistent with spec §6 phasing.
2. **Placeholder scan:** none — all code and config content is concrete; `<NEW_PROJECT_ID>` is a runtime value produced by Task 8 Step 1, not a placeholder.
3. **Type consistency:** registry entry shape identical across Tasks 5–7; component prop names in Task 7 templates match Task 5–6 definitions (`variant`, `size`, `tone`, `label`, `hint`, `error`, `revealed`, `state`); npm script names consistent (`tokens`, `tokens:check`, `build`, `test`, `check`).
```
