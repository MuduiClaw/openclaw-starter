#!/usr/bin/env node
/**
 * Blueprint Infographic Renderer v2
 * 重建版：信息密度优先、纯中文、通用业务场景
 * 
 * Usage: node render-v2.mjs <input.json> [--output path.png] [--size xhs|wechat|square|poster]
 */
import { readFileSync, writeFileSync, mkdirSync, existsSync } from 'fs';
import { resolve, dirname, join } from 'path';
import { fileURLToPath } from 'url';

const __dirname = dirname(fileURLToPath(import.meta.url));
const ROOT = resolve(__dirname, '..');
const SIZES = {
  xhs:     { width: 1242, height: 1660 },
  wechat:  { width: 1080, height: 1920 },
  square:  { width: 1200, height: 1200 },
  poster:  { width: 1080, height: 1440 },
};

// ── CLI ──
const args = process.argv.slice(2);
let inputPath, outputPath, sizeName = 'xhs', emitHtml = false, themeName = '', fontStyle = 'default', layoutName = '';
for (let i = 0; i < args.length; i++) {
  if (args[i] === '--output' || args[i] === '-o') { outputPath = args[++i]; continue; }
  if (args[i] === '--size' || args[i] === '-s') { sizeName = args[++i]; continue; }
  if (args[i] === '--theme' || args[i] === '-t') { themeName = args[++i]; continue; }
  if (args[i] === '--font' || args[i] === '-f') { fontStyle = args[++i]; continue; }
  if (args[i] === '--layout' || args[i] === '-l') { layoutName = args[++i]; continue; }
  if (args[i] === '--html') { emitHtml = true; continue; }
  if (!inputPath) inputPath = args[i];
}
if (!inputPath) { console.error('Usage: node render-v2.mjs <input.json> [--output path.png] [--size xhs] [--theme ocean|forest|sunset|slate] [--layout banner|dense|hero|mosaic] [--font default|handwritten] [--html]'); process.exit(1); }
const size = SIZES[sizeName];
if (!size) { console.error(`Unknown size: ${sizeName}. Available: ${Object.keys(SIZES).join(', ')}`); process.exit(1); }
const data = JSON.parse(readFileSync(resolve(inputPath), 'utf8'));

// ══════════════════════════════════════════════════
// DESIGN TOKENS — Loaded from design-tokens.json
// ══════════════════════════════════════════════════
// Design OS compliant: design decisions in JSON, implementation in code.
// Add themes/fonts/layouts by editing design-tokens.json — no renderer changes needed.
const TOKENS = JSON.parse(readFileSync(resolve(ROOT, 'design-tokens.json'), 'utf8'));

// ─── Resolve themes: merge base into themes that extend it ───
const BASE = TOKENS.base;
const THEMES = {};
for (const [key, t] of Object.entries(TOKENS.themes)) {
  if (t.extends === 'base') {
    const { extends: _, name, description, ...colors } = t;
    THEMES[key] = { name, ...BASE, ...colors };
  } else {
    const { extends: _, name, description, ...rest } = t;
    THEMES[key] = { name, ...rest };
  }
}

const FONT_STYLES = {};
for (const [key, f] of Object.entries(TOKENS.fonts)) {
  const { name, $note, ...rest } = f;
  FONT_STYLES[key] = rest;
}

const LAYOUTS = {};
for (const [key, l] of Object.entries(TOKENS.layouts)) {
  const { description, ...rest } = l;
  LAYOUTS[key] = { ...rest, desc: description };
}

function themeToVars(t, fontFamily = 'Noto Sans SC', monoFamily = 'IBM Plex Mono') {
  return `
  --bg: ${t.bg}; --grid: ${t.grid};
  --black: #2B2B2B; --white: #FFFFFF;
  --card: ${t.card}; --card-alt: ${t.cardAlt};
  --border: #2B2B2B; --border-light: ${t.borderLight};
  --primary: ${t.primary}; --primary-bg: ${t.primaryBg}; --primary-light: ${t.primaryLight};
  --accent: ${t.accent}; --accent-bg: ${t.accentBg}; --accent-light: ${t.accentLight};
  --warn: ${t.warn}; --warn-bg: ${t.warnBg}; --warn-light: ${t.warnLight};
  --highlight: ${t.highlight}; --highlight-bg: ${t.highlightBg}; --highlight-light: ${t.highlightLight};
  --gray-50: ${t.gray[50]}; --gray-100: ${t.gray[100]}; --gray-200: ${t.gray[200]};
  --gray-300: ${t.gray[300]}; --gray-400: ${t.gray[400]}; --gray-500: ${t.gray[500]}; --gray-600: ${t.gray[600]};
  --font: '${fontFamily}', 'PingFang SC', sans-serif;
  --mono: '${monoFamily}', 'Consolas', monospace;`;
}

