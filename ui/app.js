"use strict";

// ---------------------------------------------------------------------------
// Bridge to AutoHotkey (WebViewToo host objects).
//
// AHK registers callbacks with AddCallbackToScript("Name", Func); they appear
// here as `ahk.Name(args...)` returning Promises. AHK pushes updates back with
// PostWebMessageAsJson(...), received via the 'message' event.
// ---------------------------------------------------------------------------

const isHost = !!(window.chrome && window.chrome.webview && typeof ahk !== "undefined");

const mockState = {
    vcHotkey: "F8",
    staffHotkey: "F9",
    staffEnabled: false,
    saveCaptures: true,
    logging: true,
    model: "accurate",
    abbrs: [],
    models: [
        { key: "fast", label: "Fast", desc: "Lower CPU use." },
        { key: "accurate", label: "Accurate", desc: "Best accuracy." },
    ],
    engineOk: true,
    debug: { version: "v0.1", os: "Windows", ahk: "v2.0", webview2: "-", model: "accurate", engine: "ok", dataDir: "" },
};

async function call(name, ...args) {
    if (isHost && typeof ahk[name] === "function") return await ahk[name](...args);
    throw new Error("No AHK handler for " + name);
}

const Bridge = {
    isHost,
    async getState() {
        if (isHost) return JSON.parse(await call("GetState"));
        return JSON.parse(JSON.stringify(mockState));
    },
    async save(state) {
        if (isHost) return await call("Save", JSON.stringify(state));
        Object.assign(mockState, state);
        return "Saved (preview).";
    },
    async openDataFolder() {
        if (isHost) return await call("OpenDataFolder");
        return "Preview mode.";
    },
    async resetDefaults() {
        if (isHost) return JSON.parse(await call("ResetDefaults"));
        return JSON.parse(JSON.stringify(mockState));
    },
};

// ---------------------------------------------------------------------------
// Hotkeys: stored as AHK syntax (^!+R), shown as "Ctrl + Alt + Shift + R".
// ---------------------------------------------------------------------------

function ahkToFriendly(hk) {
    if (!hk) return "Not set";
    let s = hk;
    const parts = [];
    while (s.length && "^!+#".includes(s[0])) {
        if (s[0] === "^") parts.push("Ctrl");
        else if (s[0] === "!") parts.push("Alt");
        else if (s[0] === "+") parts.push("Shift");
        else if (s[0] === "#") parts.push("Win");
        s = s.slice(1);
    }
    let key = s;
    const aliases = { PgUp: "PageUp", PgDn: "PageDown", Esc: "Escape", BS: "Backspace", Del: "Delete", Ins: "Insert" };
    if (aliases[key]) key = aliases[key];
    if (key.length === 1) key = key.toUpperCase();
    parts.push(key);
    return parts.join(" + ");
}

function eventToAhk(e) {
    if (["Control", "Alt", "Shift", "Meta"].includes(e.key)) return "";
    if (e.key === "Escape") return "";

    let main;
    if (/^F\d{1,2}$/.test(e.key)) main = e.key;
    else if (e.key === " ") main = "Space";
    else if (e.key === "ArrowUp") main = "Up";
    else if (e.key === "ArrowDown") main = "Down";
    else if (e.key === "ArrowLeft") main = "Left";
    else if (e.key === "ArrowRight") main = "Right";
    else if (e.key === "PageUp") main = "PgUp";
    else if (e.key === "PageDown") main = "PgDn";
    else if (e.key === "Backspace") main = "BS";
    else if (e.key === "Delete") main = "Del";
    else if (e.key === "Insert") main = "Ins";
    else if (e.key.length === 1) main = e.key.toUpperCase();
    else main = e.key;

    let prefix = "";
    if (e.ctrlKey) prefix += "^";
    if (e.altKey) prefix += "!";
    if (e.shiftKey) prefix += "+";
    if (e.metaKey) prefix += "#";
    return prefix + main;
}

function setHotkeyField(field, ahkCombo) {
    field.dataset.raw = ahkCombo || "";
    field.value = ahkToFriendly(ahkCombo);
}

