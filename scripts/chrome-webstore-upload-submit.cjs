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
const packageZip = path.resolve(process.env.CWS_PACKAGE_ZIP || path.join(repoRoot, "build/VibeVault-Browser-Importer.zip"));
const itemBase = `https://chrome.google.com/webstore/devconsole/${publisherId}/${itemId}`;
const headless = process.env.HEADLESS !== "0";
const waitForGoogleSignInMs = Number(process.env.WAIT_FOR_GOOGLE_SIGNIN_MS || "0");
const privacyJustifications = {
  clipboardRead:
    "Used only after the user clicks a provider copy action on a supported API-key dashboard, so Vibe Vault can detect a copied API key pattern and show a local Save panel. Clipboard text is not stored by the extension or sent anywhere until the user clicks Save."
};

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

async function controls(page) {
  return page.locator("input, button, [role=button], a").evaluateAll((elements) =>
    elements
      .map((element, index) => {
        const rect = element.getBoundingClientRect();
        const style = getComputedStyle(element);
        return {
          index,
          tag: element.tagName,
          type: element.getAttribute("type"),
          name: element.getAttribute("name"),
          id: element.id || null,
          aria: element.getAttribute("aria-label"),
          text: (element.innerText || element.getAttribute("value") || "").trim().replace(/\s+/g, " ").slice(0, 180),
          visible: rect.width > 0 && rect.height > 0 && style.visibility !== "hidden" && style.display !== "none",
          disabled: Boolean(element.disabled) || element.getAttribute("aria-disabled") === "true"
        };
      })
      .filter((control) => control.visible && (control.text || control.aria || control.type))
  );
}

async function loginControls(page) {
  return (await controls(page)).filter((control) =>
    /identifier|passwd|password|next|try another|continue|passkey|verify/i.test(
      `${control.type || ""} ${control.name || ""} ${control.id || ""} ${control.aria || ""} ${control.text || ""}`
    )
  );
}

