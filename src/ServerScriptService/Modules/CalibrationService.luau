local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Shared calibration (data-driven via ReplicatedStorage/Config/Calibration).
-- Server owns authoritative validation; clients can read for UI/VFX.
local Calibration = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Calibration"))

local CalibrationService = {}

function CalibrationService.Init()
	Calibration.Init()
end

function CalibrationService.Get()
	return Calibration.Get()
end

function CalibrationService.GetOxygenRequirement(level)
	return Calibration.GetOxygenRequirement(level)
end

function CalibrationService.GetUpgradePrice(statName, playerOxygenLevel, playerBackpackUpgrades)
	return Calibration.GetUpgradePrice(statName, playerOxygenLevel, playerBackpackUpgrades)
end

return CalibrationService


