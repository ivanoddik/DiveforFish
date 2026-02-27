# Calibration Sync Kit

This kit isolates the calibration plugin and the scripts it depends on, so you can transplant the system to another Roblox project.

## Core files to copy (required)

- `src/Plugins/CalibrationSync.plugin.lua`
- `src/ReplicatedStorage/Modules/Calibration.lua`
- `src/ReplicatedStorage/Modules/ConfigReader.lua`
- `src/ReplicatedStorage/Modules/Utilities.lua`
- `src/ServerScriptService/Services/CalibrationService.lua`

## Optional helper (recommended)

- `tools/BootstrapCalibration.lua`

Use this once in Studio to ensure `ReplicatedStorage/Config/Calibration` exists.

## Runtime container requirements in target game

- `ReplicatedStorage/Modules` must contain:
  - `Calibration`
  - `ConfigReader`
  - `Utilities`
- `ServerScriptService/Services` must contain:
  - `CalibrationService`
- Your server bootstrap must call:
  - `CalibrationService.Init()`

## Plugin behavior and data contract

`CalibrationSync.plugin.lua` writes synced values into:

- `ReplicatedStorage/Config/Calibration`

It fetches sheet data from the configured Apps Script endpoint and creates/updates Value objects under the calibration tree.

## Dependency map

- `CalibrationSync.plugin.lua`
  - Depends on Roblox services only (`HttpService`, `ReplicatedStorage`, `ChangeHistoryService`)
  - Writes calibration data instances under `ReplicatedStorage/Config/Calibration`
- `CalibrationService.lua`
  - Depends on `ReplicatedStorage.Modules.Calibration`
- `Calibration.lua`
  - Depends on `ReplicatedStorage.Modules.ConfigReader`
  - Depends on `ReplicatedStorage.Modules.Utilities`
  - Reads/watches `ReplicatedStorage/Config/Calibration`

## Consumers in this project (not required for transplant)

These currently read calibration values, but are game-specific. Do not copy unless you want their behavior:

- `src/ServerScriptService/Core/GameManager.lua` (init call)
- `src/ServerScriptService/Systems/*` (multiple systems)
- `src/ServerScriptService/Services/PlayerService.lua`
- `src/StarterPlayer/StarterPlayerScripts/*` (camera/UI/VFX clients)

## Transplant checklist

1. Copy the **required** files into matching service/module locations in the target game.
2. Ensure your startup script calls `CalibrationService.Init()` on server boot.
3. Install plugin by placing `CalibrationSync.plugin.lua` into your local Roblox plugins folder.
4. In Studio Command Bar, set plugin URL:

```lua
plugin:SetSetting("CalibrationSync_WebAppUrl", "https://script.google.com/macros/s/YOUR_SCRIPT_ID/exec")
```

5. Click **Calibration -> Sync Calibration** in Studio toolbar.
6. Verify `ReplicatedStorage/Config/Calibration` is populated.

## Notes

- The plugin is editor-time tooling; it is not required at runtime once data is synced.
- `Calibration.lua` auto-provisions defaults when config folders are missing.
- If your target game uses different stat naming, adapt the sheet processors in `CalibrationSync.plugin.lua`.