function initHotkeyFields() {
    document.querySelectorAll("[data-hotkey]").forEach((field) => {
        field.addEventListener("click", () => {
            document.querySelectorAll("[data-hotkey].is-capturing").forEach((f) => {
                f.classList.remove("is-capturing", "recording");
                setHotkeyField(f, f.dataset.raw);
            });
            field.classList.add("is-capturing", "recording");
            field.value = "Press a key…";
        });
    });

    document.addEventListener("keydown", (e) => {
        const field = document.querySelector("[data-hotkey].is-capturing");
        if (!field) return;
        e.preventDefault();
        const combo = eventToAhk(e);
        if (!combo) return;
        field.classList.remove("is-capturing", "recording");
        setHotkeyField(field, combo);
    });
}

// ---------------------------------------------------------------------------
// Tabs
// ---------------------------------------------------------------------------

function initTabs() {
    const nav = document.getElementById("nav");
    nav.addEventListener("click", (e) => {
        const btn = e.target.closest(".nav-item");
        if (!btn) return;
        nav.querySelectorAll(".nav-item").forEach((b) => b.classList.toggle("is-active", b === btn));
        document.querySelectorAll(".page").forEach((p) => p.classList.toggle("is-active", p.dataset.page === btn.dataset.tab));
    });
}

// ---------------------------------------------------------------------------
// Abbreviations (dynamic list, max 9)
// ---------------------------------------------------------------------------

const MAX_ABBR = 9;
let abbrs = [];

function renderAbbrList() {
    const list = document.getElementById("abbr-list");
    list.innerHTML = "";
    abbrs.forEach((val, i) => {
        const row = document.createElement("div");
        row.className = "abbr";

        const key = document.createElement("span");
        key.className = "abbr-key";
        key.textContent = String(i + 1);

        const input = document.createElement("input");
        input.className = "field";
        input.type = "text";
        input.maxLength = 24;
        input.placeholder = "e.g. " + (val || "VC name");
        input.value = val || "";
        input.addEventListener("input", () => {
            abbrs[i] = input.value;
        });

        const remove = document.createElement("button");
        remove.className = "abbr-remove";
        remove.type = "button";
        remove.textContent = "\u00d7";
        remove.title = "Remove";
        remove.addEventListener("click", () => {
            abbrs.splice(i, 1);
            renderAbbrList();
        });

        row.append(key, input, remove);
        list.appendChild(row);
    });
    document.getElementById("abbr-add").disabled = abbrs.length >= MAX_ABBR;
}

function initAbbr() {
    document.getElementById("abbr-add").addEventListener("click", () => {
        if (abbrs.length >= MAX_ABBR) return;
        abbrs.push("");
        renderAbbrList();
        const inputs = document.querySelectorAll("#abbr-list .field");
        if (inputs.length) inputs[inputs.length - 1].focus();
    });
}

function normAbbrs(list) {
    const out = list.slice(0, MAX_ABBR).map((v) => (v || "").trim());
    while (out.length && out[out.length - 1] === "") out.pop();
    return out;
}

// ---------------------------------------------------------------------------
// Render state
// ---------------------------------------------------------------------------

function render(state) {
    setHotkeyField(document.getElementById("vcHotkey"), state.vcHotkey);
    setHotkeyField(document.getElementById("staffHotkey"), state.staffHotkey);
    document.getElementById("staffEnabled").checked = !!state.staffEnabled;
    document.getElementById("saveCaptures").checked = !!state.saveCaptures;
    document.getElementById("logging").checked = !!state.logging;

    abbrs = (state.abbrs || []).slice();
    renderAbbrList();

    const models = document.getElementById("models");
    models.innerHTML = "";
    (state.models || []).forEach((m) => {
        const el = document.createElement("div");
        el.className = "model" + (m.key === state.model ? " is-selected" : "");
        el.dataset.key = m.key;
        const name = document.createElement("div");
        name.className = "model-name";
        name.textContent = m.label;
        const desc = document.createElement("div");
        desc.className = "model-desc";
        desc.textContent = m.desc;
        el.append(name, desc);
        el.addEventListener("click", () => {
            models.querySelectorAll(".model").forEach((x) => x.classList.toggle("is-selected", x === el));
            models.dataset.selected = m.key;
        });
        models.appendChild(el);
    });
    models.dataset.selected = state.model;

    const dot = document.getElementById("engine-dot");
    const label = document.getElementById("engine-label");
    dot.className = "engine-dot " + (state.engineOk ? "ok" : "bad");
    label.textContent = state.engineOk ? "Engine ready" : "Engine missing";

    renderAbout(state.debug || {});
}

