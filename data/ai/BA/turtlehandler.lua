require "unittable"
require "unitlists"

local DebugEnabled = false

local function EchoDebug(inStr)
	if DebugEnabled then
		game:SendToConsole("TurtleHandler: " .. inStr)
	end
end

local antinukeMod = 1000
local shieldMod = 1000
local jamMod = 1000
local radarMod = 1000
local sonarMod = 1000
local distanceMod = 200

local factoryPriority = 4 -- added to tech level

TurtleHandler = class(Module)

function TurtleHandler:Name()
	return "TurtleHandler"
end

function TurtleHandler:internalName()
	return "turtlehandler"
end

function TurtleHandler:Init()
	self.turtles = {} -- things to protect
	self.shells = {} -- defense buildings, shields, and jamming
	self.totalPriority = 0
end

function TurtleHandler:UnitBuilt(unit)
	local un = unit:Name()
	local ut = unitTable[un]
	if ut.isBuilding then
		local upos = unit:GetPosition()
		local uid = unit:ID()
		if defendList[un] then
			self:AddTurtle(upos, uid, defendList[un])
		elseif ut.buildOptions then
			self:AddTurtle(upos, uid, factoryPriority + ut.techLevel)
		elseif ut.isWeapon and not antinukeList[un] and not nukeList[un] and not bigPlasmaList[un] then
			self:AddDefense(upos, uid, un)
		elseif antinukeList[un] then
			self:AddShell(upos, uid, 1, "antinuke", 72000)
		elseif shieldList[un] then
			self:AddShell(upos, uid, 1, "shield", 450)
		elseif ut.jammerRadius ~= 0 then
			self:AddShell(upos, uid, 1, "jam", ut.jammerRadius)
		elseif ut.radarRadius ~= 0 then
			self:AddShell(upos, uid, 1, "radar", ut.radarRadius * 0.5)
		elseif ut.sonarRadius ~= 0 then
			self:AddShell(upos, uid, 1, "sonar", ut.sonarRadius * 0.5)
		end
	end
end

function TurtleHandler:UnitDead(unit)
	local un = unit:Name()
	local ut = unitTable[un]
	if ut.isBuilding then
		if ut.isWeapon or shieldList[un] then
			self:RemoveShell(unit:ID())
		elseif defendList[un] or ut.buildOptions then
			self:RemoveTurtle(unit:ID())
		end
	end
end


function TurtleHandler:AddTurtle(position, uid, priority)
	local turtle = {position = position, uid = uid, priority = priority, ground = 0, air = 0, submerged = 0, antinuke = 0, shield = 0, jam = 0, radar = 0, sonar = 0}
	for i, shell in pairs(self.shells) do
		local dist = distance(position, shell.position)
		if dist < shell.radius then
			turtle[shell.layer] = turtle[shell.layer] + shell.value
			table.insert(shell.attachments, turtle)
		end
	end
	table.insert(self.turtles, turtle)
	self.totalPriority = self.totalPriority + priority
end

function TurtleHandler:RemoveTurtle(uid)
	for i, turtle in pairs(self.turtles) do
		if turtle.uid == uid then
			table.remove(self.turtles, i)
			self.totalPriority = self.totalPriority - turtle.priority
		end
	end
	for si, shell in pairs(self.shells) do
		for ti, turtle in pairs(shell.attachments) do
			if turtle.uid == uid then
				table.remove(shell.attachments, ti)
			end
		end
	end
end

function TurtleHandler:AddDefense(position, uid, unitName)
	local ut = unitTable[unitName]
	-- effective defense ranges are less than actual ranges, because if a building is just inside a weapon range, it's not defended
	local defense = ut.metalCost
	if ut.groundRange ~= 0 then
		self:AddShell(position, uid, defense, "ground", ut.groundRange * 0.5)
	end
	if ut.airRange ~= 0 then
		self:AddShell(position, uid, defense, "air", ut.airRange * 0.5)
	end
	if ut.submergedRange ~= 0 then
		self:AddShell(position, uid, defense, "submerged", ut.submergedRange * 0.5)
	end
end