// ══════════════════════════════════════════════════
// CSS TEMPLATE — Blueprint Infographic System v2
// ══════════════════════════════════════════════════
function getCSS(width, theme, fontStyleName = 'default') {
  const fs = FONT_STYLES[fontStyleName] || FONT_STYLES.default;
  return `
* { margin:0; padding:0; box-sizing:border-box; }
:root {
  ${themeToVars(theme, fs.family, fs.mono)}
  /* 遗留兼容（部分模块引用） */
  --red: #C83030;
  --red-bg: #FDE8E8;
}

/* ─── PAGE ─── */
.page {
  width: ${width}px;
  background: var(--bg);
  position: relative;
  overflow: hidden;
  font-family: var(--font);
  color: var(--black);
  -webkit-font-smoothing: antialiased;
}
.page::before {
  content: '';
  position: absolute; inset: 0;
  background-image:
    linear-gradient(var(--grid) 0.5px, transparent 0.5px),
    linear-gradient(90deg, var(--grid) 0.5px, transparent 0.5px);
  background-size: 20px 20px;
  opacity: 0.5;
  z-index: 0;
}
.page::after {
  content: '';
  position: absolute; inset: 0;
  background-image:
    linear-gradient(var(--grid) 1px, transparent 1px),
    linear-gradient(90deg, var(--grid) 1px, transparent 1px);
  background-size: 100px 100px;
  opacity: 0.3;
  z-index: 0;
}
/* Dot grid overlay */
.dot-grid {
  position: absolute; inset: 0; z-index: 0; pointer-events: none;
  opacity: 0.12;
  background-image: radial-gradient(circle, var(--black) 0.6px, transparent 0.6px);
  background-size: 10px 10px;
  background-position: 5px 5px;
}
/* Paper noise */
.paper-noise {
  position: absolute; inset: 0; z-index: 0; pointer-events: none;
  opacity: 0.08;
  background-image: url("data:image/svg+xml,%3Csvg viewBox='0 0 200 200' xmlns='http://www.w3.org/2000/svg'%3E%3Cfilter id='n'%3E%3CfeTurbulence type='fractalNoise' baseFrequency='0.9' numOctaves='4' stitchTiles='stitch'/%3E%3C/filter%3E%3Crect width='100%25' height='100%25' filter='url(%23n)'/%3E%3C/svg%3E");
  background-size: 200px 200px;
}
.content { position: relative; z-index: 1; padding: 24px 28px; }

/* ─── CORNER MARKS ─── */
.corner {
  position: absolute; width: 36px; height: 36px; z-index: 2;
}
.corner svg { width: 100%; height: 100%; }
.c-tl { top: 10px; left: 10px; }
.c-tr { top: 10px; right: 10px; transform: scaleX(-1); }
.c-bl { bottom: 10px; left: 10px; transform: scaleY(-1); }
.c-br { bottom: 10px; right: 10px; transform: scale(-1); }
/* Edge ruler */
.edge-ruler {
  position: absolute; z-index: 2;
}
.edge-ruler.left {
  left: 6px; top: 50px; bottom: 50px; width: 10px;
}
.edge-ruler.right {
  right: 6px; top: 50px; bottom: 50px; width: 10px;
}
/* Scattered annotations */
.scatter-note {
  position: absolute;
  font-family: var(--mono);
  font-size: 6px;
  color: var(--gray-500);
  letter-spacing: 0.8px;
  z-index: 2;
}

/* ─── HEADER ─── */
.header {
  margin-bottom: 16px;
  border: 3px solid var(--black);
  box-shadow: 6px 6px 0 rgba(0,0,0,0.18);
  position: relative;
  overflow: hidden;
}
.h-banner {
  background: var(--primary);
  padding: 18px 20px 14px;
  position: relative;
}
.h-banner::after {
  content: '';
  position: absolute;
  right: 0; top: 0; bottom: 0;
  width: 160px;
  background: repeating-linear-gradient(
    -45deg,
    transparent, transparent 10px,
    rgba(0,0,0,0.08) 10px, rgba(0,0,0,0.08) 11px
  );
}
.h-title {
  font-size: 44px;
  font-weight: 900;
  line-height: 1.08;
  letter-spacing: -1px;
  color: #FFFFFF;
  position: relative;
  z-index: 1;
}
.h-eyebrow {
  font-family: var(--mono);
  font-size: 9px;
  font-weight: 700;
  letter-spacing: 2px;
  text-transform: uppercase;
  color: rgba(255,255,255,0.7);
  margin-bottom: 8px;
}
.h-foot {
  background: var(--black);
  padding: 6px 20px;
  display: flex;
  align-items: center;
  justify-content: space-between;
}
.h-sub {
  font-size: 13px;
  font-weight: 500;
  color: rgba(255,255,255,0.75);
  line-height: 1.4;
}
.h-meta {
  font-family: var(--mono);
  font-size: 7px;
  color: rgba(255,255,255,0.4);
  letter-spacing: 1px;
  text-transform: uppercase;
}

/* ─── MODULE GRID ─── */
.grid {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 8px;
  grid-auto-flow: dense;
  grid-auto-rows: minmax(140px, auto);
}
.grid.cols-3 { grid-template-columns: 1fr 1fr 1fr; }
.grid.cols-3 .mod.wide { grid-column: span 3; }
.grid.cols-3 .mod.span-2 { grid-column: span 2; }
.grid.cols-3 .mod.tall { grid-row: span 2; }

/* ─── MODULE CARD ─── */
.mod {
  background: var(--card);
  border: 3px solid var(--black);
  box-shadow: 6px 6px 0 rgba(0,0,0,0.18);
  display: flex;
  flex-direction: column;
  overflow: hidden;
  min-height: 140px;
  position: relative;
}
.mod.tall { grid-row: span 2; }
.mod.wide { grid-column: span 2; }

/* Module corner L-brackets */
.mc {
  position: absolute; inset: 0; pointer-events: none; z-index: 5;
}
.mc span {
  position: absolute;
  width: 10px; height: 10px;
  border-color: rgba(255,255,255,0.6);
  border-style: solid;
  display: block;
}
.mc span:nth-child(1) { top: 4px; left: 4px; border-width: 2px 0 0 2px; }
.mc span:nth-child(2) { top: 4px; right: 4px; border-width: 2px 2px 0 0; }
.mc span:nth-child(3) { bottom: 4px; left: 4px; border-width: 0 0 2px 2px; }
.mc span:nth-child(4) { bottom: 4px; right: 4px; border-width: 0 2px 2px 0; }
.mod-h {
  height: 28px;
  background: var(--black);
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 0 10px;
  flex-shrink: 0;
}
.mod-h-left { display: flex; align-items: center; gap: 6px; }
.mod-id {
  font-family: var(--mono);
  font-size: 8px;
  font-weight: 600;
  color: rgba(255,255,255,0.5);
  letter-spacing: 0.5px;
}
.mod-t {
  font-size: 11px;
  font-weight: 800;
  color: white;
  letter-spacing: 0.3px;
}
.mod-close {
  font-size: 10px;
  color: rgba(255,255,255,0.3);
  cursor: pointer;
}
.mod-b {
  padding: 10px 12px;
  flex: 1;
  display: flex;
  flex-direction: column;
}
/* Accent bar under module header — color set by type */
.mod-accent {
  height: 4px;
  flex-shrink: 0;
}
.mod-accent.a-primary { background: var(--primary); }
.mod-accent.a-highlight { background: var(--highlight); }
.mod-accent.a-warn { background: var(--warn); }
.mod-accent.a-accent { background: var(--accent); }
.mod-accent.a-gray { background: var(--gray-400); }

/* ─── MATRIX MODULE ─── */
.mx-grid {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 8px;
  flex: 1;
}
.mx-cell {
  padding: 7px 10px;
  border: 1px solid var(--border-light);
  display: flex;
  flex-direction: column;
  gap: 4px;
  position: relative;
}
.mx-cell.good { background: var(--card); border-color: var(--gray-200); border-left: 3px solid var(--primary); }
.mx-cell.bad { background: var(--gray-100); border-color: var(--border-light); }
.mx-cell.warn { background: var(--card); border-color: var(--gray-200); border-left: 3px solid var(--warn); }
.mx-cell.highlight { background: var(--card); border-color: var(--gray-200); border-left: 3px solid var(--primary); }
.mx-cell.bad::after {
  content: '';
  position: absolute;
  top: 0; left: 0; right: 0; bottom: 0;
  background: repeating-linear-gradient(
    -45deg,
    transparent, transparent 8px,
    rgba(0,0,0,0.04) 8px, rgba(0,0,0,0.04) 9px
  );
  pointer-events: none;
}
.mx-icon { width: 28px; height: 28px; flex-shrink: 0; }
.mx-icon svg { width: 100%; height: 100%; }
.mx-t { font-size: 12px; font-weight: 800; line-height: 1.2; }
.mx-d { font-size: 10px; color: var(--gray-600); line-height: 1.35; }
.mx-axis {
  font-family: var(--mono);
  font-size: 7px;
  color: var(--gray-500);
  text-align: center;
  margin-top: 6px;
  letter-spacing: 0.5px;
}

/* ─── TIMELINE MODULE ─── */
.tl { display: flex; flex-direction: column; flex: 1; gap: 6px; }
.tl-track {
  display: flex;
  justify-content: space-between;
  position: relative;
  padding: 0 8px;
}
.tl-track::before {
  content: '';
  position: absolute;
  top: 9px; left: 18px; right: 18px;
  height: 2px;
  background: var(--gray-300);
}
.tl-node { text-align: center; position: relative; z-index: 1; flex: 1; }
.tl-dot {
  width: 18px; height: 18px;
  border-radius: 50%;
  border: 2px solid var(--gray-300);
  background: var(--card);
  margin: 0 auto 6px;
}
.tl-dot.active { border-color: var(--highlight); background: var(--highlight); }
.tl-dot.done { border-color: var(--primary); background: var(--primary); }
.tl-year { font-family: var(--mono); font-size: 11px; font-weight: 700; }
.tl-label { font-size: 11px; font-weight: 700; margin-top: 2px; }
.tl-detail { font-size: 10px; color: var(--gray-500); margin-top: 2px; line-height: 1.4; }
.tl-bar {
  height: 8px;
  background: var(--gray-200);
  position: relative;
  margin: 0 8px;
}
.tl-fill {
  position: absolute;
  top: 0; left: 0; bottom: 0;
  background: linear-gradient(90deg, var(--gray-200), var(--primary));
}
.tl-phases {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 6px;
  padding: 0 8px;
}
.tl-phase {
  padding: 6px 8px;
  background: var(--card);
  border: 1px solid var(--gray-200);
  font-size: 10px;
  font-weight: 500;
  line-height: 1.4;
}
.tl-phase .num {
  font-family: var(--mono);
  font-size: 9px;
  font-weight: 700;
  color: var(--highlight);
  margin-right: 4px;
}

/* ─── BREAKDOWN MODULE ─── */
.bd { flex: 1; display: flex; flex-direction: column; gap: 4px; }
.bd-title {
  padding: 8px 12px;
  border: 1.5px solid var(--black);
  background: rgba(255,255,255,0.7);
  font-size: 13px;
  font-weight: 900;
  display: flex;
  align-items: center;
  justify-content: space-between;
}
.bd-stack { display: flex; flex-direction: column; gap: 0; flex: 1; }
.bd-layer {
  display: flex;
  align-items: center;
  gap: 6px;
  padding: 8px 12px;
  border: 1px solid var(--border-light);
  border-bottom: none;
  position: relative;
}
.bd-layer:last-child { border-bottom: 1px solid var(--border-light); }
.bd-layer:nth-child(odd) { background: var(--primary-light); }
.bd-layer:nth-child(even) { background: var(--card); }
.bd-layer .icon { width: 20px; height: 20px; flex-shrink: 0; }
.bd-layer .icon svg { width: 100%; height: 100%; }
.bd-layer .name { font-size: 11px; font-weight: 700; flex-shrink: 0; }
.bd-layer .desc { font-size: 9px; color: var(--gray-600); line-height: 1.35; }
.bd-layer .num {
  font-family: var(--mono);
  font-size: 7px;
  color: var(--gray-500);
  position: absolute;
  right: 8px; top: 4px;
}

/* ─── LOOP MODULE ─── */
.lp { flex: 1; display: flex; flex-direction: column; align-items: center; gap: 8px; }
.lp-diagram { position: relative; width: 100%; height: 210px; }
.lp-node {
  position: absolute;
  background: var(--card);
  border: 1.5px solid var(--black);
  padding: 5px 10px;
  font-size: 11px;
  font-weight: 700;
  box-shadow: 2px 2px 0 rgba(0,0,0,0.08);
  text-align: center;
  z-index: 2;
}
.lp-node .sub { font-size: 8px; font-weight: 400; color: var(--gray-500); margin-top: 2px; }
.lp-center {
  position: absolute;
  top: 50%; left: 50%;
  transform: translate(-50%, -50%);
  background: var(--card);
  border: 2px solid var(--black);
  padding: 10px 14px;
  text-align: center;
  z-index: 3;
  box-shadow: 3px 3px 0 rgba(0,0,0,0.10);
  max-width: 200px;
}
.lp-center .text { font-size: 12px; font-weight: 700; line-height: 1.5; }
.lp-center .sub { font-size: 10px; color: var(--gray-600); margin-top: 4px; line-height: 1.4; }
.lp-footer {
  font-size: 9px;
  color: var(--gray-500);
  text-align: center;
  padding-top: 6px;
  border-top: 1px solid var(--border-light);
  width: 100%;
}

/* ─── WARNING MODULE ─── */
.wn { flex: 1; display: flex; flex-direction: column; }
.wn-stripe {
  height: 20px;
  background: repeating-linear-gradient(45deg, var(--black) 0, var(--black) 9px, var(--highlight) 9px, var(--highlight) 18px);
  flex-shrink: 0;
}
.wn-header {
  background: var(--black);
  padding: 7px 14px;
  text-align: center;
}
.wn-header span { color: white; font-size: 14px; font-weight: 900; letter-spacing: 0.5px; }
.wn-body {
  background: var(--warn);
  padding: 10px;
  flex: 1;
  display: flex;
  gap: 8px;
  color: white;
}
.wn-icon { flex-shrink: 0; width: 50px; display: flex; align-items: center; justify-content: center; }
.wn-icon svg { width: 44px; height: 44px; }
.wn-items { flex: 1; display: flex; flex-direction: column; gap: 6px; }
.wn-headline {
  font-size: 14px;
  font-weight: 900;
  line-height: 1.2;
  margin-bottom: 2px;
}
.wn-item {
  display: flex;
  gap: 8px;
  align-items: flex-start;
  font-size: 11px;
  line-height: 1.5;
}
.wn-bullet {
  flex-shrink: 0;
  width: 16px; height: 16px;
  background: rgba(0,0,0,0.25);
  color: white;
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 9px;
  font-weight: 700;
  margin-top: 1px;
}

/* ─── STATS MODULE ─── */
.st { flex: 1; display: flex; gap: 14px; }
.st-badge {
  width: 130px;
  flex-shrink: 0;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  gap: 6px;
}
.st-badge svg { width: 110px; height: 110px; }
.st-badge .label {
  font-family: var(--mono);
  font-size: 7px;
  color: var(--gray-500);
  letter-spacing: 1px;
  text-align: center;
}
.st-metrics { flex: 1; display: flex; flex-direction: column; gap: 6px; }
.st-metric {
  padding: 10px 12px;
  background: var(--card);
  border: 1px solid var(--gray-200);
  border-left: 4px solid var(--highlight);
  display: flex;
  align-items: baseline;
  gap: 6px;
}
.st-metric.m1 { background: var(--card); border-left-color: var(--primary); }
.st-metric.m2 { background: var(--card); border-left-color: var(--highlight); }
.st-metric.m3 { background: var(--card); border-left-color: var(--gray-300); }
.st-val-wrap { display: flex; align-items: baseline; gap: 4px; flex-shrink: 0; }
.st-value { font-size: 26px; font-weight: 900; line-height: 1; letter-spacing: -1px; }
.st-unit { font-size: 11px; font-weight: 700; color: var(--gray-600); }
.st-context { font-size: 10px; color: var(--gray-500); line-height: 1.4; flex: 1; }

/* ─── PROGRESS MODULE ─── */
.pg { flex: 1; display: flex; flex-direction: column; gap: 8px; }
.pg-item { display: flex; align-items: center; gap: 8px; }
.pg-label {
  width: 70px;
  flex-shrink: 0;
  font-size: 10px;
  font-weight: 600;
  text-align: right;
  line-height: 1.3;
}
.pg-track {
  flex: 1;
  height: 22px;
  background: var(--gray-100);
  position: relative;
  border: 1px solid var(--gray-200);
}
.pg-fill {
  position: absolute;
  top: 0; left: 0; bottom: 0;
  background: var(--warn);
  display: flex;
  align-items: center;
  justify-content: flex-end;
  padding-right: 4px;
}
.pg-pct {
  font-family: var(--mono);
  font-size: 9px;
  font-weight: 700;
  color: white;
  letter-spacing: 0.5px;
}
.pg-fill.low { background: var(--gray-300); }
.pg-fill.mid { background: var(--primary); opacity: 0.7; }
.pg-fill.high { background: var(--primary); }
.pg-summary {
  display: flex;
  gap: 6px;
  padding-top: 8px;
  border-top: 1.5px solid var(--border);
}
.pg-stat {
  flex: 1;
  padding: 8px 10px;
  text-align: center;
  border: 1.5px solid var(--border-light);
}
.pg-stat .num { font-size: 28px; font-weight: 900; line-height: 1; letter-spacing: -0.5px; }
.pg-stat .text { font-size: 9px; color: var(--gray-600); margin-top: 3px; line-height: 1.3; }
.pg-stat.accent { background: var(--gray-50); border-color: var(--primary); }
.pg-stat:first-child { border-left: 3px solid var(--primary); }
.pg-note {
  font-size: 9px;
  color: var(--gray-500);
  text-align: center;
  padding-top: 4px;
  border-top: 1px solid var(--border-light);
}

/* ─── COMPARISON MODULE ─── */
.cp { flex: 1; display: flex; flex-direction: column; gap: 8px; }
.cp-cols { display: flex; gap: 8px; flex: 1; }
.cp-side { flex: 1; border: 1px solid var(--border-light); display: flex; flex-direction: column; }
.cp-side.winner { border-color: var(--primary); }
.cp-sh {
  padding: 6px 10px;
  font-size: 12px;
  font-weight: 700;
  border-bottom: 2px solid var(--border);
  display: flex;
  align-items: center;
  gap: 6px;
}
.cp-side.winner .cp-sh { border-bottom-color: var(--primary); color: var(--primary); }
.cp-item {
  padding: 5px 10px;
  font-size: 10px;
  line-height: 1.5;
  border-bottom: 1px solid var(--gray-100);
}
.cp-item:last-child { border-bottom: none; }
.cp-vs {
  display: flex;
  align-items: center;
  font-family: var(--mono);
  font-size: 14px;
  font-weight: 700;
  color: var(--gray-500);
  flex-shrink: 0;
}
.cp-verdict {
  padding: 6px 10px;
  background: var(--gray-100);
  border: 1px solid #E0C880;
  font-size: 11px;
  font-weight: 700;
  text-align: center;
}

/* ─── PYRAMID MODULE ─── */
.py { flex: 1; display: flex; flex-direction: column; justify-content: center; align-items: center; gap: 0; padding: 8px 0; }
.py-level {
  text-align: center;
  padding: 8px 14px;
  border: 1px solid var(--border);
  margin-bottom: -1px;
  display: flex;
  flex-direction: column;
  gap: 2px;
}
.py-level.top { background: var(--highlight-bg); border-color: var(--highlight); }
.py-level.mid { background: var(--primary-light); border-color: var(--primary-bg); }
.py-level.base { background: var(--gray-100); border-color: var(--gray-200); }
.py-name { font-size: 12px; font-weight: 700; }
.py-desc { font-size: 9px; color: var(--gray-600); line-height: 1.4; }

/* ─── CHART MODULE ─── */
.ch { flex: 1; display: flex; flex-direction: column; align-items: center; justify-content: center; }
.ch svg { width: 100%; }
.ch-note { font-size: 9px; color: var(--gray-500); margin-top: 6px; text-align: center; }

/* ─── FLOWCHART MODULE ─── */
.fl { flex: 1; display: flex; flex-direction: column; gap: 6px; }
.fl-row { display: flex; align-items: center; gap: 6px; justify-content: center; }
.fl-node {
  padding: 6px 12px;
  border: 1.5px solid var(--black);
  font-size: 11px;
  font-weight: 700;
  background: var(--card);
  text-align: center;
  min-width: 80px;
}
.fl-node.start { background: var(--highlight-bg); border-color: var(--highlight); border-width: 2.5px; }
.fl-node.end { background: var(--primary-light); border-color: var(--primary); border-width: 2.5px; }
.fl-node.decision {
  transform: rotate(0deg);
  background: var(--gray-50);
  border-color: #D090A0;
}
.fl-arrow {
  font-size: 14px;
  color: var(--gray-500);
  flex-shrink: 0;
}
.fl-desc {
  font-size: 9px;
  color: var(--gray-600);
  font-weight: 400;
  margin-top: 2px;
}

/* ─── CHECKLIST MODULE ─── */
.cl { flex: 1; display: flex; flex-direction: column; gap: 4px; }
.cl-item {
  display: flex;
  align-items: flex-start;
  gap: 8px;
  padding: 5px 8px;
  border-bottom: 1px solid var(--gray-100);
}
.cl-check {
  width: 16px; height: 16px;
  border: 1.5px solid var(--border);
  flex-shrink: 0;
  display: flex;
  align-items: center;
  justify-content: center;
  margin-top: 1px;
}
.cl-check.done { background: var(--card); border-color: var(--primary); }
.cl-check.fail { background: var(--gray-50); border-color: var(--warn); }
.cl-text { font-size: 10.5px; line-height: 1.5; flex: 1; }
.cl-text .note { font-size: 9px; color: var(--gray-500); display: block; margin-top: 1px; }

/* ─── FOOTER ─── */
.footer {
  margin-top: 16px;
  padding: 8px 0;
  border-top: 1px solid var(--border);
  display: flex;
  justify-content: space-between;
  align-items: center;
}
.footer .meta {
  font-family: var(--mono);
  font-size: 7px;
  color: var(--gray-500);
  letter-spacing: 0.5px;
}
.barcode {
  display: flex;
  align-items: flex-end;
  gap: 0;
  height: 16px;
}
.barcode i {
  display: block;
  width: 1px;
  background: var(--black);
}
.barcode i.s { background: transparent; }

/* ══════════════════════════════════════════════════
   LAYOUT: dense — tight 3-col, ruler frame, no banner
   ══════════════════════════════════════════════════ */
.layout-dense .content { padding: 24px 32px; }
.layout-dense .header {
  margin-bottom: 10px;
  border: none;
  box-shadow: none;
  background: transparent;
}
.layout-dense .h-banner { display: none; }
.layout-dense .h-foot { display: none; }
.layout-dense .h-inline {
  display: flex;
  align-items: baseline;
  gap: 16px;
  padding: 12px 0;
  border-bottom: 3px solid var(--black);
}
.layout-dense .h-inline-title {
  font-size: 36px;
  font-weight: 900;
  letter-spacing: -1px;
  line-height: 1.1;
}
.layout-dense .h-inline-sub {
  font-size: 12px;
  color: var(--gray-600);
  flex: 1;
}
.layout-dense .h-inline-meta {
  font-family: var(--mono);
  font-size: 7px;
  color: var(--gray-400);
  letter-spacing: 1px;
}
.layout-dense .grid { gap: 8px; }
.layout-dense .mod {
  border-width: 2px;
  box-shadow: 3px 3px 0 rgba(0,0,0,0.10);
  min-height: 160px;
}
.layout-dense .mod-h { height: 28px; }
.layout-dense .mod-b { padding: 10px; }
/* Ruler frame around page */
.ruler-frame {
  position: absolute;
  z-index: 3;
  pointer-events: none;
}
.ruler-frame.top, .ruler-frame.bottom {
  left: 20px; right: 20px; height: 14px;
}
.ruler-frame.top { top: 4px; }
.ruler-frame.bottom { bottom: 4px; }
.ruler-frame.left, .ruler-frame.right {
  top: 20px; bottom: 20px; width: 14px;
}
.ruler-frame.left { left: 4px; }
.ruler-frame.right { right: 4px; }
/* Crosshair marks */
.crosshair {
  position: absolute; z-index: 3;
  width: 20px; height: 20px;
}
.crosshair svg { width: 100%; height: 100%; }

/* ══════════════════════════════════════════════════
   LAYOUT: hero — first module as full-width hero
   ══════════════════════════════════════════════════ */
.layout-hero .content { padding: 32px 44px; }
.layout-hero .header {
  margin-bottom: 12px;
  border: none;
  box-shadow: none;
  background: transparent;
}
.layout-hero .h-banner { display: none; }
.layout-hero .h-foot { display: none; }
.layout-hero .h-minimal {
  padding: 0 0 12px;
}
.layout-hero .h-minimal-eyebrow {
  font-family: var(--mono);
  font-size: 8px;
  letter-spacing: 2px;
  color: var(--gray-500);
  margin-bottom: 6px;
}
.layout-hero .h-minimal-title {
  font-size: 48px;
  font-weight: 900;
  letter-spacing: -1px;
  line-height: 1.08;
  border-bottom: 4px solid var(--primary);
  padding-bottom: 10px;
}
.layout-hero .h-minimal-sub {
  font-size: 13px;
  color: var(--gray-600);
  margin-top: 8px;
}
.layout-hero .hero-mod {
  margin-bottom: 12px;
}
.layout-hero .hero-mod .mod {
  border-width: 3px;
  box-shadow: 8px 8px 0 rgba(0,0,0,0.15);
  min-height: 280px;
}
.layout-hero .hero-mod .mod-h {
  height: 42px;
}
.layout-hero .hero-mod .mod-t {
  font-size: 16px;
}
.layout-hero .hero-mod .mod-b {
  padding: 18px;
}

/* ══════════════════════════════════════════════════
   LAYOUT: mosaic — asymmetric grid with CSS areas
   ══════════════════════════════════════════════════ */
.layout-mosaic .content { padding: 20px 24px; }
.layout-mosaic .header {
  margin-bottom: 12px;
  border: none;
  box-shadow: none;
}
.layout-mosaic .h-banner { display: none; }
.layout-mosaic .h-foot { display: none; }
.layout-mosaic .h-strip {
  background: var(--primary);
  padding: 14px 24px;
  display: flex;
  align-items: center;
  justify-content: space-between;
  border: 3px solid var(--black);
  box-shadow: 4px 4px 0 rgba(0,0,0,0.15);
}
.layout-mosaic .h-strip-title {
  font-size: 32px;
  font-weight: 900;
  color: white;
  letter-spacing: -0.5px;
}
.layout-mosaic .h-strip-sub {
  font-size: 11px;
  color: rgba(255,255,255,0.75);
  max-width: 40%;
  text-align: right;
  line-height: 1.4;
}
.layout-mosaic .mosaic-grid {
  display: grid;
  gap: 8px;
}
/* Mosaic patterns — set by JS via grid-template-areas */
.layout-mosaic .mod { min-height: 0; flex: 1; }
.layout-mosaic .mosaic-grid > div > .mod { height: 100%; }
/* ── Wide modules (span 2 columns) emphasis ── */
.layout-mosaic .mosaic-large > .mod {
  border-width: 3px;
  box-shadow: 5px 5px 0 rgba(0,0,0,0.15);
}
.layout-mosaic .mosaic-large > .mod > .mod-h {
  font-size: 16px;
  padding: 12px 16px;
  background: var(--primary);
  letter-spacing: 0.5px;
}
/* Side modules next to large: compact, tighter */
.layout-mosaic .mosaic-side > .mod {
  border-width: 2px;
  font-size: 12px;
}
.layout-mosaic .mosaic-side > .mod > .mod-h {
  font-size: 12px;
  padding: 8px 12px;
}
`;
}

