const HOST_NAME = "com.lunaos.vibevault.importer";

chrome.runtime.onMessage.addListener((message, sender, sendResponse) => {
  if (!message || typeof message !== "object") {
    return false;
  }

  if (message.type === "VV_PING_NATIVE") {
    chrome.runtime.sendNativeMessage(HOST_NAME, { type: "ping" }, (response) => {
      const error = chrome.runtime.lastError;
      if (error) {
        sendResponse({ ok: false, error: error.message });
        return;
      }
      sendResponse(response || { ok: false, error: "No response from Vibe Vault host" });
    });
    return true;
  }

  if (message.type !== "VV_SAVE_SECRET") {
    return false;
  }

  const payload = message.payload || {};
  const request = {
    type: "save_secret",
    name: String(payload.name || ""),
    value: String(payload.value || ""),
    provider: String(payload.provider || ""),
    sourceUrl: String(sender.tab?.url || payload.sourceUrl || ""),
    overwrite: Boolean(payload.overwrite),
    mcpAllowed: Boolean(payload.mcpAllowed)
  };

  chrome.runtime.sendNativeMessage(HOST_NAME, request, (response) => {
    const error = chrome.runtime.lastError;
    if (error) {
      sendResponse({
        ok: false,
        code: "native_host_unavailable",
        error: `Vibe Vault host unavailable: ${error.message}`
      });
      return;
    }
    sendResponse(response || { ok: false, code: "empty_response", error: "No response from Vibe Vault host" });
  });

  return true;
});
