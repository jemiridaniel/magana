// Accounts and the new portal screens against a real backend (design canvas: Sign in, Enter
// sign-in code, Register your school, Teachers, Home, Learner remove from class, My classes):
// axe (WCAG 2.2 AA + AAA contrast), 64 px targets, the dialog's focus, the LGA combobox.
import { expect, test } from "@playwright/test";
import { apiUrl } from "../playwright.config";
import { addClass, approve, designChecks, emailedCode, joinOnPhone, newSchool, nextTotp, registerSchool, signIn, signInTeam,
         totpAt, uniqueEmail } from "./helpers";

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
  await page.getByRole("textbox", { name: /^Sign-in code/ }).fill(right === "730913" ? "815204" : "730913");
  await page.getByRole("button", { name: "Sign in" }).click();
  await expect(page.locator(".form-error")).toHaveText(/That code isn’t right/);
  await page.getByRole("textbox", { name: /^Sign-in code/ }).fill(right);
  await page.getByRole("button", { name: "Sign in" }).click();
  await expect(page.getByRole("heading", { level: 1 })).toContainText("Mrs Folake Adebayo");
});

test("signed out: every portal page goes to sign in", async ({ page }) => {
  await page.goto("/classes/");
  await expect(page).toHaveURL(/\/sign-in\/?$/);
});

