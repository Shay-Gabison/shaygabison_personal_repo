// dl-sharepoint.js — download a SharePoint/OneDrive video via the user's authenticated Chrome.
// Graph/az tokens lack Files scopes (403); use cookie auth instead.
// usage: node dl-sharepoint.js <share-url> <out.mp4>
const { chromium } = require('playwright');
const fs=require('fs'),os=require('os'),path=require('path');
const [,, share, out]=process.argv;
const src=path.join(os.homedir(),'Library/Application Support/Google/Chrome'),tmp='/tmp/demo_sp_'+Date.now();
fs.mkdirSync(tmp+'/Default/Network',{recursive:true});
try{fs.copyFileSync(src+'/Local State',tmp+'/Local State')}catch{}
for(const f of ['Cookies','Login Data','Preferences','Secure Preferences','Web Data'])try{fs.copyFileSync(src+'/Default/'+f,tmp+'/Default/'+f)}catch{}
try{fs.copyFileSync(src+'/Default/Network/Cookies',tmp+'/Default/Network/Cookies')}catch{}
(async()=>{
  const ctx=await chromium.launchPersistentContext(tmp,{channel:'chrome',headless:true});
  const pg=ctx.pages()[0]||await ctx.newPage();
  await pg.goto(share,{waitUntil:'networkidle',timeout:60000});
  const u=pg.url(); const m=u.match(/id=([^&]+)/);
  const srv=m?decodeURIComponent(m[1]):null; const host=new URL(u).origin;
  const user=srv?srv.split('/').slice(0,3).join('/'):'';
  const dl=host+user+'/_layouts/15/download.aspx?SourceUrl='+encodeURIComponent(srv);
  const r=await pg.request.get(dl); fs.writeFileSync(out, await r.body());
  await ctx.close(); fs.rmSync(tmp,{recursive:true,force:true});
  console.log('downloaded', out, r.status());
})();
