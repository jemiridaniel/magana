import type { Metadata, Viewport } from "next";
import { Footer, Header } from "@/components/Chrome";
import { LOADER_CSS, LOADER_HTML, LOADER_JS } from "@/components/loader";
import Ready from "@/components/Ready";
import "./globals.css";

export const metadata: Metadata = {
  metadataBase: new URL("https://magana.ng"),
  title: { default: "Magana: hear any printed page, in your language", template: "%s · Magana" },
  description:
    "Magana is a free app that reads printed pages aloud for blind and low-vision Nigerians: schoolwork, medicine labels, bank statements and letters, in English, Hausa, Yorùbá and Igbo.",
};

export const viewport: Viewport = { themeColor: "#0A6B4B", width: "device-width", initialScale: 1 };

export default function RootLayout({ children }: Readonly<{ children: React.ReactNode }>) {
  return (
    <html lang="en-NG">
      <head>
        <link rel="preload" href="/fonts/atkinson-hyperlegible-regular.woff2" as="font" type="font/woff2" crossOrigin="anonymous" />
        <link rel="preload" href="/fonts/atkinson-hyperlegible-bold.woff2" as="font" type="font/woff2" crossOrigin="anonymous" />
        <style dangerouslySetInnerHTML={{ __html: LOADER_CSS }} />
        <noscript><style>{"#mg-loader{display:none}"}</style></noscript>
      </head>
      <body>
        {/* The loader first, so it paints before anything else; React never touches its inside. */}
        <div dangerouslySetInnerHTML={{ __html: LOADER_HTML }} suppressHydrationWarning />
        <script dangerouslySetInnerHTML={{ __html: LOADER_JS }} />
        <a className="skip-link" href="#main">Skip to main content</a>
        <Header />
        <main id="main" tabIndex={-1}>{children}</main>
        <Footer />
        <Ready />
      </body>
    </html>
  );
}
