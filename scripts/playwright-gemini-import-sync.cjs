#!/usr/bin/env node
const crypto = require("crypto");
const fs = require("fs");
const os = require("os");
const path = require("path");
const { execFileSync, spawnSync } = require("child_process");

function loadPlaywright() {
  const candidates = [
    process.env.PLAYWRIGHT_MODULE_PATH,
    path.join(os.homedir(), ".cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright")
  ].filter(Boolean);
  for (const candidate of candidates) {
    try {
      return require(candidate);
    } catch (_) {
      // Try the next candidate.
    }
  }
  return require("playwright");
}

const { chromium } = loadPlaywright();

const repoRoot = path.resolve(__dirname, "..");
const extensionDir = path.join(repoRoot, "extensions/browser-vibevault");
const outDir = path.join(repoRoot, "build/playwright");
const chromePath = process.env.CHROME_PATH || "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome";
const vibevault = path.join(repoRoot, ".build/debug/vibevault");
const browserHost = path.join(repoRoot, ".build/debug/vibevault-browser-host");
const hostName = "com.lunaos.vibevault.importer";
const realGemini = process.argv.includes("--real-gemini") || process.env.VIBEVAULT_REAL_GEMINI === "1";
const mockClipboard = process.argv.includes("--mock-clipboard") || process.env.VIBEVAULT_MOCK_CLIPBOARD === "1";
const tryCliExport = process.argv.includes("--try-cli-export") || process.env.VIBEVAULT_TRY_CLI_EXPORT === "1";
const keepProviderKey = process.argv.includes("--keep-provider-key") || process.env.VIBEVAULT_KEEP_GEMINI_KEY === "1";
const googleEmail = process.env.GOOGLE_EMAIL || "info@finsavvyai.com";
const timestamp = new Date().toISOString().replace(/[-:.TZ]/g, "").slice(0, 14);
const secretName = (process.env.VIBEVAULT_E2E_SECRET_NAME || `GEMINI_API_KEY_E2E_${timestamp}`).toUpperCase();
const geminiKeyName = process.env.VIBEVAULT_E2E_GEMINI_KEY_NAME || `VibeVault E2E ${timestamp}`;
const syncPassphrase = process.env.VIBEVAULT_E2E_SYNC_PASSPHRASE || `vibevault-e2e-sync-${timestamp}-${crypto.randomBytes(6).toString("hex")}`;

fs.mkdirSync(outDir, { recursive: true });

function requireFile(filePath, label) {
  if (!fs.existsSync(filePath)) {
    throw new Error(`${label} not found: ${filePath}`);
  }
}

function maskSecret(value) {
  if (!value) return null;
  if (value.length <= 12) return "****";
  return `${value.slice(0, 6)}...${value.slice(-4)}`;
}

function testHome(prefix) {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), prefix));
  fs.mkdirSync(path.join(dir, "tmp"), { recursive: true });
  return dir;
}

function envForHome(home) {
  return {
    ...process.env,
    TMPDIR: path.join(home, "tmp"),
    VIBEVAULT_VAULT_DIR: home
  };
}

function chromeNativeHostManifestPath() {
  return path.join(
    os.homedir(),
    "Library/Application Support/Google/Chrome/NativeMessagingHosts",
    `${hostName}.json`
  );
}

function writeHostWrapper(home) {
  const wrapper = path.join(home, "vibevault-browser-host-wrapper.sh");
  const body = [
    "#!/bin/sh",
    `export TMPDIR=${JSON.stringify(path.join(home, "tmp"))}`,
    `export VIBEVAULT_VAULT_DIR=${JSON.stringify(home)}`,
    `exec ${JSON.stringify(browserHost)}`
  ].join("\n") + "\n";
  fs.writeFileSync(wrapper, body, { mode: 0o755 });
  return wrapper;
}

