local L = AceLibrary("AceLocale-2.2"):new("SolarPower")

SolarPower.commPrefix = "SOLPWR"

SOLARPOWER_MAXCLASSES = 22
SOLARPOWER_MAXPERCLASS = 8
SOLARPOWER_NORMALBLESSINGDURATION = 30 * 60
SOLARPOWER_GREATERBLESSINGDURATION = 30 * 60
SOLARPOWER_MAXAURAS = 0
SOLARPOWER_MAXBLESSINGS = 4

SOLARPOWER_CONFIG_COLUMN_WIDTH = 86
SOLARPOWER_CONFIG_NAME_WIDTH = 136
SOLARPOWER_CONFIG_CLASS_COLUMNS = 22
SOLARPOWER_CONFIG_GRID_WIDTH = SOLARPOWER_CONFIG_NAME_WIDTH + SOLARPOWER_CONFIG_CLASS_COLUMNS * SOLARPOWER_CONFIG_COLUMN_WIDTH
SOLARPOWER_CONFIG_CLERIC_ROW_HEIGHT = 56
SOLARPOWER_CONFIG_CLASS_HEADER_HEIGHT = 54
SOLARPOWER_CONFIG_CLASS_PLAYER_ROW_STEP = 13
SOLARPOWER_CONFIG_GRID_TOP_PADDING = 10
SOLARPOWER_CONFIG_GRID_BOTTOM_PADDING = 10
SOLARPOWER_CONFIG_HEADER_CLERIC_GAP = 6
SOLARPOWER_CONFIG_VIEWPORT_WIDTH = 960
SOLARPOWER_CONFIG_SCROLL_TOP = 34
SOLARPOWER_CONFIG_SCROLL_BOTTOM = 44
SOLARPOWER_CONFIG_FRAME_WIDTH = SOLARPOWER_CONFIG_VIEWPORT_WIDTH + 16
SOLARPOWER_CONFIG_MIN_WIDTH = 400
SOLARPOWER_CONFIG_MAX_WIDTH = SOLARPOWER_CONFIG_GRID_WIDTH + 24
SOLARPOWER_CONFIG_MIN_HEIGHT = 180
SOLARPOWER_CONFIG_MAX_HEIGHT = 900

SolarPower.IsVanilla = false
SolarPower.IsTBC = false
SolarPower.IsVanillaOrTBC = false
SolarPower.IsWrath = false
SolarPower.IsCoA = true

SolarPower.CONFIG_DRAGHANDLE = L["DRAGHANDLE"]

local defaultBuffs = {}
for i = 1, SOLARPOWER_MAXCLASSES do
	defaultBuffs[i] = 0
end

SOLARPOWER_DEFAULT_VALUES = {
	buffscale = 0.75,
	configscale = 0.65,
	configwidth = nil,
	configheight = nil,
	smartbuffs = true,
	smartpets = true,
	greaterbuffs = false,
	extras = false,
	autobuff = {
		autokey1 = ",",
		autokey2 = "CTRL-,",
		autobutton = true,
		waitforpeople = false,
	},
	display = {
		rows = 11,
		columns = 2,
		gapping = -1,
		buttonWidth = 100,
		buttonHeight = 34,
		alignClassButtons = "9",
		alignPlayerButtons = "compact-left",
		edges = true,
		frameLocked = false,
		hideDragHandle = false,
		hidePlayerButtons = false,
		hideClassButtons = true,
		classColor = false,
		nameClassColor = false,
		flashBuffAutoButtons = true,
		PlainButtons = false,
		HideKeyText = false,
		HideCount = false,
		LockBuffBars = false,
		HideCountText = false,
		HideTimerText = false,
	},
	ShowInParty = true,
	ShowWhenSingle = true,
	skin = "Smooth",
	cBuffNeedAll = { r = 1.0, g = 0.0, b = 0.0, t = 0.5 },
	cBuffNeedSome = { r = 1.0, g = 1.0, b = 0.5, t = 0.5 },
	cBuffNeedSpecial = { r = 0.0, g = 0.0, b = 1.0, t = 0.5 },
	cBuffGood = { r = 0.0, g = 0.7, b = 0.0, t = 0.5 },
	sets = {
		["primary"] = {
			buffs = { unpack(defaultBuffs) },
		},
		["secondary"] = {
			buffs = { unpack(defaultBuffs) },
		},
	},
	disabled = false,
	layout = "Standard",
}

SolarPower_Credits1 = "SolarPower - CoA Sun Cleric Devotions"
SolarPower.BuffBarTitle = "Solar Devotions (%d)"

SOLARPOWER_CLEAR = L["PP_CLEAR"]
SOLARPOWER_REFRESH = L["PP_REFRESH"]
SOLARPOWER_OPTIONS = L["PP_OPTIONS"]
SOLARPOWER_AUTOASSIGN = L["AUTOASSIGN"]
SOLARPOWER_FREEASSIGN = L["FREEASSIGN"]
SOLARPOWER_ASSIGNMENTS1 = L["PP_RAS1"]
SOLARPOWER_ASSIGNMENTS2 = L["PP_RAS2"]

SolarPower.Skins = {
	["None"] = "Interface\\Tooltips\\UI-Tooltip-Background",
	["Banto"] = "Interface\\AddOns\\SolarPower\\Skins\\Banto",
	["BantoBarReverse"] = "Interface\\AddOns\\SolarPower\\Skins\\BantoBarReverse",
	["Glaze"] = "Interface\\AddOns\\SolarPower\\Skins\\Glaze",
	["Gloss"] = "Interface\\AddOns\\SolarPower\\Skins\\Gloss",
	["Healbot"] = "Interface\\AddOns\\SolarPower\\Skins\\Healbot",
	["oCB"] = "Interface\\AddOns\\SolarPower\\Skins\\oCB",
	["Smooth"] = "Interface\\AddOns\\SolarPower\\Skins\\Smooth",
}

SolarPower.Edge = "Interface\\Tooltips\\UI-Tooltip-Border"

SolarPower.Templates = {
	[1] = {},
	[2] = {},
	[3] = {},
	[4] = {},
}

for classId, classInfo in ipairs(SolarPower.CoAClasses) do
	local devotion = classInfo.defaultDevotion or 1
	for templateId = 1, 4 do
		SolarPower.Templates[templateId][classId] = { devotion }
	end
end

SolarPower.Layouts = {
	["Standard"] = true,
}

function SolarPower:ApplyCoADefaultAssignments(playerName)
	if not SolarPower_Assignments.CoA[playerName] then
		SolarPower_Assignments.CoA[playerName] = {}
	end
	for classId, classInfo in ipairs(self.CoAClasses) do
		SolarPower_Assignments.CoA[playerName][classId] = classInfo.defaultDevotion or 0
	end
end
