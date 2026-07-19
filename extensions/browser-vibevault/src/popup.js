const commandElement = document.getElementById("command");
const statusElement = document.getElementById("status");
const copyButton = document.getElementById("copy");

const installCommand = `vibevault browser install --browser chrome --extension-id ${chrome.runtime.id}`;
commandElement.textContent = installCommand;

copyButton.addEventListener("click", async () => {
  await navigator.clipboard.writeText(installCommand);
  copyButton.textContent = "Copied";
  window.setTimeout(() => {
    copyButton.textContent = "Copy command";
  }, 1200);
});

chrome.runtime.sendMessage({ type: "VV_PING_NATIVE" }, (response) => {
  const error = chrome.runtime.lastError;
  if (error || !response?.ok) {
    statusElement.textContent = "Not connected";
    statusElement.className = "pill error";
    return;
  }
  statusElement.textContent = "Connected";
  statusElement.className = "pill ok";
});
