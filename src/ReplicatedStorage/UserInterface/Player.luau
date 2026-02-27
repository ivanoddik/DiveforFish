local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")
local CollectionService = game:GetService("CollectionService")

local Player = {}

local player = Players.LocalPlayer
local pGui = player:WaitForChild("PlayerGui")
local mainGui = pGui:WaitForChild("Main", 60) or pGui:WaitForChild("Main")
local frames = mainGui:WaitForChild("Frames")

-- Index UI
local indexFrame = frames:WaitForChild("Index")
local mutationsPanel = indexFrame:WaitForChild("Mutations")
local mutationsScroll = mutationsPanel:WaitForChild("ScrollingFrame")
local mainScroll = indexFrame:WaitForChild("ScrollingFrame")
local modelsFrame = mainScroll:WaitForChild("ModelsFrame")
local holderTemplate = modelsFrame:WaitForChild("Holder")

local currentMutationFilter = "Normal"

-- Rebirth UI
local rebirthFrame = frames:WaitForChild("Rebirth")
local starterPackFrame = frames:WaitForChild("StarterPack")
local requirementsFrame = rebirthFrame:WaitForChild("Requirements")
local displayFrame = requirementsFrame:WaitForChild("Display")
local progressFrame = rebirthFrame:WaitForChild("Progress")
local progressTitle = progressFrame:WaitForChild("Title")
local progressBar = progressFrame:WaitForChild("Bar")
local buttonsFrame = rebirthFrame:WaitForChild("Buttons")
local rebirthBtn = buttonsFrame:WaitForChild("Rebirth")
local skipBtn = buttonsFrame:WaitForChild("Skip")

-- Upgrade UI
local oxygenFrame = frames:WaitForChild("Oxygen")
local oxygenHolder = oxygenFrame:WaitForChild("UpgradeHolder")
local backpackFrame = frames:WaitForChild("Carry")
local backpackHolder = backpackFrame:WaitForChild("UpgradeHolder")
local dailyFrame = frames:WaitForChild("Daily")
local dailyRewardFrame = dailyFrame:WaitForChild("Reward")
local dailyClaimBtn = dailyFrame:WaitForChild("Claim")
local dailyClaimTitle = dailyClaimBtn:WaitForChild("Title")

local Assets = ReplicatedStorage:WaitForChild("Storage"):WaitForChild("Assets")
local Calibration = require(ReplicatedStorage.Modules.Calibration)
local REMOTES = ReplicatedStorage:WaitForChild("Remotes")
local REBIRTH_SKIP = REMOTES:WaitForChild("RebirthSkip")
local UPDATE_COLLECTION = REMOTES:WaitForChild("UpdateCollection")
local UPGRADE_STAT = REMOTES:WaitForChild("UpgradeStat")
local CLAIM_DAILY = REMOTES:WaitForChild("ClaimDailyReward")
local UPDATE_DAILY = REMOTES:WaitForChild("UpdateDailyReward")

local Animations = require(ReplicatedStorage:WaitForChild("UserInterface"):WaitForChild("Animations"))
local Monetization = require(ReplicatedStorage:WaitForChild("UserInterface"):WaitForChild("Monetization"))

local GRADIENTS = {
	Gold = Assets:WaitForChild("GradientGold"),
	Diamond = Assets:WaitForChild("GradientDiamond"),
	Emerald = Assets:WaitForChild("GradientEmerald"),
	Blood = Assets:WaitForChild("GradientBlood")
}

local RARITY_COLORS = {
	["Common"] = Color3.fromRGB(95, 95, 95),
	["Uncommon"] = Color3.fromRGB(170, 255, 0),
	["Rare"] = Color3.fromRGB(85, 170, 255),
	["Epic"] = Color3.fromRGB(255, 170, 0),
	["Legendary"] = Color3.fromRGB(255, 85, 0),
	["Mythical"] = Color3.fromRGB(255, 0, 0),
	["Cosmic"] = Color3.fromRGB(170, 0, 255),
	["Secret"] = Color3.fromRGB(35, 35, 35)
}

local REWARD_TABLE = {
	[1] = { RewardName = "2x Speed (15m)", ImageID = "rbxassetid://80984811786217" },
	[2] = { RewardName = "Rolls Car", ImageID = "rbxassetid://119334840758630" },
	[3] = { RewardName = "10k Cash", ImageID = "rbxassetid://88231213378824" },
	[4] = { RewardName = "Green Car", ImageID = "rbxassetid://106352808274301" },
	[5] = { RewardName = "10k Cash", ImageID = "rbxassetid://88231213378824" },
	[6] = { RewardName = "2x Speed (15m)", ImageID = "rbxassetid://80984811786217" },
	[7] = { RewardName = "10k Cash", ImageID = "rbxassetid://88231213378824" },
}

