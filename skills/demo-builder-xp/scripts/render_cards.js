// render_cards.js — record deck slides as webm. CROSS-PLATFORM (resolves deck to a file:// URL).
// usage: node render_cards.js <deck.html> <outdir> <id:dur,id:dur,...>
const { chromium } = (() => { try { return require('playwright'); } catch (e) { return require('playwright-core'); } })();
const { launchCtx } = require('./chan.js');
const fs = require('fs');
const path = require('path');
const url = require('url');
const [,, deck, outdir, spec] = process.argv;
const deckUrl = url.pathToFileURL(path.resolve(deck)).href;
const slides = spec.split(',').map(s => { const [id,d]=s.split(':'); return [id, parseFloat(d)]; });
(async () => {
  fs.mkdirSync(outdir, { recursive: true });
  for (const [id, dur] of slides) {
    const ctx = await launchCtx(chromium, '', {
      headless:true, viewport:{width:1440,height:900}, deviceScaleFactor:1,
      recordVideo:{ dir: outdir+'/_v_'+id, size:{width:1440,height:900} }
    });
    const pg = ctx.pages()[0] || await ctx.newPage();
    // Paint a dark background FIRST so the recording never starts on a white pre-paint frame.
    await pg.goto('data:text/html,<html><body style="margin:0;background:%230b0e14"></body></html>');
    await pg.waitForTimeout(300);
    await pg.goto(deckUrl+'?slide='+id);
    await pg.waitForTimeout(dur*1000);
    await ctx.close();
    const wd = outdir+'/_v_'+id;
    const f = fs.readdirSync(wd).find(x=>x.endsWith('.webm'));
    fs.renameSync(wd+'/'+f, outdir+'/card_'+id+'.webm');
    console.log('card', id, dur+'s');
  }
})();
