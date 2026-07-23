#!/usr/bin/env node
const fs = require("fs");
const path = require("path");

const { chromium } = require("playwright");

const repoRoot = path.resolve(__dirname, "..");
const outDir = path.join(repoRoot, "build/playwright");
const sessionFile = path.join(outDir, "chrome-webstore-session-dir.txt");
const chromePath = process.env.CHROME_PATH || "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome";
const googleEmail = process.env.GOOGLE_EMAIL || "info@finsavvyai.com";
const googlePassword = process.env.FINSAVVYAI_INFO_GOOGLE_PASSWORD || process.env.GOOGLE_PASSWORD || "";
const publisherId = process.env.CWS_PUBLISHER_ID || "5b1df73d-ce41-4dba-9959-7df1474c5c82";
const itemId = process.env.CWS_ITEM_ID || "nfeigikipagiccmhlolgfbeienkckbpc";
const itemBase = `https://chrome.google.com/webstore/devconsole/${publisherId}/${itemId}`;
const headless = process.env.HEADLESS !== "0";
const waitForGoogleSignInMs = Number(process.env.WAIT_FOR_GOOGLE_SIGNIN_MS || "0");

fs.mkdirSync(outDir, { recursive: true });

function requireFile(filePath, label) {
  if (!fs.existsSync(filePath)) throw new Error(`${label} not found: ${filePath}`);
}

async function bodyText(page) {
  return ((await page.locator("body").innerText({ timeout: 15000 }).catch(() => "")) || "").trim();
}

async function clickIfVisible(locator, timeout = 4000) {
  if (await locator.isVisible({ timeout }).catch(() => false)) {
    await locator.click();
    return true;
  }
  return false;
}

async function loginControls(page) {
  return page.locator("input, button, [role=button], a").evaluateAll((elements) =>
    elements
      .map((element, index) => {
        const rect = element.getBoundingClientRect();
        return {
          index,
          tag: element.tagName,
          type: element.getAttribute("type"),
          name: element.getAttribute("name"),
          id: element.id || null,
          aria: element.getAttribute("aria-label"),
          text: (element.innerText || "").trim().replace(/\s+/g, " ").slice(0, 120),
          visible: rect.width > 0 && rect.height > 0 && getComputedStyle(element).visibility !== "hidden" && getComputedStyle(element).display !== "none"
        };
      })
      .filter((control) =>
        control.visible &&
        /identifier|passwd|password|next|try another|continue|passkey/i.test(
          `${control.type || ""} ${control.name || ""} ${control.id || ""} ${control.aria || ""} ${control.text || ""}`
        )
      )
  );
}

