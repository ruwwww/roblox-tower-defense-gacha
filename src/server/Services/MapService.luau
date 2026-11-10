--!strict
local Workspace = game:GetService("Workspace")

local MathUtil = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Utils"):WaitForChild("MathUtil"))

local MapService = {
	Waypoints = {} :: { Vector3 },
	Folders = {} :: { [string]: Folder },
	BasePosition = Vector3.new(0, 0, 0),
	SpawnPosition = Vector3.new(0, 0, 0),
	TrackSegments = {} :: { { Start: Vector3, End: Vector3 } },
}

local WAYPOINT_COORDINATES = {
	Vector3.new(-120, 1, -80), -- 1: Spawn Gate
	Vector3.new(-40,  1, -80), -- 2: Turn South
	Vector3.new(-40,  1, -20), -- 3: Turn East
	Vector3.new(40,   1, -20), -- 4: Turn North
	Vector3.new(40,   1, -80), -- 5: Turn East
	Vector3.new(100,  1, -80), -- 6: Turn South
	Vector3.new(100,  1, 60),  -- 7: Turn West
	Vector3.new(0,    1, 60),  -- 8: Turn North
	Vector3.new(0,    1, 20),  -- 9: Base Crystal
}

local TRACK_WIDTH = 12

function MapService.SetupMap()
	-- Clean existing map folder if present
	local existingMap = Workspace:FindFirstChild("Map")
	if existingMap then
		existingMap:Destroy()
	end

	local mapFolder = Instance.new("Folder")
	mapFolder.Name = "Map"
	mapFolder.Parent = Workspace

	local folders = { "Towers", "Enemies", "Waypoints", "Track", "Decorations", "Effects" }
	for _, folderName in folders do
		local f = Instance.new("Folder")
		f.Name = folderName
		f.Parent = mapFolder
		MapService.Folders[folderName] = f
	end

	MapService.Waypoints = WAYPOINT_COORDINATES
	MapService.SpawnPosition = WAYPOINT_COORDINATES[1]
	MapService.BasePosition = WAYPOINT_COORDINATES[#WAYPOINT_COORDINATES]

	-- Build Waypoints
	local wpFolder = MapService.Folders.Waypoints
	for index, coord in ipairs(WAYPOINT_COORDINATES) do
		local wpPart = Instance.new("Part")
		wpPart.Name = "WP_" .. tostring(index)
		wpPart.Size = Vector3.new(2, 0.4, 2)
		wpPart.Position = coord
		wpPart.Anchored = true
		wpPart.CanCollide = false
		wpPart.Transparency = 1
		wpPart.Parent = wpFolder
	end

	-- Build Road / Track segments
	local trackFolder = MapService.Folders.Track
	MapService.TrackSegments = {}

	for i = 1, #WAYPOINT_COORDINATES - 1 do
		local p1 = WAYPOINT_COORDINATES[i]
		local p2 = WAYPOINT_COORDINATES[i + 1]
		table.insert(MapService.TrackSegments, { Start = p1, End = p2 })

		local segmentVec = p2 - p1
		local length = segmentVec.Magnitude
		local midpoint = (p1 + p2) / 2

		local roadPart = Instance.new("Part")
		roadPart.Name = "RoadSegment_" .. tostring(i)
		roadPart.Size = Vector3.new(TRACK_WIDTH, 0.6, length + TRACK_WIDTH)
		roadPart.CFrame = CFrame.lookAt(midpoint, p2)
		roadPart.Anchored = true
		roadPart.CanCollide = true
		roadPart.Material = Enum.Material.Slate
		roadPart.Color = Color3.fromRGB(65, 68, 75)
		roadPart.TopSurface = Enum.SurfaceType.Smooth
		roadPart.Parent = trackFolder

		-- Decorative borders
		for _, sideOffset in { -TRACK_WIDTH / 2, TRACK_WIDTH / 2 } do
			local curb = Instance.new("Part")
			curb.Name = "Curb"
			curb.Size = Vector3.new(1.2, 1.2, length + TRACK_WIDTH)
			curb.CFrame = roadPart.CFrame * CFrame.new(sideOffset, 0.3, 0)
			curb.Anchored = true
			curb.CanCollide = true
			curb.Material = Enum.Material.Cobblestone
			curb.Color = Color3.fromRGB(120, 115, 110)
			curb.Parent = trackFolder
		end
	end

	-- Build Base Crystal
	local crystalModel = Instance.new("Model")
	crystalModel.Name = "BaseCrystal"
	crystalModel.Parent = mapFolder

	local crystalPlatform = Instance.new("Part")
	crystalPlatform.Name = "Platform"
	crystalPlatform.Size = Vector3.new(18, 1.5, 18)
	crystalPlatform.Position = MapService.BasePosition - Vector3.new(0, 0.25, 0)
	crystalPlatform.Anchored = true
	crystalPlatform.Material = Enum.Material.Pavement
	crystalPlatform.Color = Color3.fromRGB(40, 45, 60)
	crystalPlatform.Parent = crystalModel

	local crystal = Instance.new("Part")
	crystal.Name = "CrystalCore"
	crystal.Size = Vector3.new(6, 12, 6)
	crystal.Position = MapService.BasePosition + Vector3.new(0, 6.5, 0)
	crystal.Anchored = true
	crystal.CanCollide = false
	crystal.Material = Enum.Material.Neon
	crystal.Color = Color3.fromRGB(80, 200, 255)
	crystal.Parent = crystalModel

	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(100, 220, 255)
	light.Range = 25
	light.Brightness = 3
	light.Parent = crystal

	-- Build Spawn Portal
	local spawnModel = Instance.new("Model")
	spawnModel.Name = "SpawnPortal"
	spawnModel.Parent = mapFolder

	local spawnPlatform = Instance.new("Part")
	spawnPlatform.Name = "PortalPlatform"
	spawnPlatform.Size = Vector3.new(16, 1.5, 16)
	spawnPlatform.Position = MapService.SpawnPosition - Vector3.new(0, 0.25, 0)
	spawnPlatform.Anchored = true
	spawnPlatform.Material = Enum.Material.Cobblestone
	spawnPlatform.Color = Color3.fromRGB(50, 30, 40)
	spawnPlatform.Parent = spawnModel

	local portalRing = Instance.new("Part")
	portalRing.Name = "PortalCore"
	portalRing.Size = Vector3.new(10, 10, 2)
	portalRing.Position = MapService.SpawnPosition + Vector3.new(0, 5, 0)
	portalRing.Anchored = true
	portalRing.CanCollide = false
	portalRing.Material = Enum.Material.Neon
	portalRing.Color = Color3.fromRGB(220, 50, 80)
	portalRing.Parent = spawnModel

	print("[MapService] Arena, track, waypoints, crystal, and spawn portal generated successfully.")
end

function MapService.GetWaypoints(): { Vector3 }
	return MapService.Waypoints
end

function MapService.IsPositionOnTrack(targetPos: Vector3, clearancePadding: number?): boolean
	local padding = clearancePadding or 2
	local threshold = (TRACK_WIDTH / 2) + padding

	for _, segment in ipairs(MapService.TrackSegments) do
		local p1 = segment.Start
		local p2 = segment.End

		local segVec = Vector3.new(p2.X - p1.X, 0, p2.Z - p1.Z)
		local segLength = segVec.Magnitude
		if segLength > 0 then
			local segDir = segVec / segLength
			local targetVec = Vector3.new(targetPos.X - p1.X, 0, targetPos.Z - p1.Z)
			local projection = targetVec:Dot(segDir)

			if projection >= -padding and projection <= segLength + padding then
				local closestPoint = p1 + (segDir * math.clamp(projection, 0, segLength))
				local dist = MathUtil.DistanceXZ(targetPos, closestPoint)
				if dist < threshold then
					return true
				end
			end
		end
	end

	-- Also protect the Base Crystal and Spawn Portal area
	if MathUtil.DistanceXZ(targetPos, MapService.BasePosition) < 12 then
		return true
	end
	if MathUtil.DistanceXZ(targetPos, MapService.SpawnPosition) < 12 then
		return true
	end

	return false
end

return MapService