// ══════════════════════════════════════════════════
// SVG ICON LIBRARY
// ══════════════════════════════════════════════════
const ICONS = {
  cross: `<svg viewBox="0 0 24 24" fill="none" stroke="#C83030" stroke-width="2.5" stroke-linecap="round"><line x1="4" y1="4" x2="20" y2="20"/><line x1="20" y1="4" x2="4" y2="20"/></svg>`,
  check: `<svg viewBox="0 0 24 24" fill="none" stroke="var(--primary)" stroke-width="2.5" stroke-linecap="round"><polyline points="4,12 10,18 20,6"/></svg>`,
  warn: `<svg viewBox="0 0 24 24" fill="none" stroke="#D4A820" stroke-width="2" stroke-linecap="round"><path d="M12 2L2 20h20L12 2z"/><line x1="12" y1="9" x2="12" y2="14"/><circle cx="12" cy="17" r="0.5" fill="#D4A820"/></svg>`,
  star: `<svg viewBox="0 0 24 24" fill="#D4A820" stroke="none"><polygon points="12,2 15,9 22,9 16,14 18,22 12,17 6,22 8,14 2,9 9,9"/></svg>`,
  arrow: `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"><line x1="4" y1="12" x2="20" y2="12"/><polyline points="14,6 20,12 14,18"/></svg>`,
  skull: `<svg viewBox="0 0 56 56" fill="none" stroke="white" stroke-width="2">
    <polygon points="28,4 52,16 52,40 28,52 4,40 4,16" fill="none" stroke="white" stroke-width="2.5"/>
    <polygon points="28,10 46,20 46,36 28,46 10,36 10,20" fill="none" stroke="white" stroke-width="1" stroke-dasharray="3,3"/>
    <line x1="18" y1="24" x2="24" y2="28" stroke-width="3" stroke-linecap="round"/>
    <line x1="24" y1="24" x2="18" y2="28" stroke-width="3" stroke-linecap="round"/>
    <line x1="32" y1="24" x2="38" y2="28" stroke-width="3" stroke-linecap="round"/>
    <line x1="38" y1="24" x2="32" y2="28" stroke-width="3" stroke-linecap="round"/>
    <line x1="22" y1="35" x2="34" y2="35" stroke-width="2" stroke-linecap="round"/>
    <line x1="25" y1="33" x2="25" y2="37" stroke-width="1"/>
    <line x1="28" y1="33" x2="28" y2="37" stroke-width="1"/>
    <line x1="31" y1="33" x2="31" y2="37" stroke-width="1"/>
  </svg>`,
  gear: `<svg viewBox="0 0 100 100" fill="none" stroke="#2B2B2B" stroke-width="2"><circle cx="50" cy="50" r="38" fill="#D8D8D8"/><circle cx="50" cy="50" r="28" fill="#E0E0E0"/><circle cx="50" cy="50" r="18" fill="none" stroke-dasharray="4,4"/><line x1="50" y1="10" x2="50" y2="4"/><line x1="50" y1="90" x2="50" y2="96"/><line x1="10" y1="50" x2="4" y2="50"/><line x1="90" y1="50" x2="96" y2="50"/><line x1="21" y1="21" x2="17" y2="17"/><line x1="79" y1="21" x2="83" y2="17"/><line x1="21" y1="79" x2="17" y2="83"/><line x1="79" y1="79" x2="83" y2="83"/></svg>`,
  person: `<svg viewBox="0 0 24 24" fill="none" stroke="#2B2B2B" stroke-width="1.8"><circle cx="12" cy="7" r="4"/><path d="M4 21c0-4.4 3.6-8 8-8s8 3.6 8 8"/></svg>`,
  book: `<svg viewBox="0 0 24 24" fill="none" stroke="#2B2B2B" stroke-width="1.8"><path d="M4 4h16v16H4z"/><line x1="12" y1="4" x2="12" y2="20"/><line x1="7" y1="8" x2="10" y2="8"/><line x1="14" y1="8" x2="17" y2="8"/></svg>`,
  code: `<svg viewBox="0 0 24 24" fill="none" stroke="#2B2B2B" stroke-width="1.8" stroke-linecap="round"><polyline points="7,8 3,12 7,16"/><polyline points="17,8 21,12 17,16"/><line x1="14" y1="4" x2="10" y2="20"/></svg>`,
  chart: `<svg viewBox="0 0 24 24" fill="none" stroke="#2B2B2B" stroke-width="1.8"><rect x="3" y="12" width="4" height="8"/><rect x="10" y="6" width="4" height="14"/><rect x="17" y="2" width="4" height="18"/></svg>`,
  target: `<svg viewBox="0 0 24 24" fill="none" stroke="#2B2B2B" stroke-width="1.8"><circle cx="12" cy="12" r="10"/><circle cx="12" cy="12" r="6"/><circle cx="12" cy="12" r="2" fill="#D42060"/></svg>`,
  lightning: `<svg viewBox="0 0 24 24" fill="#D4A820" stroke="none"><polygon points="13,2 5,14 11,14 9,22 19,10 13,10"/></svg>`,
  lock: `<svg viewBox="0 0 24 24" fill="none" stroke="#2B2B2B" stroke-width="1.8"><rect x="5" y="11" width="14" height="10" rx="1"/><path d="M8 11V7a4 4 0 018 0v4"/></svg>`,
  rocket: `<svg viewBox="0 0 24 24" fill="none" stroke="#2B2B2B" stroke-width="1.8"><path d="M12 2c-3 4-4 8-4 12h8c0-4-1-8-4-12z"/><path d="M8 14l-2 4h12l-2-4"/><line x1="12" y1="18" x2="12" y2="22"/></svg>`,
  scissors: `<svg viewBox="0 0 24 24" fill="none" stroke="#2B2B2B" stroke-width="1.8"><circle cx="6" cy="18" r="3"/><circle cx="18" cy="18" r="3"/><line x1="8.5" y1="16" x2="18" y2="4"/><line x1="15.5" y1="16" x2="6" y2="4"/></svg>`,
  play: `<svg viewBox="0 0 24 24" fill="none" stroke="#2B2B2B" stroke-width="1.8"><polygon points="6,4 20,12 6,20" fill="none"/></svg>`,
  flag: `<svg viewBox="0 0 24 24" fill="none" stroke="#2B2B2B" stroke-width="1.8"><line x1="5" y1="3" x2="5" y2="21"/><path d="M5 3h14l-4 6 4 6H5"/></svg>`,
  search: `<svg viewBox="0 0 24 24" fill="none" stroke="#2B2B2B" stroke-width="1.8"><circle cx="10" cy="10" r="7"/><line x1="15" y1="15" x2="21" y2="21"/></svg>`,
};

