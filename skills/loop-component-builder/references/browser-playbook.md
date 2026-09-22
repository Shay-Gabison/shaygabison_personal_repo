# Sub-Minute Loop Browser Playbook

Fast mode creates a real Loop page with complete, visibly structured plain text.
It intentionally avoids Loop's dynamic `/` insert menu and avoids reload.

## Consolidated Fast Script

Prepare `bodyText` before invoking the script:

- Checklist: `☐ Item`
- Bullets: `• Item`
- Numbered list: `1. Item`
- Table: tab-separated rows

```js
async (page) => {
  const startedAt = Date.now();
  const title = "Example title";
  const bodyText = [
    "☐ First item",
    "☐ Second item",
    "☐ Last item",
  ].join("\n");
  const firstExpected = "First item";
  const lastExpected = "Last item";

  if (/login|signin/i.test(page.url())) {
    return { needsSignIn: true };
  }

  const myWorkspace = page.getByRole("tab", { name: "My workspace" });
  if (await myWorkspace.isVisible().catch(() => false)) {
    await myWorkspace.click();
  }

  await page.getByTestId("WorkspaceNavigationViewAddPageButton").click();
  await page.getByTestId("AddPageButtonMenuNewPage").click();

  const titleBox = page.getByRole("textbox", { name: "Title" });
  await titleBox.waitFor({ state: "visible", timeout: 8000 });
  await titleBox.click();
  await page.keyboard.press("Meta+A");
  await titleBox.pressSequentially(title, { delay: 3 });

  const canvas = page.getByRole("textbox", { name: "Canvas" });
  await canvas.click();
  await canvas.pressSequentially(bodyText, { delay: 1 });

  await page.waitForTimeout(1800);

  const savedTitle = await titleBox.innerText();
  const savedBody = await canvas.innerText();

  if (
    savedTitle !== title ||
    !savedBody.includes(firstExpected) ||
    !savedBody.includes(lastExpected)
  ) {
    throw new Error("Loop verification failed");
  }

  return {
    title: savedTitle,
    url: page.url(),
    itemCount: bodyText.split("\n").length,
    elapsedMs: Date.now() - startedAt,
  };
}
```

Do not verify the title with `page.title()`. Loop's browser tab title can lag
behind the saved page title.

## Semantic Mode

Use semantic mode only when the user explicitly requires native Loop controls.
It may exceed one minute.

1. Click the Canvas.
2. Clear partial content.
3. Type `/` through a direct sequential browser typing operation.
4. Locate and select Checklist, Table, or another native block.
5. Populate and verify semantic roles.

Never open **Share** or **Copy as Loop component** just to obtain a URL.

