local MutationsConfig = {}

MutationsConfig.CONFIG = {
	["Mutations"] = {
		["Gold"] = { -- Mutation Name
			Color = {226, 155, 64}, -- Only for Parts/Meshes without a texture
			FillColor = {255, 170, 0}, -- Highlight FillColor
			OutlineColor = {188, 125, 0}, -- Highlight Outline
			nMultiplier = 1.2 -- Cash Multiplier
		},
		["Diamond"] = {
			Color = {13, 105, 172},
			FillColor = {0, 255, 255},
			OutlineColor = {8, 63, 102},
			nMultiplier = 1.5
		},
		["Emerald"] = {
			Color = {52, 117, 33},
			FillColor = {85, 170, 0},
			OutlineColor = {54, 108, 0},
			Multiplier = 2
		},
		["Blood"] = {
			Color = {95, 0, 0},
			FillColor = {255, 0, 0},
			OutlineColor = {95, 0, 0},
			Multiplier = 3
		},
	},
}

-- Constant for easier access
MutationsConfig.Mutations = MutationsConfig.CONFIG.Mutations

return MutationsConfig
