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
		ensureString(r1, "Name", "Rebirth 1")
		ensureNumber(r1, "Id", 101, 1, 9999, true)
		ensureString(r1, "Models", "Orange Car, Purple Car")
		ensureNumber(r1, "OxygenRequired", 150, 0, 999999, true)
		ensureNumber(r1, "Movespeed", 17.6, 0, 300, false)
		ensureNumber(r1, "RebirthGoldMultiplier", 1.1, 1, 100, false)
		ensureNumber(r1, "Floor", 2, 0, 9999, true)
		ensureNumber(r1, "Pad", 11, 0, 9999, true)

		local upgrades = ensureFolder(calFolder, "Upgrades")
		local backLevels = ensureFolder(upgrades, "BackpackLevels")
		local bl1 = ensureFolder(backLevels, "1")
		ensureNumber(bl1, "Cost", 100000, 0, 999999999, true)
		ensureNumber(bl1, "NewLevel", 2, 0, 9999, true)
		local oxyLevels = ensureFolder(upgrades, "OxygenLevels")
		local ox100 = ensureFolder(oxyLevels, "100")
		ensureNumber(ox100, "Cost1", 500, 0, 9999999, true)
		ensureNumber(ox100, "NewLevel1", 101, 0, 9999999, true)
		ensureNumber(ox100, "Cost5", 2750, 0, 9999999, true)
		ensureNumber(ox100, "NewLevel5", 105, 0, 9999999, true)
		ensureNumber(ox100, "Cost10", 6125, 0, 9999999, true)
		ensureNumber(ox100, "NewLevel10", 110, 0, 9999999, true)
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
				Name = "",
				Id = 0,
				Models = {},
				OxygenRequired = 150,
				Movespeed = 16,
				RebirthGoldMultiplier = 1,
				Floor = nil,
				Pad = nil
			}

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

			local oxyInst = levelFolder:FindFirstChild("OxygenRequired")
			if oxyInst and oxyInst:IsA("IntValue") then desc.OxygenRequired = oxyInst.Value end

			local speedInst = levelFolder:FindFirstChild("Movespeed")
			if speedInst and speedInst:IsA("NumberValue") then desc.Movespeed = speedInst.Value end

			local goldInst = levelFolder:FindFirstChild("RebirthGoldMultiplier")
			if goldInst and goldInst:IsA("NumberValue") then desc.RebirthGoldMultiplier = goldInst.Value end
			
			local floorInst = levelFolder:FindFirstChild("Floor")
			if floorInst and floorInst:IsA("IntValue") then desc.Floor = floorInst.Value end
			
			local padInst = levelFolder:FindFirstChild("Pad")
			if padInst and padInst:IsA("IntValue") then desc.Pad = padInst.Value end

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
			if upgFolder.Name == "BackpackLevels" then
				local bpMap = {}
				for _, levelFolder in ipairs(upgFolder:GetChildren()) do
					local levelNum = tonumber(levelFolder.Name)
					if levelNum and levelFolder:IsA("Folder") then
						local lvlDesc = { Cost = 0, NewLevel = levelNum + 1 }
						
						local c = levelFolder:FindFirstChild("Cost")
						if c and c:IsA("IntValue") then lvlDesc.Cost = c.Value end
						local n = levelFolder:FindFirstChild("NewLevel")
						if n and n:IsA("IntValue") then lvlDesc.NewLevel = n.Value end
						
						bpMap[levelNum] = lvlDesc
					end
				end
				out["BackpackLevels"] = bpMap
			elseif upgFolder.Name == "OxygenLevels" then
				local oxyMap = {}
				for _, levelFolder in ipairs(upgFolder:GetChildren()) do
					local levelNum = tonumber(levelFolder.Name)
					if levelNum and levelFolder:IsA("Folder") then
						local lvlDesc = {
							Cost1 = 0, NewLevel1 = levelNum,
							Cost5 = 0, NewLevel5 = levelNum,
							Cost10 = 0, NewLevel10 = levelNum
						}
						
						local c1 = levelFolder:FindFirstChild("Cost1")
						if c1 and c1:IsA("IntValue") then lvlDesc.Cost1 = c1.Value end
						local n1 = levelFolder:FindFirstChild("NewLevel1")
						if n1 and n1:IsA("IntValue") then lvlDesc.NewLevel1 = n1.Value end
						
						local c5 = levelFolder:FindFirstChild("Cost5")
						if c5 and c5:IsA("IntValue") then lvlDesc.Cost5 = c5.Value end
						local n5 = levelFolder:FindFirstChild("NewLevel5")
						if n5 and n5:IsA("IntValue") then lvlDesc.NewLevel5 = n5.Value end
						
						local c10 = levelFolder:FindFirstChild("Cost10")
						if c10 and c10:IsA("IntValue") then lvlDesc.Cost10 = c10.Value end
						local n10 = levelFolder:FindFirstChild("NewLevel10")
						if n10 and n10:IsA("IntValue") then lvlDesc.NewLevel10 = n10.Value end
						
						oxyMap[levelNum] = lvlDesc
					end
				end
				out["OxygenLevels"] = oxyMap
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
	local rStats = cal.Rebirths[rebirthLevel]
	if rStats then
		return rStats.OxygenRequired
	end
	return math.huge -- Extremely high fallback if level out of bounds
end

function Calibration.GetUpgradePrice(statName, playerOxygenLevel, playerBackpackUpgrades)
	local cal = Calibration.Get()
	
	if statName == "Backpack" then
		local backpackLevel = (playerBackpackUpgrades or 0) + 1
		local bpMap = cal.Upgrades["BackpackLevels"]
		if not bpMap then return math.huge end
		
		local levelData = bpMap[backpackLevel]
		if not levelData then return math.huge end
		
		return levelData.Cost, levelData.NewLevel
	end

	-- Handling new explicit Oxygen map (Oxygen1, Oxygen5, Oxygen10)
	local oxyMap = cal.Upgrades["OxygenLevels"]
	if not oxyMap then return math.huge end
	
	local currentLvl = playerOxygenLevel or 100
	local levelData = oxyMap[currentLvl]
	
	-- Fallback if the requested level maxes out beyond the sheet
	if not levelData then return math.huge end
	
	if statName == "Oxygen1" then
		return levelData.Cost1, levelData.NewLevel1
	elseif statName == "Oxygen5" then
		return levelData.Cost5, levelData.NewLevel5
	elseif statName == "Oxygen10" then
		return levelData.Cost10, levelData.NewLevel10
	end

	return math.huge, currentLvl
end

return Calibration
