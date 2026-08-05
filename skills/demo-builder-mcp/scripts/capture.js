// capture.js — ONE cross-platform Playwright capture tool (macOS / Windows / Linux).
// Modes:
//   node capture.js cards   <deck.html> <outdir> <id:dur,id:dur,...>        deck slides -> card_<id>.webm
//   node capture.js panel   <spec.json> <out.webm>                          terminal/code/logs animated panel
//   node capture.js browser <url> <out.(webm|png)> <secs> [scrollPx] [zoom] authed ADO/portal capture (real cookies)
//
// Everything renders at 1440x900. The whole thing is just Playwright + a little HTML, so it runs
// identically everywhere with NO tmux / asciinema / agg / Homebrew. Set NODE_PATH to wherever
// playwright is installed (e.g. ~/demo_build/node_modules) before invoking.
const { chromium } = (() => { try { return require('playwright'); } catch (e) { return require('playwright-core'); } })();
const fs = require('fs'), os = require('os'), path = require('path'), url = require('url');

// --- browser launch: use whatever Chromium the machine has (chrome -> msedge -> bundled) --------
// On managed Windows boxes Chrome may be absent but Edge is always present, and ADO SSO usually
// lives in Edge. Override order with DBXP_CHANNEL=msedge; DBXP_NOSANDBOX=1 for locked-down boxes.
async function launchCtx(profileDir, opts) {
  const channels = process.env.DBXP_CHANNEL ? [process.env.DBXP_CHANNEL] : ['chrome', 'msedge'];
  const extra = process.env.DBXP_NOSANDBOX ? { args: ['--no-sandbox', ...(opts.args || [])] } : {};
  let lastErr;
  for (const channel of channels) {
    try { return await chromium.launchPersistentContext(profileDir, { channel, ...opts, ...extra }); }
    catch (e) { lastErr = e; }
  }
  try { return await chromium.launchPersistentContext(profileDir, { ...opts, ...extra }); }
  catch (e) {
    const msg = (lastErr && lastErr.message) || (e && e.message) || 'unknown';
    throw new Error('No usable browser (tried ' + channels.join(', ') +
      ', then bundled chromium). Install Google Chrome or Microsoft Edge. Cause: ' + msg);
  }
}

// ============================ mode: cards =====================================================
async function cards([deck, outdir, spec]) {
  const deckUrl = url.pathToFileURL(path.resolve(deck)).href;
  const slides = spec.split(',').map(s => { const [id, d] = s.split(':'); return [id, parseFloat(d)]; });
  fs.mkdirSync(outdir, { recursive: true });
  for (const [id, dur] of slides) {
    const ctx = await launchCtx('', {
      headless: true, viewport: { width: 1440, height: 900 }, deviceScaleFactor: 1,
      recordVideo: { dir: outdir + '/_v_' + id, size: { width: 1440, height: 900 } },
    });
    const pg = ctx.pages()[0] || await ctx.newPage();
    // Paint a dark background FIRST so the recording never starts on a white pre-paint frame.
    await pg.goto('data:text/html,<html><body style="margin:0;background:%230b0e14"></body></html>');
    await pg.waitForTimeout(300);
    await pg.goto(deckUrl + '?slide=' + id);
    await pg.waitForTimeout(dur * 1000);
    await ctx.close();
    const wd = outdir + '/_v_' + id;
    const f = fs.readdirSync(wd).find(x => x.endsWith('.webm'));
    fs.renameSync(wd + '/' + f, outdir + '/card_' + id + '.webm');
    fs.rmSync(wd, { recursive: true, force: true });
    console.log('card', id, dur + 's');
  }
}

