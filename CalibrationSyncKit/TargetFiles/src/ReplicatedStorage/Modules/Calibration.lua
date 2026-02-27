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
		ensureNumber(car, "BaseTime", 60, 0, 9999, false)
		ensureNumber(car, "SellValue", 500, 0, 99999, true)
		ensureNumber(car, "NormalEarnings", 15, 0, 99999, true)
		ensureNumber(car, "GoldEarnings", 30, 0, 99999, true)
		ensureNumber(car, "DiamondEarnings", 45, 0, 99999, true)
		ensureNumber(car, "EmeraldEarnings", 60, 0, 99999, true)
		ensureNumber(car, "BloodEarnings", 75, 0, 99999, true)
		local icons = ensureFolder(car, "Icons")
		ensureString(icons, "Normal", "rbxassetid://100378056095272")

		local mutations = ensureFolder(calFolder, "Mutations")
		local normal = ensureFolder(mutations, "Normal")
		ensureNumber(normal, "SpawnChance", 0.65, 0, 1, false)

		local gold = ensureFolder(mutations, "Gold")
		ensureColor3(gold, "Color", Color3.fromRGB(226, 155, 64))
		ensureColor3(gold, "FillColor", Color3.fromRGB(255, 170, 0))
		ensureColor3(gold, "OutlineColor", Color3.fromRGB(188, 125, 0))
		ensureNumber(gold, "SpawnChance", 0.15, 0, 1, false)

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

		local sZone = ensureFolder(calFolder, "SpawnZones")
		local dArea = ensureFolder(sZone, "DefaultArea")
		ensureNumber(dArea, "MaxCommon", 7, 0, 9999, true)
		ensureNumber(dArea, "MaxUncommon", 9, 0, 9999, true)
		ensureNumber(dArea, "MaxRare", 12, 0, 9999, true)
		ensureNumber(dArea, "MaxEpic", 12, 0, 9999, true)
		ensureNumber(dArea, "MaxLegendary", 9, 0, 9999, true)
		ensureNumber(dArea, "MaxMythical", 7, 0, 9999, true)
		ensureNumber(dArea, "MaxCosmic", 5, 0, 9999, true)
		ensureNumber(dArea, "MaxSecret", 4, 0, 9999, true)
		ensureNumber(dArea, "MinSpawnDistance", 8, 0, 9999, false)
		ensureNumber(dArea, "SpawnQueueDelay", 0.5, 0.05, 999, false)
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
						BaseTime = 0,
						SellValue = 0,
						NormalEarnings = 0,
						GoldEarnings = 0,
						DiamondEarnings = 0,
						EmeraldEarnings = 0,
						BloodEarnings = 0,
						Icons = {}
					}

					local timeInst = carFolder:FindFirstChild("BaseTime")
					if timeInst and timeInst:IsA("NumberValue") then desc.BaseTime = timeInst.Value end
					
					local sellInst = carFolder:FindFirstChild("SellValue")
					if sellInst and sellInst:IsA("IntValue") then desc.SellValue = sellInst.Value end

					local normInst = carFolder:FindFirstChild("NormalEarnings")
					if normInst and normInst:IsA("IntValue") then desc.NormalEarnings = normInst.Value end
					
					local goldInst = carFolder:FindFirstChild("GoldEarnings")
					if goldInst and goldInst:IsA("IntValue") then desc.GoldEarnings = goldInst.Value end
					
					local diaInst = carFolder:FindFirstChild("DiamondEarnings")
					if diaInst and diaInst:IsA("IntValue") then desc.DiamondEarnings = diaInst.Value end
					
					local emInst = carFolder:FindFirstChild("EmeraldEarnings")
					if emInst and emInst:IsA("IntValue") then desc.EmeraldEarnings = emInst.Value end
					
					local bloInst = carFolder:FindFirstChild("BloodEarnings")
					if bloInst and bloInst:IsA("IntValue") then desc.BloodEarnings = bloInst.Value end

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
				SpawnChance = 0
			}

			local colInst = mFolder:FindFirstChild("Color")
			if colInst and colInst:IsA("Color3Value") then desc.Color = colInst.Value end

			local fillInst = mFolder:FindFirstChild("FillColor")
			if fillInst and fillInst:IsA("Color3Value") then desc.FillColor = fillInst.Value end

			local outInst = mFolder:FindFirstChild("OutlineColor")
			if outInst and outInst:IsA("Color3Value") then desc.OutlineColor = outInst.Value end

			local spawnInst = mFolder:FindFirstChild("SpawnChance")
			if spawnInst and spawnInst:IsA("NumberValue") then desc.SpawnChance = spawnInst.Value end

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

