# AI Handoff Prompt - Calibration Tool Migration

Use this prompt with another AI assistant to continue the migration work.

---

## Prompt to Give the AI

You are helping migrate a Roblox calibration sync tool from an existing game into a different game.

### Context

I have extracted a calibration sync kit from a source project. The key files are:

- `src/Plugins/CalibrationSync.plugin.lua`
- `src/ReplicatedStorage/Modules/Calibration.lua`
- `src/ReplicatedStorage/Modules/ConfigReader.lua`
- `src/ReplicatedStorage/Modules/Utilities.lua`
- `src/ServerScriptService/Services/CalibrationService.lua`
- optional: `tools/BootstrapCalibration.lua`

The plugin syncs spreadsheet data into `ReplicatedStorage/Config/Calibration`.

### Critical Requirement

The calibrations for the **new game are completely different from the original project**.  
Do not assume the same stats, folders, sheet names, column headers, or balancing logic.

Treat the old calibration schema only as reference for architecture, not as functional design.

### Your Task

1. Audit the current calibration architecture (plugin + runtime modules).
2. Redesign the calibration schema for the new game requirements.
3. Refactor the plugin processors so they map to the new spreadsheet structure.
4. Keep runtime modules robust with safe fallbacks and validation.
5. Produce a migration plan and implement in small, testable steps.

### Constraints

- Preserve clean separation between:
  - editor-time sync tooling (plugin),
  - runtime read layer (`Calibration`, `CalibrationService`),
  - gameplay consumers.
- Do not break existing startup flow.
- Add warnings/errors when required keys are missing instead of silently failing.
- Prefer backward-compatible transition code while migrating.

### Expected Deliverables

1. Updated schema document:
   - calibration tree layout
   - required keys
   - types/defaults/ranges
2. Updated plugin logic:
   - new sheet list
   - new field mappings
   - deprecation/removal of old processors
3. Updated runtime API usage:
   - any new getters/helpers needed
   - validation and fallback behavior
4. Verification checklist:
   - plugin sync success
   - data appears correctly in `ReplicatedStorage/Config/Calibration`
   - gameplay systems read correct values

### Work Plan You Should Follow

1. Discover all current consumers of calibration values.
2. Propose a new schema based on the target game systems.
3. Implement schema + plugin mapping changes.
4. Adapt runtime accessors/getters.
5. Update consumers incrementally.
6. Run focused validation after each step.
7. Summarize changed files and remaining risks.

### Output Format

When reporting progress, provide:

- What changed
- Why it changed
- Which files were edited
- What still needs to be migrated
- Any assumptions needing confirmation

---

## Notes for Human Operator

- If needed, pair this with `CalibrationSyncKit/README.md` and `CalibrationSyncKit/FILES_MANIFEST.txt`.
- Ask the AI to start by proposing the new target calibration schema before changing code.
