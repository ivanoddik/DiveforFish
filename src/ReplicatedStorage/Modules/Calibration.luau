local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Utilities = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Utilities"))
local ConfigReader = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("ConfigReader"))

local Calibration = {}

local _calibration = nil
local _bound = false
local _changeMaid = nil

--------------------------------------------------------------------------------
-- SCHEMA DEFAULTS & INITIALIZATION
--------------------------------------------------------------------------------

local function getRoot()
	local function ensureFolder(parent, name)
		local f = parent:FindFirstChild(name)
		if f and f:IsA("Folder") then
			return f
		end
		f = Instance.new("Folder")
		f.Name = name
		f.Parent = parent
		return f
	end

	local function ensureNumber(parent, name, value, minV, maxV, isInt)
		local v = parent:FindFirstChild(name)
		local created = false
		if not (v and (v:IsA("NumberValue") or v:IsA("IntValue"))) then
			v = Instance.new(isInt and "IntValue" or "NumberValue")
			v.Name = name
			v.Parent = parent
			created = true
		end
		if created and type(value) == "number" then
			v.Value = isInt and math.floor(value + 0.5) or value
		end
		if type(minV) == "number" then
			v:SetAttribute("Min", minV)
		end
		if type(maxV) == "number" then
			v:SetAttribute("Max", maxV)
		end
		return v
	end

	local function ensureString(parent, name, value)
		local v = parent:FindFirstChild(name)
		local created = false
		if not (v and v:IsA("StringValue")) then
			v = Instance.new("StringValue")
			v.Name = name
			v.Parent = parent
			created = true
		end
		if created and type(value) == "string" then
			v.Value = value
		end
		return v
	end

	local function ensureColor3(parent, name, value)
		local v = parent:FindFirstChild(name)
		local created = false
		if not (v and v:IsA("Color3Value")) then
			v = Instance.new("Color3Value")
			v.Name = name
			v.Parent = parent
			created = true
		end
		if created and typeof(value) == "Color3" then
			v.Value = value
		end
		return v
	end

	local function ensureDefaults(calFolder)
		-- Provide functional backups if the sheet hasn't synced yet.
		local models = ensureFolder(calFolder, "Models")
		local common = ensureFolder(models, "Common")
		local car = ensureFolder(common, "Orange Car")
		ensureNumber(car, "Earnings", 15, 0, 99999, true)
		ensureNumber(car, "BaseTime", 60, 0, 9999, false)
		local icons = ensureFolder(car, "Icons")
		ensureString(icons, "Normal", "rbxassetid://100378056095272")

		local mutations = ensureFolder(calFolder, "Mutations")
		local gold = ensureFolder(mutations, "Gold")
		ensureColor3(gold, "Color", Color3.fromRGB(226, 155, 64))
		ensureColor3(gold, "FillColor", Color3.fromRGB(255, 170, 0))
		ensureColor3(gold, "OutlineColor", Color3.fromRGB(188, 125, 0))
		ensureNumber(gold, "Multiplier", 1.2, 1, 100, false)

		local rebirths = ensureFolder(calFolder, "Rebirths")
		local r1 = ensureFolder(rebirths, "1")
		ensureString(r1, "Type", "Floor")
		ensureString(r1, "Name", "Floor2")
		ensureString(r1, "Models", "Orange Car, Rolls Car")

		local upgrades = ensureFolder(calFolder, "Upgrades")
		local back = ensureFolder(upgrades, "Backpack")
		ensureString(back, "LevelCosts", "500000, 25000000, 1000000000")
		local ox1 = ensureFolder(upgrades, "Oxygen1")
		ensureNumber(ox1, "BasePrice", 500, 0, 9999999, true)
		ensureNumber(ox1, "BaseIncrement", 25, 0, 9999, true)
		ensureNumber(ox1, "IncrementModifier", 1, 1, 10, true)
	end

	local config = ReplicatedStorage:FindFirstChild("Config")
	if not (config and config:IsA("Folder")) then
		warn("[Calibration] Missing Config folder. Creating runtime defaults under ReplicatedStorage/Config/Calibration.")
		config = ensureFolder(ReplicatedStorage, "Config")
	end

	local cal = config:FindFirstChild("Calibration")
	if not (cal and cal:IsA("Folder")) then
		warn("[Calibration] Missing ReplicatedStorage/Config/Calibration. Creating runtime defaults.")
		cal = ensureFolder(config, "Calibration")
	end

	ensureDefaults(cal)
	return cal
