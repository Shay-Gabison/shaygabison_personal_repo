---
name: fairfax-manual-action-icm
description: Create IcM incidents for manual actions in Fairfax sovereign clouds. Use when the user needs to request NSP association management (list, delete, create), Geneva Actions, JIT-based portal operations, or any manual task in USME/USGV that requires authorized on-site personnel. Triggers include 'fairfax manual action', 'fairfax IcM', 'sovereign cloud ticket', 'mtpfairfaxtask', 'NSP association fairfax', or any request for a manual action in a restricted cloud.
domain: fairfax-operations
confidence: adopted
source: Operational experience — IcM 846141252, 848222555
license: Complete terms in LICENSE.txt
---

# Fairfax Manual Action IcM

Create IcM incidents for manual actions in restricted sovereign clouds (Fairfax/ITAR), routed to the MDA + MDE Fairfax Support team. Non-US personnel cannot access Fairfax directly — the only path is filing an IcM to the US-based support team.

## When to Use This Skill

- User needs a manual action performed in Fairfax (USME / USGV)
- User needs to list, delete, or create NSP associations in sovereign clouds
- User needs to run Geneva Actions in Fairfax
- User mentions "fairfax IcM", "sovereign cloud manual action", "mtpfairfaxtask"
- Action cannot be done via automated deployment (EV2)

## Workflow

### Step 1: Gather Information

Ask the user for:
1. **What action is needed?** (e.g., delete NSP association, create NSP association, list associations, run Geneva Action)
2. **Target resources** — full Azure resource IDs or names + resource groups + subscriptions
3. **Geneva Action link** (if applicable) — the portal.microsoftgeneva.com URL
4. **Severity** — default 3 for proactive; 2.5 (value `25`) if tied to an active parent IcM
5. **Parent IcM** (if any) — for context reference
6. **Cloud** — USME (GCC-M) or USGV (GPRD)

### Step 2: Create IcM via Playwright + Edge

Use Playwright with the user's Edge persistent profile to automate IcM creation. This bypasses Intune/Conditional Access issues that block headless browsers.

```javascript
import { chromium } from 'playwright';

const browser = await chromium.launchPersistentContext(
  '/Users/shaygabison/Library/Application Support/Microsoft Edge/Profile 2',
  { channel: 'msedge', headless: false, args: ['--disable-blink-features=AutomationControlled'] }
);
const page = await browser.newPage();

// Navigate to template URL (pre-selects team + tags)
await page.goto('https://aka.ms/mtpfairfaxtask/mda', { waitUntil: 'domcontentloaded', timeout: 60000 });

// Handle SSO if needed
if (page.url().includes('IdentityProvider')) {
  await page.click('a[href*="identityProvider=EntraID-OIDC"]', { timeout: 10000 });
  await page.waitForURL('**/incidents/create**', { timeout: 120000 });
}

// Wait for form to load
await page.waitForTimeout(5000);

// Fill Title
await page.fill('input[aria-label="Title"]', '[FF Manual Action] - <description>');

// Severity 2.5 (or 3 for proactive)
await page.evaluate(() => document.querySelector('input[value="25"][name="requiredForm-Severity"]').click());

// Environment: PROD
await page.selectOption('select[aria-label="Environment"]', 'PROD');

// Customer/SLA Impact: No
await page.evaluate(() => document.querySelector('input[name="requiredForm-IsCustomerSlaImpacting"][value="false"]').click());

// Description
await page.evaluate(() => {
  const editors = [...document.querySelectorAll('[contenteditable="true"]')].filter(e => e.offsetParent !== null);
  if (editors[0]) {
    editors[0].innerHTML = 'See first discussion comment for detailed action request.';
    editors[0].dispatchEvent(new Event('input', {bubbles: true}));
    editors[0].classList.remove('ng-empty');
    editors[0].classList.add('ng-not-empty', 'ng-dirty', 'ng-touched');
  }
});

// Submit
await page.click('button.btn-primary:has-text("Submit")');
await page.waitForURL('**/incidents/details/**', { timeout: 30000 });

// Extract incident ID
const match = page.url().match(/incidents\/details\/(\d+)/);
const incidentId = match[1];
```

**IMPORTANT:** Close Edge before launching (`osascript -e 'tell application "Microsoft Edge" to quit'`) — Playwright can't use a profile that's already open.

### Step 3: Post Formatted Discussion Entry

Navigate to the incident and post the HTML discussion:

```javascript
await page.goto(`https://portal.microsofticm.com/imp/v5/incidents/details/${incidentId}/summary`, { waitUntil: 'domcontentloaded', timeout: 60000 });
await page.waitForTimeout(8000);

await page.evaluate((html) => {
  const editors = [...document.querySelectorAll('[contenteditable="true"]')].filter(e => e.offsetParent !== null);
  const editor = editors[editors.length - 1]; // Last visible editor = discussion
  editor.focus();
  editor.innerHTML = html;
  editor.dispatchEvent(new Event('input', {bubbles: true}));
  editor.classList.remove('ng-empty');
  editor.classList.add('ng-not-empty', 'ng-dirty', 'ng-touched');
}, discussionHtml);

await page.waitForTimeout(2000);
await page.locator('button:has-text("Save"), button:has-text("Post"), button:has-text("Add")').first().click();
```

### Step 4 (Optional): Link Parent IcM

If there's a parent IcM, mention it in the discussion context section. Direct linking via the portal can be done manually by the user.

## Discussion Entry Template (HTML)

```html
<h2>ACTION REQUIRED</h2>
<p>Please perform the following steps.</p>
<hr>
<h3>Target Resource</h3>
<ul>
  <li><b>Resource name:</b> [name]</li>
  <li><b>Resource Group:</b> [rg]</li>
  <li><b>Cloud:</b> USME (GCC-M) / USGV (GPRD)</li>
  <li><b>Subscription:</b> [subscription-id]</li>