function writeManifest(filePath, hostPath, extensionId) {
  fs.mkdirSync(path.dirname(filePath), { recursive: true });
  fs.writeFileSync(filePath, JSON.stringify({
    name: hostName,
    description: "Vibe Vault browser API key importer",
    path: hostPath,
    type: "stdio",
    allowed_origins: [`chrome-extension://${extensionId}/`]
  }, null, 2));
}

function copyChromeProfile(sourceDir) {
  const dest = fs.mkdtempSync(path.join(os.tmpdir(), "vibevault-gemini-signedin-profile-"));
  const rsync = spawnSync("rsync", [
    "-a",
    "--exclude=Singleton*",
    "--exclude=Crashpad",
    "--exclude=ShaderCache",
    "--exclude=GrShaderCache",
    "--exclude=GraphiteDawnCache",
    "--exclude=Default/Cache",
    "--exclude=Default/Code Cache",
    "--exclude=Default/GPUCache",
    `${sourceDir.replace(/\/$/, "")}/`,
    `${dest}/`
  ], { encoding: "utf8" });
  if (rsync.status !== 0) {
    throw new Error(`could not copy signed-in Chrome profile: ${rsync.stderr || rsync.stdout}`);
  }
  return dest;
}

function installTemporaryNativeHost(userDataDir, hostPath, extensionId) {
  const globalPath = chromeNativeHostManifestPath();
  const previous = fs.existsSync(globalPath) ? fs.readFileSync(globalPath) : null;
  writeManifest(globalPath, hostPath, extensionId);
  writeManifest(path.join(userDataDir, "NativeMessagingHosts", `${hostName}.json`), hostPath, extensionId);
  return () => {
    if (previous) {
      fs.mkdirSync(path.dirname(globalPath), { recursive: true });
      fs.writeFileSync(globalPath, previous);
    } else if (fs.existsSync(globalPath)) {
      fs.unlinkSync(globalPath);
    }
  };
}

async function launchWithExtension(userDataDir) {
  return chromium.launchPersistentContext(userDataDir, {
    headless: false,
    env: process.env,
    args: [
      `--disable-extensions-except=${extensionDir}`,
      `--load-extension=${extensionDir}`,
      "--no-first-run",
      "--no-default-browser-check"
    ],
    viewport: { width: 1440, height: 900 },
    acceptDownloads: true
  });
}

async function waitForExtensionId(context) {
  const existing = context.serviceWorkers().find((worker) => worker.url().startsWith("chrome-extension://"));
  if (existing) return new URL(existing.url()).hostname;
  try {
    const worker = await context.waitForEvent("serviceworker", { timeout: 20000 });
    return new URL(worker.url()).hostname;
  } catch (_) {
    const page = await context.newPage();
    await page.goto("chrome://extensions", { waitUntil: "domcontentloaded" });
    const extensionId = await page.evaluate(() => {
      const manager = document.querySelector("extensions-manager");
      const managerRoot = manager?.shadowRoot;
      const itemList = managerRoot?.querySelector("extensions-item-list");
      const itemListRoot = itemList?.shadowRoot;
      const items = Array.from(itemListRoot?.querySelectorAll("extensions-item") || []);
      for (const item of items) {
        const root = item.shadowRoot;
        const name = root?.querySelector("#name")?.textContent?.trim() || "";
        const id = item.getAttribute("id");
        if (/vibe vault importer/i.test(name) && id) return id;
      }
      return null;
    });
    await page.close();
    if (extensionId) return extensionId;
    throw new Error("could not determine unpacked extension id");
  }
}

async function nativeStatus(context, extensionId) {
  const popup = await context.newPage();
  await popup.goto(`chrome-extension://${extensionId}/src/popup.html`);
  await popup.locator("#status").waitFor({ timeout: 15000 });
  await popup.waitForFunction(() => document.querySelector("#status")?.textContent !== "Checking", null, { timeout: 15000 });
  const status = ((await popup.locator("#status").textContent()) || "").trim();
  await popup.screenshot({ path: path.join(outDir, "gemini-import-sync-popup.png"), fullPage: true });
  await popup.close();
  return status;
}