function icon(name, size = 24) {
  return `<div style="width:${size}px;height:${size}px;flex-shrink:0;">${ICONS[name] || ICONS.star}</div>`;
}

// ══════════════════════════════════════════════════
// MODULE RENDERERS — 纯中文、高密度
// ══════════════════════════════════════════════════

function renderMatrix(mod) {
  const c = mod.content;
  const cells = (c.cells || []).map(cell => {
    const cls = cell.style || 'neutral'; // good, bad, warn, highlight
    const ic = cell.icon ? icon(cell.icon, 22) : '';
    return `
      <div class="mx-cell ${cls}">
        ${ic}
        <div class="mx-t">${cell.title || ''}</div>
        <div class="mx-d">${cell.desc || ''}</div>
      </div>`;
  }).join('');
  const axis = c.axisNote ? `<div class="mx-axis">${c.axisNote}</div>` : '';
  return `<div class="mx-grid">${cells}</div>${axis}`;
}

function renderTimeline(mod) {
  const c = mod.content;
  const nodes = (c.milestones || []).map(m => {
    const dotCls = m.active ? 'active' : m.done ? 'done' : '';
    return `
      <div class="tl-node">
        <div class="tl-dot ${dotCls}"></div>
        <div class="tl-year">${m.year || ''}</div>
        <div class="tl-label">${m.label || ''}</div>
        <div class="tl-detail">${m.detail || ''}</div>
      </div>`;
  }).join('');
  const bar = c.progress != null
    ? `<div class="tl-bar"><div class="tl-fill" style="width:${c.progress}%"></div></div>`
    : '';
  const phases = (c.phases || []).map((p, i) =>
    `<div class="tl-phase"><span class="num">${i + 1}.</span>${p}</div>`
  ).join('');
  return `
    <div class="tl">
      <div class="tl-track">${nodes}</div>
      ${bar}
      ${phases ? `<div class="tl-phases">${phases}</div>` : ''}
    </div>`;
}