</ul>
<hr>
<h3>Step 1 — [Action verb]</h3>
<p>[Instructions with Geneva Action link]</p>
<p><b>Geneva Action:</b><br>
<a href="[URL]">[URL]</a></p>
<p>Parameters:</p>
<ul>
  <li>[param 1]</li>
  <li>[param 2]</li>
</ul>
<hr>
<h3>Step 2 — [Next action if multi-step]</h3>
<p>[Instructions]</p>
<ul>
  <li>[details]</li>
</ul>
<hr>
<h3>Context</h3>
<p>Part of [parent work]. Parent IcM [ID]. Non-US team, cannot access sovereign cloud directly.</p>
```

## Technical Notes

### IcM Portal Automation

| Issue | Solution |
|-------|----------|
| Intune/Conditional Access blocks headless browsers | Use `chromium.launchPersistentContext` with Edge profile |
| Must close Edge before Playwright can use profile | `osascript -e 'tell application "Microsoft Edge" to quit'` |
| Template URL pre-fills team + tags | Use `https://aka.ms/mtpfairfaxtask/mda` — skips wizard steps |
| Severity 2.5 = value `25` | `input[value="25"][name="requiredForm-Severity"]` |
| Contenteditable fields need Angular class manipulation | Remove `ng-empty`, add `ng-not-empty`, `ng-dirty`, `ng-touched` |
| Discussion editor is the last visible `[contenteditable="true"]` | Filter by `offsetParent !== null`, take last one |

### Edge Profile Location

```
/Users/shaygabison/Library/Application Support/Microsoft Edge/Profile 2
```

### Common Geneva Actions

| Action | Geneva ID | Purpose |
|--------|-----------|---------|
| List NSP Associations | `BC3E564C` | List all associations on an NSP |
| Delete NSP Association | `43FB26C9` | Remove an association from a resource |

### NSP Profiles (Gov Clouds)

| Cloud | Region | Profile1 | NoAzureCloudGenericIpsProfile |
|-------|--------|----------|-------------------------------|
| GCCM | USMV | `mdacommon-nsp-gccm-usmv/mdacommon-profile1-gccm-usmv` | `mdacommon-nsp-gccm-usmv/mdacommon-noazurecloudgenericipsprofile-gccm-usmv` |
| GPRD | USGV | `mdacommon-nsp-gprd-usgv/mdacommon-profile1-gprd-usgv` | `mdacommon-nsp-gprd-usgv/mdacommon-noazurecloudgenericipsprofile-gprd-usgv` |

### NSP Infrastructure

| Cloud | NSP Name | NSP RG | NSP Subscription |
|-------|----------|--------|------------------|
| GCCM | mdacommon-nsp-gccm-usmv | mps-mda-mdacommon-nsp-gccm-usmv-rg | de1aa163-1664-427b-8026-c2e7ee7e3f4e |
| GPRD | mdacommon-nsp-gprd-usgv | mps-mda-mdacommon-nsp-gprd-usgv-rg | 439de912-a832-4d44-a9f5-40d9da87618b |

### Configuration

| Setting | Value |
|---------|-------|
| Owning Team | MDA + MDE Fairfax Support |
| Team ID | 140755 |
| Service ID | 33114 |
| Template URL | https://aka.ms/mtpfairfaxtask/mda |
| Tag | MTPFF |
| Environment | PROD |
| SLA | 2 business days |

### Other Team Templates

| Team | Template URL |
|------|-------------|
| MDI | https://aka.ms/mtpfairfaxtask/mdi |
| OneSoc | https://aka.ms/mtpfairfaxtask/onesoc |
| XDR | https://aka.ms/mtpfairfaxtask/xdr |
| DK8s Platform | https://aka.ms/mtpfairfaxtask/dk8s |
| XSPM | https://aka.ms/mtpfairfaxtask/xspm |
| MDE/D4IoT | https://aka.ms/mtpfairfaxtask/mde |

## Examples

### Example 1: Delete and Re-create NSP Association (GCCM)

**User says:** "Create a Fairfax IcM to delete the common NSP association and create ev2-certs on NoAzureCloudGenericIpsProfile for mda-ga-fm-usgv"

**Title:** `[FF Manual Action] - Delete common NSP association and create ev2-certs on NoAzureCloudGenericIpsProfile for mda-ga-fm-usgv Key Vault`

**Discussion:** HTML with Step 1 (delete via Geneva Action `43FB26C9`) and Step 2 (create ev2-certs on `mdacommon-noazurecloudgenericipsprofile-gccm-usmv`).

### Example 2: List NSP Associations (GPRD)

**User says:** "Create a Fairfax IcM to list NSP associations for mdacommon-nsp-gprd-usgv"

**Title:** `[FF Manual Action] - List NSP associations for mdacommon-nsp-gprd-usgv`

**Discussion:** HTML with Geneva Action link (`BC3E564C`), target NSP resource ID, expected output: list of association names.

### Example 3: Single Delete

**User says:** "Fairfax IcM to delete ev2-certs association from KV mda-ga-fm-usgv in GCCM"

**Title:** `[FF Manual Action] - Delete ev2-certs NSP association from mda-ga-fm-usgv Key Vault`

**Discussion:** HTML with Geneva Action `43FB26C9`, resource ID, association name `ev2-certs`.
