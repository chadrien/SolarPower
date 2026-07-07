-- Luacheck config for SolarPower (WoW 3.3.5a / WotLK, Project Ascension CoA)
-- Run from repo root:
--   luacheck SolarPower/*.lua --no-color --no-max-line-length --exclude-files SolarPower/libs

std = "lua51"
max_line_length = false

exclude_files = {
	"SolarPower/libs/**",
	"dist/**",
}

-- Common WoW addon idioms; keep real undefined-variable bugs visible.
ignore = {
	"212/self",
	"212/event",
	"212/level",
	"212/value",
	"212/msg",
	"212/mousebutton",
	"212/button",
	"212/displayedButtons",
	"21./_.*",
	-- Inherited PallyPower style (fix opportunistically, not blocking CI).
	"611", -- trailing whitespace
	"612", -- line contains only whitespace
	"621", -- inconsistent indentation (SPACE/TAB mix)
}

-- Globals this addon defines or assigns (XML callbacks, locale strings, legacy parse temps).
globals = {
	"SolarPower",
	"SolarPowerDB",
	"SolarPower_Assignments",
	"SolarPower_NormalAssignments",
	"SolarPower_AuraAssignments",
	"SolarPower_SavedPresets",
	"SOLARPOWER_MAXCLASSES",
	"SOLARPOWER_MAXPERCLASS",
	"SOLARPOWER_MAXBLESSINGS",
	"SOLARPOWER_MAXAURAS",
	"SOLARPOWER_DEFAULT_VALUES",
	"SOLARPOWER_NORMALBLESSINGDURATION",
	"SOLARPOWER_GREATERBLESSINGDURATION",
	"SOLARPOWER_CONFIG_COLUMN_WIDTH",
	"SOLARPOWER_CONFIG_NAME_WIDTH",
	"SOLARPOWER_CONFIG_CLASS_COLUMNS",
	"SOLARPOWER_CONFIG_GRID_WIDTH",
	"SOLARPOWER_CONFIG_CLASS_HEADER_HEIGHT",
	"SOLARPOWER_CONFIG_CLASS_PLAYER_ROW_STEP",
	"SOLARPOWER_CONFIG_GRID_TOP_PADDING",
	"SOLARPOWER_CONFIG_GRID_BOTTOM_PADDING",
	"SOLARPOWER_CONFIG_HEADER_CLERIC_GAP",
	"SOLARPOWER_CONFIG_CLERIC_ROW_HEIGHT",
	"SOLARPOWER_CONFIG_FRAME_WIDTH",
	"SOLARPOWER_CONFIG_MIN_WIDTH",
	"SOLARPOWER_CONFIG_MAX_WIDTH",
	"SOLARPOWER_CONFIG_MIN_HEIGHT",
	"SOLARPOWER_CONFIG_MAX_HEIGHT",
	"SOLARPOWER_CONFIG_VIEWPORT_WIDTH",
	"SOLARPOWER_CONFIG_SCROLL_TOP",
	"SOLARPOWER_CONFIG_SCROLL_BOTTOM",
	"SOLPWR",
	"LOCK_ACTIONBAR",
	"AllPallys",
	"SyncList",
	"ChatControl",
	"LastCast",
	"PP_IsCleric",
	"PP_Symbols",
	"flavor",

	-- Locale / config UI strings (written in SolarPowerValues.lua).
	"SolarPower_Credits1",
	"SOLARPOWER_CLEAR",
	"SOLARPOWER_REFRESH",
	"SOLARPOWER_OPTIONS",
	"SOLARPOWER_AUTOASSIGN",
	"SOLARPOWER_FREEASSIGN",
	"SOLARPOWER_ASSIGNMENTS1",
	"SOLARPOWER_ASSIGNMENTS2",

	-- XML OnClick / OnLoad handlers and config callbacks.
	"SolarPowerConfigFrame_UpdateFlavor",
	"SolarPowerConfig_Clear",
	"SolarPowerConfig_Options",
	"SolarPowerConfig_Refresh",
	"SolarPowerConfig_Toggle",
	"SolarPowerConfig_ShowCredits",
	"SolarPowerConfigFrame_MouseUp",
	"SolarPowerConfigFrame_MouseDown",
	"SolarPowerConfigGrid_Update",
	"SolarPowerGrid_NormalBlessingMenu",
	"SolarPowerPlayerButton_OnClick",
	"SolarPowerPlayerButton_OnMouseWheel",
	"SolarPowerGridButton_OnClick",
	"SolarPowerGridButton_OnMouseWheel",
	"PlayerButton_DragStart",
	"PlayerButton_DragStop",
	"GetNormalBlessings",
	"SetNormalBlessings",

	-- Legacy PallyPower message-parse temporaries (implicit globals).
	"_",
	"name",
	"class",
	"skill",
	"aura",
	"assign",
	"numbers",
	"rank",
	"talent",
	"count",
	"tmp",
	"cur",
	"shift",
	"spell2",
	"classDuration",
	"specialDuration",
	"cx",
	"cy",
	"px",
	"py",

	-- FrameXML-defined addon frames (methods/properties mutated from Lua).
	SolarPowerFrame = { other_fields = true },
	SolarPowerAnchor = { other_fields = true },
	SolarPowerConfigFrame = { other_fields = true },
	"SolarPowerConfigFrameFreeAssign",
	SolarPowerAuto = { other_fields = true },
}

-- WoW 3.3.5 client API and FrameXML globals (read-only from addon code).
read_globals = {
	-- Third-party libraries bundled with the addon.
	"AceLibrary",

	-- Lua / Blizzard table helpers (WoW 3.3.5 embeds Lua 5.1).
	"min",
	"max",
	"floor",
	"ceil",
	"mod",
	"time",
	"strsplit",
	"strjoin",
	"strtrim",
	"tinsert",
	"tremove",
	"wipe",
	"getglobal",
	table = {
		fields = {
			"wipe",
			"getn",
		},
	},

	-- Addon messaging.
	"RegisterAddonMessagePrefix",
	"SendAddonMessage",

	-- Units and roster.
	"UnitName",
	"UnitClass",
	"UnitExists",
	"UnitBuff",
	"UnitAura",
	"UnitIsDeadOrGhost",
	"UnitIsPartyLeader",
	"UnitCreatureFamily",
	"GetNumRaidMembers",
	"GetNumPartyMembers",
	"GetRaidRosterInfo",
	"MAX_RAID_MEMBERS",
	"MAX_PARTY_MEMBERS",
	"IsPartyLeader",
	"IsRaidLeader",
	"IsRaidOfficer",

	-- Spells and items.
	"GetSpellInfo",
	"GetItemCount",
	"IsSpellInRange",
	"GetActiveTalentGroup",
	"CLASS_ICON_TCOORDS",

	-- Time, combat, instances.
	"GetTime",
	"InCombatLockdown",
	"IsInInstance",
	"IsShiftKeyDown",
	"IsControlKeyDown",
	"IsAltKeyDown",

	-- Frames and UI.
	"CreateFrame",
	"UIParent",
	"GameTooltip",
	"MouseIsOver",
	"this",
	"SetOverrideBindingClick",
	"ClearOverrideBindings",
	"SecureHandlerExecute",
	"SecureHandlerSetFrameRef",
	"displayedButtons",

	-- Chat / system messages.
	"SendChatMessage",
	"arg1",
	"ERR_NOT_LEADER",
	"ERR_NOT_IN_RAID",
	"ERR_RAID_YOU_JOINED",
	"ERR_RAID_YOU_LEFT",
	"ERR_LEFT_GROUP_YOU",
	"ERR_GROUP_DISBANDED",
}

-- Per-file overrides (returned so luacheck merges them reliably).
return {
	files = {
		["**/SolarPower.lua"] = {
			ignore = {
				"211", -- unused local
				"213", -- unused loop variable
				"231", -- never accessed
				"311", -- assigned but unused
				"411", -- variable previously defined
				"412", -- argument previously defined
				"413", -- loop variable previously defined
				"421", -- shadowing local
				"423", -- shadowing loop variable
				"431", -- shadowing upvalue
				"542", -- empty if branch
			},
		},
	},
}