function renderBreakdown(mod) {
  const c = mod.content;
  const layers = (c.layers || []).map((l, i) => {
    const ic = l.icon ? `<div class="icon">${ICONS[l.icon] || ''}</div>` : '';
    return `
      <div class="bd-layer">
        ${ic}
        <div class="name">${l.name || ''}</div>
        <div class="desc">${l.desc || ''}</div>
        <div class="num">${String(i + 1).padStart(2, '0')}</div>
      </div>`;
  }).join('');
  const title = c.title
    ? `<div class="bd-title"><span>${c.title}</span></div>`
    : '';
  return `<div class="bd">${title}<div class="bd-stack">${layers}</div></div>`;
}

function renderLoop(mod) {
  const c = mod.content;
  const nodes = c.nodes || [];
  const n = nodes.length;

  // SVG arrow helper
  const svgArrow = (dir) => {
    const rotate = { right: 0, down: 90, left: 180, up: 270 }[dir] || 0;
    return `<svg width="28" height="18" viewBox="0 0 28 18" fill="none" style="flex-shrink:0;">
      <line x1="0" y1="9" x2="22" y2="9" stroke="#A09888" stroke-width="2"/>
      <polygon points="22,4 28,9 22,14" fill="#A09888"/>
    </svg>`;
  };
  const svgArrowV = `<svg width="18" height="28" viewBox="0 0 18 28" fill="none" style="flex-shrink:0;display:block;">
    <line x1="9" y1="0" x2="9" y2="22" stroke="#A09888" stroke-width="2"/>
    <polygon points="4,22 9,28 14,22" fill="#A09888"/>
  </svg>`;
  const svgArrowVU = `<svg width="18" height="28" viewBox="0 0 18 28" fill="none" style="flex-shrink:0;display:block;">
    <line x1="9" y1="28" x2="9" y2="6" stroke="#A09888" stroke-width="2"/>
    <polygon points="4,6 9,0 14,6" fill="#A09888"/>
  </svg>`;

  const nodeBox = (nd, borderColor, bg) =>
    `<div style="padding:9px 14px;border:2.5px solid ${borderColor};background:${bg};text-align:center;box-shadow:3px 3px 0 rgba(0,0,0,0.10);min-width:110px;flex:1;">
      <div style="font-size:12px;font-weight:800;line-height:1.3;">${nd.label || ''}</div>
      ${nd.sub ? `<div style="font-size:9px;color:var(--gray-500);margin-top:3px;line-height:1.4;">${nd.sub}</div>` : ''}
    </div>`;

  let flowHtml = '';
  if (n === 4) {
    flowHtml = `
      <div style="display:flex;align-items:center;gap:8px;margin-bottom:8px;">
        ${nodeBox(nodes[0], 'var(--highlight)', 'var(--highlight-bg)')}
        ${svgArrow('right')}
        ${nodeBox(nodes[1], 'var(--black)', 'var(--card)')}
      </div>
      <div style="display:flex;justify-content:space-between;padding:0 52px;margin-bottom:8px;">
        ${svgArrowVU}
        ${svgArrowV}
      </div>
      <div style="display:flex;align-items:center;gap:8px;">
        ${nodeBox(nodes[3], 'var(--black)', 'var(--card)')}
        <svg width="28" height="18" viewBox="0 0 28 18" fill="none" style="flex-shrink:0;">
          <line x1="28" y1="9" x2="6" y2="9" stroke="#A09888" stroke-width="2"/>
          <polygon points="6,4 0,9 6,14" fill="#A09888"/>
        </svg>
        ${nodeBox(nodes[2], 'var(--primary)', 'var(--primary-light)')}
      </div>`;
  } else {
    flowHtml = `<div style="display:flex;align-items:center;justify-content:center;gap:6px;flex-wrap:wrap;">${
      nodes.map((nd, i) => {
        const arrow = i < n - 1 ? svgArrow('right') : '';
        return nodeBox(nd, 'var(--black)', 'var(--card)') + arrow;
      }).join('')
    }</div>`;
  }

  const center = c.center
    ? `<div style="margin:10px auto 0;padding:10px 16px;background:var(--primary-light);border:2.5px solid var(--black);box-shadow:4px 4px 0 rgba(0,0,0,0.10);text-align:center;width:100%;">
        <div style="font-size:12px;font-weight:800;line-height:1.5;">${c.center.text || ''}</div>
        ${c.center.sub ? `<div style="font-size:10px;color:var(--gray-600);margin-top:3px;line-height:1.4;">${c.center.sub}</div>` : ''}
      </div>`
    : '';
  const footer = c.footer
    ? `<div style="font-size:9px;color:var(--gray-500);text-align:center;padding-top:6px;border-top:1px solid var(--border-light);margin-top:auto;font-family:var(--mono);">${c.footer}</div>`
    : '';

  return `<div style="flex:1;display:flex;flex-direction:column;gap:6px;">${flowHtml}${center}${footer}</div>`;
}

function renderWarning(mod) {
  const c = mod.content;
  const items = (c.items || []).map(item =>
    `<div class="wn-item"><div class="wn-bullet">✕</div><div>${item}</div></div>`
  ).join('');
  return `
    <div class="wn">
      <div class="wn-stripe"></div>
      <div class="wn-header"><span>${c.headline || mod.title}</span></div>
      <div class="wn-body">
        <div class="wn-icon">${ICONS.skull}</div>
        <div class="wn-items">
          ${items}
          ${c.alert ? `<div style="margin-top:6px;padding:5px 10px;background:var(--gray-100);border-left:3px solid var(--warn);font-size:9px;font-weight:700;color:var(--warn);letter-spacing:0.5px;">${c.alert}</div>` : ''}
        </div>
      </div>
      <div class="wn-stripe"></div>
    </div>`;
}

function renderStats(mod) {
  const c = mod.content;
  const clsMap = ['m1', 'm2', 'm3'];
  const metrics = (c.metrics || []).map((m, i) => {
    return `<div class="st-metric ${clsMap[i] || 'm3'}">
      <div class="st-val-wrap">
        <div class="st-value">${m.value || ''}</div>
        <div class="st-unit">${m.unit || ''}</div>
      </div>
      ${m.context ? `<div class="st-context">${m.context}</div>` : ''}
    </div>`;
  }).join('');

  // Badge emblem — styled hexagonal/circular with internal detail
  const badge = c.badge ? `
    <div class="st-badge">
      <svg viewBox="0 0 100 100" fill="none" style="width:100px;height:100px;">
        <circle cx="50" cy="50" r="44" stroke="#2B2B2B" stroke-width="2.5" fill="var(--card)"/>
        <circle cx="50" cy="50" r="36" stroke="#2B2B2B" stroke-width="1" stroke-dasharray="3,3"/>
        <circle cx="50" cy="50" r="28" stroke="#2B2B2B" stroke-width="0.5"/>
        <line x1="50" y1="6" x2="50" y2="14" stroke="#2B2B2B" stroke-width="1.5"/>
        <line x1="50" y1="86" x2="50" y2="94" stroke="#2B2B2B" stroke-width="1.5"/>
        <line x1="6" y1="50" x2="14" y2="50" stroke="#2B2B2B" stroke-width="1.5"/>
        <line x1="86" y1="50" x2="94" y2="50" stroke="#2B2B2B" stroke-width="1.5"/>
        <text x="50" y="46" text-anchor="middle" font-size="8" font-weight="900" fill="#2B2B2B" font-family="'Noto Sans SC'">${c.badge.name || ''}</text>
        <text x="50" y="60" text-anchor="middle" font-size="7" font-weight="500" fill="#786E64" font-family="'IBM Plex Mono'">${c.badge.year || ''}</text>
      </svg>
    </div>` : '';

  return `<div class="st">${badge}<div class="st-metrics">${metrics}</div></div>`;
}

function renderProgress(mod) {
  const c = mod.content;
  const items = (c.bars || []).map(b => {
    const w = b.value || 0;
    const cls = w > 70 ? 'high' : w > 40 ? 'mid' : 'low';
    return `
      <div class="pg-item">
        <div class="pg-label">${b.label || ''}</div>
        <div class="pg-track">
          <div class="pg-fill ${cls}" style="width:${w}%">
            <span class="pg-pct">${w}%</span>
          </div>
        </div>
      </div>`;
  }).join('');

  const summary = (c.summary || []).map((s, i) =>
    `<div class="pg-stat ${i === (c.summary.length - 1) ? 'accent' : ''}">
      <div class="num">${s.value || ''}</div>
      <div class="text">${s.label || ''}</div>
    </div>`
  ).join('');

  const note = c.note ? `<div class="pg-note">${c.note}</div>` : '';

  return `
    <div class="pg">
      ${items}
      ${summary ? `<div class="pg-summary">${summary}</div>` : ''}
      ${note}
    </div>`;
}

