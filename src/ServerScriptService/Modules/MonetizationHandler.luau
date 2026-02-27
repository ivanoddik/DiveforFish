local MonetizationHandler = {}

local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local TweenService = game:GetService("TweenService")
local CollectionService = game:GetService("CollectionService")

local DataService = require(ServerScriptService.Modules.DataService)
local PlayerHandler = require(ServerScriptService.Modules.PlayerHandler)
local RebirthHandler = require(ServerScriptService.Modules.RebirthHandler)
local UpgradeHandler = require(ServerScriptService.Modules.UpgradeHandler)

local VIP_PASS_ID = 1724695567
local SPEED_BOOST_PASS_ID = 1729255670

local PRODUCT_ID_SHARK = 3543931967
local PRODUCT_ID_REBIRTH_SKIP = 3543968930
local PRODUCT_ID_EXCLUSIVE_BUNDLE = 3544528945
local PRODUCT_ID_OP_BUNDLE = 3544529000
local PRODUCT_ID_STARTER_PACK = 3544528726
local PRODUCT_ID_OXYGEN_1 = 3544883755
local PRODUCT_ID_OXYGEN_5 = 3544883902
local PRODUCT_ID_OXYGEN_10 = 3544884007
local PRODUCT_ID_BACKPACK_UPGRADE = 3545646933

local BOOST_MULTIPLIER = 1.5

local ASSETS = ReplicatedStorage:WaitForChild("Storage"):WaitForChild("Assets")
local GOLDEN_BASE_PREFAB = ASSETS:WaitForChild("GoldenBase")
local SHARK_PREFAB = ASSETS:WaitForChild("Shark")
local SOUNDS = ReplicatedStorage:WaitForChild("Storage"):WaitForChild("Sound")
local ALARM_SOUND = SOUNDS:WaitForChild("Alarm")

local START_PART = workspace:WaitForChild("Map"):WaitForChild("Important"):WaitForChild("Start")
local FINISH_PART = workspace:WaitForChild("Map"):WaitForChild("Important"):WaitForChild("Finish")

local REMOTES = ReplicatedStorage:WaitForChild("Remotes")
local VIP_REWARD_REMOTE = REMOTES:WaitForChild("VIPReward")
local REBIRTH_SKIP_REMOTE = REMOTES:WaitForChild("RebirthSkip")
local UPDATE_TUTORIAL = REMOTES:WaitForChild("UpdateTutorial")

local function findModelInfoInConfig(modelName)
	local Calibration = require(ReplicatedStorage.Modules.Calibration)
	local modelsConfig = Calibration.Get().Models
	for rarity, models in pairs(modelsConfig) do
		if models[modelName] then
			return models[modelName], rarity
		end
	end
	return nil
end

local function grantCar(player, carName)
	local model = ReplicatedStorage.Models:FindFirstChild(carName)
	if not model then return end
	
	local info, rarity = findModelInfoInConfig(carName)
	if not info then
		error("[MonetizationHandler] Model " .. carName .. " not found in ModelsConfig!")
	end
	
	local tool = Instance.new("Tool")
	tool.Name = carName
	
	-- Metadata for earnings and mutation
	tool:SetAttribute("Mutation", "Normal")
	tool:SetAttribute("Level", 1)
	tool:SetAttribute("SourceModelName", carName)
	tool:SetAttribute("Earnings", info.Earnings or 0)
	tool:SetAttribute("Rarity", rarity or "Common")
	
	if info.Icons then
		tool.TextureId = info.Icons["Normal"] or ""
	end
	
	local root = model.PrimaryPart:Clone()
	root.Name = "Handle"
	root.Anchored = false
	root.CanCollide = false
	root.Parent = tool
	
	for _, child in model:GetChildren() do
		if child:IsA("BasePart") and child ~= model.PrimaryPart then
			local p = child:Clone()
			p.Anchored = false
			p.CanCollide = false
			p.Parent = tool
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = root
			weld.Part1 = p
			weld.Parent = p
		end
	end
	
	CollectionService:AddTag(tool, "SpecialTool")
	tool:SetAttribute("SpecialTool", true)
	tool.Parent = player:WaitForChild("Backpack")
end

function MonetizationHandler.CheckVIPPass(player)
	local success, hasPass = pcall(function()
		return MarketplaceService:UserOwnsGamePassAsync(player.UserId, VIP_PASS_ID)
	end)
	
	if success and hasPass then
		local profile = DataService:GetProfile(player)
		if profile then
			profile.CurrentMultiplier *= BOOST_MULTIPLIER
			
			-- VIP Rewards: +50 MaxOxygen and +50 Current Oxygen
			if not profile.Data.VIPClaimed then
				profile:Increment("MaxOxygen", 50)
				profile:Increment("Oxygen", 50)
				player:SetAttribute("MaxOxygen", profile.Data.MaxOxygen)
				player:SetAttribute("Oxygen", profile.Data.Oxygen)
				profile:Update("VIPClaimed", true)
			end
		end
		
		task.spawn(function()
			local base = PlayerHandler.GetPlayerBase(player)
			while not base do
				task.wait(0.5)
				base = PlayerHandler.GetPlayerBase(player)
			end
			PlayerHandler.SwapBase(player, GOLDEN_BASE_PREFAB)
		end)
	end
