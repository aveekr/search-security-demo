(() => {
  const cfg = window.DEMO_CONFIG;
  if (!cfg) {
    alert("Missing config.js. Copy web/config.sample.js to web/config.js and set values.");
    return;
  }

  const showSessionError = (msg) => {
    const el = document.getElementById("sessionInfo");
    if (!el) {
      alert(msg);
      return;
    }
    el.textContent = msg;
    el.classList.remove("ok");
    el.classList.add("err");
  };

  if (!window.msal || !window.msal.PublicClientApplication) {
    showSessionError("MSAL library failed to load. Check network and reload the page.");
    return;
  }

  const loginBtn = document.getElementById("loginBtn");
  const logoutBtn = document.getElementById("logoutBtn");
  const sessionInfo = document.getElementById("sessionInfo");
  const searchBtn = document.getElementById("searchBtn");
  const searchStatus = document.getElementById("searchStatus");
  const searchResults = document.getElementById("searchResults");
  const uploadBtn = document.getElementById("uploadBtn");
  const uploadStatus = document.getElementById("uploadStatus");

  const queryInput = document.getElementById("queryInput");
  const searchType = document.getElementById("searchType");
  const titleInput = document.getElementById("titleInput");
  const contentInput = document.getElementById("contentInput");
  const advisorInput = document.getElementById("advisorInput");

  const state = {
    account: null,
    idToken: null,
    advisorId: null,
    claims: null,
    lookupDebug: null
  };

  const msalConfig = {
    auth: {
      clientId: cfg.entra.clientId,
      authority: `https://login.microsoftonline.com/${cfg.entra.tenantId}`,
      redirectUri: cfg.entra.redirectUri
    },
    cache: {
      cacheLocation: "sessionStorage"
    }
  };

  let msalClient;
  try {
    msalClient = new msal.PublicClientApplication(msalConfig);
  } catch (err) {
    showSessionError(`MSAL init failed: ${err.message}`);
    return;
  }
  const loginRequest = { scopes: ["openid", "profile", "email"] };

  const setStatus = (el, msg, ok = true) => {
    if (!el) {
      return;
    }
    el.textContent = msg;
    el.classList.remove("ok", "err");
    el.classList.add(ok ? "ok" : "err");
  };

  const functionUrl = (path, withCode = true) => {
    const base = cfg.api.baseUrl.replace(/\/$/, "");
    const code = cfg.api.functionKey;
    if (!withCode) {
      return `${base}${path}`;
    }
    const join = path.includes("?") ? "&" : "?";
    return `${base}${path}${join}code=${encodeURIComponent(code)}`;
  };

  const authHeaders = () => {
    const headers = { "Content-Type": "application/json" };
    if (state.idToken) {
      headers.Authorization = `Bearer ${state.idToken}`;
    }
    return headers;
  };

  const resolveAdvisorFromFallback = () => {
    const upn = state.account?.username;
    if (!upn) {
      return null;
    }

    const exact = cfg.fallbackAdvisorMap?.[upn];
    if (exact) {
      return exact;
    }

    const normalizedUpn = upn.toLowerCase();
    const fallbackMap = cfg.fallbackAdvisorMap || {};
    for (const key of Object.keys(fallbackMap)) {
      if (key.toLowerCase() === normalizedUpn) {
        return fallbackMap[key];
      }
    }

    return null;
  };

  const refreshSessionUi = () => {
    if (!sessionInfo || !loginBtn || !logoutBtn) {
      return;
    }

    if (!state.account) {
      sessionInfo.textContent = "Not signed in";
      loginBtn.classList.remove("hidden");
      logoutBtn.classList.add("hidden");
      return;
    }

    const who = state.account.username || state.account.name || "unknown";
    const advisor = state.advisorId || "(not mapped)";
    let sessionText = `Signed in: ${who} | advisorId: ${advisor}`;

    if (state.claims) {
      const authFlag = state.claims.authenticated === true ? "true" : "false";
      const mappedFlag = state.claims.mapped === true ? "true" : "false";
      const claimOid = state.claims.oid || "none";
      const claimUpn = state.claims.upn || "none";
      sessionText += ` | auth:${authFlag} mapped:${mappedFlag}`;
      sessionText += ` | oid:${claimOid} | upn:${claimUpn}`;
    }

    if (state.lookupDebug && state.lookupDebug.claimsPresent) {
      const hasOid = state.lookupDebug.claimsPresent.oid ? "true" : "false";
      const hasUpn = state.lookupDebug.claimsPresent.upn ? "true" : "false";
      sessionText += ` | claimsPresent(oid:${hasOid},upn:${hasUpn})`;
    }

    if (state.lookupDebug && state.lookupDebug.identityLookupError) {
      sessionText += ` | lookupError: ${state.lookupDebug.identityLookupError}`;
    }
    sessionInfo.textContent = sessionText;
    loginBtn.classList.add("hidden");
    logoutBtn.classList.remove("hidden");

    if (advisorInput && !advisorInput.value && state.advisorId) {
      advisorInput.value = state.advisorId;
    }
  };

  const loadUserContext = async () => {
    try {
      const res = await fetch(functionUrl("/api/me-context?debug=1"), {
        method: "GET",
        headers: authHeaders()
      });

      const ctx = await res.json();
      state.lookupDebug = ctx.debug || null;

      if (res.ok) {
        state.advisorId = ctx.advisorId || null;
        state.claims = ctx;
      } else {
        state.claims = ctx;
        state.advisorId = resolveAdvisorFromFallback();
      }
    } catch {
      state.advisorId = resolveAdvisorFromFallback();
    }

    refreshSessionUi();
  };

  const login = async () => {
    try {
      const loginResp = await msalClient.loginPopup(loginRequest);
      state.account = loginResp.account;
      state.idToken = loginResp.idToken;
      await loadUserContext();
    } catch (err) {
      // Popup blockers or browser policies can block popup login.
      if ((err.errorCode || "").includes("popup") || (err.message || "").toLowerCase().includes("popup")) {
        setStatus(sessionInfo, "Popup blocked. Switching to redirect login...", false);
        try {
          await msalClient.loginRedirect(loginRequest);
          return;
        } catch (redirectErr) {
          setStatus(sessionInfo, `Redirect login failed: ${redirectErr.message}`, false);
          alert(`Login failed: ${redirectErr.message}`);
          return;
        }
      }

      setStatus(sessionInfo, `Login failed: ${err.message}`, false);
      alert(`Login failed: ${err.message}`);
    }
  };

  const logout = async () => {
    const account = state.account;
    state.account = null;
    state.idToken = null;
    state.advisorId = null;
    state.claims = null;
    refreshSessionUi();
    if (account) {
      await msalClient.logoutPopup({ account });
    }
  };

  const runSearch = async () => {
    if (!queryInput || !searchType || !searchStatus || !searchResults) {
      return;
    }

    const query = queryInput.value.trim();
    if (!query) {
      setStatus(searchStatus, "Enter a query", false);
      return;
    }

    const advisorId = state.advisorId || advisorInput.value.trim();
    if (!advisorId) {
      setStatus(searchStatus, "No advisor mapping found. Map user first.", false);
      return;
    }

    const payload = {
      query,
      advisorId,
      searchType: searchType.value,
      top: 10
    };

    try {
      setStatus(searchStatus, "Searching...", true);
      const res = await fetch(functionUrl("/api/search"), {
        method: "POST",
        headers: authHeaders(),
        body: JSON.stringify(payload)
      });

      const body = await res.json();
      if (!res.ok) {
        const detail = body.details ? ` | ${body.details}` : "";
        setStatus(searchStatus, `${body.error || "Search failed"}${detail}`, false);
        return;
      }

      setStatus(searchStatus, `Search OK: ${body.count} result(s) for ${advisorId}`, true);

      searchResults.innerHTML = "";
      (body.results || []).forEach((item) => {
        const card = document.createElement("article");
        card.className = "result-item";
        card.innerHTML = `
          <h4>${item.title || "Untitled"}</h4>
          <p class="result-meta">${item.id || ""} | ${item.clientId || "N/A"} | ${item.documentType || "N/A"}</p>
          <p>${item.summary || "No summary"}</p>
        `;
        searchResults.appendChild(card);
      });
    } catch (err) {
      setStatus(searchStatus, `Search failed: ${err.message}`, false);
    }
  };

  const uploadDocument = async () => {
    if (!titleInput || !contentInput || !advisorInput || !uploadStatus) {
      return;
    }

    const title = titleInput.value.trim();
    const content = contentInput.value.trim();
    const advisorIdsRaw = advisorInput.value.trim();

    if (!title || !content || !advisorIdsRaw) {
      setStatus(uploadStatus, "Title, content, and advisor IDs are required", false);
      return;
    }

    const advisorIds = advisorIdsRaw.split(",").map((x) => x.trim()).filter(Boolean);

    const payload = {
      documentId: `ui-doc-${Date.now()}`,
      title,
      content,
      advisorIds,
      clientId: "client-ui-demo",
      documentType: "ui-upload"
    };

    try {
      setStatus(uploadStatus, "Uploading...", true);
      const res = await fetch(functionUrl("/api/documents"), {
        method: "POST",
        headers: authHeaders(),
        body: JSON.stringify(payload)
      });

      const body = await res.json();
      if (!res.ok) {
        setStatus(uploadStatus, body.error || "Upload failed", false);
        return;
      }

      setStatus(uploadStatus, `Upload OK: ${body.documentId}`, true);
      titleInput.value = "";
      contentInput.value = "";
    } catch (err) {
      setStatus(uploadStatus, `Upload failed: ${err.message}`, false);
    }
  };

  const bootstrap = async () => {
    try {
      await msalClient.handleRedirectPromise();
    } catch (err) {
      setStatus(sessionInfo, `Redirect handling error: ${err.message}`, false);
    }

    const accounts = msalClient.getAllAccounts();
    if (accounts.length > 0) {
      state.account = accounts[0];
      try {
        const token = await msalClient.acquireTokenSilent({
          ...loginRequest,
          account: state.account
        });
        state.idToken = token.idToken;
      } catch {
        state.idToken = null;
      }
      await loadUserContext();
    } else {
      refreshSessionUi();
    }
  };

  if (loginBtn) {
    loginBtn.addEventListener("click", login);
  }
  if (logoutBtn) {
    logoutBtn.addEventListener("click", logout);
  }
  if (searchBtn) {
    searchBtn.addEventListener("click", runSearch);
  }
  if (uploadBtn) {
    uploadBtn.addEventListener("click", uploadDocument);
  }

  bootstrap();

  window.addEventListener("error", (evt) => {
    showSessionError(`UI error: ${evt.message}`);
  });
})();
