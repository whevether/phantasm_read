# EPUB browser regression test

This test generates a real EPUB ZIP and runs the embedded EPUB.js shell in a temporary headless Chrome context. It checks nested TOC, spine search, asynchronous replies, script isolation, chapter/anchor preview clipping, flow switching and font reset. It uses no account data or installed browser profile.

Install the test tool outside the repository, then run from the repository root:

```sh
npm install --prefix /tmp/phantasm-epub-test --no-audit --no-fund playwright-core
CHROME_PATH='/Applications/Google Chrome.app/Contents/MacOS/Google Chrome' \
  NODE_PATH=/tmp/phantasm-epub-test/node_modules node test/js/epub_shell_test.cjs
```

Set `CHROME_PATH` to your local Chrome/Chromium executable. Alternatively, install the browser expected by Playwright and omit `CHROME_PATH`.

The Dart regression tests run with `flutter test`; they do not need Node or Chrome. Printing and audio platform seams are faked in unit tests. Native rendering and platform plugin behavior still require device testing.
