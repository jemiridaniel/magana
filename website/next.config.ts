import type { NextConfig } from "next";

// The website at https://magana.ng: static files only (Caddy serves out/; deploy/Caddyfile).
// No cookies, analytics or trackers, and no API calls.
const nextConfig: NextConfig = {
  output: "export",
  trailingSlash: true,
  images: { unoptimized: true },
  reactCompiler: true,
  poweredByHeader: false,
};

export default nextConfig;
