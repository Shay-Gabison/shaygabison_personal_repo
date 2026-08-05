// record-adx.js — open an Azure Data Explorer (Kusto Web UI) deep link (query preloaded),
// run the query (Shift+Enter), wait for the result grid/chart, and record a crisp 1440x900 clip.
// Reuses the running Chrome profile (cookies) for SSO. usage:
//   node record-adx.js <url> <out.webm> <seconds> [mode=chart|grid]
const { chromium } = require('playwright');
const fs = require('fs'), os = require('os'), path = require('path');
const [,, url, out, secs, mode] = process.argv;
const dur = parseFloat(secs||'30');
const src = path.join(os.homedir(),'Library/Application Support/Google/Chrome');
const tmp = '/tmp/demo_chrome_'+Date.now();
fs.mkdirSync(tmp+'/Default/Network',{recursive:true});
for (const f of ['Local State']) try{fs.copyFileSync(src+'/'+f,tmp+'/'+f)}catch{}
for (const f of ['Cookies','Login Data','Preferences','Secure Preferences','Web Data'])
  try{fs.copyFileSync(src+'/Default/'+f,tmp+'/Default/'+f)}catch{}
try{fs.copyFileSync(src+'/Default/Network/Cookies',tmp+'/Default/Network/Cookies')}catch{}
(async () => {
  const ctx = await chromium.launchPersistentContext(tmp, {
    channel:'chrome', headless:true, viewport:{width:1440,height:900}, deviceScaleFactor:2,
    recordVideo:{ dir:'/tmp/demo_brec', size:{width:1440,height:900} }
  });
  const pg = ctx.pages()[0]||await ctx.newPage();
  await pg.goto(url, { waitUntil:'domcontentloaded', timeout:90000 });
  try { await pg.waitForLoadState('networkidle', { timeout:20000 }); } catch {}
  // Let Monaco editor + connection settle.
  await pg.waitForTimeout(8000);
  // Dismiss any blocking dialogs (VPN notice, welcome, etc.).
  for (const label of ['Approve and Continue','Got it','Close','OK','Accept']) {
    try { const btn = pg.getByRole('button', { name: label }); if (await btn.count()) { await btn.first().click({ timeout: 2500 }); await pg.waitForTimeout(600); } } catch {}
  }
  await pg.waitForTimeout(500);
  // Focus the query editor (Monaco) and run with Shift+Enter.
  try {
    const editor = await pg.$('.monaco-editor');
    if (editor) { const b = await editor.boundingBox(); if (b) await pg.mouse.click(b.x + b.width/2, b.y + 40); }
  } catch {}
  await pg.waitForTimeout(800);
  for (let attempt=0; attempt<3; attempt++) {
    try { await pg.keyboard.press('Shift+Enter'); } catch {}
    await pg.waitForTimeout(3500);
    // Check if results appeared (grid rows or chart svg).
    const has = await pg.evaluate(() => !!(document.querySelector('.ag-row') || document.querySelector('svg .highcharts-series') || document.querySelector('canvas')));
    if (has) break;
  }
  await pg.waitForTimeout(2000);
  // Hold on the result with gentle motion (small wheel scrolls) so the section isn't static.
  const holdMs = dur*1000;
  const steps = Math.max(8, Math.round(holdMs/1400));
  try { await pg.mouse.move(700, 720); } catch {}
  for (let i=0;i<steps;i++){
    try { await pg.mouse.wheel(0, (i%2===0)? 60 : -60); } catch {}
    await pg.waitForTimeout(holdMs/steps);
  }
  await ctx.close();
  const f = fs.readdirSync('/tmp/demo_brec').find(x=>x.endsWith('.webm'));
  fs.renameSync('/tmp/demo_brec/'+f, out);
  fs.rmSync(tmp,{recursive:true,force:true});
  console.log('recorded', out);
})();