function renderComparison(mod) {
  const c = mod.content;
  const leftItems = (c.left?.items || []).map((item, i) => 
    `<div class="cp-item"><span style="font-family:var(--mono);font-size:8px;color:var(--gray-400);margin-right:4px;">${String(i+1).padStart(2,'0')}</span>${item}</div>`
  ).join('');
  const rightItems = (c.right?.items || []).map((item, i) => 
    `<div class="cp-item"><span style="font-family:var(--mono);font-size:8px;color:var(--gray-400);margin-right:4px;">${String(i+1).padStart(2,'0')}</span>${item}</div>`
  ).join('');
  const leftWin = c.winner === 'left';
  const rightWin = c.winner === 'right';
  const leftIcon = leftWin ? `<span style="color:var(--primary);margin-right:4px;">✓</span>` : `<span style="color:var(--warn);margin-right:4px;">✕</span>`;
  const rightIcon = rightWin ? `<span style="color:var(--primary);margin-right:4px;">✓</span>` : `<span style="color:var(--warn);margin-right:4px;">✕</span>`;
  return `
    <div class="cp">
      <div class="cp-cols">
        <div class="cp-side ${leftWin ? 'winner' : ''}">
          <div class="cp-sh">${leftIcon}${c.left?.title || 'A'}</div>
          ${leftItems}
        </div>
        <div class="cp-vs">VS</div>
        <div class="cp-side ${rightWin ? 'winner' : ''}">
          <div class="cp-sh">${rightIcon}${c.right?.title || 'B'}</div>
          ${rightItems}
        </div>
      </div>
      ${c.verdict ? `<div class="cp-verdict">${c.verdict}</div>` : ''}
    </div>`;
}

function renderPyramid(mod) {
  const c = mod.content;
  const levels = (c.levels || []).reverse(); // top first
  const n = levels.length;
  
  // Full-width stacked design with number badges — no white space on sides
  return `
    <div style="flex:1;display:flex;flex-direction:column;gap:0;">
      ${levels.map((l, i) => {
        const bg = i === 0 ? 'var(--highlight-bg)' : i === n - 1 ? 'var(--gray-100)' : 'var(--primary-light)';
        const borderColor = i === 0 ? 'var(--highlight)' : i === n - 1 ? 'var(--gray-200)' : 'var(--primary-bg)';
        const numBg = i === 0 ? 'var(--highlight)' : i === n - 1 ? 'var(--gray-400)' : 'var(--primary)';
        const levelLabel = i === 0 ? '顶层' : i === n - 1 ? '基础' : `L${n - i}`;
        return `<div style="display:flex;align-items:stretch;border:1px solid ${borderColor};border-bottom:${i < n-1 ? 'none' : `1px solid ${borderColor}`};background:${bg};">
          <div style="width:40px;background:${numBg};display:flex;flex-direction:column;align-items:center;justify-content:center;flex-shrink:0;padding:4px 0;">
            <div style="font-family:var(--mono);font-size:14px;font-weight:900;color:white;line-height:1;">${n - i}</div>
            <div style="font-size:6px;color:rgba(255,255,255,0.7);margin-top:1px;">${levelLabel}</div>
          </div>
          <div style="padding:8px 12px;flex:1;">
            <div style="font-size:12px;font-weight:700;line-height:1.3;">${l.name || ''}</div>
            <div style="font-size:10px;color:var(--gray-600);line-height:1.5;margin-top:2px;">${l.desc || ''}</div>
          </div>
        </div>`;
      }).join('')}
      <div style="margin-top:6px;font-size:8px;color:var(--gray-500);text-align:center;font-family:var(--mono);">
        ▲ 越高越稀缺 · 每层是上层的前提
      </div>
    </div>`;
}

function renderChart(mod) {
  const c = mod.content;
  const points = c.points || [];
  if (!points.length) return '<div class="ch">暂无数据</div>';

  const maxY = Math.max(...points.map(p => p.y || 0));
  const W = 480, H = 180, P = 48, PB = 22, PT = 20;

  // Grid lines for professionalism
  const gridCount = 4;
  const gridLines = Array.from({length: gridCount + 1}, (_, i) => {
    const y = PT + (i / gridCount) * (H - PT - PB);
    const val = Math.round(maxY * (1 - i / gridCount));
    return `<line x1="${P}" y1="${y}" x2="${W - 10}" y2="${y}" stroke="#E0DAD0" stroke-width="0.5" stroke-dasharray="3,3"/>
            <text x="${P - 4}" y="${y + 3}" text-anchor="end" font-size="7" fill="#A09888" font-family="'IBM Plex Mono'">${val}</text>`;
  }).join('');

  if (c.type === 'bar') {
    const barW = Math.min(32, (W - P * 2) / points.length - 8);
    const bars = points.map((p, i) => {
      const bh = maxY > 0 ? ((p.y || 0) / maxY) * (H - PT - PB) : 0;
      const x = P + i * ((W - P - 10) / points.length) + 8;
      const color = p.color || (i === points.length - 1 ? 'var(--accent)' : 'var(--primary)');
      return `<rect x="${x}" y="${H - PB - bh}" width="${barW}" height="${bh}" fill="${color}"/>
              <text x="${x + barW/2}" y="${H - PB - bh - 5}" text-anchor="middle" font-size="8" font-weight="700" fill="#2B2B2B">${p.y}</text>
              <text x="${x + barW/2}" y="${H - 4}" text-anchor="middle" font-size="8" fill="#786E64">${p.label}</text>`;
    }).join('');
    return `<div class="ch">
      <svg viewBox="0 0 ${W} ${H}">
        ${gridLines}
        <line x1="${P}" y1="${H - PB}" x2="${W - 10}" y2="${H - PB}" stroke="#C8C0B4" stroke-width="1"/>
        ${bars}
      </svg>
      ${c.note ? `<div class="ch-note">${c.note}</div>` : ''}
    </div>`;
  }

  // Line chart with area fill and grid
  const pts = points.map((p, i) => {
    const x = P + (i / Math.max(points.length - 1, 1)) * (W - P - 10);
    const y = H - PB - (maxY > 0 ? ((p.y || 0) / maxY) * (H - PT - PB) : 0);
    return { x, y, label: p.label, val: p.y };
  });
  const line = pts.map(p => `${p.x},${p.y}`).join(' ');
  const area = `${P},${H - PB} ${line} ${pts[pts.length-1].x},${H - PB}`;
  const labels = pts.map((p, i) => {
    const isLast = i === pts.length - 1;
    const dotColor = isLast ? 'var(--accent)' : 'var(--primary)';
    const r = isLast ? 4 : 3;
    return `<circle cx="${p.x}" cy="${p.y}" r="${r}" fill="${dotColor}" stroke="white" stroke-width="1.5"/>
     <text x="${p.x}" y="${p.y - 10}" text-anchor="middle" font-size="9" font-weight="700" fill="#2B2B2B">${p.val}</text>
     <text x="${p.x}" y="${H - 6}" text-anchor="middle" font-size="8" fill="#786E64">${p.label}</text>`;
  }).join('');

  // Peak annotation
  const peak = pts.reduce((a, b) => a.val > b.val ? a : b);
  const peakAnnotation = `<line x1="${peak.x}" y1="${peak.y}" x2="${peak.x}" y2="${H - PB}" stroke="var(--warn)" stroke-width="0.5" stroke-dasharray="2,2"/>`;

  return `<div class="ch">
    <svg viewBox="0 0 ${W} ${H}">
      ${gridLines}
      <line x1="${P}" y1="${H - PB}" x2="${W - 10}" y2="${H - PB}" stroke="#C8C0B4" stroke-width="1"/>
      <line x1="${P}" y1="${PT}" x2="${P}" y2="${H - PB}" stroke="#C8C0B4" stroke-width="0.5"/>
      <polygon points="${area}" fill="var(--gray-200)" opacity="0.5" stroke="none"/>
      <polyline points="${line}" fill="none" stroke="var(--primary)" stroke-width="2.5" stroke-linejoin="round"/>
      ${peakAnnotation}
      ${labels}
    </svg>
    ${c.note ? `<div class="ch-note">${c.note}</div>` : ''}
  </div>`;
}

function renderFlowchart(mod) {
  const c = mod.content;
  const steps = c.steps || [];
  const rows = [];
  // Render in rows of 3
  for (let i = 0; i < steps.length; i += 3) {
    const chunk = steps.slice(i, i + 3);
    const nodes = chunk.map((s, j) => {
      const cls = i === 0 && j === 0 ? 'start' : (i + j === steps.length - 1) ? 'end' : (s.type || '');
      const arrow = (i + j < steps.length - 1 && j < 2) ? '<div class="fl-arrow">→</div>' : '';
      return `<div class="fl-node ${cls}"><div>${s.label || ''}</div>${s.desc ? `<div class="fl-desc">${s.desc}</div>` : ''}</div>${arrow}`;
    }).join('');
    rows.push(`<div class="fl-row">${nodes}</div>`);
    if (i + 3 < steps.length) {
      rows.push(`<div class="fl-row"><div class="fl-arrow">↓</div></div>`);
    }
  }
  return `<div class="fl">${rows.join('')}</div>`;
}

function renderChecklist(mod) {
  const c = mod.content;
  const items = (c.items || []).map((item, i) => {
    const cls = item.status === 'done' ? 'done' : item.status === 'fail' ? 'fail' : '';
    const mark = item.status === 'done' ? '✓' : item.status === 'fail' ? '✕' : '';
    const bg = i % 2 === 0 ? '' : 'background:var(--gray-50);';
    return `
      <div class="cl-item" style="${bg}">
        <div style="font-family:var(--mono);font-size:7px;color:var(--gray-400);width:16px;text-align:center;flex-shrink:0;margin-top:2px;">${String(i+1).padStart(2,'0')}</div>
        <div class="cl-check ${cls}">${mark}</div>
        <div class="cl-text">${item.text || ''}${item.note ? `<span class="note">${item.note}</span>` : ''}</div>
      </div>`;
  }).join('');
  
  // Summary line at bottom
  const total = (c.items || []).length;
  const done = (c.items || []).filter(i => i.status === 'done').length;
  const fail = (c.items || []).filter(i => i.status === 'fail').length;
  const pending = total - done - fail;
  const summary = `<div style="display:flex;gap:12px;justify-content:center;padding-top:6px;border-top:1px solid var(--border-light);margin-top:auto;font-size:9px;">
    <span style="color:var(--primary);font-weight:700;">✓ ${done} 通过</span>
    <span style="color:var(--warn);font-weight:700;">✕ ${fail} 警告</span>
    ${pending > 0 ? `<span style="color:var(--gray-500);">○ ${pending} 待查</span>` : ''}
  </div>`;
  
  return `<div class="cl">${items}${summary}</div>`;
}