local function readSpawnZones(root)
	local out = {}
	local zFolder = root:FindFirstChild("SpawnZones")
	if not zFolder then return out end
	
	for _, f in ipairs(zFolder:GetChildren()) do
		if f:IsA("Folder") then
			local desc = {
				MaxCommon = 7,
				MaxUncommon = 9,
				MaxRare = 12,
				MaxEpic = 12,
				MaxLegendary = 9,
				MaxMythical = 7,
				MaxCosmic = 5,
				MaxSecret = 4,
				MinSpawnDistance = 8,
				SpawnQueueDelay = 0.5
			}
			
			local function tryRead(propName)
				local inst = f:FindFirstChild(propName)
				if inst and (inst:IsA("IntValue") or inst:IsA("NumberValue")) then
					desc[propName] = inst.Value
				end
			end
			
			tryRead("MaxCommon") tryRead("MaxUncommon") tryRead("MaxRare") tryRead("MaxEpic")
			tryRead("MaxLegendary") tryRead("MaxMythical") tryRead("MaxCosmic") tryRead("MaxSecret")
			tryRead("MinSpawnDistance") tryRead("SpawnQueueDelay")
			
			out[f.Name] = desc
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
		SpawnZones = readSpawnZones(root),
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
	
	local currentLvl = playerOxygenLevel
	if currentLvl == nil or currentLvl == 0 then currentLvl = 100 end
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

function Calibration.GetModelEarnings(modelName, mutationName)
	local cal = Calibration.Get()
	for _, rarityTable in pairs(cal.Models) do
		local modelData = rarityTable[modelName]
		if modelData then
			local t = mutationName or "Normal"
			if t == "Normal" then return modelData.NormalEarnings or 0
			elseif t == "Gold" then return modelData.GoldEarnings or 0
			elseif t == "Diamond" then return modelData.DiamondEarnings or 0
			elseif t == "Emerald" then return modelData.EmeraldEarnings or 0
			elseif t == "Blood" then return modelData.BloodEarnings or 0
			end
			return modelData.NormalEarnings or 0
		end
	end
	return 0
end

function Calibration.GetSellValue(modelName)
	local cal = Calibration.Get()
	for _, rarityTable in pairs(cal.Models) do
		local modelData = rarityTable[modelName]
		if modelData then
			return modelData.SellValue or 0
		end
	end
	return 0
end

function Calibration.GetMutationSpawns()
	local cal = Calibration.Get()
	local spawns = {}
	for name, mData in pairs(cal.Mutations) do
		if mData.SpawnChance and mData.SpawnChance > 0 then
			table.insert(spawns, {name = name, chance = mData.SpawnChance})
		end
	end
	
	table.sort(spawns, function(a, b)
		return a.chance < b.chance
	end)
	
	return spawns
end

function Calibration.GetZoneSpawnLimits(zoneName)
	local cal = Calibration.Get()
	if cal and cal.SpawnZones and cal.SpawnZones[zoneName] then
		return cal.SpawnZones[zoneName]
	end
	
	return {
		MaxCommon = 7,
		MaxUncommon = 9,
		MaxRare = 12,
		MaxEpic = 12,
		MaxLegendary = 9,
		MaxMythical = 7,
		MaxCosmic = 5,
		MaxSecret = 4,
		MinSpawnDistance = 8,
		SpawnQueueDelay = 0.5
	}
end

return Calibration
