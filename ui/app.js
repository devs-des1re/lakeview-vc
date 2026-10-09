"use strict";

// ---------------------------------------------------------------------------
// Bridge to AutoHotkey (WebViewToo host objects).
//
// The AHK side registers callbacks with AddCallbackToScript("Name", Func),
// which appear here as `ahk.Name(args...)`. Those calls return Promises, so we
// await the ones that return values. AHK pushes updates back with
// PostWebMessageAsJson(...) / PostWebMessageAsString(...), received via the
// 'message' event on window.chrome.webview.
// ---------------------------------------------------------------------------

const isHost = !!(window.chrome && window.chrome.webview && typeof ahk !== "undefined");

const mockState = {
    vcHotkey: "F8",
    staffHotkey: "F9",
    captureWidth: 420,
    captureHeight: 110,
    captureScale: 2,
    staffEnabled: false,
    saveCaptures: true,
    logging: true,
    model: "accurate",
    abbrs: ["", "", "", "", "", "", "", "", ""],
    models: [
        { key: "fast", label: "Fast", desc: "Lower CPU use, English-tuned recognition." },
        { key: "accurate", label: "Accurate", desc: "Best accuracy for usernames." },
    ],
    engineOk: true,
};

async function call(name, ...args) {
    if (isHost && typeof ahk[name] === "function") {
        return await ahk[name](...args);
    }
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

    async testCapture() {
        if (isHost) return await call("TestCapture");
        return "Preview mode: no capture taken.";
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
// Hotkey capture fields.
// ---------------------------------------------------------------------------

function initHotkeyFields() {
    document.querySelectorAll("[data-hotkey]").forEach((field) => {
        field.addEventListener("click", () => {
            document.querySelectorAll("[data-hotkey].is-capturing").forEach((f) => f.classList.remove("is-capturing"));
            field.classList.add("is-capturing");
            field.value = "Press keys…";
        });
    });

    document.addEventListener("keydown", (e) => {
        const field = document.querySelector("[data-hotkey].is-capturing");
        if (!field) return;
        e.preventDefault();
        const combo = describeCombo(e);
        if (!combo) return;
        field.value = combo;
        field.classList.remove("is-capturing");
    });
}

function describeCombo(e) {
    if (["Control", "Alt", "Shift", "Meta"].includes(e.key)) return "";
    if (e.key === "Escape") return "";

    let main = "";
    if (/^F\d{1,2}$/.test(e.key)) main = e.key;
    else if (e.key === " ") main = "Space";
    else if (e.key === "ArrowUp") main = "Up";
    else if (e.key === "ArrowDown") main = "Down";
    else if (e.key === "ArrowLeft") main = "Left";
    else if (e.key === "ArrowRight") main = "Right";
    else if (e.key.length === 1) main = e.key.toUpperCase();
    else main = e.key;

    let prefix = "";
    if (e.ctrlKey) prefix += "^";
    if (e.altKey) prefix += "!";
    if (e.shiftKey) prefix += "+";
    if (e.metaKey) prefix += "#";

    return prefix + main;
}

// ---------------------------------------------------------------------------
// Tabs
// ---------------------------------------------------------------------------

const PAGE_META = {
    general: ["General", "Normal VC capture settings."],
    staff: ["Staff", "Staff logging with 1-9 VC abbreviations."],
    settings: ["Settings", "Model, logging and data options."],
    about: ["About", "About LakeviewVC."],
};

function initTabs() {
    const nav = document.getElementById("nav");
    nav.addEventListener("click", (e) => {
        const btn = e.target.closest(".nav-item");
        if (!btn) return;
        const tab = btn.dataset.tab;
        nav.querySelectorAll(".nav-item").forEach((b) => b.classList.toggle("is-active", b === btn));
        document.querySelectorAll(".page").forEach((p) => p.classList.toggle("is-active", p.dataset.page === tab));
        document.getElementById("page-title").textContent = PAGE_META[tab][0];
        document.getElementById("page-sub").textContent = PAGE_META[tab][1];
    });
}

// ---------------------------------------------------------------------------
// State <-> DOM
// ---------------------------------------------------------------------------

function render(state) {
    document.getElementById("vcHotkey").value = state.vcHotkey || "";
    document.getElementById("staffHotkey").value = state.staffHotkey || "";
    document.getElementById("captureWidth").value = state.captureWidth;
    document.getElementById("captureHeight").value = state.captureHeight;
    document.getElementById("captureScale").value = state.captureScale;
    document.getElementById("staffEnabled").checked = !!state.staffEnabled;
    document.getElementById("saveCaptures").checked = !!state.saveCaptures;
    document.getElementById("logging").checked = !!state.logging;

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

    const grid = document.getElementById("abbr-grid");
    grid.innerHTML = "";
    (state.abbrs || []).forEach((val, i) => {
        const wrap = document.createElement("div");
        wrap.className = "abbr";
        const key = document.createElement("span");
        key.className = "abbr-key";
        key.textContent = String(i + 1);
        const input = document.createElement("input");
        input.className = "field";
        input.type = "text";
        input.maxLength = 24;
        input.value = val || "";
        wrap.append(key, input);
        grid.appendChild(wrap);
    });

    const dot = document.getElementById("engine-dot");
    const label = document.getElementById("engine-label");
    dot.className = "engine-dot " + (state.engineOk ? "ok" : "bad");
    label.textContent = state.engineOk ? "OCR engine ready" : "Engine missing";
}

function collect() {
    const models = document.getElementById("models");
    return {
        vcHotkey: document.getElementById("vcHotkey").value.trim(),
        staffHotkey: document.getElementById("staffHotkey").value.trim(),
        captureWidth: Number(document.getElementById("captureWidth").value) || 420,
        captureHeight: Number(document.getElementById("captureHeight").value) || 110,
        captureScale: Math.min(4, Math.max(1, Number(document.getElementById("captureScale").value) || 2)),
        staffEnabled: document.getElementById("staffEnabled").checked,
        saveCaptures: document.getElementById("saveCaptures").checked,
        logging: document.getElementById("logging").checked,
        model: models.dataset.selected || "accurate",
        abbrs: [...document.querySelectorAll("#abbr-grid .abbr input")].map((i) => i.value.trim()),
    };
}

function setStatus(message, kind) {
    const el = document.getElementById("status");
    el.textContent = message;
    el.dataset.kind = kind || "";
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

    document.getElementById("test-capture").addEventListener("click", async () => {
        setStatus("Testing capture…");
        try {
            setStatus((await Bridge.testCapture()) || "Done.", "ok");
        } catch (e) {
            setStatus("Test failed: " + e, "err");
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
    initActions();
    try {
        render(await Bridge.getState());
        setStatus(Bridge.isHost ? "Ready." : "Preview mode (no AHK host).");
    } catch (e) {
        setStatus("Could not load settings: " + e, "err");
    }
}

document.addEventListener("DOMContentLoaded", boot);
