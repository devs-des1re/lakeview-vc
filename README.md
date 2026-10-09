# LakeviewVC

A lightweight AutoHotkey v2 desktop tool that reads a Roblox player's username
from the screen using offline OCR, resolves it to a real Roblox username via
public APIs, and sends the appropriate chat command.

> LakeviewVC is an independent tool and is not affiliated with, endorsed by, or
> associated with Lakeview City RP or Roblox Corporation.

## Features

- Offline OCR via [RapidOCR-json](https://github.com/hiroi-sora/RapidOCR-json)
  (no Python runtime required).
- Mouse-anchored screen capture — point at a username, press one hotkey. The
  capture is upscaled (default 2x) before OCR, which sharply improves accuracy
  on Roblox's small nametag text.
- Reads the `@username` shown on Roblox nametags directly; falls back to the
  official public APIs (validate, then search-and-match the display name) when
  no `@` token is present. Usernames are always used, never display names.
- Chat commands:
  - Normal: `;vc {username}`
  - Staff: `:log vc {username} {selection}`
- Dark HTML UI (AutoHotkey + WebView2) for hotkeys, capture size, model choice,
  staff abbreviations and settings.
- Minimizes to the system tray; tray left-click reopens, right-click offers
  _Open GUI_ and _Close App_.
- Configuration and logs saved to `%APPDATA%\LakeviewVC`.

## Requirements

- Windows 10/11
- [AutoHotkey v2](https://www.autohotkey.com/) (to run the script directly)

## Running

1. Install AutoHotkey v2.
2. Run `src/LakeviewVC.ahk`.
3. On first run, choose a model in the **Settings** tab — the selected model is
   downloaded to `%APPDATA%\LakeviewVC\models`. Nothing is downloaded until you
   press **Save**, so the base download stays small.

Hotkeys only fire while the Roblox window (`RobloxPlayerBeta.exe`) is focused,
so typing anywhere else never triggers a capture.

The UI is an HTML page hosted in a native window via WebView2 (Edge), bridged to
AutoHotkey. WebView2 is bundled with Windows 10/11; no browser install needed.

## License

MIT. See [LICENSE](./LICENSE).