async function pageBody(page) {
  return ((await page.locator("body").textContent({ timeout: 10000 }).catch(() => "")) || "").replace(/\s+/g, " ").trim();
}

async function ensureGoogleSignedIn(page) {
  if (!page.url().includes("accounts.google.com")) return;

  const password = process.env.FINSAVVYAI_INFO_GOOGLE_PASSWORD || process.env.GOOGLE_PASSWORD || "";
  if (!password) {
    throw new Error("Google sign-in required, but no password was available in the environment.");
  }

  const emailInput = page.locator('input[type="email"]').first();
  if (await emailInput.isVisible({ timeout: 5000 }).catch(() => false)) {
    await emailInput.fill(googleEmail);
    await page.getByRole("button", { name: /next/i }).click();
    await page.waitForLoadState("domcontentloaded", { timeout: 15000 }).catch(() => {});
  }

  const passwordInput = page.locator('input[type="password"]').first();
  if (await passwordInput.isVisible({ timeout: 15000 }).catch(() => false)) {
    await passwordInput.fill(password);
    await page.getByRole("button", { name: /next/i }).click();
    await page.waitForLoadState("domcontentloaded", { timeout: 30000 }).catch(() => {});
    await page.waitForLoadState("networkidle", { timeout: 30000 }).catch(() => {});
  }

  if (page.url().includes("accounts.google.com")) {
    const body = await pageBody(page);
    throw new Error(`Google sign-in still requires attention: ${body.slice(0, 180)}`);
  }
}

async function extractGeminiKeys(page) {
  const values = await page.evaluate(() => {
    const texts = [];
    const visible = (el) => {
      const rect = el.getBoundingClientRect();
      const style = getComputedStyle(el);
      return rect.width > 0 && rect.height > 0 && style.display !== "none" && style.visibility !== "hidden";
    };

    for (const element of document.querySelectorAll("input, textarea, [contenteditable='true']")) {
      if (!visible(element)) continue;
      const value = "value" in element ? element.value : element.textContent;
      if (value) texts.push(value);
    }

    const walker = document.createTreeWalker(document.body, NodeFilter.SHOW_TEXT, {
      acceptNode(node) {
        const parent = node.parentElement;
        if (!parent || !visible(parent)) return NodeFilter.FILTER_REJECT;
        if (["SCRIPT", "STYLE", "NOSCRIPT", "SVG"].includes(parent.tagName)) return NodeFilter.FILTER_REJECT;
        return node.nodeValue.trim() ? NodeFilter.FILTER_ACCEPT : NodeFilter.FILTER_REJECT;
      }
    });
    let node;
    while ((node = walker.nextNode())) texts.push(node.nodeValue);
    return texts.join("\n");
  });
  return Array.from(new Set(values.match(/AIza[0-9A-Za-z_-]{30,}/g) || []));
}

async function waitForGeneratedGeminiKey(page) {
  const deadline = Date.now() + 60000;
  let last = [];
  while (Date.now() < deadline) {
    last = await extractGeminiKeys(page);
    if (last.length > 0) return last[0];
    const body = await pageBody(page).catch(() => "");
    if (/failed to generate api key/i.test(body) || /request is suspicious/i.test(body)) {
      throw new Error("Gemini refused automated API-key creation: Failed to generate API key, the request is suspicious.");
    }
    await page.waitForTimeout(1000);
  }
  return null;
}