function TurtleHandler:AddShell(position, uid, value, layer, radius)
	local attachments = {}
	for i, turtle in pairs(self.turtles) do
		local dist = distance(position, turtle.position)
		if dist < radius then
			turtle[layer] = turtle[layer] + value
			table.insert(attachments, turtle)
		end
	end
	table.insert(self.shells, {position = position, uid = uid, value = value, layer = layer, radius = radius, attachments = attachments})
end

function TurtleHandler:RemoveShell(uid)
	for si, shell in pairs(self.shells) do
		if shell.uid == uid then
			for ti, turtle in pairs(shell.attachments) do
				turtle[shell.layer] = turtle[shell.layer] - shell.value
			end
			table.remove(self.shells, si)
		end
	end
end

function TurtleHandler:LeastTurtled(builder, unitName, bombard)
	if builder == nil then return end
	EchoDebug("checking for least turtled from " .. builder:Name() .. " for " .. tostring(unitName) .. " bombard: " .. tostring(bombard))
	if unitName == nil then return end
	local position = builder:GetPosition()
	local ut = unitTable[unitName]
	local Metal = game:GetResourceByName("Metal")
	local ground, air, submerged, antinuke, shield, jam, radar, sonar
	if ut.isWeapon and not antinukeList[unitName] then
		if ut.groundRange ~= 0 then
			ground = true
		end
		if ut.airRange ~= 0 then
			air = true
		end
		if ut.submergedRange ~= 0 then
			submerged = true
		end
	elseif antinukeList[unitName] then
		antinuke = true
	elseif shieldList[unitName] then
		shield = true
	elseif ut.jammerRadius ~= 0 then
		jam = true
	elseif ut.radarRadius ~= 0 then
		radar = true
	elseif ut.sonarRadius ~= 0 then
		sonar = true
	end
	local bestDist = 100000
	local best
	for i, turtle in pairs(self.turtles) do
		local isLocal = true
		if ground or air or submerged then
			isLocal = ai.maphandler:CheckDefenseLocalization(unitName, turtle.position)
		end
		if ai.maphandler:UnitCanGoHere(builder, turtle.position) and isLocal then
			local okay = true
			if bombard and unitName ~= nil then 
				okay = ai.targethandler:IsBombardPosition(turtle.position, unitName)
			end
			if okay then
				local mod = 0
				if ground then mod = mod + turtle.ground end
				if air then mod = mod + turtle.air end
				if submerged then mod = mod + turtle.submerged end
				if antinuke then mod = mod + turtle.antinuke * antinukeMod end
				if shield then mod = mod + turtle.shield * shieldMod end
				if jam then mod = mod + turtle.jam * jamMod end
				if radar then mod = mod + turtle.radar * radarMod end
				if sonar then mod = mod + turtle.sonar * sonarMod end
				local modLimit = (turtle.priority / self.totalPriority) * Metal.income * 80
				modLimit = math.floor(modLimit)
				EchoDebug("turtled: " .. mod .. ", limit: " .. tostring(modLimit) .. ", priority: " .. turtle.priority .. ", total priority: " .. self.totalPriority)
				if mod < modLimit then
					local dist = distance(position, turtle.position)
					dist = dist - (modLimit * distanceMod)
					EchoDebug("distance: " .. dist)
					if dist < bestDist then
						EchoDebug("best distance")
						bestDist = dist
						best = turtle.position
					end
				end
			end
		end
	end
	return best
end

function TurtleHandler:MostTurtled(builder, bombard)
	if builder == nil then return end
	EchoDebug("checking for most turtled from " .. builder:Name() .. ", bombard: " .. tostring(bombard))
	local position = builder:GetPosition()
	local bestDist = 100000
	local best
	for i, turtle in pairs(self.turtles) do
		if ai.maphandler:UnitCanGoHere(builder, turtle.position) then
			local okay = true
			if bombard then 
				okay = ai.targethandler:IsBombardPosition(turtle.position, bombard)
			end
			if okay then
				local mod = turtle.ground + turtle.air + turtle.submerged
				EchoDebug("turtled: " .. mod .. ", priority: " .. turtle.priority .. ", total priority: " .. self.totalPriority)
				if mod ~= 0 then
					local dist = distance(position, turtle.position)
					dist = dist - (mod * distanceMod)
					EchoDebug("distance: " .. dist)
					if dist < bestDist then
						EchoDebug("best distance")
						bestDist = dist
						best = turtle.position
					end
				end
			end
		end
	end
	return best
end