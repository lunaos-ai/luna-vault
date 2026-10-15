(() => {
  const trusted = location.protocol === "https:" && (
    ["app.pushci.dev", "staging.pushci.dev", "amliq.finance"].includes(location.hostname)
    || location.hostname.endsWith(".amliq.finance")
  );
  if (!trusted || window.top !== window) return;
  let pending = false;
  const publish = (message) => window.postMessage(message, location.origin);
  function announce() {
    chrome.runtime.sendMessage({ type: "VV_PING_NATIVE" }, (response) => {
      if (!chrome.runtime.lastError && response?.ok === true) {
        publish({ type: "VV_AUTHENTICATOR_AVAILABLE" });
      }
    });
  }
  window.addEventListener("message", (event) => {
    if (event.source !== window || event.origin !== location.origin) return;
    if (event.data?.type === "VV_AUTHENTICATOR_CHECK") { announce(); return; }
    if (event.data?.type !== "VV_SAVE_AUTHENTICATOR" || pending) return;
    const { otpauthURI, requestId } = event.data;
    if (requestId !== undefined && (typeof requestId !== "string" || requestId.length > 128)) return;
    const respond = (ok, code = null) => publish({
      type: "VV_SAVE_AUTHENTICATOR_RESULT", requestId, ok, code
    });
    try {
      if (typeof otpauthURI !== "string" || otpauthURI.length > 16_384) throw new Error();
      const uri = new URL(otpauthURI);
      if (uri.protocol !== "otpauth:" || uri.hostname !== "totp" || !uri.searchParams.get("secret")) {
        throw new Error();
      }
    } catch { respond(false, "invalid_authenticator"); return; }
    pending = true;
    chrome.runtime.sendMessage({ type: "VV_SAVE_AUTHENTICATOR", payload: { otpauthURI } }, (response) => {
      pending = false;
      const ok = !chrome.runtime.lastError && response?.ok === true;
      // Native success means queued for review in the app, not saved or enabled.
      respond(ok, ok ? "review_in_app" : "native_host_unavailable");
    });
  });
  announce();
})();