async function createRealGeminiKey(page) {
  await page.goto("https://aistudio.google.com/app/api-keys", { waitUntil: "domcontentloaded", timeout: 60000 });
  await ensureGoogleSignedIn(page);
  await page.waitForLoadState("networkidle", { timeout: 30000 }).catch(() => {});
  await page.getByRole("button", { name: /close guided tour/i }).click({ timeout: 3000 }).catch(() => {});
  await page.getByRole("button", { name: /create api key/i }).first().waitFor({ timeout: 30000 });
  await page.screenshot({ path: path.join(outDir, "gemini-import-sync-before-create.png"), fullPage: true });

  await page.getByRole("button", { name: /create api key/i }).first().click();
  await page.getByLabel(/name your key/i).fill(geminiKeyName).catch(async () => {
    await page.locator('input[aria-label="Name your key"], input[type="text"], input').first().fill(geminiKeyName);
  });
  await page.getByRole("button", { name: /^create key$/i }).click();

  const generatedKey = await waitForGeneratedGeminiKey(page);
  const panel = page.locator("#vv-importer");
  const panelVisible = await panel.isVisible({ timeout: 20000 }).catch(() => false);
  if (!generatedKey) {
    await redactGeminiSecrets(page);
    await page.screenshot({ path: path.join(outDir, "gemini-import-sync-after-create-no-key.png"), fullPage: true }).catch(() => {});
    const diagnostic = await page.evaluate(() => {
      const visible = (el) => {
        const rect = el.getBoundingClientRect();
        const style = getComputedStyle(el);
        return rect.width > 0 && rect.height > 0 && style.display !== "none" && style.visibility !== "hidden";
      };
      const controls = Array.from(document.querySelectorAll("button,a,[role='button'],input,textarea")).map((el) => {
        const text = (el.innerText || el.textContent || el.value || el.getAttribute("aria-label") || el.getAttribute("placeholder") || "").replace(/\s+/g, " ").trim();
        return {
          tag: el.tagName,
          role: el.getAttribute("role"),
          aria: el.getAttribute("aria-label"),
          text,
          disabled: Boolean(el.disabled) || el.getAttribute("aria-disabled") === "true",
          visible: visible(el)
        };
      }).filter((item) => item.visible && (item.text || item.aria)).slice(0, 120);
      return {
        url: location.href,
        body: document.body.innerText.replace(/\s+/g, " ").trim().slice(0, 2500),
        controls
      };
    });
    fs.writeFileSync(path.join(outDir, "gemini-import-sync-after-create-no-key.json"), JSON.stringify(diagnostic, null, 2));
  }
  return { generatedKey, panelVisible };
}

async function createMockGeminiKey(page) {
  const generatedKey = `AIza${crypto.randomBytes(28).toString("base64url")}`;
  await page.route("https://aistudio.google.com/**", async (route) => {
    const body = mockClipboard
      ? `<!doctype html>
        <html>
          <head><title>Mock Google AI Studio</title></head>
          <body style="font-family: -apple-system; padding: 48px">
            <h1>API Keys</h1>
            <p>${geminiKeyName}</p>
            <button id="copy-key" aria-label="Copy API key">content_copy Copy API key</button>
            <script>
              document.querySelector("#copy-key").addEventListener("click", async () => {
                await navigator.clipboard.writeText(${JSON.stringify(generatedKey)});
              });
            </script>
          </body>
        </html>`
      : `<!doctype html>
        <html>
          <head><title>Mock Google AI Studio</title></head>
          <body style="font-family: -apple-system; padding: 48px">
            <h1>API Keys</h1>
            <button>Create API key</button>
            <p>${geminiKeyName}</p>
            <code>${generatedKey}</code>
          </body>
        </html>`;
    await route.fulfill({
      status: 200,
      contentType: "text/html",
      body
    });
  });
  await page.goto("https://aistudio.google.com/app/api-keys", { waitUntil: "domcontentloaded", timeout: 30000 });
  if (mockClipboard) {
    await page.getByRole("button", { name: /copy api key/i }).click();
  }
  await page.locator("#vv-importer").waitFor({ timeout: 15000 });
  return { generatedKey, panelVisible: true };
}