end

local function handleSharkSpawn()
	local shark = SHARK_PREFAB:Clone()
	shark.PrimaryPart = shark:FindFirstChild("HitBox") or shark:FindFirstChildWhichIsA("BasePart")
	
	local targetCFrame = CFrame.new(START_PART.Position) * SHARK_PREFAB:GetPivot().Rotation
	shark:PivotTo(targetCFrame)
	shark.Parent = workspace
	
	ALARM_SOUND:Play()
	
	local hitBox = shark:FindFirstChild("HitBox")
	if hitBox then
		hitBox.Touched:Connect(function(hit)
			local character = hit.Parent
			local humanoid = character:FindFirstChildOfClass("Humanoid")
			if humanoid then humanoid.Health = 0 end
		end)
	end
	
	local tweenInfo = TweenInfo.new(5, Enum.EasingStyle.Linear)
	local finishCFrame = CFrame.new(FINISH_PART.Position) * targetCFrame.Rotation
	local tween = TweenService:Create(shark.PrimaryPart, tweenInfo, {CFrame = finishCFrame})
	tween.Completed:Connect(function() shark:Destroy() end)
	tween:Play()
end

function MonetizationHandler.ProcessReceipt(receiptInfo)
	local player = game.Players:GetPlayerByUserId(receiptInfo.PlayerId)
	if not player then return Enum.ProductPurchaseDecision.NotProcessedYet end
	
	local profile = DataService:GetProfile(player)
	if not profile then return Enum.ProductPurchaseDecision.NotProcessedYet end

	local decision = Enum.ProductPurchaseDecision.NotProcessedYet

	if receiptInfo.ProductId == PRODUCT_ID_SHARK then
		task.spawn(handleSharkSpawn)
		decision = Enum.ProductPurchaseDecision.PurchaseGranted
	elseif receiptInfo.ProductId == PRODUCT_ID_REBIRTH_SKIP then
		RebirthHandler.ProcessSkip(player)
		decision = Enum.ProductPurchaseDecision.PurchaseGranted
	elseif receiptInfo.ProductId == PRODUCT_ID_EXCLUSIVE_BUNDLE then
		grantCar(player, "Sport Car")
		grantCar(player, "Rolls Car")
		grantCar(player, "Muscle Car")
		decision = Enum.ProductPurchaseDecision.PurchaseGranted
	elseif receiptInfo.ProductId == PRODUCT_ID_OP_BUNDLE then
		grantCar(player, "Black Car")
		grantCar(player, "Muscle Car")
		profile:Increment("Cash", 25000000)
		decision = Enum.ProductPurchaseDecision.PurchaseGranted
	elseif receiptInfo.ProductId == PRODUCT_ID_STARTER_PACK then
		grantCar(player, "Orange Car")
		grantCar(player, "Red Car")
		profile:Increment("Cash", 5000000)
		decision = Enum.ProductPurchaseDecision.PurchaseGranted
	elseif receiptInfo.ProductId == PRODUCT_ID_OXYGEN_1 then
		UpgradeHandler.ApplyOxygenUpgrade(player, 1)
		decision = Enum.ProductPurchaseDecision.PurchaseGranted
	elseif receiptInfo.ProductId == PRODUCT_ID_OXYGEN_5 then
		UpgradeHandler.ApplyOxygenUpgrade(player, 5)
		decision = Enum.ProductPurchaseDecision.PurchaseGranted
	elseif receiptInfo.ProductId == PRODUCT_ID_OXYGEN_10 then
		UpgradeHandler.ApplyOxygenUpgrade(player, 10)
		decision = Enum.ProductPurchaseDecision.PurchaseGranted
	elseif receiptInfo.ProductId == PRODUCT_ID_BACKPACK_UPGRADE then
		UpgradeHandler.ApplyBackpackUpgrade(player)
		decision = Enum.ProductPurchaseDecision.PurchaseGranted
	end

	if decision == Enum.ProductPurchaseDecision.PurchaseGranted then
		REMOTES.Notify:FireClient(player, "Thank you for your purchase!", true)
	end

	return decision
end

function MonetizationHandler.Init()
	MarketplaceService.ProcessReceipt = MonetizationHandler.ProcessReceipt
	
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, wasPurchased)
		if wasPurchased then
			REMOTES.Notify:FireClient(player, "Thank you for your purchase!", true)
			if passId == VIP_PASS_ID then
				MonetizationHandler.CheckVIPPass(player)
			end
		end
	end)

	VIP_REWARD_REMOTE.OnServerEvent:Connect(function(player)
		MonetizationHandler.CheckVIPPass(player)
	end)

	REBIRTH_SKIP_REMOTE.OnServerEvent:Connect(function(player, action)
		if action == "Skip" then
			MarketplaceService:PromptProductPurchase(player, PRODUCT_ID_REBIRTH_SKIP)
		elseif type(action) == "number" then
			RebirthHandler.ProcessRebirth(player, action)
		end
	end)

	DataService.OnProfileLoaded:Connect(function(player)
		MonetizationHandler.CheckVIPPass(player)
	end)
end

return MonetizationHandler
