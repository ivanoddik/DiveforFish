--[[
	CalibrationSync Plugin
	=======================
	Plugin para Roblox Studio que sincroniza dados de calibração
	de uma Google Spreadsheet (via Apps Script Web App) para o sistema Calibration.
	
	Adaptado para o projeto DIVE-FOR-CARS.
]]

-- Services
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ChangeHistoryService = game:GetService("ChangeHistoryService")

-- Plugin setup
local toolbar = plugin:CreateToolbar("Calibration")
local syncButton = toolbar:CreateButton(
	"Sync Calibration",
	"Download calibration values from Google Spreadsheet",
	"rbxassetid://6031075938" -- Sync icon
)

pcall(function()
	syncButton:SetActive(false)
end)

-- Plugin settings
local SETTING_WEBAPP_URL = "CalibrationSync_WebAppUrl"
local DEFAULT_WEBAPP_URL = "https://script.google.com/macros/s/AKfycbzWfZVHh2fBYDxFBmLAevfnBSfI1mRruPPdaHxbqdD3iMKgnmX5EkN4ckAPnQUgyQbFLQ/exec"

local function getPluginSetting(key)
	return plugin:GetSetting(key)
end

local function setPluginSetting(key, value)
	plugin:SetSetting(key, value)
end

local function getWebAppUrl()
	local savedUrl = getPluginSetting(SETTING_WEBAPP_URL)
	if savedUrl and savedUrl ~= "" then
		return savedUrl
	end
	return DEFAULT_WEBAPP_URL
end

local function fetchSheet(webAppUrl, sheetName)
	local url = string.format(
		"%s?sheetNameString=%s",
		webAppUrl,
		HttpService:UrlEncode(sheetName)
	)
	
	local success, response = pcall(function()
		return HttpService:GetAsync(url)
	end)
	
	if not success then
		return nil, "HTTP Error: " .. tostring(response)
	end
	
	local parseSuccess, data = pcall(function()
		return HttpService:JSONDecode(response)
	end)
	
	if not parseSuccess then
		return nil, "JSON Parse Error"
	end
	
	if type(data) == "table" and data.error then
		return nil, "Script Error: " .. tostring(data.error)
	end
	
	return data, nil
end

local function ensureFolder(parent, name)
	local folder = parent:FindFirstChild(name)
	if folder and folder:IsA("Folder") then
		return folder
	end
	folder = Instance.new("Folder")
	folder.Name = name
	folder.Parent = parent
	return folder
end

local function setNumberValue(parent, name, value, isInt)
	if value == nil then return false end
	
	local numValue = tonumber(value)
	if not numValue then return false end
	
	local existing = parent:FindFirstChild(name)
	if existing then
		if existing:IsA("NumberValue") or existing:IsA("IntValue") then
			existing.Value = isInt and math.floor(numValue + 0.5) or numValue
			return true
		end
	end
	
	local newValue = Instance.new(isInt and "IntValue" or "NumberValue")
	newValue.Name = name
	newValue.Value = isInt and math.floor(numValue + 0.5) or numValue
	newValue.Parent = parent
	return true
end

local function setStringValue(parent, name, value)
	if value == nil then return false end
	
	local existing = parent:FindFirstChild(name)
	if existing and existing:IsA("StringValue") then
		existing.Value = tostring(value)
		return true
	end
	
	local newValue = Instance.new("StringValue")
	newValue.Name = name
	newValue.Value = tostring(value)
	newValue.Parent = parent
	return true
end

local function setColor3Value(parent, name, valueStr)
	if valueStr == nil or valueStr == "" then return false end
	
	local r, g, b = valueStr:match("(%d+)%s*,%s*(%d+)%s*,%s*(%d+)")
	if not r or not g or not b then return false end
	
	local color = Color3.fromRGB(tonumber(r), tonumber(g), tonumber(b))
	
	local existing = parent:FindFirstChild(name)
	if existing and existing:IsA("Color3Value") then
		existing.Value = color
		return true
	end
	
	local newValue = Instance.new("Color3Value")
	newValue.Name = name
	newValue.Value = color
	newValue.Parent = parent
	return true
end