async function importThroughExtension(page) {
  const panel = page.locator("#vv-importer");
  await panel.waitFor({ timeout: 25000 });
  const row = panel.locator(".vv-row").first();
  await row.locator(".vv-name").fill(secretName);
  await row.locator(".vv-save").click();
  await panel.locator(".vv-status").waitFor({ timeout: 20000 });
  await page.waitForFunction(
    () => document.querySelector("#vv-importer .vv-status")?.textContent?.includes("Saved"),
    null,
    { timeout: 20000 }
  );
  return ((await panel.locator(".vv-status").textContent()) || "").trim();
}

async function redactGeminiSecrets(page) {
  await page.evaluate(() => {
    const mask = (value) => value.replace(/AIza[0-9A-Za-z_-]{30,}/g, (secret) => {
      if (secret.length <= 12) return "****";
      return `${secret.slice(0, 6)}...${secret.slice(-4)}`;
    });
    const walker = document.createTreeWalker(document.body, NodeFilter.SHOW_TEXT);
    const nodes = [];
    let node;
    while ((node = walker.nextNode())) nodes.push(node);
    for (const text of nodes) {
      const next = mask(text.nodeValue || "");
      if (next !== text.nodeValue) text.nodeValue = next;
    }
    for (const element of document.querySelectorAll("input, textarea")) {
      if ("value" in element) element.value = mask(element.value || "");
    }
  });
}

function runVibeVault(args, home, extraEnv = {}, timeout = 90000) {
  return spawnSync(vibevault, args, {
    cwd: repoRoot,
    env: { ...envForHome(home), ...extraEnv },
    encoding: "utf8",
    timeout
  });
}

function listSecretNames(home) {
  const output = execFileSync(vibevault, ["list", "--json"], {
    cwd: repoRoot,
    env: envForHome(home),
    encoding: "utf8"
  });
  return JSON.parse(output).map((item) => item.name);
}

function makeCloudSyncBundle({ name, value, notes, passphrase, filePath }) {
  const now = new Date().toISOString().replace(/\.\d{3}Z$/, "Z");
  const snapshot = {
    exportedAt: now,
    secrets: [{
      createdAt: now,
      mcpAllowed: false,
      name,
      notes,
      updatedAt: now,
      value
    }],
    sourceHost: "vibevault-playwright-e2e",
    version: 1
  };
  const salt = crypto.randomBytes(32);
  const stretched = crypto.pbkdf2Sync(passphrase, salt, 600000, 32, "sha256");
  const key = Buffer.from(crypto.hkdfSync("sha256", stretched, salt, Buffer.from("vibevault-cloud-sync-v1"), 32));
  const nonce = crypto.randomBytes(12);
  const cipher = crypto.createCipheriv("aes-256-gcm", key, nonce);
  const ciphertext = Buffer.concat([cipher.update(JSON.stringify(snapshot), "utf8"), cipher.final()]);
  const envelope = {
    cipher: "aes-256-gcm",
    ciphertext: ciphertext.toString("base64"),
    createdAt: now,
    kdf: "pbkdf2-sha256+hkdf-sha256",
    kdfIterations: 600000,
    nonce: nonce.toString("base64"),
    salt: salt.toString("base64"),
    sourceHost: snapshot.sourceHost,
    tag: cipher.getAuthTag().toString("base64"),
    version: 1
  };
  fs.mkdirSync(path.dirname(filePath), { recursive: true });
  fs.writeFileSync(filePath, JSON.stringify(envelope, null, 2));
}

