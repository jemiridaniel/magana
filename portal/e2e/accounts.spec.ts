// Accounts and the new portal screens against a real backend (design canvas: Sign in, Enter
// sign-in code, Register your school, Teachers, Home, Learner remove from class, My classes):
// axe (WCAG 2.2 AA + AAA contrast), 64 px targets, the dialog's focus, the LGA combobox.
import AxeBuilder from "@axe-core/playwright";
import { expect, test } from "@playwright/test";
import { apiUrl } from "../playwright.config";
import { addClass, approve, designChecks, emailedCode, joinOnPhone, newSchool, registerSchool, signIn, uniqueEmail } from "./helpers";

test("sign in: the email, then the code; a wrong code says so; both pages pass the checks", async ({ page }) => {
  const email = uniqueEmail("signin");
  await approve(await registerSchool(email));
  await page.goto("/sign-in/");
  await designChecks(page);
  await page.getByLabel("Email address").fill(email);
  await page.getByRole("button", { name: "Send me a code" }).click();
  await expect(page.getByRole("heading", { name: "Check your email" })).toBeFocused();
  await expect(page.getByText(/ask for a new code in \d+ s/)).toBeVisible();
  await designChecks(page);
  const right = await emailedCode(email);
  await page.getByLabel("Sign-in code").fill(right === "730913" ? "815204" : "730913");
  await page.getByRole("button", { name: "Sign in" }).click();
  await expect(page.locator(".form-error")).toHaveText(/That code isn’t right/);
  await page.getByLabel("Sign-in code").fill(right);
  await page.getByRole("button", { name: "Sign in" }).click();
  await expect(page.getByRole("heading", { level: 1 })).toContainText("Mrs Folake Adebayo");
});

test("signed out: every portal page goes to sign in", async ({ page }) => {
  await page.goto("/classes/");
  await expect(page).toHaveURL(/\/sign-in\/?$/);
});

test("register your school: state select, LGA combobox by keyboard, then pending until approved", async ({ page }) => {
  await page.goto("/register/");
  await page.getByLabel("Your full name").fill("Mr Chinedu Okafor");
  await page.getByLabel("Your email").fill(uniqueEmail("register"));
  await page.getByLabel("Your phone number").fill("0803 000 0002");
  await page.getByLabel("School name").fill("Surulere Grammar School");
  await page.getByLabel("State").selectOption({ label: "Lagos" });
  const lga = page.getByRole("combobox", { name: "Local government area" });
  await lga.fill("Ik");
  await expect(lga).toHaveAttribute("aria-expanded", "true");
  await expect(page.getByRole("listbox").getByRole("option")).toHaveText(["Ikeja", "Ikorodu"]);
  await expect(page.locator("[aria-live=polite]").filter({ hasText: "LGAs" })).toHaveText("2 of Lagos’s 20 LGAs");
  await designChecks(page);
  await lga.press("ArrowDown");
  await lga.press("ArrowDown");
  await expect(lga).toHaveAttribute("aria-activedescendant", /opt-1$/);
  await lga.press("Enter");
  await expect(lga).toHaveValue("Ikorodu");
  await expect(lga).toHaveAttribute("aria-expanded", "false");
  await page.getByRole("button", { name: "Register school" }).click();
  await expect(page.locator(".form-error")).toHaveText(/Tick the box/);
  await page.getByLabel(/I confirm I lead this school/).check();
  await page.getByRole("button", { name: "Register school" }).click();
  await expect(page.getByRole("heading", { name: "Thank you" })).toBeFocused();
});

test("Home: an empty school reads well and passes the checks", async ({ page }) => {
  await newSchool(page);
  await expect(page.getByRole("heading", { name: "Quick actions" })).toBeVisible();
  await expect(page.getByText("No classes yet.")).toBeVisible();
  await expect(page.getByText("No figures yet this week.")).toBeVisible();
  await expect(page.getByText("Add a second school admin")).toBeVisible();
  await expect(page.getByText("School admin", { exact: true }).first()).toBeVisible();
  await designChecks(page);
  await page.getByRole("link", { name: "Magana for Teachers, Home" }).click();
  await expect(page).toHaveURL(/\/$/);
});

test("My classes: the class code, a learner joins, consent, and Remove from class in an accessible dialog", async ({ page }) => {
  await newSchool(page);
  const cls = await addClass(page, "SS2 Science", "sss2", "guided");
  await joinOnPhone(page, cls.code);
  await page.goto(`/classes/?class=${cls.id}`);
  await expect(page.getByText(`${cls.code.slice(0, 3)} ${cls.code.slice(3)}`)).toBeVisible();
  await expect(page.getByRole("cell", { name: "Waiting for consent" })).toBeVisible();
  await designChecks(page);

  // Home now shows the pending consent, built from real data.
  await page.goto("/");
  await expect(page.getByText("1 guardian hasn’t agreed yet")).toBeVisible();
  await designChecks(page);

  await page.goto(`/classes/?class=${cls.id}`);
  const open = page.getByRole("button", { name: "Remove from class: New learner" });
  await open.click();
  const dialog = page.getByRole("dialog", { name: "Remove New learner from SS2 Science?" });
  await expect(dialog).toBeVisible();
  for (let i = 0; i < 8; i++) {  // Tab stays inside the dialog
    await page.keyboard.press("Tab");
    expect(await page.evaluate(() => !!document.activeElement?.closest("dialog"))).toBe(true);
  }
  await designChecks(page);
  await page.keyboard.press("Escape");
  await expect(dialog).toBeHidden();
  await expect(open).toBeFocused();  // focus back on the button

  await open.click();
  await dialog.getByRole("button", { name: "Remove from class" }).click();
  await expect(dialog.getByRole("alert")).toHaveText("Choose a reason.");
  await dialog.getByLabel("Left the school or changed class").check();
  await dialog.getByRole("button", { name: "Remove from class" }).click();
  await expect(page.getByRole("status").filter({ hasText: "is removed from SS2 Science" })).toBeVisible();
  await expect(page.getByRole("cell", { name: "Removed" })).toBeVisible();
});