function renderAbout(d) {
    const dl = document.getElementById("about-info");
    dl.innerHTML = "";
    const rows = [
        ["Version", d.version],
        ["Operating system", d.os],
        ["AutoHotkey", d.ahk],
        ["WebView2", d.webview2],
        ["Active model", d.model],
        ["OCR engine", d.engine],
        ["Data folder", d.dataDir],
    ];
    rows.forEach(([k, v]) => {
        const dt = document.createElement("dt");
        dt.textContent = k;
        const dd = document.createElement("dd");
        dd.textContent = v != null && v !== "" ? String(v) : "-";
        dl.append(dt, dd);
    });
    dl.dataset.raw = rows.map(([k, v]) => k + ": " + (v || "-")).join("\n");
}

function collect() {
    const models = document.getElementById("models");
    return {
        vcHotkey: document.getElementById("vcHotkey").dataset.raw || "",
        staffHotkey: document.getElementById("staffHotkey").dataset.raw || "",
        staffEnabled: document.getElementById("staffEnabled").checked,
        saveCaptures: document.getElementById("saveCaptures").checked,
        logging: document.getElementById("logging").checked,
        model: models.dataset.selected || "accurate",
        abbrs: normAbbrs(abbrs),
    };
}

function setStatus(message, kind) {
    const el = document.getElementById("status");
    el.textContent = message;
    el.dataset.kind = kind || "";
}

function initTitleBar() {
    const gui = (typeof ahk !== "undefined" && ahk.gui) ? ahk.gui : null;
    if (!gui) return;

    document.getElementById("win-min").addEventListener("click", () => gui.Minimize());
    document.getElementById("win-close").addEventListener("click", () => {
        if (typeof ahk.CloseWindow === "function") ahk.CloseWindow();
        else gui.Hide();
    });
}

// ---------------------------------------------------------------------------
// Actions
// ---------------------------------------------------------------------------

function initActions() {
    document.getElementById("save").addEventListener("click", async () => {
        setStatus("Saving…");
        try {
            setStatus((await Bridge.save(collect())) || "Saved.", "ok");
        } catch (e) {
            setStatus("Save failed: " + e, "err");
        }
    });

    document.getElementById("open-folder").addEventListener("click", () => Bridge.openDataFolder());

    document.getElementById("reset").addEventListener("click", async () => {
        if (!confirm("Reset all settings to their defaults?")) return;
        try {
            render(await Bridge.resetDefaults());
            setStatus("Defaults restored.", "ok");
        } catch (e) {
            setStatus("Reset failed: " + e, "err");
        }
    });

    document.getElementById("copy-debug").addEventListener("click", async () => {
        const raw = document.getElementById("about-info").dataset.raw || "";
        try {
            await navigator.clipboard.writeText(raw);
            setStatus("Debug info copied.", "ok");
        } catch {
            setStatus("Could not copy.", "err");
        }
    });
}

// ---------------------------------------------------------------------------
// Messages from AHK
// ---------------------------------------------------------------------------

if (window.chrome && window.chrome.webview) {
    window.chrome.webview.addEventListener("message", (event) => {
        let msg = event.data;
        if (typeof msg === "string") {
            try {
                msg = JSON.parse(msg);
            } catch {
                setStatus(msg);
                return;
            }
        }
        if (msg && msg.type === "status") setStatus(msg.message, msg.kind);
        else if (msg && msg.type === "state") render(msg.state);
    });
}

// ---------------------------------------------------------------------------
// Boot
// ---------------------------------------------------------------------------

async function boot() {
    initTabs();
    initHotkeyFields();
    initAbbr();
    initTitleBar();
    initActions();
    try {
        render(await Bridge.getState());
        setStatus(isHost ? "Ready." : "Preview mode (no AHK host).");
    } catch (e) {
        setStatus("Could not load settings: " + e, "err");
    }
}

document.addEventListener("DOMContentLoaded", boot);
