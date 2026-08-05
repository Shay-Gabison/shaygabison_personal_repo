// render-cards.js — record deck slides as webm.
// usage: node render-cards.js <deck.html> <outdir> <id:dur,id:dur,...>
const { chromium } = require('playwright');
const fs = require('fs');
const [,, deck, outdir, spec] = process.argv;
const slides = spec.split(',').map(s => { const [id,d]=s.split(':'); return [id, parseFloat(d)]; });
(async () => {
  fs.mkdirSync(outdir, { recursive: true });
  for (const [id, dur] of slides) {
    const ctx = await chromium.launchPersistentContext('', {
      channel:'chrome', headless:true, viewport:{width:1440,height:900}, deviceScaleFactor:1,
      recordVideo:{ dir: outdir+'/_v_'+id, size:{width:1440,height:900} }
    });
    const pg = ctx.pages()[0] || await ctx.newPage();
    // Paint a dark background FIRST so the recording never starts on a white pre-paint frame.
    await pg.goto('data:text/html,<html><body style="margin:0;background:%230b0e14"></body></html>');
    await pg.waitForTimeout(300);
    await pg.goto('file://'+deck+'?slide='+id);
    await pg.waitForTimeout(dur*1000);
    await ctx.close();
    const wd = outdir+'/_v_'+id;
    const f = fs.readdirSync(wd).find(x=>x.endsWith('.webm'));
    fs.renameSync(wd+'/'+f, outdir+'/card_'+id+'.webm');
    console.log('card', id, dur+'s');
  }
})();