test("Learner page: details, record consent, move within the school; it passes the checks", async ({ page }) => {
  await newSchool(page);
  const a = await addClass(page, "SS2 Science", "sss2", "guided");
  await addClass(page, "SS2 Arts", "sss2", "guided");
  await joinOnPhone(page, a.code);
  await page.goto(`/classes/?class=${a.id}`);
  await page.getByRole("link", { name: "New learner" }).click();
  await expect(page.getByRole("heading", { name: "New learner", level: 1 })).toBeVisible();
  await expect(page.getByText(/Pending since/)).toBeVisible();
  await designChecks(page);
  await page.getByRole("button", { name: "Record consent" }).click();
  await page.getByRole("dialog").getByLabel("Signed the consent form").check();
  await page.getByRole("dialog").getByRole("button", { name: "Record consent" }).click();
  await expect(page.getByText(/^Received/)).toBeVisible();
  await page.getByRole("button", { name: "Move to another class" }).click();
  await page.getByLabel("New class (in this school)").selectOption({ label: "SS2 Arts · Guided · 13–17" });
  await page.getByRole("dialog").getByRole("button", { name: "Move" }).click();
  await expect(page.getByRole("paragraph").filter({ hasText: "SS2 Arts · Guided · 13–17" })).toBeVisible();
});

test("Teachers (school admin): invite, then remove with their class moved first; School details shows the log", async ({ page }) => {
  await newSchool(page);
  const email = uniqueEmail("grace");
  await page.goto("/teachers/");
  await designChecks(page);
  await page.getByLabel("Full name").fill("Miss Grace Eze");
  await page.getByLabel("Email", { exact: true }).fill(email);
  await page.getByRole("button", { name: "Send invite" }).click();
  await expect(page.getByRole("status").filter({ hasText: `Invitation sent to ${email}` })).toBeVisible();
  await expect(page.getByRole("row").filter({ hasText: email })).toContainText("Invited");

  // She signs in (accepting the invitation) in another browser and takes a class.
  const other = await page.context().browser()!.newContext();
  const grace = await other.newPage();
  await signIn(grace, email);
  const cls = await addClass(grace, "Primary 5 Science", "p5", "classroom");
  await other.close();

  await page.reload();
  const row = page.getByRole("row").filter({ hasText: email });
  await expect(row).toContainText("Active");
  await expect(row).toContainText(cls.name);
  await row.getByRole("button", { name: "Remove Miss Grace Eze" }).click();
  const dialog = page.getByRole("dialog", { name: "Remove Miss Grace Eze?" });
  await dialog.getByRole("button", { name: "Remove" }).click();
  await expect(dialog.getByRole("alert")).toHaveText("Choose a new teacher for each of their classes first.");
  await dialog.getByLabel(`New teacher for ${cls.name}`).selectOption({ label: "Mrs Folake Adebayo" });
  await dialog.getByRole("button", { name: "Remove" }).click();
  await expect(page.getByRole("row").filter({ hasText: email })).toContainText("Removed");

  await page.goto("/school/");
  await expect(page.getByText(/removed\s+Miss Grace Eze/)).toBeVisible();
  await designChecks(page);
});

test("the Magana team approves a pending school on its own page", async ({ page }) => {
  await registerSchool(uniqueEmail("pending"), "Kano Model School");
  await signIn(page, "team@magana.test").catch(() => undefined);  // the team lands on /admin/, not Home
  await page.goto("/admin/");
  const school = page.getByRole("listitem").filter({ hasText: "Kano Model School" }).first();
  await expect(school).toBeVisible();
  await expect((await new AxeBuilder({ page: page as never }).withTags(["wcag2a", "wcag2aa", "wcag2aaa"]).analyze()).violations).toEqual([]);
  await school.getByRole("button", { name: /^Approve/ }).click();
  await expect(page.getByRole("status")).toHaveText("Kano Model School: approved.");
});

test("an under-18 who changes class needs their teacher's code (the backend checks it)", async ({ page }) => {
  await newSchool(page);
  const a = await addClass(page, "JSS 2 A", "jss2", "guided");
  const b = await addClass(page, "JSS 2 B", "jss2", "guided");
  const j = await joinOnPhone(page, a.code);
  const phone = { "X-Magana-Tier": "guided", "X-Magana-Learner": j.token, "X-Magana-Device": "teen-phone" };
  const tc = (await (await page.request.get(`${apiUrl}/portal/me/teacher-code`)).json()).teacher_code;
  const r = await page.request.post(`${apiUrl}/learner/change-class`, { data: { teacher_code: tc, class_code: b.code }, headers: phone });
  expect((await r.json()).class.name).toBe("JSS 2 B");
});