// ── Renderer Map ──
const RENDERERS = {
  matrix: renderMatrix,
  timeline: renderTimeline,
  breakdown: renderBreakdown,
  loop: renderLoop,
  warning: renderWarning,
  stats: renderStats,
  progress: renderProgress,
  comparison: renderComparison,
  pyramid: renderPyramid,
  chart: renderChart,
  flowchart: renderFlowchart,
  checklist: renderChecklist,
};

// ══════════════════════════════════════════════════
// HTML BUILDER
// ══════════════════════════════════════════════════

// Map module type to accent color class
const ACCENT_MAP = {
  matrix: 'a-primary', timeline: 'a-accent', breakdown: 'a-primary',
  loop: 'a-highlight', warning: 'a-warn', stats: 'a-highlight',
  progress: 'a-accent', comparison: 'a-accent', pyramid: 'a-primary',
  chart: 'a-primary', flowchart: 'a-accent', checklist: 'a-gray',
};

function renderModule(mod, extraClass = '') {
  const renderer = RENDERERS[mod.type];
  if (!renderer) return `<div class="mod"><div class="mod-b">未知模块类型: ${mod.type}</div></div>`;

  const spanClass = [
    mod.span === 'tall' ? 'tall' : '',
    mod.span === 'wide' ? 'wide' : '',
    extraClass
  ].filter(Boolean).join(' ');
  const isWarning = mod.type === 'warning';
  const accent = ACCENT_MAP[mod.type] || 'a-gray';

  const header = `<div class="mod-h">
    <div class="mod-h-left">
      <span class="mod-id">[${mod.slot}]</span>
      <span class="mod-t">${mod.title}</span>
    </div>
    <span class="mod-close">✕</span>
  </div>
  <div class="mod-accent ${accent}"></div>`;

  const corners = `<div class="mc"><span></span><span></span><span></span><span></span></div>`;

  if (isWarning) {
    return `<div class="mod ${spanClass}">
      ${corners}
      ${header}
      ${renderer(mod)}
    </div>`;
  }

  return `<div class="mod ${spanClass}">
    ${corners}
    ${header}
    <div class="mod-b">${renderer(mod)}</div>
  </div>`;
}

function generateBarcode() {
  const bars = [];
  for (let i = 0; i < 20; i++) {
    const h = 8 + Math.floor(Math.random() * 8);
    const w = Math.random() > 0.5 ? 2 : 1;
    bars.push(`<i style="width:${w}px;height:${h}px;"></i>`);
    if (Math.random() > 0.4) bars.push(`<i class="s" style="width:${Math.random() > 0.5 ? 2 : 1}px;"></i>`);
  }
  return bars.join('');
}

function cornerSvg() {
  return `<svg viewBox="0 0 36 36" fill="none" stroke="#2B2B2B" stroke-width="2.5" stroke-linecap="square"><polyline points="0,36 0,0 36,0"/><line x1="0" y1="0" x2="5" y2="5" stroke-width="1"/></svg>`;
}

function edgeRulerSvg(height = 800) {
  const ticks = [];
  for (let y = 0; y <= height; y += 10) {
    const isMajor = y % 50 === 0;
    const w = isMajor ? 8 : 4;
    const sw = isMajor ? 0.6 : 0.3;
    ticks.push(`<line x1="0" y1="${y}" x2="${w}" y2="${y}" stroke="#A09890" stroke-width="${sw}"/>`);
  }
  return `<svg viewBox="0 0 10 ${height}" preserveAspectRatio="none" style="width:10px;height:100%;">
    <line x1="0" y1="0" x2="0" y2="${height}" stroke="#A09890" stroke-width="0.5"/>
    ${ticks.join('')}
  </svg>`;
}

function scatterAnnotations() {
  // 用编号代码保持蓝图技术感，不含英文单词
  const notes = [
    { text: '20.092', top: 80, side: 'right:16px' },
    { text: '04.03', top: 240, side: 'left:16px' },
    { text: '08', top: 420, side: 'right:16px' },
    { text: '2.0', top: 600, side: 'left:16px' },
    { text: '06.A', top: 780, side: 'right:16px' },
    { text: '15.B', top: 960, side: 'left:16px' },
    { text: '08.C', top: 1140, side: 'right:16px' },
    { text: '0692', top: 1320, side: 'left:16px' },
    { text: '2.0.1', top: 160, side: 'left:16px' },
    { text: '44', top: 500, side: 'right:16px' },
    { text: 'A3', top: 840, side: 'right:14px;transform:rotate(90deg)' },
    { text: '07', top: 1060, side: 'left:14px;transform:rotate(-90deg)' },
  ];
  return notes.map(n =>
    `<div class="scatter-note" style="top:${n.top}px;${n.side};">${n.text}</div>`
  ).join('');
}

// ══════════════════════════════════════════════════
// LAYOUT-SPECIFIC DECORATIONS
// ══════════════════════════════════════════════════

function rulerFrameSvg(width, height) {
  // Ruler marks on all 4 sides
  const ticksH = [];
  for (let x = 0; x <= width; x += 10) {
    const major = x % 50 === 0;
    const h = major ? 10 : 5;
    const sw = major ? 0.8 : 0.3;
    ticksH.push(`<line x1="${x}" y1="0" x2="${x}" y2="${h}" stroke="#A09890" stroke-width="${sw}"/>`);
  }
  return `<svg viewBox="0 0 ${width} 14" preserveAspectRatio="none" style="width:100%;height:14px;">
    <line x1="0" y1="13" x2="${width}" y2="13" stroke="#A09890" stroke-width="0.5"/>
    ${ticksH.join('')}
  </svg>`;
}

function crosshairSvg() {
  return `<svg viewBox="0 0 20 20" fill="none" stroke="#A09890" stroke-width="0.8">
    <line x1="10" y1="0" x2="10" y2="20"/><line x1="0" y1="10" x2="20" y2="10"/>
    <circle cx="10" cy="10" r="4" fill="none"/>
  </svg>`;
}

// ══════════════════════════════════════════════════
// HTML BUILDERS — One per Layout Architecture
// ══════════════════════════════════════════════════

function renderModuleGrid(mods, gridCols) {
  // Calculate auto-fill for last module
  let colSlots = 0;
  mods.forEach(m => {
    if (m.span === 'wide') { /* resets row */ }
    else if (m.span === 'tall') colSlots += gridCols;
    else colSlots++;
  });
  const remainder = colSlots % gridCols;
  const needsFill = remainder > 0;
  const fillSpan = needsFill ? gridCols - remainder : 0;
  
  return mods.map((m, i) => {
    let extra = '';
    if (needsFill && m.span !== 'wide' && m.span !== 'tall') {
      const remaining = mods.slice(i + 1).filter(x => x.span !== 'wide' && x.span !== 'tall');
      if (remaining.length === 0) {
        extra = fillSpan >= gridCols ? 'wide' : (gridCols === 3 && fillSpan === 1 ? 'span-2' : 'wide');
      }
    }
    return renderModule(m, extra);
  }).join('\n');
}

function htmlShell(data, size, theme, fontStyleName, layoutClass, inner) {
  const fs = FONT_STYLES[fontStyleName] || FONT_STYLES.default;
  return `<!DOCTYPE html>
<html lang="zh-CN">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=${size.width}">
<title>${data.title || '信息图'}</title>
<style>
@import url('https://fonts.googleapis.com/css2?family=${fs.googleFamily}&display=swap');
${getCSS(size.width, theme, fontStyleName)}
</style>
</head>
<body style="margin:0;background:#999;">
<div class="page ${layoutClass}">
${inner}
</div>
</body>
</html>`;
}

function dateStr() {
  const now = new Date();
  return `${now.getFullYear()}.${String(now.getMonth()+1).padStart(2,'0')}.${String(now.getDate()).padStart(2,'0')}`;
}

function footerHtml() {
  const d = dateStr();
  return `<div class="footer">
    <div style="display:flex;align-items:center;gap:10px;">
      <div class="barcode">${generateBarcode()}</div>
      <span class="meta">${d}</span>
      <span class="meta">#${Math.floor(Math.random()*9000000+1000000).toString(16).toUpperCase()}</span>
    </div>
    <div style="display:flex;align-items:center;gap:10px;">
      <span class="meta">v2.0</span>
      <div class="barcode">${generateBarcode()}</div>
    </div>
  </div>`;
}

// ── Layout: BANNER (original) ──
function buildBanner(data, size, theme, fontStyleName) {
  const mods = data.modules || [];
  const nMods = mods.length;
  const gridCols = nMods >= 8 ? 3 : 2;
  const gridClass = gridCols === 3 ? 'grid cols-3' : 'grid';
  const d = dateStr();
  
  const inner = `
  <div class="dot-grid"></div>
  <div class="paper-noise"></div>
  <div class="corner c-tl">${cornerSvg()}</div>
  <div class="corner c-tr">${cornerSvg()}</div>
  <div class="corner c-bl">${cornerSvg()}</div>
  <div class="corner c-br">${cornerSvg()}</div>
  <div class="edge-ruler left">${edgeRulerSvg(1600)}</div>
  <div class="edge-ruler right">${edgeRulerSvg(1600)}</div>
  ${scatterAnnotations()}
  <div class="content">
    <div class="header">
      <div class="h-banner">
        <div class="h-eyebrow">系统蓝图 · ${d} · ${nMods} 模块</div>
        <div class="h-title">${data.title || ''}</div>
      </div>
      <div class="h-foot">
        <div class="h-sub">${data.subtitle || ''}</div>
        <div class="h-meta">v2.0 · #${Math.floor(Math.random()*9000+1000)}</div>
      </div>
    </div>
    <div class="${gridClass}">
      ${renderModuleGrid(mods, gridCols)}
    </div>
    ${footerHtml()}
  </div>`;
  return htmlShell(data, size, theme, fontStyleName, '', inner);
}