end

--------------------------------------------------------------------------------
-- RUNTIME DATA READERS
--------------------------------------------------------------------------------

local function readModels(root)
	local out = {}
	local modelsFolder = root:FindFirstChild("Models")
	if not modelsFolder then return out end

	for _, rarityFolder in ipairs(modelsFolder:GetChildren()) do
		if rarityFolder:IsA("Folder") then
			local rarity = rarityFolder.Name
			out[rarity] = {}

			for _, carFolder in ipairs(rarityFolder:GetChildren()) do
				if carFolder:IsA("Folder") then
					local desc = {
						Earnings = 0,
						BaseTime = 0,
						Icons = {}
					}

					local earnInst = carFolder:FindFirstChild("Earnings")
					if earnInst and earnInst:IsA("IntValue") then desc.Earnings = earnInst.Value end

					local timeInst = carFolder:FindFirstChild("BaseTime")
					if timeInst and timeInst:IsA("NumberValue") then desc.BaseTime = timeInst.Value end

					local iconsFolder = carFolder:FindFirstChild("Icons")
					if iconsFolder and iconsFolder:IsA("Folder") then
						for _, it in ipairs(iconsFolder:GetChildren()) do
							if it:IsA("StringValue") then
								desc.Icons[it.Name] = it.Value
							end
						end
					end

					out[rarity][carFolder.Name] = desc
				end
			end
		end
	end
	return out
end

local function readMutations(root)
	local out = {}
	local mutFolder = root:FindFirstChild("Mutations")
	if not mutFolder then return out end

	for _, mFolder in ipairs(mutFolder:GetChildren()) do
		if mFolder:IsA("Folder") then
			local desc = {
				Color = Color3.fromRGB(255, 255, 255),
				FillColor = Color3.fromRGB(255, 255, 255),
				OutlineColor = Color3.fromRGB(0, 0, 0),
				Multiplier = 1
			}

			local colInst = mFolder:FindFirstChild("Color")
			if colInst and colInst:IsA("Color3Value") then desc.Color = colInst.Value end

			local fillInst = mFolder:FindFirstChild("FillColor")
			if fillInst and fillInst:IsA("Color3Value") then desc.FillColor = fillInst.Value end

			local outInst = mFolder:FindFirstChild("OutlineColor")
			if outInst and outInst:IsA("Color3Value") then desc.OutlineColor = outInst.Value end

			local multInst = mFolder:FindFirstChild("Multiplier")
			if multInst and multInst:IsA("NumberValue") then desc.Multiplier = multInst.Value end

			out[mFolder.Name] = desc
		end
	end

	return out
end

