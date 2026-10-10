"use strict";

// VC picker popup. AHK pushes the abbreviation list via PostWebMessageAsJson and
// receives the chosen number (or cancel) through the host-object callback `ahk.Choose`.

let items = [];

function hostFn(name) {
    try {
        if (typeof ahk !== "undefined" && ahk) return ahk[name];
    } catch {
        /* not in host */
    }
    return undefined;
}

function render() {
    const list = document.getElementById("list");
    list.innerHTML = "";
    items.forEach((abbr, i) => {
        const row = document.createElement("button");
        row.className = "picker-item";
        row.type = "button";
        const key = document.createElement("span");
        key.className = "picker-key";
        key.textContent = String(i + 1);
        const label = document.createElement("span");
        label.className = "picker-label";
        label.textContent = abbr;
        row.append(key, label);
        row.addEventListener("click", () => choose(String(i + 1)));
        list.appendChild(row);
    });
}

function choose(num) {
    const fn = hostFn("Choose");
    if (!fn) return;
    try {
        Promise.resolve(fn(num)).catch(() => {});
    } catch {
        /* ignore */
    }
}

function ready() {
    const fn = hostFn("Ready");
    if (!fn) return;
    try {
        Promise.resolve(fn()).catch(() => {});
    } catch {
        /* ignore */
    }
}

document.addEventListener("keydown", (e) => {
    if (e.key === "Escape") return choose("cancel");
    if (/^[1-9]$/.test(e.key)) choose(e.key);
});

if (window.chrome && window.chrome.webview) {
    window.chrome.webview.addEventListener("message", (event) => {
        let msg = event.data;
        if (typeof msg === "string") {
            try {
                msg = JSON.parse(msg);
            } catch {
                return;
            }
        }
        if (msg && msg.type === "items") {
            items = msg.items || [];
            render();
        }
    });
}

document.addEventListener("DOMContentLoaded", () => {
    render();
    ready();
});
