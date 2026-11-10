--!strict

local MathUtil = {}

function MathUtil.DistanceXZ(a: Vector3, b: Vector3): number
	local dx = a.X - b.X
	local dz = a.Z - b.Z
	return math.sqrt(dx * dx + dz * dz)
end

function MathUtil.SnapToGrid(position: Vector3, gridSize: number, yLevel: number?): Vector3
	local x = math.floor((position.X + (gridSize / 2)) / gridSize) * gridSize
	local z = math.floor((position.Z + (gridSize / 2)) / gridSize) * gridSize
	return Vector3.new(x, yLevel or position.Y, z)
end

function MathUtil.FormatNumber(value: number): string
	if value >= 1000000 then
		return string.format("%.1fM", value / 1000000)
	elseif value >= 1000 then
		return string.format("%.1fK", value / 1000)
	else
		return tostring(math.floor(value))
	end
end

function MathUtil.FormatTime(seconds: number): string
	local s = math.max(0, math.floor(seconds))
	local mins = math.floor(s / 60)
	local secs = s % 60
	return string.format("%02d:%02d", mins, secs)
end

return MathUtil