async function cleanupGeminiKey(page) {
  if (keepProviderKey || !realGemini) return { attempted: false, deleted: false, reason: "cleanup disabled" };
  try {
    await page.goto("https://aistudio.google.com/app/api-keys", { waitUntil: "domcontentloaded", timeout: 60000 });
    await page.waitForLoadState("networkidle", { timeout: 30000 }).catch(() => {});
    const rowHandle = await page.evaluateHandle((name) => {
      const hasName = (el) => (el.innerText || el.textContent || "").includes(name);
      const candidates = Array.from(document.querySelectorAll("tr, mat-row, li, div"));
      return candidates.find((el) => hasName(el) && Array.from(el.querySelectorAll("button")).some((button) => /more_vert|more actions/i.test(button.innerText || button.getAttribute("aria-label") || ""))) || null;
    }, geminiKeyName);
    const row = rowHandle.asElement();
    if (!row) return { attempted: true, deleted: false, reason: "row not found" };
    const more = await row.$("button[aria-label*='more'], button");
    if (!more) return { attempted: true, deleted: false, reason: "more actions button not found" };
    await more.click();
    await page.waitForTimeout(1000);
    const deleteControl = page.getByRole("menuitem", { name: /delete/i }).first()
      .or(page.getByRole("button", { name: /delete/i }).first())
      .or(page.getByText(/^delete/i).first());
    if (!(await deleteControl.isVisible({ timeout: 5000 }).catch(() => false))) {
      return { attempted: true, deleted: false, reason: "delete control not found" };
    }
    await deleteControl.click();
    await page.waitForTimeout(1000);
    const confirm = page.getByRole("button", { name: /delete|confirm|remove/i }).last();
    if (await confirm.isVisible({ timeout: 5000 }).catch(() => false)) {
      await confirm.click();
    }
    await page.waitForTimeout(3000);
    const body = await pageBody(page);
    return { attempted: true, deleted: !body.includes(geminiKeyName), reason: body.includes(geminiKeyName) ? "key still visible" : null };
  } catch (error) {
    return { attempted: true, deleted: false, reason: error.message };
  }
}

