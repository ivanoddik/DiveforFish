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

function CalibrationService.GetUpgradeCost(upgradeId, currentLevel)
	return Calibration.GetUpgradeCost(upgradeId, currentLevel)
end

function CalibrationService.ApplyUpgradeToStats(stats, upgradeId, newLevel)
	return Calibration.ApplyUpgradeToStats(stats, upgradeId, newLevel)
end

return CalibrationService


