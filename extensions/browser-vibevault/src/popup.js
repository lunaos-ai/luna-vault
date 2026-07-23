const commandElement = document.getElementById("command");
const statusElement = document.getElementById("status");
const statusDetailElement = document.getElementById("status-detail");
const copyButton = document.getElementById("copy");
const retryButton = document.getElementById("retry");
const installButton = document.getElementById("install");
const licenseButton = document.getElementById("license");
const securityButton = document.getElementById("security");

const installCommand = `vibevault browser install --browser chrome --extension-id ${chrome.runtime.id}`;

commandElement.textContent = installCommand;
copyButton.addEventListener("click", copyInstallCommand);
retryButton.addEventListener("click", pingNativeHost);
installButton.addEventListener("click", () => openURL("https://vibevault.lunaos.ai/download"));
licenseButton.addEventListener("click", () => openURL("https://vibevault.lunaos.ai/#pricing"));
securityButton.addEventListener("click", () => openURL("https://vibevault.lunaos.ai/security"));

pingNativeHost();

async function copyInstallCommand() {
  try {
    await navigator.clipboard.writeText(installCommand);
    setButtonText(copyButton, "Copied", "Copy command");
  } catch (_) {
    setButtonText(copyButton, "Copy failed", "Copy command");
  }
}

function pingNativeHost() {
  setStatus("Checking", "pill", "Testing the local Vibe Vault connection.");
  chrome.runtime.sendMessage({ type: "VV_PING_NATIVE" }, (response) => {
    const error = chrome.runtime.lastError;
    if (error || !response?.ok) {
      setStatus(
        "Not connected",
        "pill error",
        "Run the setup command once. If Chrome was open, restart Chrome or click Test again."
      );
      return;
    }
    setStatus(
      "Connected",
      "pill ok",
      `Ready to save keys into your local vault${response.version ? ` (host ${response.version})` : ""}.`
    );
  });
}

function setStatus(label, className, detail) {
  statusElement.textContent = label;
  statusElement.className = className;
  statusDetailElement.textContent = detail;
}

function setButtonText(button, next, previous) {
  button.textContent = next;
  window.setTimeout(() => {
    button.textContent = previous;
  }, 1200);
}

function openURL(url) {
  chrome.tabs.create({ url });
}
