-- Conqueror of Azeroth class definitions (tokens from UnitClass on CoA)
SolarPower.CoAClasses = {
	{ token = "NECROMANCER",    index = 23, name = "Necromancer",      defaultDevotion = 1 },
	{ token = "PYROMANCER",     index = 24, name = "Pyromancer",       defaultDevotion = 1 },
	{ token = "CULTIST",        index = 25, name = "Cultist",          defaultDevotion = 1 },
	{ token = "STARCALLER",     index = 26, name = "Starcaller",       defaultDevotion = 1 },
	{ token = "SUNCLERIC",      index = 27, name = "Sun Cleric",       defaultDevotion = 1 },
	{ token = "TINKER",         index = 28, name = "Tinker",           defaultDevotion = 1 },
	{ token = "SPIRITMAGE",     index = 3,  name = "Runemaster",       defaultDevotion = 1 },
	{ token = "WILDWALKER",     index = 31, name = "Primalist",        defaultDevotion = 1 },
	{ token = "REAPER",         index = 31, name = "Reaper",           defaultDevotion = 1 },
	{ token = "PROPHET",        index = 29, name = "Venomancer",       defaultDevotion = 1 },
	{ token = "CHRONOMANCER",   index = 33, name = "Chronomancer",     defaultDevotion = 1 },
	{ token = "SONOFARUGAL",    index = 34, name = "Son of Arugal",    defaultDevotion = 1 },
	{ token = "GUARDIAN",       index = 35, name = "Guardian",         defaultDevotion = 1 },
	{ token = "STORMBRINGER",   index = 36, name = "Stormbringer",     defaultDevotion = 1 },
	{ token = "DEMONHUNTER",    index = 14, name = "Felsworn",         defaultDevotion = 1 },
	{ token = "BARBARIAN",      index = 38, name = "Barbarian",        defaultDevotion = 1 },
	{ token = "WITCHDOCTOR",    index = 39, name = "Witch Doctor",     defaultDevotion = 1 },
	{ token = "WITCHHUNTER",    index = 40, name = "Witch Hunter",     defaultDevotion = 1 },
	{ token = "FLESHWARDEN",    index = 17, name = "Knight of Xoroth", defaultDevotion = 1 },
	{ token = "MONK",           index = 19, name = "Templar",          defaultDevotion = 1 },
	{ token = "RANGER",         index = 43, name = "Ranger",           defaultDevotion = 1 },
	{ token = "PET",            index = nil, name = "Pets",             defaultDevotion = 1 },
}

SolarPower.ClassID = {}
SolarPower.ClassToID = {}
SolarPower.ClassColors = {}
SolarPower.ClassDisplayNames = {}

local classColors = {
	{ r = 0.77, g = 0.12, b = 0.23 }, -- Necromancer
	{ r = 1.00, g = 0.45, b = 0.10 }, -- Pyromancer
	{ r = 0.55, g = 0.10, b = 0.55 }, -- Cultist
	{ r = 0.40, g = 0.60, b = 1.00 }, -- Starcaller
	{ r = 1.00, g = 0.82, b = 0.20 }, -- Sun Cleric
	{ r = 0.60, g = 0.60, b = 0.60 }, -- Tinker
	{ r = 0.20, g = 0.60, b = 0.86 }, -- Runemaster
	{ r = 0.20, g = 0.80, b = 0.20 }, -- Primalist
	{ r = 0.50, g = 0.10, b = 0.10 }, -- Reaper
	{ r = 0.10, g = 0.70, b = 0.20 }, -- Venomancer
	{ r = 0.30, g = 0.50, b = 0.90 }, -- Chronomancer
	{ r = 0.60, g = 0.30, b = 0.60 }, -- Son of Arugal
	{ r = 0.70, g = 0.70, b = 0.80 }, -- Guardian
	{ r = 0.30, g = 0.70, b = 1.00 }, -- Stormbringer
	{ r = 0.60, g = 0.10, b = 0.60 }, -- Felsworn
	{ r = 0.80, g = 0.40, b = 0.10 }, -- Barbarian
	{ r = 0.10, g = 0.70, b = 0.50 }, -- Witch Doctor
	{ r = 0.80, g = 0.60, b = 0.20 }, -- Witch Hunter
	{ r = 0.40, g = 0.10, b = 0.10 }, -- Knight of Xoroth
	{ r = 0.90, g = 0.80, b = 0.50 }, -- Templar
	{ r = 0.20, g = 0.60, b = 0.20 }, -- Ranger
	{ r = 0.85, g = 0.70, b = 0.45 }, -- Pets
}

for id, classInfo in ipairs(SolarPower.CoAClasses) do
	SolarPower.ClassID[id] = classInfo.token
	SolarPower.ClassToID[classInfo.token] = id
	SolarPower.ClassDisplayNames[classInfo.token] = classInfo.name
	local color = classColors[id] or { r = 0.5, g = 0.5, b = 0.5 }
	SolarPower.ClassColors[classInfo.token] = color
end

SolarPower.ClassIconAtlas = "Interface\\GLUES\\CHARACTERCREATE\\UI-CHARACTERCREATE-CLASSES"
SolarPower.PetClassIcon = "Interface\\AddOns\\SolarPower\\Icons\\Pet"

function SolarPower:SetClassIcon(texture, classID)
	if not texture then
		return
	end
	local classInfo = self.CoAClasses[classID]
	if not classInfo then
		return
	end
	if classInfo.token == "PET" then
		texture:SetTexture(self.PetClassIcon)
		texture:SetTexCoord(0, 1, 0, 1)
		return
	end
	local coords = CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[classInfo.token]
	if coords then
		texture:SetTexture(self.ClassIconAtlas)
		texture:SetTexCoord(coords[1], coords[2], coords[3], coords[4])
	else
		texture:SetTexture("Interface\\Icons\\Devotion_of_Radiance")
		texture:SetTexCoord(0, 1, 0, 1)
	end
end

function SolarPower:DumpClassToken(unit)
	unit = unit or "target"
	if not UnitExists(unit) then
		self:Print("No unit selected. Target a player or use: /sp dumpclass party1")
		return
	end
	local token, index = select(2, UnitClass(unit)), select(3, UnitClass(unit))
	local name = UnitName(unit)
	self:Print(string.format("%s: %s=%s", name or unit, token or "?", tostring(index or "?")))
end