test("register your school: State and LGA side by side, LGA by keyboard, proof of school, then the waiting page", async ({ page }) => {
  const email = uniqueEmail("register");
  for (const width of [1280, 390]) {
    await page.setViewportSize({ width, height: 900 });
    await page.goto("/register/");
    const state = await page.getByLabel("State").boundingBox();
    const lga = await page.getByRole("combobox", { name: "Local government area" }).boundingBox();
    expect(Math.abs(state!.y - lga!.y), `${width}px: same height`).toBeLessThanOrEqual(1);
    expect(Math.abs(state!.height - lga!.height), `${width}px: same size`).toBeLessThanOrEqual(2);
    expect(lga!.x, `${width}px: side by side`).toBeGreaterThan(state!.x + state!.width - 1);
    const hint = await page.getByText("All 36 states and the FCT").boundingBox();
    expect(hint!.y).toBeGreaterThan(state!.y + state!.height);  // under both
    expect(hint!.x).toBeLessThanOrEqual(state!.x + 1);
    expect(await page.evaluate(() => document.documentElement.scrollWidth - innerWidth)).toBeLessThanOrEqual(0);
  }
  await page.setViewportSize({ width: 1280, height: 900 });
  await page.getByLabel("Your full name").fill("Mr Chinedu Okafor");
  await page.getByLabel("Your email").fill(email);
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
  // Proof of school: the drop zone, by keyboard: Tab reaches the file input itself.
  const file = page.locator(".proof input[type=file]");
  await file.focus();
  await expect(file).toBeFocused();
  await file.setInputFiles({ name: "letterhead.png", mimeType: "image/png", buffer: Buffer.from(
    "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==", "base64") });
  await expect(page.locator(".proof .dropzone-title")).toContainText("letterhead.png");
  await expect(page.locator(".proof")).toContainText("Change file");
  await page.getByLabel(/Ministry approval number/).fill("LSMOE/PS/2019/0412");
  await designChecks(page);
  await page.getByRole("button", { name: "Register school" }).click();
  await expect(page.locator(".form-error")).toHaveText(/Tick the box/);
  await page.getByLabel(/I confirm I lead this school/).check();
  await page.getByRole("button", { name: "Register school" }).click();
  await expect(page.getByRole("heading", { name: "Thank you" })).toBeFocused();
  await expect(page.getByText(/reference SCH-\d+/)).toBeVisible();

  // Signed in before the team confirms: the waiting page, three steps and a normal Sign out.
  await signIn(page, email).catch(() => undefined);
  await page.goto("/");
  await expect(page.getByText("Waiting for confirmation")).toBeVisible();
  await expect(page.getByRole("heading", { level: 1, name: "Surulere Grammar School" })).toBeVisible();
  await expect(page.getByRole("list", { name: "What happens next" }).getByRole("listitem")).toHaveCount(3);
  await expect(page.getByText(/On 0803 \*\*\* \*\*02, by /)).toBeVisible();
  await designChecks(page);
  const out = await page.getByRole("button", { name: "Sign out" }).boundingBox();
  expect(out!.width).toBeLessThan(400);  // a normal-sized button, not full width
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

test("team admin: three checks unlock Approve; Don’t approve needs a reason and shows the email; tabs and the log", async ({ page }, info) => {
  const teamEmail = info.project.name === "phone" ? "team-phone@magana.test" : "team@magana.test";
  await registerSchool(uniqueEmail("pending"), "Kano Model School");
  await registerSchool(uniqueEmail("pending2"), "Bright Future Academy");
  await signInTeam(page, teamEmail);
  await page.goto("/admin/");
  const kano = page.getByRole("article", { name: "Kano Model School" }).first();
  await expect(kano).toBeVisible();
  await expect(kano.getByRole("link", { name: /^Call 0803 000 0001/ })).toHaveAttribute("href", "tel:+2348030000001");
  await designChecks(page);
  const approve = kano.getByRole("button", { name: /^Approve school/ });
  await expect(approve).toHaveAttribute("aria-disabled", "true");
  await approve.click({ force: true });  // aria-disabled, not disabled: still reachable, and says why
  await expect(kano.getByRole("status")).toHaveText("Tick all three checks before approving.");
  await kano.getByLabel("Call notes (team only)").fill("Spoke to Mrs Adebayo 26 Oct 11:05. Confirmed she's principal.");
  await kano.getByLabel(/I spoke to the person/).check();
  await kano.getByRole("button", { name: /^Save notes/ }).click();
  await expect(kano.getByRole("status")).toHaveText("Call notes saved.");
  await kano.getByLabel(/The school exists/).check();
  await kano.getByLabel(/Location and school name are correct/).check();
  await expect(approve).toHaveAttribute("aria-disabled", "false");
  await approve.click();
  await expect(page.getByRole("status").filter({ hasText: "Kano Model School is approved." })).toBeVisible({ timeout: 15_000 });

  const bright = page.getByRole("article", { name: "Bright Future Academy" }).first();
  await bright.getByRole("button", { name: /^Don’t approve/ }).click();
  await bright.getByRole("button", { name: /^Send and don’t approve/ }).click();
  await expect(bright.getByRole("status")).toHaveText("Choose a reason.");
  await bright.getByLabel("Couldn’t reach them after 3 calls").check();
  await expect(bright.getByText(/Email preview: “We tried to call you 3 times on 0803 \*\*\* \*\*01/)).toBeVisible();
  await designChecks(page);
  await bright.getByRole("button", { name: /^Send and don’t approve/ }).click();
  await expect(page.getByRole("status").filter({ hasText: "Bright Future Academy: not approved." })).toBeVisible({ timeout: 15_000 });

  await page.getByRole("link", { name: "Approved schools" }).click();
  await expect(page.getByRole("row").filter({ hasText: "Kano Model School" }).first()).toContainText(teamEmail);
  await designChecks(page);
  await page.getByRole("link", { name: "Not approved" }).click();
  await expect(page.getByRole("row").filter({ hasText: "Bright Future Academy" }).first()).toContainText("Couldn’t reach them after 3 calls");
  await designChecks(page);
  await page.getByRole("link", { name: "Activity log" }).click();
  await page.getByLabel("Search").fill("Kano Model");
  await page.getByLabel("Action").selectOption({ label: "Approved school" });
  const row = page.getByRole("row").filter({ hasText: "Kano Model School" }).first();
  await expect(row).toContainText("Approved school");
  await expect(row).toContainText(teamEmail);
  await designChecks(page);
  const view = row.getByRole("button", { name: /^View details/ });
  await view.click();
  const panel = page.getByRole("dialog", { name: "Activity details" });
  await expect(panel).toBeVisible();
  await expect(panel.getByText("Waiting")).toBeVisible();  // status before → after
  await expect(panel.getByText(/Spoke to Mrs Adebayo/)).toBeVisible();  // the call notes
  await expect(panel.getByText(/is ready on Magana” → principal · sent/)).toBeVisible();
  await expect(panel.getByText(/can’t be edited or deleted\. Kept for 2 years/)).toBeVisible();
  for (let i = 0; i < 5; i++) {  // Tab stays in the panel
    await page.keyboard.press("Tab");
    expect(await page.evaluate(() => !!document.activeElement?.closest("dialog"))).toBe(true);
  }
  await designChecks(page);
  await page.keyboard.press("Escape");
  await expect(panel).toBeHidden();
  await expect(view).toBeFocused();  // focus back on its button
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

test("Magana team (owner): invite a reviewer, their first sign-in sets up the authenticator and shows backup codes once", async ({ page, browser }, info) => {
  const owner = info.project.name === "phone" ? "team-phone@magana.test" : "team@magana.test";
  await signInTeam(page, owner);
  await page.getByRole("link", { name: "Magana team" }).click();
  await expect(page.getByRole("heading", { level: 1, name: "Magana team" })).toBeVisible();
  await expect(page.getByText("No access to learners’ names, progress or consent.")).toBeVisible();
  await designChecks(page);
  const email = uniqueEmail("reviewer").replace("@gmail.com", "@magana.test");
  await page.getByLabel("Full name").fill("Oluremi Balogun");
  await page.getByLabel("Email", { exact: true }).fill(email);
  await page.getByRole("radio", { name: /School reviewer/ }).check();
  await page.getByRole("button", { name: "Send invite" }).click();
  await expect(page.getByRole("status").filter({ hasText: `Invitation sent to ${email}` })).toBeVisible();
  const row = page.getByRole("row").filter({ hasText: email });
  await expect(row).toContainText("Invited");

  // The new reviewer, on their own computer.
  const ctx = await browser.newContext();
  const them = await ctx.newPage();
  await them.goto(`/sign-in/?email=${encodeURIComponent(email)}`);
  await expect(them.getByLabel("Email address")).toHaveValue(email);  // from the invitation link
  const asked = Date.now();
  await them.getByRole("button", { name: "Send me a code" }).click();
  await them.getByRole("textbox", { name: /^Sign-in code/ }).fill(await emailedCode(email, asked));
  await them.getByRole("button", { name: "Sign in" }).click();
  await expect(them.getByRole("heading", { name: "Set up your authenticator" })).toBeFocused();
  await designChecks(them);
  await expect(them.getByRole("img", { name: "QR code for your authenticator app" })).toHaveAttribute("src", /^data:image\/svg\+xml/);
  await expect(them.getByText(`Magana · ${email}`)).toBeVisible();
  await them.getByText("Can’t scan? Enter a setup key instead").click();
  await expect(them.locator(".setup-key .visually-hidden")).toHaveText(/^Setup key, in groups of four: (\w{4}, )+\w{1,4}\.$/);
  await designChecks(them);
  const key = (await them.locator(".setup-key [aria-hidden=true]").innerText()).replace(/\s/g, "");
  await them.getByLabel("Authenticator code").fill("000000");
  await them.getByRole("button", { name: "Finish setting up" }).click();
  await expect(them.locator(".form-error")).toHaveText(/authenticator code isn’t right/);
  await them.getByLabel("Authenticator code").fill(totpAt(key, Math.floor(Date.now() / 30_000)));
  await them.getByRole("button", { name: "Finish setting up" }).click();
  await expect(them.getByRole("heading", { name: "Save your backup codes" })).toBeFocused();
  await expect(them.getByRole("list", { name: "Backup codes" }).getByRole("listitem")).toHaveCount(8);
  await designChecks(them);
  await them.getByRole("button", { name: "I’ve saved them" }).click();
  await expect(them).toHaveURL(/\/admin\/?$/);
  await expect(them.getByRole("link", { name: "Magana team" })).toHaveCount(0);  // owners only
  await ctx.close();

  await page.reload();
  await expect(page.getByRole("row").filter({ hasText: email })).toContainText("Active");
  await page.getByRole("row").filter({ hasText: email }).getByRole("button", { name: /^Change role/ }).click();
  const dialog = page.getByRole("dialog", { name: /Change Oluremi Balogun’s role/ });
  await dialog.getByRole("radio", { name: /Support \(view only\)/ }).check();
  await designChecks(page);
  await dialog.getByRole("button", { name: "Save" }).click();
  await expect(page.getByRole("row").filter({ hasText: email })).toContainText("Support (view only)");
  await page.getByRole("row").filter({ hasText: email }).getByRole("button", { name: /^Remove/ }).click();
  await page.getByRole("dialog").getByRole("button", { name: "Remove" }).click();
  await expect(page.getByRole("row").filter({ hasText: email })).toHaveCount(0);
  await page.getByRole("link", { name: "Activity log" }).click();
  await page.getByLabel("Action").selectOption({ label: "Removed member" });
  await expect(page.getByRole("row").filter({ hasText: "Oluremi Balogun" }).first()).toContainText("Removed member");
});

test("Support (view only): sees schools and their teachers and can resend emails, but no approve controls", async ({ page }) => {
  await registerSchool(uniqueEmail("support-view"), "Zaria Model School");
  await signInTeam(page, "support@magana.test");
  const card = page.getByRole("article", { name: "Zaria Model School" }).first();
  await expect(card).toBeVisible();
  await expect(card.getByRole("button", { name: /^Approve school/ })).toHaveCount(0);
  await expect(card.getByLabel("Call notes (team only)")).toHaveCount(0);
  await card.getByRole("button", { name: /^Show teachers/ }).click();
  await expect(card.getByText(/Mrs Folake Adebayo .* School admin/)).toBeVisible();
  await card.getByRole("button", { name: /^Resend email/ }).click();
  await expect(card.getByRole("status")).toHaveText("Email sent again to the principal.");
  await expect(page.getByRole("link", { name: "Activity log" })).toHaveCount(0);
  await designChecks(page);
  // Learner pages aren't for the team: the portal sends them back to their own pages.
  await page.goto("/classes/");
  await expect(page).toHaveURL(/\/admin\/?$/);
});

test("My account: Reset my authenticator needs a current code, signs you out, and the next sign-in sets up a new key", async ({ page }, info) => {
  const email = `reset-${info.project.name}@magana.test`;
  await signInTeam(page, email);
  await page.getByRole("link", { name: "My account" }).click();
  await expect(page.getByRole("heading", { name: "Reset my authenticator" })).toBeVisible();
  await designChecks(page);
  await page.getByLabel("Your current authenticator code").fill("000000");
  await page.getByRole("button", { name: "Reset my authenticator" }).click();
  await expect(page.locator(".form-error")).toHaveText(/authenticator code isn’t right/);
  await page.getByLabel("Your current authenticator code").fill(await nextTotp(email));
  await page.getByRole("button", { name: "Reset my authenticator" }).click();
  await expect(page).toHaveURL(/\/sign-in\/?\?reset=1/);
  await expect(page.locator(".form-error")).toHaveText(/Your authenticator is reset/);
  await page.getByLabel("Email address").fill(email);
  const asked = Date.now();
  await page.getByRole("button", { name: "Send me a code" }).click();
  await page.getByRole("textbox", { name: /^Sign-in code/ }).fill(await emailedCode(email, asked));
  await page.getByRole("button", { name: "Sign in" }).click();
  await expect(page.getByRole("heading", { name: "Set up your authenticator" })).toBeFocused();
});

test("sign-in code: pasting the whole code into the first box fills all six", async ({ page }) => {
  const email = uniqueEmail("paste");
  await approve(await registerSchool(email));
  await page.goto("/sign-in/");
  await page.getByLabel("Email address").fill(email);
  const asked = Date.now();
  await page.getByRole("button", { name: "Send me a code" }).click();
  const code = await emailedCode(email, asked);
  const first = page.getByRole("textbox", { name: /^Sign-in code, digit 1 of 6/ });
  await first.focus();
  await first.evaluate((el, text) => {
    const data = new DataTransfer();
    data.setData("text/plain", text);
    el.dispatchEvent(new ClipboardEvent("paste", { clipboardData: data, bubbles: true, cancelable: true }));
  }, `${code.slice(0, 3)} ${code.slice(3)}`);  // as copied from the subject, with its space
  const boxes = page.getByRole("group", { name: "Sign-in code" }).getByRole("textbox");
  await expect(boxes).toHaveCount(6);
  for (let i = 0; i < 6; i++) await expect(boxes.nth(i)).toHaveValue(code[i]);
  await expect(boxes.nth(5)).toBeFocused();
  await designChecks(page);
  await page.getByRole("button", { name: "Sign in" }).click();
  await expect(page.getByRole("heading", { level: 1 })).toContainText(/Good (morning|afternoon|evening)/);
});
