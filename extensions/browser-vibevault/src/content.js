(() => {
  const PROVIDERS = [
    {
      id: "gemini",
      label: "Google Gemini",
      hosts: ["aistudio.google.com", "makersuite.google.com"],
      defaultName: "GEMINI_API_KEY",
      patterns: [/AIza[0-9A-Za-z_-]{30,}/g]
    },
    {
      id: "openai",
      label: "OpenAI",
      hosts: ["platform.openai.com"],
      defaultName: "OPENAI_API_KEY",
      patterns: [/sk-(?:proj-)?[A-Za-z0-9_-]{32,}/g]
    },
    {
      id: "anthropic",
      label: "Anthropic",
      hosts: ["console.anthropic.com"],
      defaultName: "ANTHROPIC_API_KEY",
      patterns: [/sk-ant-[A-Za-z0-9_-]{32,}/g]
    },
    {
      id: "groq",
      label: "Groq",
      hosts: ["console.groq.com"],
      defaultName: "GROQ_API_KEY",
      patterns: [/gsk_[A-Za-z0-9]{32,}/g]
    },
    {
      id: "mistral",
      label: "Mistral",
      hosts: ["console.mistral.ai"],
      defaultName: "MISTRAL_API_KEY",
      patterns: []
    },
    {
      id: "cohere",
      label: "Cohere",
      hosts: ["dashboard.cohere.com"],
      defaultName: "COHERE_API_KEY",
      patterns: []
    },
    {
      id: "together",
      label: "Together AI",
      hosts: ["api.together.ai", "app.together.ai"],
      defaultName: "TOGETHER_API_KEY",
      patterns: []
    },
    {
      id: "deepseek",
      label: "DeepSeek",
      hosts: ["platform.deepseek.com"],
      defaultName: "DEEPSEEK_API_KEY",
      patterns: []
    },
    {
      id: "openrouter",
      label: "OpenRouter",
      hosts: ["openrouter.ai"],
      defaultName: "OPENROUTER_API_KEY",
      patterns: [/sk-or-v1-[A-Za-z0-9_-]{32,}/g]
    },
    {
      id: "replicate",
      label: "Replicate",
      hosts: ["replicate.com"],
      defaultName: "REPLICATE_API_TOKEN",
      patterns: [/r8_[A-Za-z0-9]{32,}/g]
    },
    {
      id: "stripe",
      label: "Stripe",
      hosts: ["dashboard.stripe.com"],
      defaultName: "STRIPE_SECRET_KEY",
      patterns: [/sk_(?:test|live)_[0-9A-Za-z]{20,}/g]
    },
    {
      id: "github",
      label: "GitHub",
      hosts: ["github.com"],
      defaultName: "GITHUB_TOKEN",
      patterns: [/gh[pousr]_[A-Za-z0-9_]{36,}/g, /github_pat_[A-Za-z0-9_]{22,}/g]
    },
    {
      id: "vercel",
      label: "Vercel",
      hosts: ["vercel.com"],
      defaultName: "VERCEL_TOKEN",
      patterns: [/vercel_[A-Za-z0-9]{24,}/g]
    },
    {
      id: "cloudflare",
      label: "Cloudflare",
      hosts: ["dash.cloudflare.com"],
      defaultName: "CLOUDFLARE_API_TOKEN",
      patterns: []
    }
  ];

  const provider = providerFor(location.hostname);
  if (!provider) return;

  const candidates = new Map();
  const valueToId = new Map();
  let nextId = 1;
  let panel;
  let scanTimer;
  let dismissedCandidateCount = 0;

  scan();
  installObservers();

  function providerFor(hostname) {
    const host = hostname.toLowerCase();
    return PROVIDERS.find((candidate) =>
      candidate.hosts.some((providerHost) => host === providerHost || host.endsWith(`.${providerHost}`))
    );
  }

  function installObservers() {
    const observer = new MutationObserver((mutations) => {
      if (mutations.every(isImporterMutation)) return;
      scheduleScan();
    });
    observer.observe(document.documentElement, {
      childList: true,
      subtree: true,
      characterData: true,
      attributes: true,
      attributeFilter: ["value", "aria-label", "data-testid"]
    });
    document.addEventListener("selectionchange", scheduleScan, { passive: true });
    document.addEventListener("click", handlePotentialCopyClick, true);
    window.addEventListener("focus", scheduleScan, { passive: true });
    setInterval(scheduleScan, 5000);
  }

  function scheduleScan() {
    window.clearTimeout(scanTimer);
    scanTimer = window.setTimeout(scan, 300);
  }

  function scan() {
    if (!document.body) return;

    for (const text of collectVisibleText()) {
      detectProviderKeys(text);
    }

    const selection = normalizedSecret(window.getSelection()?.toString() || "");
    if (selection && isLikelySecret(selection)) {
      remember(selection, "Selection");
    }

    if (candidates.size > 0 && candidates.size > dismissedCandidateCount) {
      renderPanel();
    }
  }

  function collectVisibleText() {
    const texts = [];
    const inputSelector = "input, textarea, [contenteditable='true']";
    for (const element of document.querySelectorAll(inputSelector)) {
      if (element.closest("#vv-importer")) continue;
      if (!isVisible(element)) continue;
      const value = "value" in element ? element.value : element.textContent;
      if (value) texts.push(value);
    }

    const walker = document.createTreeWalker(document.body, NodeFilter.SHOW_TEXT, {
      acceptNode(node) {
        const parent = node.parentElement;
        if (!parent || !isVisible(parent)) return NodeFilter.FILTER_REJECT;
        if (parent.closest("#vv-importer")) return NodeFilter.FILTER_REJECT;
        if (["SCRIPT", "STYLE", "NOSCRIPT", "SVG", "OPTION"].includes(parent.tagName)) {
          return NodeFilter.FILTER_REJECT;
        }
        return node.nodeValue && node.nodeValue.trim().length > 0
          ? NodeFilter.FILTER_ACCEPT
          : NodeFilter.FILTER_REJECT;
      }
    });

    let node;
    let count = 0;
    while ((node = walker.nextNode()) && count < 6000) {
      texts.push(node.nodeValue);
      count += 1;
    }
    return texts;
  }

  function detectProviderKeys(text) {
    for (const pattern of provider.patterns) {
      pattern.lastIndex = 0;
      let match;
      while ((match = pattern.exec(text)) !== null) {
        const value = normalizedSecret(match[0]);
        if (value) remember(value, provider.label);
      }
    }
  }

  async function handlePotentialCopyClick(event) {
    const control = event.target.closest?.("button, [role='button'], a");
    if (!control || control.closest("#vv-importer")) return;

    const label = [
      control.innerText,
      control.textContent,
      control.getAttribute("aria-label"),
      control.getAttribute("title")
    ].filter(Boolean).join(" ");
    if (!/(copy|content_copy|api key|token|secret)/i.test(label)) return;

    window.setTimeout(async () => {
      try {
        const text = await navigator.clipboard?.readText?.();
        const value = normalizedSecret(text || "");
        if (!value || !isLikelySecret(value) || !matchesProvider(value)) return;
        remember(value, `${provider.label} clipboard`);
        renderPanel();
      } catch (_) {
        // Clipboard access can be denied by the browser or provider page. The
        // regular DOM/selection scanner still covers visible one-time keys.
      }
    }, 150);
  }

  function matchesProvider(value) {
    if (provider.patterns.length === 0) return true;
    return provider.patterns.some((pattern) => {
      pattern.lastIndex = 0;
      return pattern.test(value);
    });
  }

  function remember(value, sourceLabel) {
    if (valueToId.has(value)) return;
    const id = `vv-${nextId++}`;
    valueToId.set(value, id);
    candidates.set(id, {
      id,
      value,
      sourceLabel,
      defaultName: provider.defaultName || defaultNameFromHost(),
      masked: mask(value)
    });
  }

  function renderPanel() {
    if (!panel) {
      panel = document.createElement("div");
      panel.id = "vv-importer";
      panel.setAttribute("role", "dialog");
      panel.setAttribute("aria-label", "Vibe Vault");
      document.documentElement.appendChild(panel);
      panel.addEventListener("click", handlePanelClick);
      panel.addEventListener("input", handlePanelInput);
    }

    const rows = Array.from(candidates.values()).slice(0, 4);
    const signature = rows.map((candidate) => candidate.id).join("|");
    if (panel.dataset.vvSignature === signature) return;
    panel.dataset.vvSignature = signature;
    panel.innerHTML = `
      <div class="vv-header">
        <div>
          <div class="vv-title">Vibe Vault</div>
          <div class="vv-subtitle">${escapeHTML(provider.label)} key detected</div>
        </div>
        <button class="vv-icon-button" type="button" data-vv-close aria-label="Close">x</button>
      </div>
      <div class="vv-rows">
        ${rows.map((candidate) => rowHTML(candidate)).join("")}
      </div>
      <label class="vv-check">
        <input type="checkbox" data-vv-overwrite>
        <span>Update if name exists</span>
      </label>
      <div class="vv-status" aria-live="polite"></div>
    `;
  }

  function rowHTML(candidate) {
    return `
      <div class="vv-row" data-vv-id="${candidate.id}">
        <div class="vv-secret">
          <span class="vv-provider">${escapeHTML(candidate.sourceLabel)}</span>
          <code>${escapeHTML(candidate.masked)}</code>
        </div>
        <input class="vv-name" type="text" spellcheck="false" value="${escapeHTML(candidate.defaultName)}" aria-label="Secret name">
        <button class="vv-save" type="button">Save</button>
      </div>
    `;
  }

  function handlePanelInput(event) {
    if (!event.target.classList.contains("vv-name")) return;
    const sanitized = sanitizeSecretName(event.target.value);
    if (event.target.value !== sanitized) {
      event.target.value = sanitized;
    }
  }

  function handlePanelClick(event) {
    if (event.target.matches("[data-vv-close]")) {
      dismissedCandidateCount = candidates.size;
      panel.remove();
      panel = null;
      return;
    }

    if (!event.target.classList.contains("vv-save")) return;
    const row = event.target.closest("[data-vv-id]");
    const candidate = candidates.get(row?.dataset.vvId || "");
    if (!candidate) return;

    const name = row.querySelector(".vv-name")?.value || "";
    const overwrite = Boolean(panel.querySelector("[data-vv-overwrite]")?.checked);
    saveCandidate(candidate, name, overwrite, event.target);
  }

  function saveCandidate(candidate, name, overwrite, button) {
    const status = panel.querySelector(".vv-status");
    const secretName = sanitizeSecretName(name);
    if (!secretName) {
      status.textContent = "Enter a valid secret name.";
      status.dataset.state = "error";
      return;
    }

    button.disabled = true;
    status.textContent = "Saving to Vibe Vault...";
    status.dataset.state = "pending";

    chrome.runtime.sendMessage(
      {
        type: "VV_SAVE_SECRET",
        payload: {
          name: secretName,
          value: candidate.value,
          provider: candidate.sourceLabel,
          sourceUrl: location.href,
          overwrite,
          mcpAllowed: false
        }
      },
      (response) => {
        button.disabled = false;
        const error = chrome.runtime.lastError;
        if (error) {
          status.textContent = error.message;
          status.dataset.state = "error";
          return;
        }
        if (!response?.ok) {
          status.textContent = response?.error || "Could not save secret.";
          status.dataset.state = "error";
          return;
        }
        status.textContent = `Saved ${response.name || secretName}.`;
        status.dataset.state = "ok";
      }
    );
  }

  function isVisible(element) {
    const style = window.getComputedStyle(element);
    if (style.display === "none" || style.visibility === "hidden" || Number(style.opacity) === 0) {
      return false;
    }
    const rect = element.getBoundingClientRect();
    return rect.width > 0 && rect.height > 0 && rect.bottom >= 0 && rect.right >= 0
      && rect.top <= window.innerHeight && rect.left <= window.innerWidth;
  }

  function normalizedSecret(raw) {
    const value = raw.replace(/[\u200B-\u200D\uFEFF]/g, "").trim();
    if (value.includes("\n")) return "";
    return value.length <= 16_384 ? value : "";
  }

  function isLikelySecret(value) {
    if (value.length < 24 || value.length > 512) return false;
    if (/\s/.test(value)) return false;
    if (/^https?:\/\//i.test(value) || value.includes("@")) return false;
    if (!/[A-Za-z]/.test(value) || !/[0-9_-]/.test(value)) return false;
    return /^[A-Za-z0-9._\-:/+=]+$/.test(value);
  }

  function sanitizeSecretName(value) {
    return value
      .trim()
      .toUpperCase()
      .replace(/[^A-Z0-9_.-]/g, "_")
      .replace(/_+/g, "_")
      .slice(0, 128);
  }

  function defaultNameFromHost() {
    const hostPart = location.hostname.split(".").filter(Boolean)[0] || "BROWSER";
    return `${sanitizeSecretName(hostPart)}_API_KEY`;
  }

  function mask(value) {
    if (value.length <= 10) return "****";
    return `${value.slice(0, 4)}...${value.slice(-4)}`;
  }

  function isImporterMutation(mutation) {
    const target = mutation.target.nodeType === Node.ELEMENT_NODE
      ? mutation.target
      : mutation.target.parentElement;
    return Boolean(target?.closest?.("#vv-importer"));
  }

  function escapeHTML(value) {
    return String(value)
      .replaceAll("&", "&amp;")
      .replaceAll("<", "&lt;")
      .replaceAll(">", "&gt;")
      .replaceAll('"', "&quot;")
      .replaceAll("'", "&#039;");
  }
})();