local function readRebirths(root)
	local out = {}
	local rFolder = root:FindFirstChild("Rebirths")
	if not rFolder then return out end

	for _, levelFolder in ipairs(rFolder:GetChildren()) do
		local levelNum = tonumber(levelFolder.Name)
		if levelNum and levelFolder:IsA("Folder") then
			local desc = {
				Type = "Pad",
				Name = "",
				Id = 0,
				Models = {},
				OxygenBase = 150,
				OxygenIncrement = 25
			}

			local typeInst = levelFolder:FindFirstChild("Type")
			if typeInst and typeInst:IsA("StringValue") then desc.Type = typeInst.Value end

			local nameInst = levelFolder:FindFirstChild("Name")
			if nameInst and nameInst:IsA("StringValue") then desc.Name = nameInst.Value end

			local idInst = levelFolder:FindFirstChild("Id")
			if idInst and idInst:IsA("IntValue") then desc.Id = idInst.Value end

			local modInst = levelFolder:FindFirstChild("Models")
			if modInst and modInst:IsA("StringValue") then
				for token in string.gmatch(modInst.Value, "[^,]+") do
					-- trim spaces
					local m = token:match("^%s*(.-)%s*$")
					table.insert(desc.Models, m)
				end
			end

			-- Check for Rebirths logic overrides
			local oxBInst = levelFolder:FindFirstChild("OxygenBase")
			if oxBInst and oxBInst:IsA("IntValue") then desc.OxygenBase = oxBInst.Value end

			local oxIInst = levelFolder:FindFirstChild("OxygenIncrement")
			if oxIInst and oxIInst:IsA("IntValue") then desc.OxygenIncrement = oxIInst.Value end

			out[levelNum] = desc
		end
	end

	return out
end

local function readUpgrades(root)
	local out = {}
	local uFolder = root:FindFirstChild("Upgrades")
	if not uFolder then return out end

	for _, upgFolder in ipairs(uFolder:GetChildren()) do
		if upgFolder:IsA("Folder") then
			if upgFolder.Name == "Backpack" then
				local desc = { Costs = {} }
				local cInst = upgFolder:FindFirstChild("LevelCosts")
				if cInst and cInst:IsA("StringValue") then
					for token in string.gmatch(cInst.Value, "[^,]+") do
						local cost = tonumber(token:match("^%s*(.-)%s*$"))
						if cost then
							table.insert(desc.Costs, cost)
						end
					end
				end
				out[upgFolder.Name] = desc
			elseif upgFolder.Name == "BackpackLevels" then
				local desc = {}
				for _, lvlFolder in ipairs(upgFolder:GetChildren()) do
					if lvlFolder:IsA("Folder") then
						local levelNum = tonumber(lvlFolder.Name)
						if levelNum then
							local costInst = lvlFolder:FindFirstChild("Cost")
							local newLevelInst = lvlFolder:FindFirstChild("NewLevel")
							desc[levelNum] = {
								Cost = costInst and costInst.Value or math.huge,
								NewLevel = newLevelInst and newLevelInst.Value or nil
							}
						end
					end
				end
				out[upgFolder.Name] = desc
			elseif upgFolder.Name == "OxygenLevels" then
				local desc = {}
				for _, lvlFolder in ipairs(upgFolder:GetChildren()) do
					if lvlFolder:IsA("Folder") then
						local levelNum = tonumber(lvlFolder.Name)
						if levelNum then
							local cost1 = lvlFolder:FindFirstChild("Cost1")
							local newLevel1 = lvlFolder:FindFirstChild("NewLevel1")
							local cost5 = lvlFolder:FindFirstChild("Cost5")
							local newLevel5 = lvlFolder:FindFirstChild("NewLevel5")
							local cost10 = lvlFolder:FindFirstChild("Cost10")
							local newLevel10 = lvlFolder:FindFirstChild("NewLevel10")
							
							desc[levelNum] = {
								Cost1 = cost1 and cost1.Value,
								NewLevel1 = newLevel1 and newLevel1.Value,
								Cost5 = cost5 and cost5.Value,
								NewLevel5 = newLevel5 and newLevel5.Value,
								Cost10 = cost10 and cost10.Value,
								NewLevel10 = newLevel10 and newLevel10.Value,
							}
						end
					end
				end
				out[upgFolder.Name] = desc
			else
				-- Oxygen items
				local desc = {
					BasePrice = 0,
					BaseIncrement = 0,
					IncrementModifier = 1
				}
				local pInst = upgFolder:FindFirstChild("BasePrice")
				if pInst and pInst:IsA("IntValue") then desc.BasePrice = pInst.Value end

				local iInst = upgFolder:FindFirstChild("BaseIncrement")
				if iInst and iInst:IsA("IntValue") then desc.BaseIncrement = iInst.Value end

				local mInst = upgFolder:FindFirstChild("IncrementModifier")
				if mInst and mInst:IsA("IntValue") then desc.IncrementModifier = mInst.Value end

				out[upgFolder.Name] = desc
			end
		end
	end

	return out
