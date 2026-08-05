// capture_panel.js — CROSS-PLATFORM terminal / code / logs capture via Playwright.
// Replaces the Unix-only tmux + asciinema + agg toolchain: it renders a mac-chrome style panel
// in headless Chrome and records it to webm, so it runs identically on macOS, Windows, and Linux.
//
// usage: node capture_panel.js <spec.json> <out.webm>
// spec.json:
// {
//   "type": "terminal" | "code" | "logs",
//   "title": "cards + real footage",              // window title bar text
//   "lang":  "go",                                 // for type=code (naive highlighter)
//   "lines": ["$ kubectl get pods", "NAME  READY", ...],  // content, one entry per line
//   "pace":  0.10,        // seconds between lines appearing (typing/scroll feel)
//   "tail":  1.5,         // seconds to dwell on the final frame
//   "fontsize": 20
// }
const { chromium } = (() => { try { return require('playwright'); } catch (e) { return require('playwright-core'); } })();
const { launchCtx } = require('./chan.js');
const fs = require('fs');

const [, , specPath, out] = process.argv;
const spec = JSON.parse(fs.readFileSync(specPath, 'utf8'));
const type = spec.type || 'terminal';
const pace = spec.pace ?? 0.10;
const tail = spec.tail ?? 1.5;
const fs_ = spec.fontsize || 20;
const title = (spec.title || type).replace(/</g, '&lt;');
const lines = (spec.lines || []).map(String);
const dur = lines.length * pace + tail + 0.6;

function esc(s) { return s.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;'); }

// Tiny offline highlighter for code panels — keywords / strings / comments / numbers.
const KW = ['func', 'return', 'if', 'else', 'for', 'range', 'var', 'const', 'type', 'struct',
  'import', 'package', 'def', 'class', 'self', 'from', 'as', 'try', 'except', 'with', 'async',
  'await', 'let', 'new', 'public', 'private', 'void', 'int', 'string', 'bool', 'true', 'false',
  'null', 'nil', 'None', 'True', 'False', 'apiVersion', 'kind', 'metadata', 'spec'];
function hl(line) {
  // single-pass tokenizer over ESCAPED text so we never re-scan injected markup
  const s = esc(line);
  const kw = new Set(KW);
  const re = /(#.*|\/\/.*)|("[^"]*"|'[^']*'|`[^`]*`)|\b(\d+(?:\.\d+)?)\b|([A-Za-z_]\w*)/g;
  let out = '', last = 0, m;
  while ((m = re.exec(s)) !== null) {
    out += s.slice(last, m.index);
    if (m[1]) out += `<span class="cm">${m[1]}</span>`;
    else if (m[2]) out += `<span class="st">${m[2]}</span>`;
    else if (m[3]) out += `<span class="nu">${m[3]}</span>`;
    else if (m[4]) out += kw.has(m[4]) ? `<span class="kw">${m[4]}</span>` : m[4];
    last = re.lastIndex;
  }
  out += s.slice(last);
  return out;
}
function termLine(line) {
  let s = esc(line);
  // colour a leading prompt ($ or PS>) and the command word
  s = s.replace(/^(\$|PS&gt;|&gt;)\s+(\S+)/, '<span class="p">$1</span> <span class="c">$2</span>');
  s = s.replace(/(#.*)$/, '<span class="cm">$1</span>');                      // trailing comment
  return s;
}

const rendered = lines.map(type === 'code' ? hl : termLine);
const numbered = type === 'code';

const html = `<!doctype html><html><head><meta charset="utf-8"><style>
  html,body{margin:0;width:1440px;height:900px;background:#0b0e14;overflow:hidden;
    font-family:'JetBrains Mono',Menlo,Consolas,monospace}
  .win{position:absolute;left:80px;top:70px;right:80px;bottom:70px;background:#0d1117;
    border:1px solid #1f2530;border-radius:12px;box-shadow:0 24px 80px rgba(0,0,0,.5);overflow:hidden}
  .bar{height:44px;background:#161b22;display:flex;align-items:center;padding:0 16px;gap:8px;
    border-bottom:1px solid #1f2530}
  .dot{width:12px;height:12px;border-radius:50%}
  .r{background:#ff5f56}.y{background:#ffbd2e}.g{background:#27c93f}
  .name{color:#8b949e;font-size:14px;margin-left:12px}
  .term{padding:20px 24px;font-size:${fs_}px;line-height:1.5;color:#c9d1d9;white-space:pre-wrap}
  .row{opacity:0;transform:translateY(6px);transition:opacity .18s,transform .18s}
  .row.on{opacity:1;transform:none}
  .ln{color:#4b5568;display:inline-block;width:34px;user-select:none}
  .p{color:#39d353}.c{color:#58a6ff}.cm{color:#6a737d;font-style:italic}
  .st{color:#a5d6ff}.nu{color:#f0883e}.kw{color:#ff7b72}
</style></head><body>
  <div class="win">
    <div class="bar"><span class="dot r"></span><span class="dot y"></span><span class="dot g"></span>
      <span class="name">${title}</span></div>
    <div class="term" id="t">${rendered.map((r, i) =>
      `<div class="row" id="r${i}">${numbered ? `<span class="ln">${i + 1}</span>` : ''}${r || '&nbsp;'}</div>`
    ).join('')}</div>
  </div></body></html>`;

(async () => {
  const ctx = await launchCtx(chromium, '', {
    headless: true, viewport: { width: 1440, height: 900 }, deviceScaleFactor: 1,
    recordVideo: { dir: require('os').tmpdir() + '/dbxp_panel_' + Date.now(), size: { width: 1440, height: 900 } },
  });
  const pg = ctx.pages()[0] || await ctx.newPage();
  // dark background first so no white pre-paint frame
  await pg.goto('data:text/html,<html><body style="margin:0;background:%230b0e14"></body></html>');
  await pg.waitForTimeout(250);
  await pg.setContent(html);
  await pg.waitForTimeout(300);
  const term = await pg.$('#t');
  for (let i = 0; i < rendered.length; i++) {
    await pg.evaluate(k => { const e = document.getElementById('r' + k); if (e) e.classList.add('on'); }, i);
    // keep the newest line in view (scroll feel for long content)
    await pg.evaluate(() => { const t = document.getElementById('t'); t.scrollTop = t.scrollHeight; });
    await pg.waitForTimeout(pace * 1000);
  }
  await pg.waitForTimeout(tail * 1000);
  await ctx.close();
  const dir = require('fs').readdirSync(require('os').tmpdir()).map(x => x).find(() => false); // noop
  // find the recorded webm
  const base = ctx._options?.recordVideo?.dir;
  // fallback: search tmp for our dir
  const os = require('os');
  const tmp = os.tmpdir();
  const mine = fs.readdirSync(tmp).filter(d => d.startsWith('dbxp_panel_')).sort();
  const vd = tmp + '/' + mine[mine.length - 1];
  const f = fs.readdirSync(vd).find(x => x.endsWith('.webm'));
  fs.renameSync(vd + '/' + f, out);
  fs.rmSync(vd, { recursive: true, force: true });
  console.log('panel', type, out, dur.toFixed(1) + 's', rendered.length + ' lines');
})();
