// Uploads and the Check screen against the real backend (uploads_api.py): a PDF goes up,
// only its text comes back, the teacher edits a line and approves. Both pages: axe (WCAG 2.2
// AA + AAA contrast) and the 64 px rule. Handwriting reaching "Check" is covered by
// backend/tests/test_uploads.py (it needs a handwritten page).
import { expect, test } from "@playwright/test";
import { designChecks, newSchool } from "./helpers";

/** A one-page PDF with a text layer, made here: no real document. */
function textPdf(lines: string[]): Buffer {
  const content = ["BT", "/F1 18 Tf", "72 760 Td", "24 TL", ...lines.map((l) => `(${l}) '`), "ET"].join("\n");
  const objects = [
    "<< /Type /Catalog /Pages 2 0 R >>",
    "<< /Type /Pages /Kids [3 0 R] /Count 1 >>",
    "<< /Type /Page /Parent 2 0 R /MediaBox [0 0 595 842] /Contents 4 0 R /Resources << /Font << /F1 5 0 R >> >> >>",
    `<< /Length ${content.length} >>\nstream\n${content}\nendstream`,
    "<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>",
  ];
  let pdf = "%PDF-1.4\n";
  const offsets: number[] = [];
  objects.forEach((o, i) => { offsets.push(pdf.length); pdf += `${i + 1} 0 obj\n${o}\nendobj\n`; });
  const xref = pdf.length;
  pdf += `xref\n0 ${objects.length + 1}\n0000000000 65535 f \n` + offsets.map((o) => `${String(o).padStart(10, "0")} 00000 n \n`).join("");
  pdf += `trailer\n<< /Size ${objects.length + 1} /Root 1 0 R >>\nstartxref\n${xref}\n%%EOF\n`;
  return Buffer.from(pdf, "latin1");
}

test("upload a PDF, see only its text, correct a line and approve; both pages pass the checks", async ({ page }) => {
  await newSchool(page);
  await page.goto("/uploads/");
  await expect(page.getByText("No uploads yet.")).toBeVisible();
  await designChecks(page);

  await page.getByRole("button", { name: "Upload" }).click();
  await expect(page.getByRole("status").filter({ hasText: "Choose a photo or PDF first." })).toBeVisible();

  await page.getByLabel("Title").fill("SS2 Biology notes");
  await page.getByLabel("Photo or PDF").setInputFiles({
    name: "notes.pdf", mimeType: "application/pdf",
    buffer: textPdf(["Photosynthesis", "Plants make food from light", "Read pages 12 to 15"]),
  });
  await page.getByRole("button", { name: "Upload" }).click();
  await expect(page.getByRole("status").filter({ hasText: "SS2 Biology notes:" })).toBeVisible();
  const row = page.getByRole("row").filter({ hasText: "SS2 Biology notes" });
  await expect(row).toContainText("Ready");
  await designChecks(page);

  // Home lists it under "Needs your attention" as ready to share.
  await page.goto("/");
  await expect(page.getByText("SS2 Biology notes is ready")).toBeVisible();
  await expect(page.getByRole("link", { name: /^Open.*SS2 Biology notes/ })).toHaveAttribute("href", /\/uploads\/check\/?\?id=/);
  await designChecks(page);
  await page.goto("/uploads/");
  await row.getByRole("link", { name: /View text/ }).click();
  await expect(page.getByRole("heading", { level: 1, name: "SS2 Biology notes" })).toBeVisible();
  await expect(page.getByLabel(/^Line 3/)).toHaveValue("Read pages 12 to 15");
  await designChecks(page);

  await page.getByLabel(/^Line 3/).fill("Read pages 12 to 16");
  await page.getByRole("button", { name: "Save changes" }).click();
  await expect(page.getByRole("status").filter({ hasText: "Approved. Learners can now use this text." })).toBeVisible();
  await expect(page.getByText("Corrected")).toBeVisible();
  await page.reload();
  await expect(page.getByLabel(/^Line 3/)).toHaveValue("Read pages 12 to 16");
});
