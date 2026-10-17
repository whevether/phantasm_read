// Run with playwright-core available on NODE_PATH and CHROME_PATH if needed.
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const http = require("node:http");
const { chromium } = require("playwright-core");
const JSZip = require("../../assets/epubjs/jszip.min.js");

async function fixture() {
  const zip = new JSZip();
  zip.file("mimetype", "application/epub+zip");
  zip.file(
    "META-INF/container.xml",
    '<?xml version="1.0"?><container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container"><rootfiles><rootfile full-path="OEBPS/content.opf" media-type="application/oebps-package+xml"/></rootfiles></container>',
  );
  zip.file(
    "OEBPS/content.opf",
    `<?xml version="1.0"?><package xmlns="http://www.idpf.org/2007/opf" version="3.0" unique-identifier="id"><metadata xmlns:dc="http://purl.org/dc/elements/1.1/"><dc:identifier id="id">audit</dc:identifier><dc:title>Fixture</dc:title><dc:language>en</dc:language><meta property="dcterms:modified">2026-10-17T00:00:00Z</meta></metadata><manifest><item id="nav" href="nav.xhtml" media-type="application/xhtml+xml" properties="nav"/>${[1, 2, 3].map((i) => `<item id="c${i}" href="c${i}.xhtml" media-type="application/xhtml+xml"/>`).join("")}</manifest><spine>${[1, 2, 3].map((i) => `<itemref idref="c${i}"/>`).join("")}</spine></package>`,
  );
  zip.file(
    "OEBPS/nav.xhtml",
    '<?xml version="1.0"?><html xmlns="http://www.w3.org/1999/xhtml" xmlns:epub="http://www.idpf.org/2007/ops"><head><title>Contents</title></head><body><nav epub:type="toc"><ol><li><a href="c1.xhtml#head">Chapter one</a><ol><li><a href="c1.xhtml#sub">Subchapter</a></li></ol></li><li><a href="c2.xhtml#head">Chapter two</a></li><li><a href="c3.xhtml#head">Chapter three</a></li></ol></nav></body></html>',
  );
  for (const i of [1, 2, 3])
    zip.file(
      `OEBPS/c${i}.xhtml`,
      `<?xml version="1.0"?><html xmlns="http://www.w3.org/1999/xhtml"><head><title>Chapter ${i}</title></head><body><h1 id="head">Chapter ${i}</h1><p>needle${i} body text</p>${i === 1 ? Array.from({ length: 40 }, (_, j) => `<p>first chapter paragraph ${j}</p>`).join("") + '<h2 id="sub">Subchapter</h2><p>subsecret hidden outside first chapter window</p>' : ""}${Array.from({ length: 25 }, (_, j) => `<p>line ${j} chapter ${i} for pagination.</p>`).join("")}<script>window.__untrustedBookScript=true;</script></body></html>`,
    );
  return zip.generateAsync({ type: "base64" });
}
(async () => {
  const root = path.resolve(__dirname, "../../assets/epubjs");
  const server = http.createServer((req, res) => {
    const filename = path.join(
      root,
      path.basename(new URL(req.url, "http://localhost").pathname),
    );
    if (!fs.existsSync(filename)) {
      res.writeHead(404);
      res.end();
      return;
    }
    res.setHeader(
      "Content-Type",
      filename.endsWith(".html") ? "text/html" : "application/javascript",
    );
    res.end(fs.readFileSync(filename));
  });
  await new Promise((resolve) => server.listen(0, "127.0.0.1", resolve));
  const browser = await chromium.launch({
    headless: true,
    executablePath: process.env.CHROME_PATH,
  });
  try {
    const page = await browser.newPage({
      viewport: { width: 600, height: 600 },
    });
    const errors = [];
    page.on("pageerror", (error) => errors.push(String(error)));
    await page.addInitScript(() => {
      window.messages = [];
      window.EpubChannel = {
        postMessage: (m) => window.messages.push(JSON.parse(m)),
      };
    });
    await page.goto(`http://127.0.0.1:${server.address().port}/reader.html`);
    await page.waitForFunction(() => window.epubBridge);
    const base64 = await fixture();
    await page.evaluate(
      (b) => window.epubBridge.openFromBase64(b, "paginated", null, null, null),
      base64,
    );
    assert.equal(
      (await page.evaluate(() => window.epubBridge.getToc())).length,
      3,
    );
    assert.equal(
      (await page.evaluate(() => window.epubBridge.search("needle2"))).length,
      1,
    );
    await page.evaluate(() => window.epubBridge.display("c1.xhtml#sub"));
    await page.waitForFunction(() =>
      window.messages.some(
        (m) => m.type === "locationChanged" && m.payload.chapterIndex === 1,
      ),
    );
    await page.evaluate(() =>
      window.epubBridge.request(100, "getLocation", []),
    );
    await page.waitForFunction(() =>
      window.messages.some(
        (m) => m.type === "response" && m.payload.id === 100,
      ),
    );
    assert.ok(
      await page.evaluate(
        () =>
          window.messages.find(
            (m) => m.type === "response" && m.payload.id === 100,
          ).payload.result.cfi,
      ),
    );
    assert.equal(
      await page.frames()[1].evaluate(() => window.__untrustedBookScript),
      undefined,
    );
    await page.evaluate(
      (b) => window.epubBridge.openFromBase64(b, "paginated", 0, 1, null),
      base64,
    );
    assert.equal(
      (await page.evaluate(() => window.epubBridge.search("needle2"))).length,
      0,
    );
    assert.equal(
      (await page.evaluate(() => window.epubBridge.search("subsecret"))).length,
      0,
    );
    const text = await page.evaluate(() => window.epubBridge.getText());
    assert.ok(text.includes("needle1"));
    assert.ok(!text.includes("subsecret"));
    await page.evaluate(() => window.epubBridge.display("c2.xhtml#head"));
    assert.ok(
      await page.evaluate(() =>
        window.messages.some((m) => m.type === "trialBoundary"),
      ),
    );
    await page.evaluate(() => window.epubBridge.setFlow("scrolled"));
    assert.ok(
      !(await page.evaluate(() => window.epubBridge.getText())).includes(
        "subsecret",
      ),
    );
    await page.evaluate(() => window.epubBridge.setFontFamily(null));
    await page.evaluate(() => window.epubBridge.close());
    assert.deepEqual(errors, []);
    console.log(
      "EPUB browser tests passed: real ZIP parsing, nested TOC, search, async replies, script isolation, chapter/anchor trial clipping, flow and font reset.",
    );
  } finally {
    await browser.close();
    await new Promise((resolve) => server.close(resolve));
  }
})().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
