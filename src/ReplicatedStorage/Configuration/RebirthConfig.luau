local RebirthConfig = {}

RebirthConfig.REBIRTH_MAP = {
	[1] = {Type = "Floor", Name = "Floor2", Models = {"Orange Car", "Rolls Car"}},
	[2] = {Type = "Pad", Id = 12, Models = {"Orange Car", "Rolls Car"}},
	[3] = {Type = "Pad", Id = 13, Models = {"Orange Car", "Rolls Car"}},
	[4] = {Type = "Pad", Id = 14, Models = {"Orange Car", "Rolls Car"}},
	[5] = {Type = "Pad", Id = 15, Models = {"Orange Car", "Rolls Car"}},
	[6] = {Type = "Pad", Id = 16, Models = {"Orange Car", "Rolls Car"}},
	[7] = {Type = "Pad", Id = 17, Models = {"Orange Car", "Rolls Car"}},
	[8] = {Type = "Pad", Id = 18, Models = {"Orange Car", "Rolls Car"}},
	[9] = {Type = "Pad", Id = 19, Models = {"Orange Car", "Rolls Car"}},
	[10] = {Type = "Pad", Id = 20, Models = {"Orange Car", "Rolls Car"}},
	[11] = {Type = "Pad", Id = 21, Models = {"Orange Car", "Rolls Car"}},
	[12] = {Type = "Floor", Name = "Floor3", Models = {"Orange Car", "Rolls Car"}},
	[13] = {Type = "Pad", Id = 23, Models = {"Orange Car", "Rolls Car"}},
	[14] = {Type = "Pad", Id = 24, Models = {"Orange Car", "Rolls Car"}},
	[15] = {Type = "Pad", Id = 25, Models = {"Orange Car", "Rolls Car"}},
	[16] = {Type = "Pad", Id = 26, Models = {"Orange Car", "Rolls Car"}},
	[17] = {Type = "Pad", Id = 27, Models = {"Orange Car", "Rolls Car"}},
	[18] = {Type = "Pad", Id = 28, Models = {"Orange Car", "Rolls Car"}},
	[19] = {Type = "Pad", Id = 29, Models = {"Orange Car", "Rolls Car"}},
	[20] = {Type = "Pad", Id = 30, Models = {"Orange Car", "Rolls Car"}},
	[21] = {Type = "Pad", Id = 31, Models = {"Orange Car", "Rolls Car"}},
	[22] = {Type = "Pad", Id = 32, Models = {"Orange Car", "Rolls Car"}},
	[23] = {Type = "Floor", Name = "Floor4", Models = {"Orange Car", "Rolls Car"}},
	[24] = {Type = "Pad", Id = 34, Models = {"Orange Car", "Rolls Car"}},
	[25] = {Type = "Pad", Id = 35, Models = {"Orange Car", "Rolls Car"}},
	[26] = {Type = "Pad", Id = 36, Models = {"Orange Car", "Rolls Car"}},
	[27] = {Type = "Pad", Id = 37, Models = {"Orange Car", "Rolls Car"}},
	[28] = {Type = "Pad", Id = 38, Models = {"Orange Car", "Rolls Car"}},
	[29] = {Type = "Pad", Id = 39, Models = {"Orange Car", "Rolls Car"}},
	[30] = {Type = "Pad", Id = 40, Models = {"Orange Car", "Rolls Car"}},
}

function RebirthConfig.GetOxygenRequirement(rebirthLevel)
	return 150 + (rebirthLevel - 1) * 25
end

return RebirthConfig