--------------------------------------------------------------------------------
-- Processors for DIVE-FOR-CARS Schema
--------------------------------------------------------------------------------

local function processModelsSheet(data, calibration)
	local updated = 0
	local modelsFolder = ensureFolder(calibration, "Models")
	
	for modelName, rowData in pairs(data) do
		if type(rowData) == "table" then
			local rarity = rowData["Rarity"]
			if rarity and rarity ~= "" then
				local rarityFolder = ensureFolder(modelsFolder, rarity)
				local carFolder = ensureFolder(rarityFolder, modelName)
				
				if rowData["Earnings"] ~= nil and setNumberValue(carFolder, "Earnings", rowData["Earnings"], true) then updated += 1 end
				if rowData["BaseTime"] ~= nil and setNumberValue(carFolder, "BaseTime", rowData["BaseTime"], false) then updated += 1 end
				
				local iconsFolder = ensureFolder(carFolder, "Icons")
				if rowData["NormalIcon"] ~= nil and setStringValue(iconsFolder, "Normal", rowData["NormalIcon"]) then updated += 1 end
				if rowData["GoldIcon"] ~= nil and setStringValue(iconsFolder, "Gold", rowData["GoldIcon"]) then updated += 1 end
				if rowData["DiamondIcon"] ~= nil and setStringValue(iconsFolder, "Diamond", rowData["DiamondIcon"]) then updated += 1 end
				if rowData["EmeraldIcon"] ~= nil and setStringValue(iconsFolder, "Emerald", rowData["EmeraldIcon"]) then updated += 1 end
				if rowData["BloodIcon"] ~= nil and setStringValue(iconsFolder, "Blood", rowData["BloodIcon"]) then updated += 1 end
			end
		end
	end
	return updated
end

local function processMutationsSheet(data, calibration)
	local updated = 0
	local mutationsFolder = ensureFolder(calibration, "Mutations")
	
	for mutationName, rowData in pairs(data) do
		if type(rowData) == "table" then
			local mFolder = ensureFolder(mutationsFolder, mutationName)
			
			if rowData["Color"] ~= nil and setColor3Value(mFolder, "Color", rowData["Color"]) then updated += 1 end
			if rowData["FillColor"] ~= nil and setColor3Value(mFolder, "FillColor", rowData["FillColor"]) then updated += 1 end
			if rowData["OutlineColor"] ~= nil and setColor3Value(mFolder, "OutlineColor", rowData["OutlineColor"]) then updated += 1 end
			if rowData["Multiplier"] ~= nil and setNumberValue(mFolder, "Multiplier", rowData["Multiplier"], false) then updated += 1 end
		end
	end
	return updated
end

local function processRebirthsSheet(data, calibration)
	local updated = 0
	local rebirthsFolder = ensureFolder(calibration, "Rebirths")
	
	for levelStr, rowData in pairs(data) do
		local level = tonumber(levelStr)
		if level and type(rowData) == "table" then
			local rFolder = ensureFolder(rebirthsFolder, tostring(level))
			
			if rowData["Type"] ~= nil and setStringValue(rFolder, "Type", rowData["Type"]) then updated += 1 end
			if rowData["Name"] ~= nil and rowData["Name"] ~= "" and setStringValue(rFolder, "Name", rowData["Name"]) then updated += 1 end
			if rowData["Id"] ~= nil and rowData["Id"] ~= "" and setNumberValue(rFolder, "Id", rowData["Id"], true) then updated += 1 end
			if rowData["Models"] ~= nil and setStringValue(rFolder, "Models", rowData["Models"]) then updated += 1 end
			
			if rowData["OxygenBase"] ~= nil and setNumberValue(rFolder, "OxygenBase", rowData["OxygenBase"], true) then updated += 1 end
			if rowData["OxygenIncrement"] ~= nil and setNumberValue(rFolder, "OxygenIncrement", rowData["OxygenIncrement"], true) then updated += 1 end
		end
	end
	return updated
end