local currentDailyDay = 1
local lastDailyClaim = 0
local DAY_SECONDS = 24 * 60 * 60

local function formatNumber(n)
	local suffixes = {
		{1e33, "Dc"}, {1e30, "No"}, {1e27, "Oc"}, {1e24, "Sp"}, {1e21, "Sx"},
		{1e18, "Qi"}, {1e15, "Qa"}, {1e12, "T"}, {1e9, "B"}, {1e6, "M"}, {1e3, "K"}
	}
	for _, suffix in ipairs(suffixes) do
		if n >= suffix[1] then
			local val = n / suffix[1]
			if val >= 10 then
				return string.format("$%d%s", math.floor(val), suffix[2])
			else
				return string.format("$%.1f%s", val, suffix[2])
			end
		end
	end
	return string.format("$%d", math.floor(n))
end

local function updateDailyUI()
	local reward = REWARD_TABLE[currentDailyDay]
	local icon = dailyRewardFrame:FindFirstChild("RewardIcon", true)
	local name = dailyRewardFrame:FindFirstChild("RewardName", true)
	
	local now = os.time()
	local diff = now - lastDailyClaim
	
    local timeStr = ""
    local canClaim = lastDailyClaim == 0 or diff >= DAY_SECONDS

	if canClaim then
		if icon then icon.Image = reward.ImageID end
		if name then name.Text = reward.RewardName end
		dailyClaimTitle.Text = "Claim"
		dailyClaimBtn.ImageColor3 = Color3.new(1, 1, 1)
        timeStr = "Claim"
	else
		if icon then icon.Image = "rbxassetid://140126148854413" end
		if name then name.Text = reward and reward.RewardName or "" end
		
		local remaining = DAY_SECONDS - diff
		local hours = math.floor(remaining / 3600)
		local mins = math.floor((remaining % 3600) / 60)
		local secs = remaining % 60
        timeStr = string.format("%02d:%02d:%02d", hours, mins, secs)
		dailyClaimTitle.Text = timeStr
		dailyClaimBtn.ImageColor3 = Color3.fromRGB(150, 150, 150)
	end

    -- Update Billboard
    local dailyModel = workspace:FindFirstChild("Map") and workspace.Map:FindFirstChild("Important") and workspace.Map.Important:FindFirstChild("Daily")
    local attachment = dailyModel and dailyModel:FindFirstChild("Attachment")
    local billboard = attachment and attachment:FindFirstChild("BillboardGui")
    if billboard then
        local timer = billboard:FindFirstChild("Timer")
        if timer then timer.Text = timeStr end
    end
end

local modelRegistry = {} 

