// chan.js — launch a Chromium persistent context using whatever browser the machine actually has.
// On a managed Windows box Chrome may be absent but Edge is always present. Order: env override,
// then chrome, then msedge, then Playwright's bundled chromium (if it was installed).
const CHANNELS = process.env.DBXP_CHANNEL ? [process.env.DBXP_CHANNEL] : ['chrome', 'msedge'];

async function launchCtx(chromium, profileDir, opts) {
  let lastErr;
  const extra = process.env.DBXP_NOSANDBOX ? { args: ['--no-sandbox', ...(opts.args || [])] } : {};
  for (const channel of CHANNELS) {
    try {
      return await chromium.launchPersistentContext(profileDir, { channel, ...opts, ...extra });
    } catch (e) { lastErr = e; }
  }
  try {
    // last resort: bundled chromium (only exists if a full `playwright` install downloaded it)
    return await chromium.launchPersistentContext(profileDir, { ...opts, ...extra });
  } catch (e) {
    const msg = (lastErr && lastErr.message) || (e && e.message) || 'unknown';
    throw new Error('No usable browser (tried ' + CHANNELS.join(', ') +
      ', then bundled chromium). Install Google Chrome or Microsoft Edge. Cause: ' + msg);
  }
}

module.exports = { launchCtx };
