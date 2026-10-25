// Time the page loader on Chrome's "Slow 3G" preset (2,000 ms latency, 400 kbit/s down and up),
// cold cache, 3 runs each at phone and desktop size. Prints when the loader first paints, when
// the page is ready, how long the loader was on screen, and whether "Slow connection" showed.
//   node scripts/slow3g.mjs [https://magana.ng/]
import { chromium } from "playwright";

const url = process.argv[2] ?? "https://magana.ng/";
const b = await chromium.launch({ channel: "chrome" });
for (const [label, w, h] of [["phone", 390, 844], ["desktop", 1280, 900]]) {
  for (let run = 1; run <= 3; run++) {
    const ctx = await b.newContext({ viewport: { width: w, height: h } });
    const p = await ctx.newPage();
    const cdp = await ctx.newCDPSession(p);
    await cdp.send("Network.enable");
    await cdp.send("Network.setCacheDisabled", { cacheDisabled: true });
    await cdp.send("Network.emulateNetworkConditions", { offline: false, latency: 2000, downloadThroughput: 50000, uploadThroughput: 50000 });
    const t0 = Date.now();
    await p.goto(url, { waitUntil: "commit", timeout: 120000 });
    let firstByte = Date.now() - t0;
    while (Date.now() - t0 < 90000) {
      const gone = await p.evaluate(() => document.getElementById("mg-loader")?.hidden).catch(() => false);
      if (gone) break;
      await p.waitForTimeout(100);
    }
    const r = await p.evaluate(() => ({
      fcp: Math.round(performance.getEntriesByName("first-contentful-paint")[0]?.startTime ?? -1),
      ttfb: Math.round(performance.getEntriesByType("navigation")[0]?.responseStart ?? -1),
      info: window.__mgLoader,
    }));
    console.log(JSON.stringify({ label, run, firstByteMs: r.ttfb, loaderPaintMs: r.fcp, paintAfterFirstByteMs: r.fcp - r.ttfb,
      pageReadyMs: Date.now() - t0, loaderOnScreenMs: r.info?.shownMs, slowMessage: !!r.info?.slow, commitMs: firstByte }));
    await ctx.close();
  }
}
await b.close();
