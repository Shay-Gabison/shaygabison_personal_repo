// record-browser.js — drive the user's authenticated Chrome to a deep link and record (crisp).
// Copies the running Chrome profile (cookies only) so ADO/SharePoint SSO is inherited.
// usage: node record-browser.js <url> <out.webm> <seconds> [scrollPx] [zoom]
const { chromium } = require('playwright');
const fs = require('fs'), os = require('os'), path = require('path');
const [,, url, out, secs, scrollPx, zoomArg] = process.argv;
const dur = parseFloat(secs||'30'), scroll = parseInt(scrollPx||'0'), zoom = parseFloat(zoomArg||'1.0');
const src = path.join(os.homedir(),'Library/Application Support/Google/Chrome');
const tmp = '/tmp/demo_chrome_'+Date.now();
fs.mkdirSync(tmp+'/Default/Network',{recursive:true});
for (const f of ['Local State']) try{fs.copyFileSync(src+'/'+f,tmp+'/'+f)}catch{}
for (const f of ['Cookies','Login Data','Preferences','Secure Preferences','Web Data'])
  try{fs.copyFileSync(src+'/Default/'+f,tmp+'/Default/'+f)}catch{}
try{fs.copyFileSync(src+'/Default/Network/Cookies',tmp+'/Default/Network/Cookies')}catch{}
(async () => {
  // Smaller viewport + 2x scale + page zoom => large, sharp text in a 1440x900 frame.
  const ctx = await chromium.launchPersistentContext(tmp, {
    channel:'chrome', headless:true, viewport:{width:1440,height:900}, deviceScaleFactor:2,
    recordVideo:{ dir:'/tmp/demo_brec', size:{width:1440,height:900} }
  });
  const pg = ctx.pages()[0]||await ctx.newPage();
  await pg.goto(url, { waitUntil:'domcontentloaded', timeout:60000 });
  try { await pg.waitForLoadState('networkidle', { timeout:12000 }); } catch {}
  if (zoom && zoom !== 1) { try { await pg.evaluate(z=>{document.body.style.zoom=z;}, zoom); } catch {} }
  await pg.waitForTimeout(1200);
  if (scroll) {
    // Hover over the main content/log pane so the wheel targets the inner scroller (not the side list).
    try { await pg.mouse.move(1000, 520); } catch {}
    // Continuous incremental scroll => live "reading the log" motion (not a static screenshot).
    const steps = 22, totalMs = dur*1000*0.8, stepPx = Math.max(1, Math.round(scroll/steps));
    for (let i=0;i<steps;i++){ await pg.mouse.wheel(0, stepPx); await pg.waitForTimeout(totalMs/steps); }
    await pg.waitForTimeout(dur*1000*0.2);
  } else {
    await pg.waitForTimeout(dur*1000);
  }
  await ctx.close();
  const f = fs.readdirSync('/tmp/demo_brec').find(x=>x.endsWith('.webm'));
  fs.renameSync('/tmp/demo_brec/'+f, out);
  fs.rmSync(tmp,{recursive:true,force:true}); // SECURITY: delete copied auth profile
  console.log('recorded', out);
})();