// ── Layout: DENSE (compact 3-col, ruler frame, no banner) ──
function buildDense(data, size, theme, fontStyleName) {
  const mods = data.modules || [];
  const d = dateStr();
  
  const inner = `
  <div class="paper-noise"></div>
  <div class="ruler-frame top">${rulerFrameSvg(size.width - 40, 14)}</div>
  <div class="ruler-frame bottom" style="transform:scaleY(-1);">${rulerFrameSvg(size.width - 40, 14)}</div>
  <div class="ruler-frame left">
    <div style="transform:rotate(-90deg) translateX(-100%);transform-origin:top left;width:1600px;">
      ${rulerFrameSvg(1600, 14)}
    </div>
  </div>
  <div class="ruler-frame right">
    <div style="transform:rotate(90deg) translateY(-100%);transform-origin:top right;width:1600px;">
      ${rulerFrameSvg(1600, 14)}
    </div>
  </div>
  <div class="crosshair" style="top:16px;left:16px;">${crosshairSvg()}</div>
  <div class="crosshair" style="top:16px;right:16px;">${crosshairSvg()}</div>
  <div class="crosshair" style="bottom:16px;left:16px;">${crosshairSvg()}</div>
  <div class="crosshair" style="bottom:16px;right:16px;">${crosshairSvg()}</div>
  <div class="content">
    <div class="header">
      <div class="h-inline">
        <div class="h-inline-title">${data.title || ''}</div>
        <div class="h-inline-sub">${data.subtitle || ''}</div>
        <div class="h-inline-meta">${d} · ${mods.length}M</div>
      </div>
    </div>
    <div class="grid cols-3">
      ${renderModuleGrid(mods, 3)}
    </div>
    ${footerHtml()}
  </div>`;
  return htmlShell(data, size, theme, fontStyleName, 'layout-dense', inner);
}

// ── Layout: HERO (first module is oversized focal point) ──
function buildHero(data, size, theme, fontStyleName) {
  const mods = data.modules || [];
  if (mods.length === 0) return buildBanner(data, size, theme, fontStyleName);
  
  const heroMod = mods[0]; // First module becomes hero
  const restMods = mods.slice(1);
  const gridCols = restMods.length >= 6 ? 3 : 2;
  const gridClass = gridCols === 3 ? 'grid cols-3' : 'grid';
  const d = dateStr();
  
  const inner = `
  <div class="paper-noise"></div>
  <div class="corner c-tl">${cornerSvg()}</div>
  <div class="corner c-tr">${cornerSvg()}</div>
  <div class="corner c-bl">${cornerSvg()}</div>
  <div class="corner c-br">${cornerSvg()}</div>
  <div class="content">
    <div class="header">
      <div class="h-minimal">
        <div class="h-minimal-eyebrow">蓝图 · ${d} · ${mods.length} 模块</div>
        <div class="h-minimal-title">${data.title || ''}</div>
        <div class="h-minimal-sub">${data.subtitle || ''}</div>
      </div>
    </div>
    <div class="hero-mod">
      ${renderModule(heroMod, 'wide')}
    </div>
    <div class="${gridClass}">
      ${renderModuleGrid(restMods, gridCols)}
    </div>
    ${footerHtml()}
  </div>`;
  return htmlShell(data, size, theme, fontStyleName, 'layout-hero', inner);
}

// ── Layout: MOSAIC (asymmetric grid areas) ──
function buildMosaic(data, size, theme, fontStyleName) {
  const mods = data.modules || [];
  if (mods.length < 4) return buildBanner(data, size, theme, fontStyleName);
  
  const d = dateStr();
  
  // Create asymmetric grid template based on module count
  // Pattern: first module spans 2 cols wide (NOT 2×2 tall — avoids empty space)
  // Alternating wide + narrow rows create visual rhythm
  const n = mods.length;
  let gridTemplate, gridAreas;
  
  if (n <= 5) {
    // a=wide, b=single, c+d=pair, e=wide
    gridTemplate = `'a a b' 'c d e'`;
    gridAreas = ['a', 'b', 'c', 'd', 'e'];
  } else if (n <= 7) {
    // a=wide, b=single, c+d+e=triple, f=wide, g=single OR f+g=pair
    gridTemplate = `'a a b' 'c d e' 'f f g'`;
    gridAreas = ['a', 'b', 'c', 'd', 'e', 'f', 'g'];
  } else {
    // a=wide, b=single, c+d+e=triple, f=wide, g=single, h+i=pair
    gridTemplate = `'a a b' 'c d e' 'f f g' 'h h i'`;
    gridAreas = ['a', 'b', 'c', 'd', 'e', 'f', 'g', 'h', 'i'];
  }
  
  const moduleHtml = mods.slice(0, gridAreas.length).map((m, i) => {
    const area = gridAreas[i];
    const rendered = renderModule(m, '');
    // Mark wide modules (a, f, h span 2 cols) and narrow side module (b)
    const isWide = (area === 'a' || area === 'f' || area === 'h');
    const cls = isWide ? 'mosaic-large' : (area === 'b' || area === 'g' || area === 'i') ? 'mosaic-side' : '';
    return `<div class="${cls}" style="grid-area:${area};display:flex;flex-direction:column;">${rendered}</div>`;
  }).join('\n');
  
  // Remaining modules (if more than grid areas) go in a regular grid below
  const extraMods = mods.slice(gridAreas.length);
  const extraHtml = extraMods.length > 0 
    ? `<div class="grid cols-3" style="margin-top:10px;">${renderModuleGrid(extraMods, 3)}</div>`
    : '';
  
  const inner = `
  <div class="dot-grid"></div>
  <div class="paper-noise"></div>
  <div class="corner c-tl">${cornerSvg()}</div>
  <div class="corner c-tr">${cornerSvg()}</div>
  <div class="corner c-bl">${cornerSvg()}</div>
  <div class="corner c-br">${cornerSvg()}</div>
  <div class="content">
    <div class="header">
      <div class="h-strip">
        <div class="h-strip-title">${data.title || ''}</div>
        <div class="h-strip-sub">${data.subtitle || ''}</div>
      </div>
    </div>
    <div class="mosaic-grid" style="grid-template-areas:${gridTemplate};grid-template-columns:1fr 1fr 1fr;grid-template-rows:repeat(auto-fill, minmax(200px, auto));">
      ${moduleHtml}
    </div>
    ${extraHtml}
    ${footerHtml()}
  </div>`;
  return htmlShell(data, size, theme, fontStyleName, 'layout-mosaic', inner);
}

// ── Master buildHtml dispatcher ──
function buildHtml(data, size, theme, fontStyleName = 'default', layout = 'banner') {
  const builders = { banner: buildBanner, dense: buildDense, hero: buildHero, mosaic: buildMosaic };
  const builder = builders[layout] || buildBanner;
  return builder(data, size, theme, fontStyleName);
}

// ══════════════════════════════════════════════════
// MAIN — Playwright Screenshot
// ══════════════════════════════════════════════════
async function main() {
  // Resolve theme: CLI arg > JSON field > blueprint default
  let theme;
  if (themeName && THEMES[themeName]) {
    theme = THEMES[themeName];
  } else if (data.theme && THEMES[data.theme]) {
    theme = THEMES[data.theme];
  } else {
    theme = THEMES.ocean;
  }
  // Resolve layout: CLI arg > JSON field > auto-select
  let layout;
  if (layoutName && LAYOUTS[layoutName]) {
    layout = layoutName;
  } else if (data.layout && typeof data.layout === 'string' && LAYOUTS[data.layout]) {
    layout = data.layout;
  } else {
    layout = 'banner'; // default
  }
  console.log(`Layout: ${layout} (${LAYOUTS[layout].name}) | Theme: ${Object.keys(THEMES).find(k => THEMES[k] === theme) || 'blueprint'}`);
  // Resolve font style: CLI arg > JSON field > default
  const resolvedFontStyle = fontStyle !== 'default' ? fontStyle : (data.fontStyle || 'default');
  const html = buildHtml(data, size, theme, resolvedFontStyle, layout);

  if (emitHtml) {
    const htmlPath = (outputPath || 'output/demo.png').replace(/\.png$/i, '.html');
    writeFileSync(resolve(htmlPath), html);
    console.log(`HTML: ${resolve(htmlPath)}`);
  }

  if (!outputPath) outputPath = join(ROOT, 'output', 'v2-demo.png');
  mkdirSync(dirname(resolve(outputPath)), { recursive: true });

  let pw;
  try { pw = await import('/opt/homebrew/lib/node_modules/playwright/index.mjs'); }
  catch { try { pw = await import('playwright'); } catch { pw = await import('playwright-core'); } }

  const dpr = parseInt(process.env.DPR || '2', 10);   // 2x Retina by default
  const browser = await pw.chromium.launch({ headless: true });
  const ctx = await browser.newContext({ deviceScaleFactor: dpr });
  const page = await ctx.newPage();
  await page.setViewportSize({ width: size.width, height: size.height });
  await page.setContent(html, { waitUntil: 'domcontentloaded', timeout: 15000 });
  // Wait for fonts: ensure all @font-face declarations are loaded
  await page.waitForTimeout(3000);
  await page.evaluate(() => document.fonts.ready);
  const fontStatus = await page.evaluate(() => {
    const result = [];
    document.fonts.forEach(f => result.push(`${f.family} [${f.weight}] → ${f.status}`));
    return result;
  });
  if (fontStatus.length) console.log('Fonts:', fontStatus.join(' | '));
  // Debug: check what font is actually rendering for Chinese text
  const actualFont = await page.evaluate(() => {
    const el = document.querySelector('.mod-b') || document.querySelector('.page');
    const cs = window.getComputedStyle(el);
    return { fontFamily: cs.fontFamily, fontWeight: cs.fontWeight };
  });
  console.log('Actual computed:', JSON.stringify(actualFont));
  await page.waitForTimeout(500);

  // Get actual page height for full-page screenshot
  // Use offsetHeight (rendered box height) — scrollHeight gets inflated by
  // rotated ruler-frame children in dense layout (1600px-wide div rotated 90°)
  const bodyHeight = await page.evaluate(() => {
    const pg = document.querySelector('.page');
    // offsetHeight = content-driven box height (accurate)
    // scrollHeight can be inflated by transformed absolute children
    return pg.offsetHeight;
  });
  await page.setViewportSize({ width: size.width, height: bodyHeight });
  await page.waitForTimeout(500);

  await page.screenshot({ path: resolve(outputPath), type: 'png', clip: { x: 0, y: 0, width: size.width, height: bodyHeight } });
  await browser.close();

  const { statSync } = await import('fs');
  const st = statSync(resolve(outputPath));
  console.log(`Done. ${st.size} bytes`);
  console.log(`Screenshot saved: ${resolve(outputPath)}`);
}

main().catch(err => { console.error('Render failed:', err); process.exit(1); });