local function setupUpgradeLogic()
	local hud = mainGui:WaitForChild("HUD")
	local leftButtons = hud:WaitForChild("LeftButtons")
	
	local buttonMap = {
		Rebirth = rebirthFrame,
		Shop = frames:FindFirstChild("Shop"),
		Index = indexFrame,
		Pack = starterPackFrame
	}

	local spBuy = starterPackFrame:WaitForChild("Buy")
	spBuy.MouseButton1Click:Connect(function()
		local MarketplaceService = game:GetService("MarketplaceService")
		MarketplaceService:PromptProductPurchase(player, 3544528726)
	end)

	for buttonName, frame in pairs(buttonMap) do
		local btn = (buttonName == "Pack") and hud:WaitForChild("Pack") or leftButtons:WaitForChild(buttonName)
		if not frame then continue end
		
		local closeBtn = frame:WaitForChild("Close")
		
		btn.MouseButton1Click:Connect(function()
			Animations.ToggleFrame(frame, not frame:GetAttribute("Active"))
		end)
		
		closeBtn.MouseButton1Click:Connect(function()
			Animations.ToggleFrame(frame, false)
		end)
	end

	-- Interaction Parts
	local important = workspace:WaitForChild("Map"):WaitForChild("Important")
	local interactions = {
		Oxygen = important:WaitForChild("Oxygen"):WaitForChild("Touchpart"),
		Carry = important:WaitForChild("Carry"):WaitForChild("Touchpart"),
		Daily = important:WaitForChild("Daily"):WaitForChild("Touchpart")
	}
	
	dailyClaimBtn.MouseButton1Click:Connect(function()
		local now = os.time()
		if lastDailyClaim == 0 or (now - lastDailyClaim) >= DAY_SECONDS then
			CLAIM_DAILY:FireServer()
		end
	end)
	
	task.spawn(function()
		while true do
			updateDailyUI()
			task.wait(1)
		end
	end)

	for frameName, touchpart in pairs(interactions) do
		local frame = frames:WaitForChild(frameName)
		local closeBtn = frame:WaitForChild("Close")
		
		touchpart.Touched:Connect(function(hit)
			if hit.Parent == player.Character then
				Animations.ToggleFrame(frame, true)
			end
		end)

		closeBtn.MouseButton1Click:Connect(function()
			Animations.ToggleFrame(frame, false)
		end)
	end

	-- Oxygen
	for _, frameName in {"1", "5", "10"} do
		local frame = oxygenHolder:FindFirstChild(frameName)
		if frame then
			local buy = frame:FindFirstChild("Buy")
			if buy then
				CollectionService:AddTag(buy, "ButtonAnim")
				buy.MouseButton1Click:Connect(function()
					local stat = "Oxygen" .. (frameName == "1" and "1" or frameName == "5" and "5" or "10")
					UPGRADE_STAT:FireServer(stat)
				end)
			end
			
			local robuxBuy = frame:FindFirstChild("RobuxBuy")
			if robuxBuy then
				CollectionService:AddTag(robuxBuy, "ButtonAnim")
				robuxBuy.MouseButton1Click:Connect(function()
					Monetization.PromptOxygenUpgrade(tonumber(frameName))
				end)
			end
		end
	end
	
	-- Backpack (renamed from Carry logic)
	local buy = backpackHolder:FindFirstChild("Buy")
	if buy then
		CollectionService:AddTag(buy, "ButtonAnim")
		buy.MouseButton1Click:Connect(function()
			UPGRADE_STAT:FireServer("Backpack")
		end)
	end

	local robuxBuy = backpackHolder:FindFirstChild("RobuxBuy")
	if robuxBuy then
		CollectionService:AddTag(robuxBuy, "ButtonAnim")
		robuxBuy.MouseButton1Click:Connect(function()
			Monetization.PromptBackpackUpgrade()
		end)
	end
end

function buildModelRegistry()
	modelRegistry = {}
	local mutationOrder = {"Normal", "Gold", "Diamond", "Emerald", "Blood"}
	local rarityOrder = {"Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythical", "Cosmic", "Secret"}
	
	local counter = 0
	for _, rarity in ipairs(rarityOrder) do
		local models = Calibration.Get().Models[rarity]
		if not models then continue end
		
		local modelNames = {}
		for name in pairs(models) do table.insert(modelNames, name) end
		table.sort(modelNames)
		
		for _, name in ipairs(modelNames) do
			local data = models[name]
			for _, mutation in ipairs(mutationOrder) do
				local icon = data.Icons and data.Icons[mutation] or (data.Icons and data.Icons["Normal"])
                if mutation ~= "Normal" and not (data.Icons and data.Icons[mutation]) then
                    continue
                end
                
				counter += 1
				table.insert(modelRegistry, {
					Name = name,
					Rarity = rarity,
					Mutation = mutation,
					Icon = icon or "",
					LayoutOrder = counter,
                    SearchKey = string.format("%s | %s [%s]", rarity, name, mutation),
                    Key = string.format("%s | %s", rarity, name)
				})
			end
		end
	end
end

local function applyMutationFilter()
    for _, child in modelsFrame:GetChildren() do
        if child:IsA("Frame") and not child:GetAttribute("IsTemplate") then
            child.Visible = (child.Name == currentMutationFilter)
        end
    end
end

local function updateIndexDisplay(playerCollection)
	local ownedSet = {}
	if playerCollection then
		for _, entry in ipairs(playerCollection) do
            local rarity, name, mutation = entry:match("^(.+) | (.+) %[(.+)%]$")
            if not mutation then
                rarity, name = entry:match("^(.+) | (.+)$")
                mutation = "Normal"
            end
            if rarity and name then
                ownedSet[string.format("%s | %s [%s]", rarity:match("^%s*(.-)%s*$"), name:match("^%s*(.-)%s*$"), mutation or "Normal")] = true
            end
		end
	end

    for _, child in modelsFrame:GetChildren() do
        if child:IsA("Frame") and not child:GetAttribute("IsTemplate") then
            child:Destroy()
        end
    end

    for _, entry in ipairs(modelRegistry) do
        local holder = holderTemplate:Clone()
        holder:SetAttribute("IsTemplate", false)
        holder.Name = entry.Mutation
        holder.LayoutOrder = entry.LayoutOrder
        
        local isOwned = ownedSet[entry.SearchKey] == true
        
        local modelNameLabel = holder:WaitForChild("ModelName")
        local rarityLabel = holder:WaitForChild("Rarity")
        local icon = holder:WaitForChild("Icon")
        
        modelNameLabel.Text = isOwned and entry.Name or "???"
        rarityLabel.Text = entry.Rarity
        rarityLabel.TextColor3 = RARITY_COLORS[entry.Rarity] or Color3.new(1, 1, 1)
        
        icon.Image = entry.Icon
        icon.ImageColor3 = isOwned and Color3.new(1, 1, 1) or Color3.new(0, 0, 0)
        
        for _, child in modelNameLabel:GetChildren() do
            if child:IsA("UIGradient") then child:Destroy() end
        end
        
        if isOwned and entry.Mutation ~= "Normal" then
            local gradientTemplate = GRADIENTS[entry.Mutation]
            if gradientTemplate then
                gradientTemplate:Clone().Parent = modelNameLabel
            end
        end
        
        holder.Parent = modelsFrame
        holder.Visible = (entry.Mutation == currentMutationFilter)
    end
