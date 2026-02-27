local ConfigReader = {}

local function asNumber(v)
	if type(v) == "number" then
		return v
	end
	return nil
end

local function clampWithAttributes(inst, value, keyPath)
	local minV = asNumber(inst:GetAttribute("Min"))
	local maxV = asNumber(inst:GetAttribute("Max"))

	if minV and maxV and minV > maxV then
		warn(("[Config] Invalid bounds for %s (Min > Max). Swapping."):format(keyPath))
		minV, maxV = maxV, minV
	end

	if minV then
		value = math.max(minV, value)
	end
	if maxV then
		value = math.min(maxV, value)
	end
	return value
end

function ConfigReader.GetChild(parent, name, expectedClass, keyPath)
	local inst = parent:FindFirstChild(name)
	if not inst then
		error(("[Config] Missing required config: %s"):format(keyPath), 3)
	end
	if expectedClass and not inst:IsA(expectedClass) then
		error(("[Config] Invalid class for %s. Expected %s, got %s"):format(keyPath, expectedClass, inst.ClassName), 3)
	end
	return inst
end

function ConfigReader.ReadNumber(parent, name, keyPath)
	local inst = ConfigReader.GetChild(parent, name, nil, keyPath)
	if not inst:IsA("NumberValue") and not inst:IsA("IntValue") then
		error(("[Config] Invalid config type for %s. Expected NumberValue/IntValue, got %s"):format(keyPath, inst.ClassName), 3)
	end

	local v = inst.Value
	if type(v) ~= "number" then
		error(("[Config] Invalid numeric value for %s"):format(keyPath), 3)
	end

	local clamped = clampWithAttributes(inst, v, keyPath)
	if clamped ~= v then
		warn(("[Config] %s clamped from %s to %s"):format(keyPath, tostring(v), tostring(clamped)))
	end
	return clamped
end

function ConfigReader.ReadInteger(parent, name, keyPath)
	local v = ConfigReader.ReadNumber(parent, name, keyPath)
	return math.floor(v + 0.5)
end

function ConfigReader.ReadBool(parent, name, keyPath)
	local inst = ConfigReader.GetChild(parent, name, "BoolValue", keyPath)
	return inst.Value == true
end

function ConfigReader.ReadString(parent, name, keyPath)
	local inst = ConfigReader.GetChild(parent, name, "StringValue", keyPath)
	return inst.Value
end

function ConfigReader.ReadVector3XYZ(parent, xName, yName, zName, keyPath)
	return Vector3.new(
		ConfigReader.ReadNumber(parent, xName, keyPath .. "." .. xName),
		ConfigReader.ReadNumber(parent, yName, keyPath .. "." .. yName),
		ConfigReader.ReadNumber(parent, zName, keyPath .. "." .. zName)
	)
end

return ConfigReader


