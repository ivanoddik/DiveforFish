local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Monetization = {}

local PRODUCT_ID_SHARK = 3543931967
local PRODUCT_ID_EXCLUSIVE_BUNDLE = 3544528945
local PRODUCT_ID_OP_BUNDLE = 3544529000
local PRODUCT_ID_STARTER_PACK = 3544528726
local PRODUCT_ID_OXYGEN_1 = 3544883755
local PRODUCT_ID_OXYGEN_5 = 3544883902
local PRODUCT_ID_OXYGEN_10 = 3544884007
local PRODUCT_ID_BACKPACK_UPGRADE = 3545646933

local GAMEPASS_ID_VIP = 1724695567
local GAMEPASS_ID_SPEED_BOOST = 1729255670

local REMOTES = ReplicatedStorage:WaitForChild("Remotes")
local VIP_REWARD_REMOTE = REMOTES:WaitForChild("VIPReward")

local player = Players.LocalPlayer

function Monetization.PromptOxygenUpgrade(increment)
	local productId = increment == 1 and PRODUCT_ID_OXYGEN_1 or increment == 5 and PRODUCT_ID_OXYGEN_5 or PRODUCT_ID_OXYGEN_10
	if productId then
		MarketplaceService:PromptProductPurchase(player, productId)
	end
end

function Monetization.PromptBackpackUpgrade()
	MarketplaceService:PromptProductPurchase(player, PRODUCT_ID_BACKPACK_UPGRADE)
end

function Monetization.Init()
	local pGui = player:WaitForChild("PlayerGui")
	local mainGui = pGui:WaitForChild("Main")
	local frames = mainGui:WaitForChild("Frames")
	local hud = mainGui:WaitForChild("HUD")
	local shopFrame = frames:WaitForChild("Shop")
	local scrolling = shopFrame:WaitForChild("ScrollingFrame")
	local passFrame = scrolling:WaitForChild("PassFrame")
	
	local sharkButton = hud:WaitForChild("Shark")
	local leftButtons = hud:WaitForChild("LeftButtons")
	local vipButtonHUD = leftButtons:WaitForChild("VIP")
	local vipTitleHUD = vipButtonHUD:WaitForChild("Title")

	-- HUD Buttons
	sharkButton.MouseButton1Click:Connect(function()
		MarketplaceService:PromptProductPurchase(player, PRODUCT_ID_SHARK)
	end)

	local function updateHUDVIP()
		local success, hasPass = pcall(function()
			return MarketplaceService:UserOwnsGamePassAsync(player.UserId, GAMEPASS_ID_VIP)
		end)
		if success and hasPass then
			vipTitleHUD.Text = "Owned"
		end
	end

	vipButtonHUD.MouseButton1Click:Connect(function()
		local success, hasPass = pcall(function()
			return MarketplaceService:UserOwnsGamePassAsync(player.UserId, GAMEPASS_ID_VIP)
		end)
		
		if success and hasPass then
			vipTitleHUD.Text = "Owned"
		else
			MarketplaceService:PromptGamePassPurchase(player, GAMEPASS_ID_VIP)
		end
	end)

	local shopItems = {
		ExclusiveBundle = { Id = PRODUCT_ID_EXCLUSIVE_BUNDLE, Type = "Product" },
		OPBundle = { Id = PRODUCT_ID_OP_BUNDLE, Type = "Product" },
		StarterPack = { Id = PRODUCT_ID_STARTER_PACK, Type = "Product" },
		SpeedBoost = { Id = GAMEPASS_ID_SPEED_BOOST, Type = "GamePass" },
		VIP = { Id = GAMEPASS_ID_VIP, Type = "GamePass" }
	}

	for frameName, data in pairs(shopItems) do
		local frame = passFrame:FindFirstChild(frameName)
		if frame then
			local buyBtn = frame:FindFirstChild("Buy")
			if buyBtn then
				buyBtn.MouseButton1Click:Connect(function()
					if data.Type == "Product" then
						MarketplaceService:PromptProductPurchase(player, data.Id)
					else
						MarketplaceService:PromptGamePassPurchase(player, data.Id)
					end
				end)
			end
		end
	end

	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(purchasedPlayer, passId, wasPurchased)
		if purchasedPlayer == player and wasPurchased then
			if passId == GAMEPASS_ID_VIP then
				vipTitleHUD.Text = "Owned"
				VIP_REWARD_REMOTE:FireServer()
			end
		end
	end)

	updateHUDVIP()
end

return Monetization