end

local function updateRebirthDisplay()
	local rebirths = player:GetAttribute("Rebirths") or 0
	local oxygen = player:GetAttribute("Oxygen") or 0
	local collectionStr = player:GetAttribute("Collections")
	local collections = collectionStr and HttpService:JSONDecode(collectionStr) or {}

	local nextRebirth = rebirths + 1
	local reqOxygen = Calibration.GetOxygenRequirement(nextRebirth)

	progressTitle.Text = string.format("%d/%d OXYGEN", math.floor(oxygen), reqOxygen)
	local progressScale = math.clamp(oxygen / reqOxygen, 0, 1)
	TweenService:Create(progressBar, TweenInfo.new(0.5), {Size = UDim2.fromScale(progressScale, 1)}):Play()

	local cRebirths = Calibration.Get().Rebirths
	local rebirthConfig = cRebirths[nextRebirth]
	if not rebirthConfig then
		local maxK = 0
		for k in pairs(cRebirths) do if type(k) == "number" and k > maxK then maxK = k end end
		rebirthConfig = cRebirths[maxK]
	end
	local allModelsOwned = true

	if rebirthConfig and rebirthConfig.Models then
		-- Update display frames
		for i = 1, 2 do
			local displayEntry = displayFrame:FindFirstChild(tostring(i))
			local modelName = rebirthConfig.Models[i]
			
			if displayEntry then
				if modelName then
					displayEntry.Visible = true
					local modelNameLbl = displayEntry:FindFirstChild("ModelName")
					local rarityLbl = displayEntry:FindFirstChild("Rarity")
					local iconImg = displayEntry:FindFirstChild("Icon")
					local checkMark = displayEntry:FindFirstChild("CheckMark")
					
					-- Find the model data in CONFIG
					local rarity, icon
					for r, models in pairs(Calibration.Get().Models) do
						if models[modelName] then
							rarity = r
							icon = models[modelName].Icons and models[modelName].Icons.Normal
							break
						end
					end
					
					if modelNameLbl then modelNameLbl.Text = modelName end
					if rarityLbl then 
						rarityLbl.Text = rarity or "Unknown"
						rarityLbl.TextColor3 = RARITY_COLORS[rarity] or Color3.new(1, 1, 1)
					end
					if iconImg then iconImg.Image = icon or "" end
					
					-- Check if owned in any mutation
					local isOwned = false
					for _, mutation in ipairs({"Normal", "Gold", "Diamond", "Emerald", "Blood"}) do
						local key = string.format("%s | %s [%s]", rarity, modelName, mutation)
						if table.find(collections, key) then
							isOwned = true
							break
						end
					end
					
					if checkMark then checkMark.Visible = isOwned end
					if not isOwned then allModelsOwned = false end
				else
					displayEntry.Visible = false
				end
			end
		end
	end

	return allModelsOwned and oxygen >= reqOxygen
end