// ============================ mode: panel (terminal/code/logs) =================================
function esc(s) { return s.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;'); }
const KW = ['func', 'return', 'if', 'else', 'for', 'range', 'var', 'const', 'type', 'struct',
  'import', 'package', 'def', 'class', 'self', 'from', 'as', 'try', 'except', 'with', 'async',
  'await', 'let', 'new', 'public', 'private', 'void', 'int', 'string', 'bool', 'true', 'false',
  'null', 'nil', 'None', 'True', 'False', 'apiVersion', 'kind', 'metadata', 'spec'];
function hl(line) {
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
  s = s.replace(/^(\$|PS&gt;|&gt;)\s+(\S+)/, '<span class="p">$1</span> <span class="c">$2</span>');
  s = s.replace(/(#.*)$/, '<span class="cm">$1</span>');
  return s;
}
async function panel([specPath, out]) {
  const spec = JSON.parse(fs.readFileSync(specPath, 'utf8'));
  const type = spec.type || 'terminal';
  const pace = spec.pace ?? 0.10;
  const tail = spec.tail ?? 1.5;
  const fs_ = spec.fontsize || 20;
  const title = (spec.title || type).replace(/</g, '&lt;');
  const lines = (spec.lines || []).map(String);
  const dur = lines.length * pace + tail + 0.6;
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
  const recDir = path.join(os.tmpdir(), 'dbxp_panel_' + Date.now());
  const ctx = await launchCtx('', {
    headless: true, viewport: { width: 1440, height: 900 }, deviceScaleFactor: 1,
    recordVideo: { dir: recDir, size: { width: 1440, height: 900 } },
  });
  const pg = ctx.pages()[0] || await ctx.newPage();
  await pg.goto('data:text/html,<html><body style="margin:0;background:%230b0e14"></body></html>');
  await pg.waitForTimeout(250);
  await pg.setContent(html);
  await pg.waitForTimeout(300);
  for (let i = 0; i < rendered.length; i++) {
    await pg.evaluate(k => { const e = document.getElementById('r' + k); if (e) e.classList.add('on'); }, i);
    await pg.evaluate(() => { const t = document.getElementById('t'); t.scrollTop = t.scrollHeight; });
    await pg.waitForTimeout(pace * 1000);
  }
  await pg.waitForTimeout(tail * 1000);
  await ctx.close();
  const f = fs.readdirSync(recDir).find(x => x.endsWith('.webm'));
  fs.renameSync(path.join(recDir, f), out);
  fs.rmSync(recDir, { recursive: true, force: true });
  console.log('panel', type, out, dur.toFixed(1) + 's', rendered.length + ' lines');
}

// ============================ mode: browser (authed ADO/portal) ===============================
function chromeUserData() {
  const home = os.homedir();
  const wantEdge = (process.env.DBXP_PROFILE || '').toLowerCase() === 'edge'
    || (process.env.DBXP_CHANNEL || '').toLowerCase() === 'msedge';
  const local = process.env.LOCALAPPDATA || path.join(home, 'AppData/Local');
  const edge = {
    darwin: path.join(home, 'Library/Application Support/Microsoft Edge'),
    win32: path.join(local, 'Microsoft/Edge/User Data'),
    linux: path.join(home, '.config/microsoft-edge'),
  };
  const chrome = {
    darwin: path.join(home, 'Library/Application Support/Google/Chrome'),
    win32: path.join(local, 'Google/Chrome/User Data'),
    linux: null,
  };
  const plat = process.platform === 'darwin' || process.platform === 'win32' ? process.platform : 'linux';
  const edgeP = edge[plat], chromeP = chrome[plat];
  if (wantEdge && edgeP && fs.existsSync(edgeP)) return edgeP;
  if (chromeP && fs.existsSync(chromeP)) return chromeP;
  if (edgeP && fs.existsSync(edgeP)) return edgeP;
  if (plat === 'linux') {
    for (const c of ['.config/google-chrome', '.config/chromium']) {
      const p = path.join(home, c); if (fs.existsSync(p)) return p;
    }
  }
  return chromeP || edgeP || path.join(home, '.config/google-chrome');
}
async function browser([target, out, secs, scrollPx, zoomArg]) {
  const dur = parseFloat(secs || '30'), scroll = parseInt(scrollPx || '0'), zoom = parseFloat(zoomArg || '1.0');
  const src = chromeUserData();
  const tmp = path.join(os.tmpdir(), 'dbxp_chrome_' + Date.now());
  fs.mkdirSync(path.join(tmp, 'Default/Network'), { recursive: true });
  const cp = (rel) => { try { fs.copyFileSync(path.join(src, rel), path.join(tmp, rel)); } catch {} };
  cp('Local State');
  for (const f of ['Cookies', 'Login Data', 'Preferences', 'Secure Preferences', 'Web Data'])
    cp(path.join('Default', f));
  cp(path.join('Default', 'Network', 'Cookies'));

  const shot = /\.png$/i.test(out);
  const recDir = path.join(os.tmpdir(), 'dbxp_brec_' + Date.now());
  const ctx = await launchCtx(tmp, {
    headless: true, viewport: { width: 1440, height: 900 }, deviceScaleFactor: 2,
    ...(shot ? {} : { recordVideo: { dir: recDir, size: { width: 1440, height: 900 } } }),
  });
  const pg = ctx.pages()[0] || await ctx.newPage();
  await pg.goto(target, { waitUntil: 'domcontentloaded', timeout: 60000 });
  try { await pg.waitForLoadState('networkidle', { timeout: 12000 }); } catch {}
  if (zoom && zoom !== 1) { try { await pg.evaluate(z => { document.body.style.zoom = z; }, zoom); } catch {} }
  await pg.waitForTimeout(1200);
  if (shot) {
    const title = await pg.title().catch(() => '');
    const signIn = await pg.evaluate(() => /sign in|log in|microsoft account|stay signed in/i.test(document.body.innerText || '')).catch(() => false);
    await pg.screenshot({ path: out, fullPage: false });
    await ctx.close();
    fs.rmSync(tmp, { recursive: true, force: true });
    console.log('SHOT', out, '| title=', JSON.stringify(title), '| looksLikeLogin=', signIn);
    return;
  }
  if (scroll) {
    try { await pg.mouse.move(1000, 520); } catch {}
    const steps = 22, totalMs = dur * 1000 * 0.8, stepPx = Math.max(1, Math.round(scroll / steps));
    for (let i = 0; i < steps; i++) { await pg.mouse.wheel(0, stepPx); await pg.waitForTimeout(totalMs / steps); }
    await pg.waitForTimeout(dur * 1000 * 0.2);
  } else {
    await pg.waitForTimeout(dur * 1000);
  }
  await ctx.close();
  const f = fs.readdirSync(recDir).find(x => x.endsWith('.webm'));
  fs.renameSync(path.join(recDir, f), out);
  fs.rmSync(recDir, { recursive: true, force: true });
  fs.rmSync(tmp, { recursive: true, force: true }); // SECURITY: delete the copied auth profile
  console.log('recorded', out);
}

// ============================ dispatch =========================================================
(async () => {
  const mode = process.argv[2], rest = process.argv.slice(3);
  try {
    if (mode === 'cards') await cards(rest);
    else if (mode === 'panel') await panel(rest);
    else if (mode === 'browser') await browser(rest);
    else { console.error('usage: node capture.js <cards|panel|browser> ...'); process.exit(2); }
  } catch (e) { console.error(String((e && e.stack) || e)); process.exit(1); }
})();
