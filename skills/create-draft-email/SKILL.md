---
name: create-draft-email
description: "Create beautiful, Outlook-safe HTML draft emails for announcements, how-to guides, and team communications. Use when the user asks to draft an email, create an announcement, or prepare a broadcast message. Covers Identity Security Platform Axon visual style (navy hero + white card), Outlook HTML rules, checkmark-entity bugs, attachment upload workflow, and iterative design refinement."
domain: "communication"
confidence: "adopted"
---

# Create Draft Email (Outlook-Safe HTML)

Build polished HTML draft emails in the signed-in user's Outlook mailbox using the mail-* MCP tools. Optimized for announcements, how-to guides, and team broadcasts from Identity Security Platform Axon.

## When to Use This Skill

- User asks to "draft a mail", "create an email", "prepare an announcement"
- Broadcasting migration news, new pipelines, deprecations to multiple teams
- How-to / runbook emails with Kusto queries, pipeline links, screenshots
- Any email that needs rich formatting (not plain text)

## Approved Visual Style (Identity Security Platform Axon)

The user has iterated through MANY palettes. This is the **approved** layout — start here, don't reinvent:

**Structure (table-based, Outlook-safe):**
- Outer table: `#f5f6f8` background, full width
- Inner card: **fluid up to 680px** (`width="100%"` + `style="max-width:680px"`), centered, white `#ffffff`, `border-radius: 12px`, subtle box-shadow. The card MUST shrink with the viewport so content is never trimmed in narrow Outlook reading panes or small windows.
- Hero header: **navy `#1e3a8a`** solid background, white text, 🚀 emoji, `padding: 32px 40px` (drop to `24px 20px` on small screens via inline media query if needed)
- Body padding: **32-40px** (use `padding:24px 20px` minimum on small screens)
- Images: always set `style="max-width:100%;height:auto;display:block;"` so embedded screenshots scale instead of forcing horizontal scroll
- Section cards inside body: light backgrounds (`#fef2f2` red / `#f0fdf4` green / `#eef2ff` indigo / `#0f172a` dark for code)
- Signature: "— Identity Security Platform Axon" in muted gray
- **Always** add 🤖 robot emoji somewhere (user preference)

**Typography:**
- Font: `-apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif`
- Body text: 15-16px, `#334155` (slate-700), `line-height: 1.6`
- Headings: `#0f172a` (slate-900), semibold

## CRITICAL Outlook HTML Rules

Outlook **breaks** modern CSS. Follow these rules or layout falls apart:

1. **Use `<table role="presentation" cellpadding="0" cellspacing="0" border="0">` for all layout.** No flexbox, no grid.
2. **Inline all styles.** No `<style>` blocks — Outlook strips them.
3. **No `linear-gradient`** — use solid colors. Gradients render as broken/missing backgrounds.
4. **No HTML entities like `&check;`, `&rarr;`, `&hellip;`.** Outlook/Graph **escapes them** server-side → they render as literal `&check;` text in the email. **Use Unicode literals instead**:
   - ✓ (U+2713) instead of `&check;`
   - → (U+2192) instead of `&rarr;`
   - … (U+2026) instead of `&hellip;`
   - • (U+2022) instead of `&bull;`
5. Use `<br>` for line breaks, not `<p>` margins (Outlook adds unpredictable spacing).
6. Set widths fluidly: use `width="100%"` attribute on the inner table AND `style="width:100%;max-width:680px"` so the card fills small viewports and caps at 680px on wide ones. **Do NOT use a fixed pixel width** — fixed widths cause content to be clipped in narrow Outlook reading panes.
7. For embedded images: always include `style="max-width:100%;height:auto;display:block;"`. Avoid hard-coded `width=` / `height=` attributes that exceed the card width.

## Workflow

### 1. Gather Requirements
Ask user (one at a time):
- Announcement or how-to?
- Key links/pipeline IDs?
- Screenshots to attach?
- Recipients (or leave for user to fill)?

### 2. Build the HTML Body
Write to `/tmp/mail_body.html` first, then pass as `body` param. The body can be large (~30KB works fine).

**Template skeleton** (copy-paste, then customize):

