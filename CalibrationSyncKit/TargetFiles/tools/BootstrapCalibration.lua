-- Fish Inc - Bootstrap Calibration config into the PLACE (editable in Studio).
-- Run this in Roblox Studio Command Bar (Server) while NOT playing:
--   require(game:GetService("ServerScriptService").Core.GameManager) -- (optional)
--   dofile or require not needed; just run:
--   require(game:GetService("ReplicatedStorage").Modules.Calibration).Init()
--
-- This file exists as a reference / discovery aid; the actual logic lives in
-- ReplicatedStorage.Modules.Calibration (it auto-provisions missing Config).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Calibration = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Calibration"))

Calibration.Init()
print("[FishInc] Calibration config ensured under ReplicatedStorage/Config/Calibration")