async function verifyGoogleIfNeeded(page) {
  if (!page.url().includes("accounts.google.com")) return { signedIn: true, attention: null };

  const emailInput = page
    .locator('input[type="email"], input[name="identifier"], #identifierId, input[autocomplete="username"]')
    .first();
  if (await emailInput.isVisible({ timeout: 5000 }).catch(() => false)) {
    await emailInput.fill(googleEmail);
    await page.getByRole("button", { name: /^Next$/i }).click();
    await page.waitForLoadState("domcontentloaded", { timeout: 15000 }).catch(() => {});
  } else {
    const text = await bodyText(page);
    if (/verify it.?s you/i.test(text)) {
      await clickIfVisible(page.getByRole("button", { name: /^Next$/i }), 5000).catch(() => {});
      await page.waitForLoadState("domcontentloaded", { timeout: 15000 }).catch(() => {});
    }
  }

  await page.waitForTimeout(2000);
  let passwordInput = page.locator('input[name="Passwd"]:visible, input[type="password"]:visible').first();
  if (!(await passwordInput.isVisible({ timeout: 5000 }).catch(() => false))) {
    const text = await bodyText(page);
    await clickIfVisible(page.getByRole("button", { name: /try another way/i }).first(), 5000).catch(() => {});
    await page.waitForLoadState("domcontentloaded", { timeout: 15000 }).catch(() => {});
    await page.waitForTimeout(3000);

    for (const option of [/enter your password/i, /use your password/i, /^password$/i]) {
      if (await clickIfVisible(page.getByText(option).first(), 2500).catch(() => false)) {
        await page.waitForLoadState("domcontentloaded", { timeout: 15000 }).catch(() => {});
        await page.waitForTimeout(2000);
        break;
      }
    }
    passwordInput = page.locator('input[name="Passwd"]:visible, input[type="password"]:visible').first();
  }

  if (await passwordInput.isVisible({ timeout: 15000 }).catch(() => false)) {
    if (!googlePassword) {
      return { signedIn: false, attention: "password_required" };
    }
    await passwordInput.fill(googlePassword);
    await page.getByRole("button", { name: /^Next$/i }).click();
    await page.waitForLoadState("domcontentloaded", { timeout: 30000 }).catch(() => {});
    await page.waitForLoadState("networkidle", { timeout: 30000 }).catch(() => {});
  }

  if (page.url().includes("accounts.google.com")) {
    const text = await bodyText(page);
    if (/try another way/i.test(text)) {
      await clickIfVisible(page.getByRole("button", { name: /try another way/i }).first(), 5000).catch(() => {});
      await page.waitForLoadState("domcontentloaded", { timeout: 15000 }).catch(() => {});
      await page.waitForTimeout(4000);
    }
  }

  if (page.url().includes("accounts.google.com")) {
    const text = await bodyText(page);
    return {
      signedIn: false,
      attention: text.replace(/\s+/g, " ").slice(0, 300)
    };
  }

  return { signedIn: true, attention: null };
}

async function waitForManualGoogleSignIn(page, timeoutMs) {
  if (!timeoutMs || !page.url().includes("accounts.google.com")) return false;

  const deadline = Date.now() + timeoutMs;
  while (Date.now() < deadline) {
    if (!page.url().includes("accounts.google.com")) return true;
    await page.waitForTimeout(2000);
  }
  return !page.url().includes("accounts.google.com");
}

async function visibleButtons(page) {
  return page.locator("button, [role=button], a").evaluateAll((elements) =>
    elements
      .map((element, index) => ({
        index,
        tag: element.tagName,
        text: (element.innerText || "").trim().replace(/\s+/g, " ").slice(0, 180),
        aria: element.getAttribute("aria-label"),
        disabled: Boolean(element.disabled),
        ariaDisabled: element.getAttribute("aria-disabled")
      }))
      .filter((button) => button.text || button.aria)
  );
}

async function clickPublishIfAvailable(page, statusText) {
  if (/Status:\s*Pending review/i.test(statusText) || /This draft is pending review/i.test(statusText)) {
    return { attempted: false, reason: "pending_review" };
  }
  if (/Status:\s*Rejected/i.test(statusText) || /has been rejected/i.test(statusText)) {
    return { attempted: false, reason: "rejected" };
  }

  const publishButtons = page.getByText(/^Publish$/i);
  const count = await publishButtons.count().catch(() => 0);
  for (let index = 0; index < count; index += 1) {
    const button = publishButtons.nth(index);
    if (!(await button.isVisible().catch(() => false))) continue;
    if (!(await button.isEnabled().catch(() => false))) continue;

    await button.click();
    await page.waitForTimeout(3000);

    const confirm = page.getByText(/^Publish$/i).last();
    if (await confirm.isVisible({ timeout: 5000 }).catch(() => false)) {
      await confirm.click();
      await page.waitForTimeout(10000);
      await page.waitForLoadState("networkidle", { timeout: 60000 }).catch(() => {});
    }
    return { attempted: true, reason: "publish_clicked" };
  }

  return { attempted: false, reason: "publish_button_not_available" };
}

