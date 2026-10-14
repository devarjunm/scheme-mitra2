(() => {
  const loginPanel = document.getElementById("login-panel");
  const deletePanel = document.getElementById("delete-panel");
  const status = document.getElementById("status");
  const emailLabel = document.getElementById("account-email");
  const cookie = (name) => {
    const prefix = `${name}=`;
    const pair = document.cookie.split(";").map((value) => value.trim()).find((value) => value.startsWith(prefix));
    return pair ? decodeURIComponent(pair.slice(prefix.length)) : "";
  };
  const showStatus = (message, isError = false) => {
    status.textContent = message;
    status.classList.remove("hidden", "error");
    if (isError) status.classList.add("error");
  };
  const api = async (path, options = {}) => {
    const method = (options.method || "GET").toUpperCase();
    const headers = { "Content-Type": "application/json" };
    if (!["GET", "HEAD", "OPTIONS"].includes(method)) {
      const token = cookie("scheme_mitra_csrf");
      if (token) headers["X-CSRF-Token"] = token;
    }
    const response = await fetch(`/api/v1${path}`, {
      method,
      credentials: "same-origin",
      headers,
      body: options.body ? JSON.stringify(options.body) : undefined,
    });
    let data = {};
    try { data = await response.json(); } catch (_) {}
    if (!response.ok) throw new Error(data?.error?.message || data?.detail || `Request failed (${response.status}).`);
    return data;
  };

  document.getElementById("login-form").addEventListener("submit", async (event) => {
    event.preventDefault();
    const button = event.currentTarget.querySelector("button[type=submit]");
    const values = new FormData(event.currentTarget);
    const password = String(values.get("password") || "");
    button.disabled = true;
    try {
      const result = await api("/auth/login", { method: "POST", body: { email: values.get("email"), password } });
      emailLabel.textContent = result.user?.email || "your account";
      loginPanel.classList.add("hidden");
      deletePanel.classList.remove("hidden");
      showStatus("Signed in. Re-enter your password and confirm to permanently delete the account.");
      event.currentTarget.reset();
    } catch (error) {
      showStatus(error.message, true);
    } finally {
      button.disabled = false;
    }
  });

  document.getElementById("delete-form").addEventListener("submit", async (event) => {
    event.preventDefault();
    const values = new FormData(event.currentTarget);
    if (values.get("confirmation") !== "DELETE") {
      showStatus("Type DELETE exactly to confirm.", true);
      return;
    }
    if (!window.confirm("Permanently delete this Scheme Mitra account and its user-linked data? This cannot be undone.")) return;
    const button = event.currentTarget.querySelector("button[type=submit]");
    button.disabled = true;
    try {
      const result = await api("/account", { method: "DELETE", body: { password: values.get("password"), confirmation: "DELETE" } });
      loginPanel.classList.add("hidden");
      deletePanel.classList.add("hidden");
      showStatus(`${result.message}\n\n${result.backup_note || ""}`);
    } catch (error) {
      showStatus(error.message, true);
    } finally {
      button.disabled = false;
    }
  });
})();
