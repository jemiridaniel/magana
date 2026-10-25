import type { NextConfig } from "next";

// The website at https://magana.ng: static files only (Caddy serves out/; deploy/Caddyfile).
// No cookies, analytics or trackers, and no API calls.
const nextConfig: NextConfig = {
  output: "export",
  trailingSlash: true,
  images: { unoptimized: true },
  reactCompiler: true,
  poweredByHeader: false,
  // CSS inline in the HTML: an external stylesheet blocks the first paint, which held the page
  // loader back by 2–10 s on Slow 3G (docs/FINDINGS.md).
  experimental: { inlineCss: true },
};

export default nextConfig;