async function verifyGoogleIfNeeded(page) {
  if (!page.url().includes("accounts.google.com")) return { signedIn: true, attention: null };

  const emailInput = page
    .locator('input[type="email"], input[name="identifier"], #identifierId, input[autocomplete="username"]')
    .first();
  if (await emailInput.isVisible({ timeout: 8000 }).catch(() => false)) {
    await emailInput.fill(googleEmail);
    await page.getByRole("button", { name: /^Next$/i }).click();
    await page.waitForLoadState("domcontentloaded", { timeout: 20000 }).catch(() => {});
  }

  await page.waitForTimeout(2500);

  let passwordInput = page.locator('input[name="Passwd"]:visible, input[type="password"]:visible').first();
  if (!(await passwordInput.isVisible({ timeout: 7000 }).catch(() => false))) {
    await clickIfVisible(page.getByRole("button", { name: /try another way/i }).first(), 5000).catch(() => {});
    await page.waitForLoadState("domcontentloaded", { timeout: 15000 }).catch(() => {});
    await page.waitForTimeout(2500);

    for (const option of [/enter your password/i, /use your password/i, /^password$/i]) {
      if (await clickIfVisible(page.getByText(option).first(), 2500).catch(() => false)) {
        await page.waitForLoadState("domcontentloaded", { timeout: 15000 }).catch(() => {});
        await page.waitForTimeout(2000);
        break;
      }
    }
    passwordInput = page.locator('input[name="Passwd"]:visible, input[type="password"]:visible').first();
  }

  if (await passwordInput.isVisible({ timeout: 12000 }).catch(() => false)) {
    if (!googlePassword) return { signedIn: false, attention: "password_required" };
    await passwordInput.fill(googlePassword);
    await page.getByRole("button", { name: /^Next$/i }).click();
    await page.waitForLoadState("domcontentloaded", { timeout: 30000 }).catch(() => {});
    await page.waitForLoadState("networkidle", { timeout: 45000 }).catch(() => {});
    await page.waitForTimeout(3000);
  }

  if (page.url().includes("accounts.google.com")) {
    const text = await bodyText(page);
    return { signedIn: false, attention: text.replace(/\s+/g, " ").slice(0, 400) };
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

async function clickControlByText(page, patterns) {
  const candidates = [
    ...patterns.map((pattern) => page.getByRole("button", { name: pattern }).first()),
    ...patterns.map((pattern) => page.getByRole("link", { name: pattern }).first()),
    ...patterns.map((pattern) => page.getByText(pattern).first())
  ];

  for (const candidate of candidates) {
    if (!(await candidate.isVisible({ timeout: 2500 }).catch(() => false))) continue;
    if (!(await candidate.isEnabled({ timeout: 1000 }).catch(() => true))) continue;
    await candidate.click();
    return true;
  }
  return false;
}

async function navigateToPackagePage(page) {
  const candidates = [`${itemBase}/edit/package`, `${itemBase}/edit`, `${itemBase}/edit/status`];
  for (const url of candidates) {
    await page.goto(url, { waitUntil: "domcontentloaded", timeout: 60000 });
    await page.waitForLoadState("networkidle", { timeout: 45000 }).catch(() => {});
    await page.waitForTimeout(2500);
    if (page.url().includes("accounts.google.com")) return;
    const text = await bodyText(page);
    if (/package|upload|submit for review|publish/i.test(text)) return;
  }
}

async function setPackageFile(page) {
  let fileInput = page.locator('input[type="file"]').first();
  if (await fileInput.count().catch(() => 0)) {
    await fileInput.setInputFiles(packageZip);
    return { uploaded: true, method: "input[type=file]" };
  }

  for (const patternSet of [
    [/^Package$/i, /Package/i],
    [/Upload new package/i, /Upload package/i, /^Upload$/i, /Browse/i, /Choose file/i],
    [/Edit package/i, /Package/i]
  ]) {
    const chooserPromise = page.waitForEvent("filechooser", { timeout: 5000 }).catch(() => null);
    const clicked = await clickControlByText(page, patternSet).catch(() => false);
    const chooser = clicked ? await chooserPromise : null;
    if (chooser) {
      await chooser.setFiles(packageZip);
      return { uploaded: true, method: `filechooser:${patternSet[0]}` };
    }
    if (clicked) {
      await page.waitForLoadState("networkidle", { timeout: 30000 }).catch(() => {});
      await page.waitForTimeout(1500);
      fileInput = page.locator('input[type="file"]').first();
      if (await fileInput.count().catch(() => 0)) {
        await fileInput.setInputFiles(packageZip);
        return { uploaded: true, method: `clicked:${patternSet[0]}` };
      }
    }
  }

  return { uploaded: false, method: null };
}

async function waitForUploadCompletion(page) {
  const deadline = Date.now() + 180000;
  let lastText = "";
  while (Date.now() < deadline) {
    await page.waitForTimeout(3000);
    lastText = (await bodyText(page)).replace(/\s+/g, " ");
    if (/uploaded|package uploaded|submit for review|publish|save draft|draft/i.test(lastText) && !/uploading|processing/i.test(lastText)) {
      return { completed: true, text: lastText.slice(0, 1000) };
    }
    if (/error|invalid|failed|manifest/i.test(lastText)) {
      return { completed: false, text: lastText.slice(0, 1400) };
    }
  }
  return { completed: false, text: lastText.slice(0, 1400), timeout: true };
}

async function fillTextareaAfterLabel(page, labelPattern, value) {
  const textareaId = await page.evaluate((patternSource) => {
    const pattern = new RegExp(patternSource, "i");
    const nodes = [...document.querySelectorAll("label, textarea")];
    const labelIndex = nodes.findIndex((node) => node.tagName === "LABEL" && pattern.test(node.innerText || ""));
    if (labelIndex === -1) return null;
    const textarea = nodes.slice(labelIndex + 1).find((node) => node.tagName === "TEXTAREA");
    return textarea?.id || null;
  }, labelPattern.source);

  if (!textareaId) return { filled: false, reason: "textarea_not_found" };

  const locator = page.locator(`#${textareaId}`);
  const current = await locator.inputValue().catch(() => "");
  if (current.trim()) return { filled: false, reason: "already_filled", textareaId };

  await locator.fill(value);
  await page.waitForTimeout(500);
  return { filled: true, textareaId };
}

async function fillMissingPrivacyJustifications(page) {
  await page.goto(`${itemBase}/edit/privacy`, { waitUntil: "domcontentloaded", timeout: 60000 });
  await page.waitForLoadState("networkidle", { timeout: 45000 }).catch(() => {});
  await page.waitForTimeout(2500);

  const changes = {
    clipboardRead: await fillTextareaAfterLabel(page, /clipboardRead justification/i, privacyJustifications.clipboardRead)
  };

  const changed = Object.values(changes).some((change) => change.filled);
  if (changed) {
    await clickControlByText(page, [/^Save draft$/i, /^Save$/i]).catch(() => false);
    await page.waitForLoadState("networkidle", { timeout: 45000 }).catch(() => {});
    await page.waitForTimeout(4000);
  }

  await page.goto(`${itemBase}/edit`, { waitUntil: "domcontentloaded", timeout: 60000 });
  await page.waitForLoadState("networkidle", { timeout: 45000 }).catch(() => {});
  await page.waitForTimeout(2500);

  return { changed, changes };
}

async function submitIfAvailable(page) {
  const clicked = [];
  for (const pattern of [
    /Save draft/i,
    /^Save$/i,
    /Submit for review/i,
    /Send for review/i,
    /^Submit$/i,
    /^Publish$/i
  ]) {
    const didClick = await clickControlByText(page, [pattern]).catch(() => false);
    if (!didClick) continue;
    clicked.push(pattern.toString());
    await page.waitForLoadState("networkidle", { timeout: 45000 }).catch(() => {});
    await page.waitForTimeout(3000);

    for (const confirm of [/Submit for review/i, /^Submit$/i, /^Publish$/i, /^OK$/i, /^Confirm$/i]) {
      if (await clickControlByText(page, [confirm]).catch(() => false)) {
        clicked.push(`confirm:${confirm.toString()}`);
        await page.waitForLoadState("networkidle", { timeout: 45000 }).catch(() => {});
        await page.waitForTimeout(3000);
        break;
      }
    }
  }
  return clicked;
}

async function main() {
  requireFile(sessionFile, "Chrome Web Store session file");
  requireFile(chromePath, "Chrome executable");
  requireFile(packageZip, "Chrome Web Store package");

  const sessionDir = fs.readFileSync(sessionFile, "utf8").trim();
  const context = await chromium.launchPersistentContext(sessionDir, {
    headless,
    executablePath: chromePath,
    viewport: { width: 1440, height: 1100 },
    args: ["--disable-blink-features=AutomationControlled"]
  });

  const page = context.pages()[0] || await context.newPage();
  page.setDefaultTimeout(30000);

  const resultPath = path.join(outDir, "chrome-webstore-upload-submit-result.json");
  const result = {
    ok: false,
    itemId,
    packageZip,
    screenshots: {}
  };

  try {
    await navigateToPackagePage(page);

    const signIn = await verifyGoogleIfNeeded(page);
    if (!signIn.signedIn) {
      result.state = waitForGoogleSignInMs > 0 ? "waiting_for_manual_google_verification" : "google_verification_required";
      result.url = page.url();
      result.attention = signIn.attention;
      result.controls = await loginControls(page).catch(() => []);
      result.screenshots.loginBlocked = path.join(outDir, "chrome-webstore-upload-login-blocked.png");
      await page.screenshot({ path: result.screenshots.loginBlocked, fullPage: true });
      fs.writeFileSync(resultPath, JSON.stringify(result, null, 2));
      console.log(JSON.stringify(result, null, 2));

      if (waitForGoogleSignInMs <= 0) {
        process.exitCode = 2;
        return;
      }

      const manuallySignedIn = await waitForManualGoogleSignIn(page, waitForGoogleSignInMs);
      if (!manuallySignedIn) {
        result.state = "manual_google_verification_timed_out";
        result.url = page.url();
        fs.writeFileSync(resultPath, JSON.stringify(result, null, 2));
        console.log(JSON.stringify(result, null, 2));
        process.exitCode = 2;
        return;
      }
      await navigateToPackagePage(page);
    }

    result.screenshots.beforeUpload = path.join(outDir, "chrome-webstore-upload-before.png");
    await page.screenshot({ path: result.screenshots.beforeUpload, fullPage: true });

    const upload = await setPackageFile(page);
    result.upload = upload;
    await page.waitForLoadState("networkidle", { timeout: 60000 }).catch(() => {});
    const uploadCompletion = upload.uploaded ? await waitForUploadCompletion(page) : { completed: false, text: (await bodyText(page)).replace(/\s+/g, " ").slice(0, 1400) };
    result.uploadCompletion = uploadCompletion;

    result.screenshots.afterUpload = path.join(outDir, "chrome-webstore-upload-after.png");
    await page.screenshot({ path: result.screenshots.afterUpload, fullPage: true });

    if (upload.uploaded && uploadCompletion.completed) {
      result.privacy = await fillMissingPrivacyJustifications(page);
      result.submitClicks = await submitIfAvailable(page);
      await page.goto(`${itemBase}/edit/status`, { waitUntil: "domcontentloaded", timeout: 60000 }).catch(() => {});
      await page.waitForLoadState("networkidle", { timeout: 60000 }).catch(() => {});
      await page.waitForTimeout(4000);
    }

    const finalText = (await bodyText(page)).replace(/\s+/g, " ");
    result.url = page.url();
    result.status = /Status:\s*([^|]+)/i.exec(finalText)?.[1]?.trim() || null;
    result.pendingReview = /pending review|in review|submitted for review/i.test(finalText);
    result.published = /Status:\s*Published/i.test(finalText) || /\bPublished\b/i.test(finalText);
    result.rejected = /Status:\s*Rejected/i.test(finalText) || /rejected/i.test(finalText);
    result.draftUnpublished = /draft is unpublished/i.test(finalText);
    result.ok = upload.uploaded && !result.rejected && (result.pendingReview || (result.published && !result.draftUnpublished));
    result.bodyStart = finalText.slice(0, 1400);
    result.relevantControls = (await controls(page)).filter((control) =>
      /package|upload|publish|submit|review|draft|status|save|item page|privacy|permission/i.test(
        `${control.text || ""} ${control.aria || ""} ${control.type || ""}`
      )
    );
    result.screenshots.final = path.join(outDir, "chrome-webstore-upload-final.png");
    await page.screenshot({ path: result.screenshots.final, fullPage: true });
    fs.writeFileSync(resultPath, JSON.stringify(result, null, 2));
    console.log(JSON.stringify(result, null, 2));
    if (!result.ok) process.exitCode = 2;
  } finally {
    await context.close().catch(() => {});
  }
}

main().catch((error) => {
  console.error(error.stack || error.message);
  process.exit(1);
});
