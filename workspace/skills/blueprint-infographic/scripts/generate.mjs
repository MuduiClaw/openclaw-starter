#!/usr/bin/env node
/**
 * Blueprint Infographic Generator — End-to-End Pipeline
 * Topic → AI Structuring (Gemini/Antigravity) → JSON → Render → PNG
 * 
 * Usage: node generate.mjs "主题" [--output path.png] [--model gemini-3.1-pro-high]
 */
import { readFileSync, writeFileSync, mkdirSync } from 'fs';
import { resolve, dirname, join } from 'path';
import { fileURLToPath } from 'url';
import { execSync } from 'child_process';

const __dirname = dirname(fileURLToPath(import.meta.url));
const ROOT = resolve(__dirname, '..');

// ── CLI ──
const args = process.argv.slice(2);
let topic, outputPath, model = 'gemini-3.1-pro-high';
let layout = '', theme = '', font = '';
for (let i = 0; i < args.length; i++) {
  if (args[i] === '--output' || args[i] === '-o') { outputPath = args[++i]; continue; }
  if (args[i] === '--model' || args[i] === '-m') { model = args[++i]; continue; }
  if (args[i] === '--layout') { layout = args[++i]; continue; }
  if (args[i] === '--theme') { theme = args[++i]; continue; }
  if (args[i] === '--font') { font = args[++i]; continue; }
  if (!topic) topic = args[i];
}
if (!topic) {
  console.error('Usage: node generate.mjs "主题" [--output path.png] [--layout banner|dense|hero|mosaic] [--theme ocean|forest|sunset|slate|blueprint] [--font default|handwritten] [--model model-name]');
  process.exit(1);
}

// Gemini API
const GEMINI_KEY = process.env.GEMINI_API_KEY || '***REMOVED***';

// ── Load structuring prompt ──
const structPrompt = readFileSync(join(ROOT, 'prompts', 'structuring.md'), 'utf8');

// ── Step 1: AI Structuring ──
async function structureTopic(topic) {
  console.log(`[1/3] AI 结构化: "${topic}" → JSON (model: ${model})`);
  
  const userMsg = `主题: ${topic}\n\n根据主题复杂度选择 5-9 个模块。选择最匹配的 theme 和 layout。\n至少 3 个模块包含具体数字。span 模式根据内容自然选择，不要每次都用同一套。\n\n直接输出 JSON，不要 markdown 包裹，不要注释。`;

  // ── Google Gemini API ──
  const geminiModelMap = {
    'gemini-3-flash': 'gemini-3-flash-preview',
    'gemini-3-pro': 'gemini-3-pro-preview',
    'gemini-3.1-pro-high': 'gemini-3.1-pro-preview',
    'gemini-3-flash-preview': 'gemini-3-flash-preview',
    'gemini-3.1-pro-preview': 'gemini-3.1-pro-preview',
  };
  const apiModel = geminiModelMap[model] || model;
  const geminiUrl = `https://generativelanguage.googleapis.com/v1beta/models/${apiModel}:generateContent?key=${GEMINI_KEY}`;
  const resp = await fetch(geminiUrl, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      systemInstruction: { parts: [{ text: structPrompt }] },
      contents: [{ role: 'user', parts: [{ text: userMsg }] }],
      generationConfig: { temperature: 0.7, maxOutputTokens: 8000 },
    })
  });
  if (!resp.ok) {
    const errText = await resp.text();
    throw new Error(`Gemini API error ${resp.status}: ${errText}`);
  }
  const data = await resp.json();
  let content = data.candidates?.[0]?.content?.parts?.[0]?.text || '';
  
  // Strip markdown code block if present
  content = content.replace(/^```json?\s*\n?/i, '').replace(/\n?```\s*$/i, '').trim();
  
  // Debug: show raw response
  console.log(`   原始长度: ${content.length} chars`);
  if (content.length < 100) {
    console.error('AI 返回内容过短:');
    console.error(JSON.stringify(data, null, 2).substring(0, 800));
  }
  
  // Validate JSON
  let parsed;
  try {
    parsed = JSON.parse(content);
  } catch (e) {
    console.error('AI 返回的 JSON 无法解析:');
    console.error(content.substring(0, 800));
    throw new Error(`JSON parse error: ${e.message}`);
  }

  // ── Normalize AI output deviations ──
  // Add title if missing
  if (!parsed.title && parsed.modules) {
    parsed.title = topic;
  }
  // Add subtitle if missing  
  if (!parsed.subtitle) {
    parsed.subtitle = '';
  }
  // Normalize modules
  if (Array.isArray(parsed.modules)) {
    parsed.modules = parsed.modules.map(m => {
      // data → content
      if (m.data && !m.content) { m.content = m.data; delete m.data; }
      // span: "normal" → delete
      if (m.span === 'normal') delete m.span;
      // Remove extra fields
      delete m.id;
      return m;
    });
  }
  
  // Validate structure
  if (!parsed.title || !parsed.modules || !Array.isArray(parsed.modules)) {
    console.error('JSON keys:', Object.keys(parsed));
    throw new Error('JSON 结构不完整: 缺少 title 或 modules');
  }
  if (parsed.modules.length < 5 || parsed.modules.length > 9) {
    console.warn(`⚠️ 模块数量: ${parsed.modules.length} (预期 6-8)`);
  }

  return parsed;
}

// ── Step 2: Render ──
async function renderJson(jsonData, outPath) {
  console.log(`[2/3] 渲染 HTML → PNG`);
  
  const tmpJson = join(ROOT, 'output', '_tmp_gen.json');
  writeFileSync(tmpJson, JSON.stringify(jsonData, null, 2));
  
  const renderScript = join(ROOT, 'scripts', 'render-v2.mjs');
  const extras = [
    layout ? `--layout ${layout}` : '',
    theme ? `--theme ${theme}` : '',
    font ? `--font ${font}` : '',
  ].filter(Boolean).join(' ');
  const cmd = `node "${renderScript}" "${tmpJson}" --output "${outPath}" --html ${extras}`;
  
  execSync(cmd, { stdio: 'inherit', cwd: ROOT });
}

// ── Main ──
async function main() {
  const timestamp = new Date().toISOString().replace(/[:.]/g, '-').slice(0, 19);
  const safeTopic = topic.replace(/[^a-zA-Z0-9\u4e00-\u9fff]/g, '_').slice(0, 30);
  
  if (!outputPath) {
    outputPath = join(ROOT, 'output', `gen-${safeTopic}-${timestamp}.png`);
  }
  mkdirSync(dirname(resolve(outputPath)), { recursive: true });

  try {
    // Step 1: Structure
    const jsonData = await structureTopic(topic);
    
    // Save intermediate JSON
    const jsonPath = outputPath.replace(/\.png$/i, '.json');
    writeFileSync(resolve(jsonPath), JSON.stringify(jsonData, null, 2));
    console.log(`   JSON saved: ${resolve(jsonPath)}`);
    console.log(`   标题: ${jsonData.title}`);
    console.log(`   模块: ${jsonData.modules.map(m => `${m.slot}:${m.type}`).join(', ')}`);

    // Step 2: Render
    await renderJson(jsonData, resolve(outputPath));

    console.log(`[3/3] ✅ 完成!`);
    console.log(`   PNG: ${resolve(outputPath)}`);
    
  } catch (err) {
    console.error(`❌ 失败: ${err.message}`);
    process.exit(1);
  }
}

main();