async function main() {
  requireFile(path.join(extensionDir, "manifest.json"), "Extension manifest");
  requireFile(vibevault, "vibevault debug binary");
  requireFile(browserHost, "vibevault-browser-host debug binary");
  const sourceSessionFile = path.join(outDir, "chrome-webstore-session-dir.txt");
  const userDataDir = realGemini && fs.existsSync(sourceSessionFile)
    ? copyChromeProfile(fs.readFileSync(sourceSessionFile, "utf8").trim())
    : fs.mkdtempSync(path.join(os.tmpdir(), "vibevault-gemini-profile-"));
  const sourceHome = testHome("vibevault-gemini-source-");
  const targetHome = testHome("vibevault-gemini-target-");
  const wrapper = writeHostWrapper(sourceHome);

  let context = await launchWithExtension(userDataDir);
  const extensionId = await waitForExtensionId(context);
  await context.close();

  const restoreNativeHost = installTemporaryNativeHost(userDataDir, wrapper, extensionId);
  context = await launchWithExtension(userDataDir);
  let result = {
    mode: realGemini ? "real-gemini" : "mock-gemini",
    mockClipboard,
    googleEmail: realGemini ? googleEmail : null,
    geminiKeyName,
    secretName,
    extensionId,
    nativeStatus: null,
    generatedKeyMasked: null,
    providerPanelDetected: false,
    importStatus: null,
    sourceVaultHasSecret: false,
    sync: {
      cliExport: null,
      cliImport: null,
      fallbackBundleImport: null,
      targetVaultHasSecret: false
    },
    providerCleanup: null,
    artifacts: {
      result: path.join(outDir, "gemini-import-sync-result.json"),
      popup: path.join(outDir, "gemini-import-sync-popup.png"),
      beforeCreate: path.join(outDir, "gemini-import-sync-before-create.png"),
      afterImport: path.join(outDir, "gemini-import-sync-after-import-redacted.png")
    }
  };

  try {
    result.nativeStatus = await nativeStatus(context, extensionId);
    if (result.nativeStatus !== "Connected") {
      throw new Error(`native host not connected: ${result.nativeStatus}`);
    }

    const page = await context.newPage();
    await context.grantPermissions(["clipboard-read", "clipboard-write"], { origin: "https://aistudio.google.com" }).catch(() => {});
    const creation = realGemini ? await createRealGeminiKey(page) : await createMockGeminiKey(page);
    result.generatedKeyMasked = maskSecret(creation.generatedKey);
    result.providerPanelDetected = creation.panelVisible;
    if (!creation.generatedKey) {
      throw new Error("Gemini key was not visible after creation; extension could not verify the generated value.");
    }
    if (!creation.panelVisible) {
      throw new Error("Vibe Vault importer panel was not detected on the generated Gemini key page.");
    }

    result.importStatus = await importThroughExtension(page);
    await redactGeminiSecrets(page);
    await page.screenshot({ path: result.artifacts.afterImport, fullPage: true }).catch(() => {});

    result.sourceVaultHasSecret = listSecretNames(sourceHome).includes(secretName);
    if (!result.sourceVaultHasSecret) {
      throw new Error(`Imported secret was not present in source vault: ${secretName}`);
    }

    const syncPath = path.join(outDir, "gemini-import-sync.vvsync");
    let importPath = syncPath;
    if (tryCliExport) {
      const exportRun = runVibeVault(
        ["sync", "export", "--path", syncPath, "--passphrase-env", "VIBEVAULT_E2E_SYNC_PASSPHRASE"],
        sourceHome,
        { VIBEVAULT_E2E_SYNC_PASSPHRASE: syncPassphrase },
        45000
      );
      result.sync.cliExport = {
        ok: exportRun.status === 0,
        status: exportRun.status,
        signal: exportRun.signal,
        stdout: exportRun.stdout.trim(),
        stderr: exportRun.stderr.trim()
      };
    } else {
      result.sync.cliExport = {
        ok: false,
        skipped: "CLI export can require macOS device authentication; pass --try-cli-export to exercise it interactively."
      };
    }

    if (!result.sync.cliExport.ok) {
      importPath = path.join(outDir, "gemini-import-sync-fallback.vvsync");
      makeCloudSyncBundle({
        name: secretName,
        value: creation.generatedKey,
        notes: "Fallback bundle generated by Playwright after CLI export was blocked by local device authentication.",
        passphrase: syncPassphrase,
        filePath: importPath
      });
      result.sync.fallbackBundleImport = "used";
    }

    const importRun = runVibeVault(
      ["sync", "import", "--path", importPath, "--passphrase-env", "VIBEVAULT_E2E_SYNC_PASSPHRASE", "--overwrite"],
      targetHome,
      { VIBEVAULT_E2E_SYNC_PASSPHRASE: syncPassphrase },
      90000
    );
    result.sync.cliImport = {
      ok: importRun.status === 0,
      status: importRun.status,
      signal: importRun.signal,
      stdout: importRun.stdout.trim(),
      stderr: importRun.stderr.trim()
    };
    result.sync.targetVaultHasSecret = listSecretNames(targetHome).includes(secretName);
    if (!result.sync.cliImport.ok || !result.sync.targetVaultHasSecret) {
      throw new Error(`Sync import failed for ${secretName}`);
    }

    result.providerCleanup = await cleanupGeminiKey(page);
    fs.writeFileSync(result.artifacts.result, JSON.stringify(result, null, 2));
    console.log(JSON.stringify({
      mode: result.mode,
      geminiKeyName: result.geminiKeyName,
      secretName: result.secretName,
      extensionId: result.extensionId,
      nativeStatus: result.nativeStatus,
      generatedKeyMasked: result.generatedKeyMasked,
      importStatus: result.importStatus,
      sourceVaultHasSecret: result.sourceVaultHasSecret,
      sync: result.sync,
      providerCleanup: result.providerCleanup,
      result: result.artifacts.result
    }, null, 2));
  } finally {
    restoreNativeHost();
    await context.close().catch(() => {});
  }
}

main().catch((error) => {
  const failurePath = path.join(outDir, "gemini-import-sync-failure.json");
  fs.writeFileSync(failurePath, JSON.stringify({
    error: error.message,
    stack: error.stack,
    geminiKeyName,
    secretName
  }, null, 2));
  console.error(error.message);
  console.error(`failure: ${failurePath}`);
  process.exit(1);
});
