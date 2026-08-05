# vendor/ — bundled dependencies (so no external download is needed on locked-down machines)

- `node_modules/playwright-core` — tiny, pure-JS Playwright driver. Uses the Chrome/Edge already
  installed on the machine (channel:'chrome' -> 'msedge'); it never downloads a browser.

`setup.py` copies this into `<work>/node_modules` if `npm i playwright-core` is unavailable/blocked.