local function processBackpackUpgradesSheet(data, calibration)
	local updated = 0
	local upgradesFolder = ensureFolder(calibration, "Upgrades")
	
	for upgradeType, rowData in pairs(data) do
		if type(rowData) == "table" and upgradeType == "Backpack" then
			local tFolder = ensureFolder(upgradesFolder, upgradeType)
			if rowData["LevelCosts"] ~= nil and setStringValue(tFolder, "LevelCosts", rowData["LevelCosts"]) then updated += 1 end
		end
	end
	return updated
end

local function processOxygenUpgradesSheet(data, calibration)
	local updated = 0
	local upgradesFolder = ensureFolder(calibration, "Upgrades")
	
	for upgradeType, rowData in pairs(data) do
		if type(rowData) == "table" and string.match(upgradeType, "^Oxygen") then
			local tFolder = ensureFolder(upgradesFolder, upgradeType)
			if rowData["BasePrice"] ~= nil and setNumberValue(tFolder, "BasePrice", rowData["BasePrice"], true) then updated += 1 end
			if rowData["BaseIncrement"] ~= nil and setNumberValue(tFolder, "BaseIncrement", rowData["BaseIncrement"], true) then updated += 1 end
			if rowData["IncrementModifier"] ~= nil and setNumberValue(tFolder, "IncrementModifier", rowData["IncrementModifier"], true) then updated += 1 end
		end
	end
	return updated
end

local function syncCalibration()
	local webAppUrl = getWebAppUrl()
	print("[CalibrationSync] Starting sync from Web App...")
	
	local config = ensureFolder(ReplicatedStorage, "Config")
	local calibration = ensureFolder(config, "Calibration")
	
	local totalUpdated = 0
	local errors = {}
	
	local sheetsToProcess = {
		{ names = {"Models", "Cars"}, processor = processModelsSheet },
		{ names = {"Mutations"}, processor = processMutationsSheet },
		{ names = {"Rebirths"}, processor = processRebirthsSheet },
		{ names = {"BackpackUpgrades"}, processor = processBackpackUpgradesSheet },
		{ names = {"OxygenUpgrades"}, processor = processOxygenUpgradesSheet },
	}
	
	for _, sheetConfig in ipairs(sheetsToProcess) do
		local data, err = nil, nil
		local usedName = nil
		
		for _, name in ipairs(sheetConfig.names) do
			print(string.format("[CalibrationSync] Trying '%s'...", name))
			data, err = fetchSheet(webAppUrl, name)
			if data then
				usedName = name
				break
			end
		end
		
		if data then
			local updated = sheetConfig.processor(data, calibration)
			totalUpdated = totalUpdated + updated
			print(string.format("[CalibrationSync] '%s': %d values updated", usedName, updated))
		else
			local namesStr = table.concat(sheetConfig.names, ", ")
			table.insert(errors, namesStr .. ": " .. (err or "Unknown error"))
			warn(string.format("[CalibrationSync] Error fetching sheets [%s]: %s", namesStr, err or "Unknown"))
		end
	end
	
	ChangeHistoryService:SetWaypoint("CalibrationSync")
	
	if #errors > 0 then
		warn("[CalibrationSync] Completed with errors:")
		for _, err in ipairs(errors) do
			warn("  - " .. err)
		end
	end
	
	print(string.format("[CalibrationSync] ✅ Sync complete! Updated %d values.", totalUpdated))
end

local isSyncing = false
local readyForManualClick = false
local loadedAt = os.clock()
local CLICK_GUARD_SECONDS = 1.0

task.delay(CLICK_GUARD_SECONDS, function()
	readyForManualClick = true
end)

syncButton.Click:Connect(function()
	if (not readyForManualClick) or (os.clock() - loadedAt < CLICK_GUARD_SECONDS) then
		return
	end
	if isSyncing then
		warn("[CalibrationSync] Sync already in progress...")
		return
	end
	
	isSyncing = true
	syncButton.Enabled = false
	
	local success, err = pcall(syncCalibration)
	
	if not success then
		warn("[CalibrationSync] Error during sync: " .. tostring(err))
	end
	
	isSyncing = false
	syncButton.Enabled = true
end)

print("[CalibrationSync] Plugin loaded. Configure with:")
print([[  plugin:SetSetting('CalibrationSync_WebAppUrl', 'https://script.google.com/macros/s/YOUR_SCRIPT_ID/exec')]])
