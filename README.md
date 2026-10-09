# LakeviewVC

A lightweight AutoHotkey v2 desktop tool that reads a Roblox player's username
from the screen using offline OCR, resolves it to a real Roblox username via
public APIs, and sends the appropriate chat command.

> LakeviewVC is an independent tool and is not affiliated with, endorsed by, or
> associated with Lakeview City RP or Roblox Corporation.

## Features

- Offline OCR via [RapidOCR-json](https://github.com/hiroi-sora/RapidOCR-json)
  (no Python runtime required).
- Mouse-anchored screen capture — point at a username, press one hotkey.
- Roblox username resolution using the official public APIs (validate a typed
  username, otherwise search and match the closest display name). Usernames are
  always used, never display names.
- Chat commands:
  - Normal: `;vc {username}`
  - Staff: `:log vc {username} {selection}`
- Tabbed, dark UI for hotkeys, capture size, model choice, staff abbreviations
  and settings.
- Minimizes to the system tray; tray left-click reopens, right-click offers
  *Open GUI* and *Close App*.
- Configuration and logs saved to `%APPDATA%\LakeviewVC`.

## Requirements

- Windows 10/11
- [AutoHotkey v2](https://www.autohotkey.com/) (to run the script directly)

## Running

1. Install AutoHotkey v2.
2. Run `src/LakeviewVC.ahk`.
3. On first run, choose a model in the **Settings** tab — the selected model is
   downloaded to `%APPDATA%\LakeviewVC\models`.

## Data locations

| Path | Contents |
| --- | --- |
| `%APPDATA%\LakeviewVC\config.ini` | Settings |
| `%APPDATA%\LakeviewVC\logs\*.log` | Action / capture / send logs |
| `%APPDATA%\LakeviewVC\logs\errors.log` | Errors for debugging |
| `%APPDATA%\LakeviewVC\captures\*.png` | Saved captures (optional) |
| `%APPDATA%\LakeviewVC\models\` | Downloaded OCR models |

## License

MIT. See [LICENSE](./LICENSE).
