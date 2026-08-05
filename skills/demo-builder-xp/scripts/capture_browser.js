// capture_browser.js — CROSS-PLATFORM authenticated browser capture (macOS / Windows / Linux).
// Copies the real Chrome profile's cookies so ADO/portal SSO is inherited, drives a deep link,
// and records to webm. Chrome user-data path is resolved per-OS.
// usage: node capture_browser.js <url> <out.webm> <seconds> [scrollPx] [zoom]
const { chromium } = (() => { try { return require('playwright'); } catch (e) { return require('playwright-core'); } })();
const { launchCtx } = require('./chan.js');
const fs = require('fs'), os = require('os'), path = require('path');

const [, , url, out, secs, scrollPx, zoomArg] = process.argv;
const dur = parseFloat(secs || '30'), scroll = parseInt(scrollPx || '0'), zoom = parseFloat(zoomArg || '1.0');

function chromeUserData() {
  const home = os.homedir();
  // On managed boxes ADO SSO usually lives in Edge, not Chrome. Prefer Edge when asked
  // (DBXP_PROFILE=edge or DBXP_CHANNEL=msedge) or when Chrome's profile is absent.
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
  const edgeP = edge[plat];
  const chromeP = chrome[plat];
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

const src = chromeUserData();
const tmp = path.join(os.tmpdir(), 'dbxp_chrome_' + Date.now());
fs.mkdirSync(path.join(tmp, 'Default/Network'), { recursive: true });
const cp = (rel) => { try { fs.copyFileSync(path.join(src, rel), path.join(tmp, rel)); } catch {} };
cp('Local State');
for (const f of ['Cookies', 'Login Data', 'Preferences', 'Secure Preferences', 'Web Data'])
  cp(path.join('Default', f));
cp(path.join('Default', 'Network', 'Cookies'));

(async () => {
  const shot = /\.png$/i.test(out);
  const recDir = path.join(os.tmpdir(), 'dbxp_brec_' + Date.now());
  const ctx = await launchCtx(chromium, tmp, {
    headless: true, viewport: { width: 1440, height: 900 }, deviceScaleFactor: 2,
    ...(shot ? {} : { recordVideo: { dir: recDir, size: { width: 1440, height: 900 } } }),
  });
  const pg = ctx.pages()[0] || await ctx.newPage();
  await pg.goto(url, { waitUntil: 'domcontentloaded', timeout: 60000 });
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
  fs.rmSync(tmp, { recursive: true, force: true }); // SECURITY: delete copied auth profile
  console.log('recorded', out);
})();
