#!/usr/bin/env node
const fs = require("fs");
const os = require("os");
const path = require("path");
const { execFileSync } = require("child_process");

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
const nativeHostName = "com.lunaos.vibevault.importer";

fs.mkdirSync(outDir, { recursive: true });

function ensureFile(filePath, label) {
  if (!fs.existsSync(filePath)) {
    throw new Error(`${label} not found: ${filePath}`);
  }
}

function extensionIdFromContext(context) {
  const worker = context.serviceWorkers()[0];
  if (!worker) return null;
  return new URL(worker.url()).hostname;
}

function installPlaywrightNativeHost(userDataDir, extensionId) {
  const hostDir = path.join(userDataDir, "NativeMessagingHosts");
  fs.mkdirSync(hostDir, { recursive: true });
  const manifest = {
    name: nativeHostName,
    description: "Vibe Vault browser API key importer",
    path: browserHost,
    type: "stdio",
    allowed_origins: [`chrome-extension://${extensionId}/`]
  };
  fs.writeFileSync(
    path.join(hostDir, `${nativeHostName}.json`),
    JSON.stringify(manifest, null, 2)
  );
}

async function launchWithExtension(userDataDir) {
  return chromium.launchPersistentContext(userDataDir, {
    headless: false,
    args: [
      `--disable-extensions-except=${extensionDir}`,
      `--load-extension=${extensionDir}`,
      "--no-first-run",
      "--no-default-browser-check"
    ]
  });
}

async function waitForExtensionId(context) {
  let id = extensionIdFromContext(context);
  if (id) return id;
  const worker = await context.waitForEvent("serviceworker", { timeout: 15000 });
  return new URL(worker.url()).hostname;
}

async function main() {
  ensureFile(path.join(extensionDir, "manifest.json"), "Extension manifest");
  ensureFile(vibevault, "vibevault debug binary");
  ensureFile(browserHost, "vibevault-browser-host debug binary");

  const userDataDir = fs.mkdtempSync(path.join(os.tmpdir(), "vibevault-playwright-chrome-"));

  let context = await launchWithExtension(userDataDir);
  const extensionId = await waitForExtensionId(context);
  await context.close();

  execFileSync(vibevault, [
    "browser",
    "install",
    "--browser",
    "all",
    "--extension-id",
    extensionId,
    "--host-binary",
    browserHost
  ], { stdio: "inherit" });
  installPlaywrightNativeHost(userDataDir, extensionId);

  context = await launchWithExtension(userDataDir);

  const popup = await context.newPage();
  await popup.goto(`chrome-extension://${extensionId}/src/popup.html`);
  await popup.locator("#status").waitFor({ timeout: 15000 });
  await popup.waitForFunction(() => document.querySelector("#status")?.textContent !== "Checking");
  const nativeStatus = (await popup.locator("#status").textContent()).trim();
  await popup.screenshot({ path: path.join(outDir, "extension-popup.png"), fullPage: true });

  const providerPage = await context.newPage();
  const dummyGeminiKey = ["AI", "za", "Sy", "DUMMYKEY1234567890abcdefghijklmnop"].join("");
  await providerPage.route("https://aistudio.google.com/**", async (route) => {
    await route.fulfill({
      status: 200,
      contentType: "text/html",
      body: `<!doctype html>
        <html>
          <head><title>Fake Google AI Studio Key Page</title></head>
          <body style="font-family: -apple-system; padding: 48px">
            <h1>Create API key</h1>
            <p>Your new API key</p>
            <code>${dummyGeminiKey}</code>
          </body>
        </html>`
    });
  });
  await providerPage.goto("https://aistudio.google.com/app/apikey");
  await providerPage.locator("#vv-importer").waitFor({ timeout: 15000 });
  const panelText = (await providerPage.locator("#vv-importer").innerText()).replace(/\s+/g, " ").trim();
  await providerPage.screenshot({ path: path.join(outDir, "extension-provider-panel.png"), fullPage: true });

  let storeContext = context;
  if (fs.existsSync(chromePath)) {
    const storeUserDataDir = fs.mkdtempSync(path.join(os.tmpdir(), "vibevault-playwright-store-"));
    storeContext = await chromium.launchPersistentContext(storeUserDataDir, {
      executablePath: chromePath,
      headless: false,
      args: ["--no-first-run", "--no-default-browser-check"]
    });
  }

  const storePage = await storeContext.newPage();
  await storePage.goto("https://chrome.google.com/webstore/devconsole", { waitUntil: "domcontentloaded", timeout: 30000 });
  await storePage.screenshot({ path: path.join(outDir, "chrome-webstore-devconsole.png"), fullPage: true });
  const body = ((await storePage.locator("body").textContent({ timeout: 10000 }).catch(() => "")) || "").toLowerCase();
  let webStoreState = "unknown";
  if (body.includes("sign in") || body.includes("use your google account") || body.includes("accounts.google.com")) {
    webStoreState = "needs_google_sign_in";
  } else if (body.includes("developer dashboard") || body.includes("new item")) {
    webStoreState = "dashboard_reachable";
  }

  if (storeContext !== context) {
    await storeContext.close();
  }
  await context.close();

  const result = {
    extensionId,
    nativeStatus,
    panelDetected: panelText.includes("Vibe Vault") && panelText.includes("Google Gemini"),
    webStoreState,
    screenshots: {
      popup: path.join(outDir, "extension-popup.png"),
      providerPanel: path.join(outDir, "extension-provider-panel.png"),
      webStore: path.join(outDir, "chrome-webstore-devconsole.png")
    }
  };

  fs.writeFileSync(path.join(outDir, "extension-check.json"), JSON.stringify(result, null, 2));
  console.log(JSON.stringify(result, null, 2));

  if (nativeStatus !== "Connected") {
    throw new Error(`native host not connected: ${nativeStatus}`);
  }
  if (!result.panelDetected) {
    throw new Error("provider key detection panel was not detected");
  }
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