end

local function buildCalibration()
	local root = getRoot()

	local cal = {
		Models = readModels(root),
		Mutations = readMutations(root),
		Rebirths = readRebirths(root),
		Upgrades = readUpgrades(root),
	}

	return cal
end

local function bindChangeTracking()
	if _bound then
		return
	end
	_bound = true

	local root = getRoot()
	_changeMaid = Utilities.Maid.new()

	local function invalidate()
		_calibration = nil
	end

	_changeMaid:Give(root.DescendantAdded:Connect(function(desc)
		invalidate()
		_changeMaid:Give(desc.Changed:Connect(invalidate))
	end))

	_changeMaid:Give(root.DescendantRemoving:Connect(function()
		invalidate()
	end))

	for _, d in ipairs(root:GetDescendants()) do
		_changeMaid:Give(d.Changed:Connect(invalidate))
	end
end

--------------------------------------------------------------------------------
-- PUBLIC API
--------------------------------------------------------------------------------

function Calibration.Init()
	_calibration = buildCalibration()
	bindChangeTracking()
end

function Calibration.Get()
	if not _calibration then
		Calibration.Init()
	end
	return Utilities.DeepCopy(_calibration)
end

-- Recreations of DIVE-FOR-CARS hardcoded APIs

function Calibration.GetOxygenRequirement(rebirthLevel)
	local cal = Calibration.Get()
	local rStats = cal.Rebirths[1] -- Typically the base/increment stats apply to all, or are stored in level 1
	if rStats then
		return rStats.OxygenBase + (rebirthLevel - 1) * rStats.OxygenIncrement
	end
	return 150 + (rebirthLevel - 1) * 25
end

function Calibration.GetUpgradePrice(statName, playerOxygenLevel, playerBackpackUpgrades)
	local cal = Calibration.Get()
	
	if statName == "Backpack" then
		local backpackLevel = (playerBackpackUpgrades or 0) + 1
		local levelsCfg = cal.Upgrades["BackpackLevels"]
		if levelsCfg and levelsCfg[backpackLevel] then
			return levelsCfg[backpackLevel].Cost, levelsCfg[backpackLevel].NewLevel
		end
		
		local cfg = cal.Upgrades["Backpack"]
		if cfg and cfg.Costs and cfg.Costs[backpackLevel] then
			return cfg.Costs[backpackLevel]
		end
		return math.huge
	end

	if statName == "Oxygen1" or statName == "Oxygen5" or statName == "Oxygen10" then
		local oxygenLevel = playerOxygenLevel or 100
		local levelsCfg = cal.Upgrades["OxygenLevels"]
		
		if levelsCfg and levelsCfg[oxygenLevel] then
			local t = levelsCfg[oxygenLevel]
			if statName == "Oxygen1" and t.Cost1 then
				return t.Cost1, t.NewLevel1
			elseif statName == "Oxygen5" and t.Cost5 then
				return t.Cost5, t.NewLevel5
			elseif statName == "Oxygen10" and t.Cost10 then
				return t.Cost10, t.NewLevel10
			end
		end
	end

	-- Legacy fallback: Oxygen Tier 1, 5, 10
	local cfg = cal.Upgrades[statName]
	if not cfg then return math.huge end

	local basePrice = cfg.BasePrice
	local currentIncrement = cfg.BaseIncrement
	local totalPrice = basePrice

	local loopMod = cfg.IncrementModifier
	
	for i = 1, (playerOxygenLevel or 0) do
		totalPrice += currentIncrement
		
		-- Emulates original modulo additions
		if loopMod == 1 then
			currentIncrement += 1
		else
			if i % 2 == 0 then
				currentIncrement += loopMod
			end
		end
	end

	return totalPrice
end

return Calibration
