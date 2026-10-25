// Quizzes in the teacher portal, against a real backend: the design's rules (64 px targets,
// 7:1 contrast through axe's AAA rules), the "Before you assign" checks, saving, assigning,
// and the quiz reaching the learner app's endpoint for that class level.
import { expect, test, type Page } from "@playwright/test";
import { apiUrl } from "../playwright.config";
import { addClass, designChecks, newSchool } from "./helpers";

let primary5 = "";

test.beforeEach(async ({ page }) => {
  await newSchool(page);
  primary5 = (await addClass(page, "Primary 5", "p5", "classroom")).id;
  await addClass(page, "SS2 Science", "sss2", "guided");
});

/** The editor works once React has hydrated it; "Listen as a learner" only appears then. */
async function openEditor(page: Page) {
  await page.goto("/quizzes/new");
  await page.getByRole("button", { name: "Listen as a learner" }).waitFor();
}

// The learner app inside a class session the teacher opened with [code].
async function sessionQuizzes(page: Page, code: string) {
  const r = await page.request.get(`${apiUrl}/learner/quizzes?session_code=${code}`, {
    headers: { "X-Magana-Tier": "classroom", "X-Magana-Teacher-Session": "yes" },
  });
  expect(r.ok()).toBeTruthy();
  return (await r.json()).quizzes as { title: string; questions: { question: string; translations: Record<string, string>; picture: string | null }[] }[];
}

test("the sidebar starts with the Magana mark and has Quizzes after My classes", async ({ page }) => {
  await page.goto("/quizzes/new");
  const home = page.getByRole("link", { name: "Magana for Teachers, Home" });
  await expect(home).toHaveAttribute("href", "/");
  await expect(home.locator("img")).toHaveAttribute("alt", ""); // decorative
  await expect(home.locator("img")).toHaveAttribute("src", "/brand/magana_mark_on_ink.svg");
  const nav = page.getByRole("navigation", { name: "Main" }).getByRole("link");
  await expect(nav).toHaveText(["Home", "Uploads", "My classes", "Quizzes", "Attendance", "Learner progress", "Consent records",
    "Teachers", "School details", "Help"]);
  await expect(page.getByRole("link", { name: "Quizzes", exact: true })).toHaveAttribute("aria-current", "page");
  await expect(page).toHaveTitle("Create a quiz · Magana for Teachers");
  // Our icons, not Next.js's.
  await expect(page.locator('link[rel="icon"][type="image/svg+xml"]')).toHaveCount(1);
  await expect(page.locator('link[rel="apple-touch-icon"]')).toHaveCount(1);
  const ico = await page.request.get("/favicon.ico");
  expect((await ico.body()).length).toBeGreaterThan(1000);
});