local function updateUpgrades()
	local oxygenUpgrades = {
		["1"] = { Stat = "Oxygen1", Inc = 1 },
		["5"] = { Stat = "Oxygen5", Inc = 5 },
		["10"] = { Stat = "Oxygen10", Inc = 10 }
	}

	local function getPrice(stat, level)
		return Calibration.GetUpgradePrice(stat, level, 0)
	end

	local maxOxygen = player:GetAttribute("MaxOxygen") or 100
	local globalOxygenLevel = player:GetAttribute("OxygenUpgradeLevel") or 100

	for frameName, data in pairs(oxygenUpgrades) do
		local frame = oxygenHolder:FindFirstChild(frameName)
		if not frame then continue end
		
		-- Use the sync'd global level for all tier price calculations
		local price = getPrice(data.Stat, globalOxygenLevel)
		
		local buyBtn = frame:FindFirstChild("Buy")
		if buyBtn then
			local priceLabel = buyBtn:FindFirstChild("Price")
			if priceLabel then
				if price > 0 and price ~= math.huge then
					priceLabel.Text = formatNumber(price)
				else
					priceLabel.Text = "MAX"
				end
			end
		end
		
		local upgradeFrame = frame:FindFirstChild("Upgrade")
		if upgradeFrame then
			local current = upgradeFrame:FindFirstChild("Current")
			local nextLbl = upgradeFrame:FindFirstChild("Next")
			if current then current.Text = tostring(maxOxygen) end
			if nextLbl then nextLbl.Text = tostring(maxOxygen + data.Inc) end
		end
	end

	local backpackUpgrades = player:GetAttribute("BackpackUpgrades") or 0
	local backpackCapacity = player:GetAttribute("BackpackCapacity") or 1
	local backpackPrice, newBackpackLevel = Calibration.GetUpgradePrice("Backpack", 0, backpackUpgrades)
	
	local backpackUpgradeFrame = backpackHolder:FindFirstChild("Upgrade")
	if backpackUpgradeFrame then
		local current = backpackUpgradeFrame:FindFirstChild("Current")
		local nextLbl = backpackUpgradeFrame:FindFirstChild("Next")
		if current then current.Text = tostring(backpackCapacity) end
		if nextLbl then 
			if backpackPrice ~= math.huge and newBackpackLevel then
				nextLbl.Text = tostring(newBackpackLevel)
			else
				nextLbl.Text = "MAX"
			end
		end
	end
	
	local backpackBuyBtn = backpackHolder:FindFirstChild("Buy")
	if backpackBuyBtn then
		local priceLabel = backpackBuyBtn:FindFirstChild("Price")
		if priceLabel then
			if backpackPrice > 0 and backpackPrice ~= math.huge then
				priceLabel.Text = formatNumber(backpackPrice)
			else
				priceLabel.Text = "MAX"
			end
		end
	end
end

function Player.Init()
	buildModelRegistry()
	holderTemplate:SetAttribute("IsTemplate", true)
	holderTemplate.Visible = false

	for _, button in ipairs(mutationsScroll:GetChildren()) do
		if button:IsA("ImageButton") then
			button.MouseButton1Click:Connect(function()
				currentMutationFilter = button.Name
                applyMutationFilter()
			end)
		end
	end

	rebirthBtn.MouseButton1Click:Connect(function()
		if updateRebirthDisplay() then
			local nextRebirth = (player:GetAttribute("Rebirths") or 0) + 1
			REBIRTH_SKIP:FireServer(nextRebirth)
		end
	end)

	skipBtn.MouseButton1Click:Connect(function()
		REBIRTH_SKIP:FireServer("Skip")
	end)

	UPDATE_COLLECTION.OnClientEvent:Connect(function(serverCollection)
		if serverCollection then
			updateIndexDisplay(serverCollection)
		else
			local collection = player:GetAttribute("Collections")
			if collection then updateIndexDisplay(HttpService:JSONDecode(collection)) end
		end
		updateRebirthDisplay()
	end)
	
	UPDATE_DAILY.OnClientEvent:Connect(function(day, lastClaim)
		currentDailyDay = day
		lastDailyClaim = lastClaim
		updateDailyUI()
	end)

	player:GetAttributeChangedSignal("Collections"):Connect(function()
		local collection = player:GetAttribute("Collections")
		if collection then updateIndexDisplay(HttpService:JSONDecode(collection)) end
		updateRebirthDisplay()
	end)

	player:GetAttributeChangedSignal("Oxygen"):Connect(updateRebirthDisplay)
	player:GetAttributeChangedSignal("Rebirths"):Connect(updateRebirthDisplay)

	local initialCol = player:GetAttribute("Collections")
	updateIndexDisplay(initialCol and HttpService:JSONDecode(initialCol) or {})
	updateRebirthDisplay()
	
	setupUpgradeLogic()
	updateUpgrades()
	
	player:GetAttributeChangedSignal("MaxOxygen"):Connect(updateUpgrades)
	player:GetAttributeChangedSignal("OxygenUpgradeLevel"):Connect(updateUpgrades)
	player:GetAttributeChangedSignal("BackpackUpgrades"):Connect(updateUpgrades)
	player:GetAttributeChangedSignal("BackpackCapacity"):Connect(updateUpgrades)
end

return Player