```html
<!DOCTYPE html>
<html><body style="margin:0;padding:0;background:#f5f6f8;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,sans-serif;">
<table role="presentation" cellpadding="0" cellspacing="0" border="0" width="100%" style="background:#f5f6f8;padding:32px 0;">
  <tr><td align="center">
    <table role="presentation" cellpadding="0" cellspacing="0" border="0" width="100%" style="width:100%;max-width:680px;background:#ffffff;border-radius:12px;box-shadow:0 2px 8px rgba(15,23,42,0.08);overflow:hidden;">
      <!-- HERO -->
      <tr><td style="background:#1e3a8a;padding:32px 40px;color:#ffffff;">
        <div style="font-size:13px;letter-spacing:2px;text-transform:uppercase;opacity:0.85;">🚀 Announcement</div>
        <h1 style="margin:8px 0 0 0;font-size:26px;font-weight:600;color:#ffffff;">TITLE HERE</h1>
      </td></tr>
      <!-- BODY -->
      <tr><td style="padding:40px;color:#334155;font-size:16px;line-height:1.6;">
        <p>Hi team,</p>
        <p>BODY CONTENT</p>
        <!-- Before/After cards, checklists, code blocks, etc. -->
        <p style="margin-top:32px;color:#64748b;font-size:14px;">🤖 — Identity Security Platform Axon</p>
      </td></tr>
    </table>
  </td></tr>
</table>
</body></html>
```

### 3. Create the Draft
```
mail-CreateDraftMessage
  subject: "🚀 ..."
  body: <full HTML>
  contentType: "HTML"
  to: [] (or leave empty for user)
```
Save returned `messageId`.

### 4. Attach Screenshots (if any)
Resize large PNGs first — Outlook hates huge embeds:
```bash
sips -Z 1000 "/path/to/screenshot.png" --out /tmp/shot.png
base64 -i /tmp/shot.png | tr -d '\n' > /tmp/shot.b64
```
Then:
```
mail-UploadAttachment
  messageId: <id>
  fileName: "screenshot.png"
  contentBase64: <content of /tmp/shot.b64>
  contentType: "image/png"
```

### 5. Verify
```
mail-GetMessage  id: <messageId>  bodyPreviewOnly: true
```
Check preview renders cleanly (no `&check;`, no broken entities).

## Debugging: `&check;` Rendering as Literal Text

**Symptom:** User screenshot shows `&check;` text instead of ✓ in Outlook.

**Root cause:** When `mail-UpdateDraft` receives `&check;`, Graph double-escapes it to `&amp;check;` which Outlook displays verbatim.

**Fix:**
1. Fetch current body: `mail-GetMessage` with `preferHtml: true` (large — may exceed 50KB, saved to temp file)
2. Parse: body is at `data.body` as a string (NOT `data.body.content`). Strip trailing `CorrelationId:` line.
3. Replace `&amp;check;` (and `&check;`) → `✓` (Unicode literal)
4. Push back with `mail-UpdateDraft` — full body as `body` param.

## Iterative Refinement Tips

User will say "still ugly", "make it better", "more white", "revert". Patterns observed:

- **"more white"** = lighter palette, more padding, reduce saturation of accent cards
- **"revert"** = go back to the previous iteration, don't just re-tweak
- **"still ugly"** = the palette/structure is wrong, try a new approach (don't just add decoration)
- **When approved**, capture the exact HTML as a template and resist re-designing — just update text content

If user sends a screenshot showing current state, inspect it carefully for:
- Broken entities (→ fix per §Debugging)
- Cramped spacing (→ increase `padding`)
- Gray-on-gray contrast issues (→ bump text color to `#0f172a`)

## Related Tools

- `mail-CreateDraftMessage` — initial creation
- `mail-UpdateDraft` — update body/subject/recipients
- `mail-UploadAttachment` — attach files < 3MB
- `mail-GetMessage` — verify draft state
- `mail-SendDraftMessage` — send when user approves

## Important Notes

- **Never send** without explicit user confirmation. Always leave as draft.
- **Recipients:** leave `to: []` empty unless user specifies. Let them fill in Outlook.
- **Don't commit** email HTML to the repo — it's ephemeral content.
- **Screenshots:** resize to 1000px width max before attaching.
- The user values iteration — expect 3-5 rounds of refinement on visual design before approval.