test("create, check and assign a Primary 5 quiz; it reaches learners at that level", async ({ page }, info) => {
  const title = `Parts of a plant (${info.project.name})`;
  await page.addInitScript(() => {
    (window as unknown as { __said: { text: string; rate: number }[] }).__said = [];
    window.speechSynthesis.speak = (u: SpeechSynthesisUtterance) => {
      (window as unknown as { __said: { text: string; rate: number }[] }).__said.push({ text: u.text, rate: u.rate });
    };
  });
  await openEditor(page);
  await page.getByLabel("Quiz title").fill(title);
  await page.getByLabel("Class", { exact: true }).selectOption({ label: "Primary 5" });
  await expect(page.getByLabel("Class", { exact: true })).toHaveValue(primary5);
  await page.getByLabel("Subject").selectOption({ label: "Basic Science" });
  await page.getByLabel("Questions read in").selectOption({ label: "Yorùbá and English" });
  await expect(page.getByText("2 or 3 options", { exact: true })).toBeVisible();
  await expect(page.getByText("Primary 5 is a Classroom mode class (under 13).")).toBeVisible();

  await page.getByLabel("Question", { exact: true }).fill("Which part of a plant makes food for the plant?");
  await expect(page.getByText("15 words or fewer for primary classes. This one has 10.")).toBeVisible();
  await page.getByLabel("Option A", { exact: true }).last().fill("The leaf");
  await page.getByLabel("Option B", { exact: true }).last().fill("The root");
  await page.getByRole("button", { name: "+ Add option" }).click();
  await page.getByLabel("Option C", { exact: true }).last().fill("The flower");
  await expect(page.getByRole("button", { name: "+ Add option · 3 is the most for Primary 5" })).toBeDisabled();
  await page.getByLabel("Yorùbá version").fill("Apá wo nínú ewéko ló ń ṣe oúnjẹ fún ewéko náà?");
  await expect(page.getByText("Not yet checked", { exact: true })).toBeVisible();
  await page.getByLabel("Say this after a right answer").fill("Well done! Leaves make food using sunlight.");

  // No right answer yet: assigning is blocked, and focus goes to the checks.
  await expect(page.getByText("Blocks assigning: No right answer marked in question 1")).toBeVisible();
  await page.getByRole("button", { name: "Assign to class" }).click();
  await expect(page.getByRole("status").first()).toHaveText("Fix the problems in “Before you assign” first.");
  await expect(page.getByRole("heading", { name: "Before you assign" })).toBeFocused();

  await page.getByRole("button", { name: "Mark as right: option A" }).click();
  await expect(page.getByText("Right answer", { exact: true })).toBeVisible();
  await expect(page.getByText("Every question has one right answer")).toBeVisible();
  await expect(page.getByText("Yorùbá version of question 1 not yet checked")).toBeVisible();

  // A picture must be described before assigning.
  await page.getByRole("button", { name: "+ Add question 2" }).click();
  await expect(page.getByRole("heading", { name: "2 · Question 2 of 2" })).toBeFocused();
  await page.getByLabel("Question", { exact: true }).fill("What is in the picture?");
  await page.getByLabel("Option A", { exact: true }).last().fill("A seed");
  await page.getByLabel("Option B", { exact: true }).last().fill("A stone");
  await page.getByRole("button", { name: "Mark as right: option A" }).click();
  await page.getByLabel("Picture or diagram?").setInputFiles({ name: "seed.png", mimeType: "image/png", buffer: Buffer.from("89504e47", "hex") });
  await expect(page.getByText("Blocks assigning: Describe the picture in question 2")).toBeVisible();
  await designChecks(page);
  await page.getByLabel("Describe the picture in words (required)").fill("A brown bean seed, about the size of a fingernail.");

  // Listen as a learner: the app's words, slower for a primary class.
  await page.getByRole("button", { name: "Listen as a learner" }).click();
  const said = await page.evaluate(() => (window as unknown as { __said: { text: string; rate: number }[] }).__said);
  expect(said.at(-1)!.text).toBe(
    "Question 2 of 2 What is in the picture? Picture: A brown bean seed, about the size of a fingernail. A, A seed. B, A stone. Say A or B",
  );
  expect(said.at(-1)!.rate).toBeCloseTo(0.8);

  // The questions list: Ready and Editing.
  const list = page.getByRole("list").filter({ hasText: "Which part of a plant" });
  await expect(list.getByRole("button").nth(0)).toContainText("Ready");
  await expect(list.getByRole("button").nth(1)).toContainText("Editing");

  await page.getByLabel("Class session (date)").fill("2026-10-30");
  await page.getByRole("button", { name: "Assign to class" }).click();
  await expect(page.getByRole("status").first()).toHaveText(/^Assigned to Primary 5 for Fri 30 Oct 2026\. Session code: \d{6}\.$/);
  const code = (await page.locator(".session-code").textContent())!;

  // Only that session's code opens it in the learner app. The translation isn't checked
  // yet, so learners hear English.
  const mine = (await sessionQuizzes(page, code)).find((q) => q.title === title)!;
  expect(mine.questions[0].translations).toEqual({});
  expect(mine.questions[1].picture).toBe("A brown bean seed, about the size of a fingernail.");
  expect(await sessionQuizzes(page, code === "730913" ? "815204" : "730913")).toEqual([]);
  const alone = await page.request.get(`${apiUrl}/learner/quizzes?session_code=${code}`, {
    headers: { "X-Magana-Tier": "standard" },
  });
  expect(alone.status()).toBe(403); // a learner on their own: sample packs only

  // A Yorùbá-speaking teacher checks the translation: learners now get it.
  await page.getByRole("button", { name: /^1 Which part of a plant/ }).click();
  await page.getByLabel("A Yorùbá-speaking teacher checked it").check();
  await page.getByRole("button", { name: "Save draft" }).click();
  await expect(page.getByRole("status").first()).toHaveText("Draft saved.");
  const checked = (await sessionQuizzes(page, code)).find((q) => q.title === title)!;
  expect(checked.questions[0].translations).toEqual({ yo: "Apá wo nínú ewéko ló ń ṣe oúnjẹ fún ewéko náà?" });

  // All quizzes lists it; Edit opens it again.
  await page.getByRole("link", { name: "‹ All quizzes" }).click();
  await expect(page).toHaveTitle("All quizzes · Magana for Teachers");
  const row = page.getByRole("row").filter({ hasText: title });
  await expect(row).toContainText(`Assigned · Fri 30 Oct 2026 · code ${code}`);
  await designChecks(page);
  await row.getByRole("link", { name: `Edit ${title}` }).click();
  await expect(page.getByRole("heading", { name: "Edit quiz" })).toBeVisible();
  await expect(page.getByLabel("Quiz title")).toHaveValue(title);
});

test("a JSS class allows four options and needs no primary note", async ({ page }) => {
  await openEditor(page);
  await page.getByLabel("Class", { exact: true }).selectOption({ label: "SS2 Science" });
  await expect(page.getByText("2 to 4 options", { exact: true })).toBeVisible();
  await expect(page.getByText("Classroom mode class")).toHaveCount(0);
  await expect(page.getByLabel("Subject")).toContainText("Biology");
  for (let i = 0; i < 2; i++) await page.getByRole("button", { name: "+ Add option" }).click();
  await expect(page.getByRole("button", { name: "+ Add option · 4 is the most for SS2 Science" })).toBeDisabled();
});

test("Help links to the learner app's install instructions", async ({ page }) => {
  await page.goto("/help");
  await page.getByRole("button", { name: /Installing the learner app/ }).click().catch(() => undefined);
  await page.getByRole("link", { name: "Open the install instructions" }).click();
  await expect(page).toHaveTitle("Install the learner app · Magana for Teachers");
  await expect(page.getByRole("heading", { name: "On an iPhone (the web version, for testing)" })).toBeVisible();
  await designChecks(page);
});

for (const path of ["/quizzes", "/uploads", "/classes", "/help"]) {
  test(`design checks: ${path}`, async ({ page }) => {
    await page.goto(path);
    await designChecks(page);
  });
}
