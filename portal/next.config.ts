import type { NextConfig } from "next";

// PORTAL_BASE_PATH=/teachers builds static files for the Caddy on the server
// (scripts/deploy-portal.sh); without it, the usual `next dev` / `next start`.
const basePath = process.env.PORTAL_BASE_PATH ?? "";

const nextConfig: NextConfig = basePath
  ? {
      output: "export",
      basePath,
      trailingSlash: true,
      images: { unoptimized: true },
      env: { NEXT_PUBLIC_BASE_PATH: basePath },
      reactCompiler: true,
    }
  : {
      cacheComponents: true,
      partialPrefetching: true,
      reactCompiler: true,
    };

export default nextConfig;
