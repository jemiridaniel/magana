import type { Metadata } from "next";
import { Atkinson_Hyperlegible } from "next/font/google";
import ServerBanner from "@/components/ServerBanner";
import Sidebar from "@/components/Sidebar";
import "./globals.css";

const atkinson = Atkinson_Hyperlegible({
  weight: ["400", "700"],
  subsets: ["latin", "latin-ext"],
  variable: "--font-atkinson",
});

export const metadata: Metadata = {
  title: { default: "Magana for Teachers", template: "%s · Magana for Teachers" },
  description: "Make class materials accessible and keep the register for blind and low-vision learners.",
};

export default function RootLayout({ children }: Readonly<{ children: React.ReactNode }>) {
  return (
    <html lang="en-NG" className={atkinson.variable}>
      <body>
        <a className="skip-link" href="#main">Skip to main content</a>
        <div className="shell">
          <Sidebar />
          <main id="main" className="main" tabIndex={-1}>
            <ServerBanner />
            <div className="content">{children}</div>
          </main>
        </div>
      </body>
    </html>
  );
}
