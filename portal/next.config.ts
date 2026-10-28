import type { NextConfig } from "next";

// PORTAL_EXPORT=1 builds static files for Cloudflare Pages, served at the root of
// https://teachers.<domain>/ (CI); PORTAL_BASE_PATH puts them under
// a path instead. Without either, the usual `next dev` / `next start`.
const basePath = process.env.PORTAL_BASE_PATH ?? "";
const exported = process.env.PORTAL_EXPORT === "1" || basePath !== "";

const nextConfig: NextConfig = exported
  ? {
      output: "export",
      ...(basePath ? { basePath } : {}),
      trailingSlash: true,
      images: { unoptimized: true },
      env: { NEXT_PUBLIC_BASE_PATH: basePath },
      reactCompiler: true,
    }
  : {
      // The same app as the static export (no server components to cache: every page is a
      // client page that calls the API).
      reactCompiler: true,
    };

export default nextConfig;