async function main() {
  requireFile(sessionFile, "Chrome Web Store session file");
  requireFile(chromePath, "Chrome executable");

  const sessionDir = fs.readFileSync(sessionFile, "utf8").trim();
  const context = await chromium.launchPersistentContext(sessionDir, {
    headless,
    executablePath: chromePath,
    viewport: { width: 1440, height: 1100 },
    args: ["--disable-blink-features=AutomationControlled"]
  });

  const page = context.pages()[0] || await context.newPage();
  page.setDefaultTimeout(30000);

  try {
    await page.goto(`${itemBase}/edit/status`, { waitUntil: "domcontentloaded", timeout: 60000 });
    await page.waitForLoadState("networkidle", { timeout: 60000 }).catch(() => {});
    await page.waitForTimeout(3000);

    const signIn = await verifyGoogleIfNeeded(page);
    if (!signIn.signedIn) {
      await page.screenshot({ path: path.join(outDir, "chrome-webstore-publish-login-blocked.png"), fullPage: true });
      if (waitForGoogleSignInMs > 0) {
        console.log(JSON.stringify({
          ok: false,
          state: "waiting_for_manual_google_verification",
          url: page.url(),
          attention: signIn.attention,
          controls: await loginControls(page).catch(() => []),
          timeoutMs: waitForGoogleSignInMs,
          screenshot: path.join(outDir, "chrome-webstore-publish-login-blocked.png")
        }, null, 2));
        const manuallySignedIn = await waitForManualGoogleSignIn(page, waitForGoogleSignInMs);
        if (manuallySignedIn) {
          await page.goto(`${itemBase}/edit/status`, { waitUntil: "domcontentloaded", timeout: 60000 });
          await page.waitForLoadState("networkidle", { timeout: 60000 }).catch(() => {});
        } else {
          console.log(JSON.stringify({
            ok: false,
            state: "manual_google_verification_timed_out",
            url: page.url(),
            screenshot: path.join(outDir, "chrome-webstore-publish-login-blocked.png")
          }, null, 2));
          process.exitCode = 2;
          return;
        }
      } else {
      console.log(JSON.stringify({
        ok: false,
        state: "google_verification_required",
        url: page.url(),
        attention: signIn.attention,
        controls: await loginControls(page).catch(() => []),
        screenshot: path.join(outDir, "chrome-webstore-publish-login-blocked.png")
      }, null, 2));
      process.exitCode = 2;
      return;
      }
    }

    if (!page.url().includes(itemId)) {
      await page.goto(`${itemBase}/edit/status`, { waitUntil: "domcontentloaded", timeout: 60000 });
      await page.waitForLoadState("networkidle", { timeout: 60000 }).catch(() => {});
    }

    await page.screenshot({ path: path.join(outDir, "chrome-webstore-publish-before.png"), fullPage: true });
    const beforeText = await bodyText(page);
    const publish = await clickPublishIfAvailable(page, beforeText);

    await page.goto(`${itemBase}/edit/status`, { waitUntil: "domcontentloaded", timeout: 60000 }).catch(() => {});
    await page.waitForLoadState("networkidle", { timeout: 60000 }).catch(() => {});
    await page.waitForTimeout(3000);
    await page.screenshot({ path: path.join(outDir, "chrome-webstore-publish-after.png"), fullPage: true });
    const afterText = await bodyText(page);

    const result = {
      ok: true,
      url: page.url(),
      publish,
      status: /Status:\s*([^\n]+)/i.exec(afterText)?.[1]?.trim() || null,
      pendingReview: /Status:\s*Pending review/i.test(afterText) || /This draft is pending review/i.test(afterText),
      published: /Status:\s*Published/i.test(afterText),
      rejected: /Status:\s*Rejected/i.test(afterText),
      bodyStart: afterText.replace(/\s+/g, " ").slice(0, 900),
      relevantControls: (await visibleButtons(page)).filter((control) =>
        /publish|submit|review|draft|published|appeal|item page/i.test(`${control.text || ""} ${control.aria || ""}`)
      ),
      screenshots: {
        before: path.join(outDir, "chrome-webstore-publish-before.png"),
        after: path.join(outDir, "chrome-webstore-publish-after.png")
      }
    };
    fs.writeFileSync(path.join(outDir, "chrome-webstore-publish-result.json"), JSON.stringify(result, null, 2));
    console.log(JSON.stringify(result, null, 2));
  } finally {
    await context.close().catch(() => {});
  }
}

main().catch((error) => {
  console.error(error.message);
  process.exit(1);
});
