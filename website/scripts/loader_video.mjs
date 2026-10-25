// Record the page loader on video and print when each dot appeared, on a normal connection
// and on Chrome's "Slow 3G" preset (2,000 ms latency, 400 kbit/s), cold cache, first visit in a
// fresh session, then a refresh.
//   node scripts/loader_video.mjs [https://magana.ng/] [out folder]
import { chromium } from "playwright";
import fs from "node:fs";
import path from "node:path";

const url = process.argv[2] ?? "https://magana.ng/";
const out = process.argv[3] ?? "loader-videos";
fs.mkdirSync(out, { recursive: true });
const browser = await chromium.launch({ channel: "chrome" });
const results = [];

for (const network of ["normal", "slow3g"]) {
  const ctx = await browser.newContext({ viewport: { width: 1280, height: 800 }, recordVideo: { dir: out, size: { width: 1280, height: 800 } } });
  const page = await ctx.newPage();
  const cdp = await ctx.newCDPSession(page);
  await cdp.send("Network.enable");
  await cdp.send("Network.setCacheDisabled", { cacheDisabled: true });
  if (network === "slow3g") {
    await cdp.send("Network.emulateNetworkConditions", { offline: false, latency: 2000, downloadThroughput: 50000, uploadThroughput: 50000 });
  }
  for (const visit of ["first", "refresh"]) {
    const start = Date.now();
    if (visit === "first") await page.goto(url, { waitUntil: "commit", timeout: 120000 });
    else await page.reload({ waitUntil: "commit", timeout: 120000 });
    await page.waitForFunction(() => document.getElementById("mg-loader")?.hidden === true, null, { timeout: 90000 });
    const t = await page.evaluate(() => ({
      ...window.__mgLoader,
      paint: Math.round(performance.getEntriesByName("first-contentful-paint")[0]?.startTime ?? -1),
      scriptAt: Math.round(performance.timeOrigin ? 0 : 0),
    }));
    results.push({ network, visit, wallMs: Date.now() - start, ...t });
    if (network === "slow3g" && visit === "first") break;  // one Slow 3G visit is enough to watch
  }
  const video = page.video();
  await ctx.close();
  const file = path.join(out, `loader-${network}.webm`);
  fs.renameSync(await video.path(), file);
  console.log("video:", path.resolve(file));
}
await browser.close();

for (const r of results) {
  console.log(`\n${r.network}, ${r.visit} visit: loader painted at ${r.paint} ms; full at ${r.fullAt} ms after the loader's script ran;`
    + ` gone at ${r.shownMs} ms (+ fade); "Slow connection" shown: ${r.slow}`);
  console.log("  dot  ms   %");
  for (const [ms, dot, pct] of r.frames) console.log(`  ${String(dot).padStart(3)} ${String(ms).padStart(5)} ${String(pct).padStart(3)}`);
}
fs.writeFileSync(path.join(out, "frames.json"), JSON.stringify(results, null, 1));
