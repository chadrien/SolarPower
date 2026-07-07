SolarPower = AceLibrary("AceAddon-2.0"):new("AceConsole-2.0","AceDB-2.0","AceEvent-2.0","AceDebug-2.0")

local dewdrop = AceLibrary("Dewdrop-2.0")
local L = AceLibrary("AceLocale-2.2"):new("SolarPower")
local tinsert = table.insert
local tremove = table.remove
local twipe = table.wipe
local tsort = table.sort
local sfind = string.find
local ssub = string.sub
local sformat = string.format
local IsInInstance = IsInInstance

local classlist, classes = {}, {}
LastCast = {}

SolarPower_Assignments = {}
SolarPower_NormalAssignments = {}
SolarPower_AuraAssignments = {}
SolarPower_Assignments["CoA"] = {}
SolarPower_NormalAssignments["CoA"] = {}
SolarPower_AuraAssignments["CoA"] = {}

local flavor = "CoA"

SolarPower.IsVanilla = false
SolarPower.IsTBC = false
SolarPower.IsVanillaOrTBC = false
SolarPower.IsWrath = false
SolarPower.IsCoA = true

SolarPower_SavedPresets = {}

AllPallys = {}
SyncList = {}
ChatControl = {}

local initalized = false
PP_Symbols = 0
PP_IsCleric = false

-- unit tables
local party_units = {}
local raid_units = {}
local leaders = {}
local roster = {}

do
	table.insert(party_units, "player")
	table.insert(party_units, "pet")

	for i = 1, MAX_PARTY_MEMBERS do
		table.insert(party_units, ("party%d"):format(i))
		table.insert(party_units, ("partypet%d"):format(i))
	end

	for i = 1, MAX_RAID_MEMBERS do
		table.insert(raid_units, ("raid%d"):format(i))
		table.insert(raid_units, ("raidpet%d"):format(i))
	end
end

function SolarPower:OnInitialize()
	self.AutoBuffedList = {}
	self.PreviousAutoBuffedUnit = nil
	self:RegisterDB("SolarPowerDB")
	self:RegisterChatCommand({"/solarpower", "/sp"}, self.options)
	self:HookSlashCommand()
	self:RegisterDefaults("profile", SOLARPOWER_DEFAULT_VALUES)
	self.player = UnitName("player")
	self.opt = self.db.profile
	self:MigrateDisplayOptions()
	self:BuildSpellTables()
	self:ScanInventory()
	self:CreateLayout()
	self:InitConfigScroll()
	if self.opt.skin then
		SolarPower:ApplySkin(self.opt.skin)
	end
	SolarPowerConfigFrame_UpdateFlavor()
	dewdrop:Register(SolarPowerConfigFrame, "children",
		function(level, value) dewdrop:FeedAceOptionsTable(self.options) end,
		"dontHook", true
	)
end

function SolarPower:HookSlashCommand()
	local aceHandler = _G.SlashCmdList and _G.SlashCmdList["SOLARPOWER"]
	if not aceHandler or self.slashHooked then
		return
	end
	self.slashHooked = true
	_G.SlashCmdList["SOLARPOWER"] = function(msg, editBox)
		msg = (msg or ""):match("^%s*(.-)%s*$")
		local unit = msg:match("^dumpclass%s+(%S+)$")
		if unit then
			self:DumpClassToken(unit)
			return
		end
		if msg == "dumpclass" then
			self:DumpClassToken("target")
			return
		end
		return aceHandler(msg, editBox)
	end
end

function SolarPowerConfigFrame_UpdateFlavor()
	local frame = getglobal("SolarPowerConfigFrame")
	if frame then
		SolarPower:ApplyConfigFrameSize(SOLARPOWER_CONFIG_CLASS_HEADER_HEIGHT + SOLARPOWER_CONFIG_GRID_TOP_PADDING + SOLARPOWER_CONFIG_GRID_BOTTOM_PADDING)
	end
	for i = 1, SOLARPOWER_MAXCLASSES do
		local group = getglobal("SolarPowerConfigFrameClassGroup" .. i)
		if group then
			group:Show()
		end
	end
end

function SolarPower:MigrateDisplayOptions()
	local opt = self.opt
	if not opt or not opt.display then return end
	if opt.hideClassButtons ~= nil then
		opt.display.hideClassButtons = opt.hideClassButtons
		opt.hideClassButtons = nil
	end
	if opt.flashBuffAutoButtons ~= nil then
		opt.display.flashBuffAutoButtons = opt.flashBuffAutoButtons
		opt.flashBuffAutoButtons = nil
	end
	if opt.classColor ~= nil then
		opt.display.classColor = opt.classColor
		opt.classColor = nil
	end
	if opt.nameClassColor ~= nil then
		opt.display.nameClassColor = opt.nameClassColor
		opt.nameClassColor = nil
	end
end

function SolarPower:OnProfileEnable()
    self.opt = self.db.profile
	self:MigrateDisplayOptions()
	SolarPower:UpdateLayout()
end

function SolarPower:OnEnable()
	-- events
	self.opt.disable = false
	self.AutoBuffedList = self.AutoBuffedList or {}
	self.PreviousAutoBuffedUnit = self.PreviousAutoBuffedUnit or nil
	self:ScanSpells()
	self:RegisterEvent("CHAT_MSG_ADDON")
	self:RegisterEvent("CHAT_MSG_SYSTEM")
	self:RegisterEvent("PLAYER_REGEN_ENABLED")
	self:RegisterEvent("ACTIVE_TALENT_GROUP_CHANGED")
	self:RegisterBucketEvent("SPELLS_CHANGED", 1, "SPELLS_CHANGED")
	self:RegisterBucketEvent({"RAID_ROSTER_UPDATE", "PARTY_MEMBERS_CHANGED", "UNIT_PET"}, 1, "UpdateRoster")
	self:ScheduleRepeatingEvent("SolarPowerInventoryScan", self.InventoryScan, 60, self)
	self:UpdateRoster()
	self:BindKeys()
end

function SolarPower:BindKeys()
	-- First unbind stuff because clearing one removes both.
	if not self.opt.autobuff.autokey1 then
		self.opt.autobuff.autokey1 = false
	end
	if not self.opt.autobuff.autokey2 then
		self.opt.autobuff.autokey2 = false
	end
	if not self.opt.autobuff.autokey1 or not self.opt.autobuff.autokey2 then
		self:UnbindKeys()
	end
	if self.opt.autobuff.autokey1 then
		SetOverrideBindingClick(self.autoButton, false, self.opt.autobuff.autokey1, "SolarPowerAuto", "Hotkey1")
	end
	if self.opt.autobuff.autokey2 then
		SetOverrideBindingClick(self.autoButton, false, self.opt.autobuff.autokey2, "SolarPowerAuto", "Hotkey2")
	end
end

function SolarPower:OnDisable()
	-- events
	self.opt.disable = true
	for i = 1, SOLARPOWER_MAXCLASSES do
		classlist[i] = 0
		classes[i] = {}
	end
	self:UpdateLayout()
	self:UnbindKeys()
end

function SolarPower:UnbindKeys()
	ClearOverrideBindings(self.autoButton)
end

--
--  Config Window functionality
--

local function SolarPowerConfigScroll_OnMouseWheel(frame, delta)
	local scroll = SolarPower.configScroll or frame
	local child = SolarPower.configScrollChild
	if not scroll or not child then return end
	if IsControlKeyDown() then
		return
	end
	if IsShiftKeyDown() then
		local maxScroll = math.max(0, child:GetHeight() - scroll:GetHeight())
		if maxScroll <= 0 then return end
		local step = 24
		local newScroll = scroll:GetVerticalScroll() - delta * step
		if newScroll < 0 then newScroll = 0 end
		if newScroll > maxScroll then newScroll = maxScroll end
		scroll:SetVerticalScroll(newScroll)
		return
	end
	local maxScroll = math.max(0, child:GetWidth() - scroll:GetWidth())
	if maxScroll <= 0 then return end
	local step = SOLARPOWER_CONFIG_COLUMN_WIDTH
	local newScroll = scroll:GetHorizontalScroll() - delta * step
	if newScroll < 0 then newScroll = 0 end
	if newScroll > maxScroll then newScroll = maxScroll end
	scroll:SetHorizontalScroll(newScroll)
end

function SolarPower:GetConfigFrameWidth()
	local width = self.opt.configwidth or SOLARPOWER_CONFIG_FRAME_WIDTH
	if width < SOLARPOWER_CONFIG_MIN_WIDTH then
		width = SOLARPOWER_CONFIG_MIN_WIDTH
	end
	if width > SOLARPOWER_CONFIG_MAX_WIDTH then
		width = SOLARPOWER_CONFIG_MAX_WIDTH
	end
	return width
end

function SolarPower:GetConfigFrameHeight(contentMinHeight)
	local chrome = SOLARPOWER_CONFIG_SCROLL_TOP + SOLARPOWER_CONFIG_SCROLL_BOTTOM
	local height = self.opt.configheight or (contentMinHeight + chrome)
	if height < SOLARPOWER_CONFIG_MIN_HEIGHT then
		height = SOLARPOWER_CONFIG_MIN_HEIGHT
	end
	if height > SOLARPOWER_CONFIG_MAX_HEIGHT then
		height = SOLARPOWER_CONFIG_MAX_HEIGHT
	end
	return height
end

function SolarPower:ApplyConfigFrameSize(contentMinHeight)
	local frame = _G["SolarPowerConfigFrame"]
	if not frame or frame.isSizing then return end
	frame:SetWidth(self:GetConfigFrameWidth())
	frame:SetHeight(self:GetConfigFrameHeight(contentMinHeight))
end

function SolarPower:SaveConfigFrameSize()
	local frame = _G["SolarPowerConfigFrame"]
	if not frame then return end
	self.opt.configwidth = math.floor(frame:GetWidth() + 0.5)
	self.opt.configheight = math.floor(frame:GetHeight() + 0.5)
	self:UpdateConfigScroll()
end

function SolarPower:InitConfigResize(frame)
	if self.configResizeInit or not frame then return end
	self.configResizeInit = true

	if frame.SetMinResize then
		frame:SetMinResize(SOLARPOWER_CONFIG_MIN_WIDTH, SOLARPOWER_CONFIG_MIN_HEIGHT)
	end
	if frame.SetMaxResize then
		frame:SetMaxResize(SOLARPOWER_CONFIG_MAX_WIDTH, SOLARPOWER_CONFIG_MAX_HEIGHT)
	end

	local sizer = CreateFrame("Button", "SolarPowerConfigFrameSizer", frame)
	sizer:SetSize(16, 16)
	sizer:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -4, 4)
	sizer:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
	sizer:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
	sizer:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
	sizer:SetScript("OnMouseDown", function()
		frame:StartSizing("BOTTOMRIGHT")
		frame.isSizing = true
	end)
	sizer:SetScript("OnMouseUp", function()
		SolarPowerConfigFrame_MouseUp()
	end)
	sizer:SetScript("OnEnter", function()
		GameTooltip:SetOwner(sizer, "ANCHOR_TOPLEFT")
		GameTooltip:SetText("Drag to resize", 1, 1, 1)
		GameTooltip:Show()
	end)
	sizer:SetScript("OnLeave", function()
		GameTooltip:Hide()
	end)
	self.configSizer = sizer
end

function SolarPower:InitConfigScroll()
	if self.configScroll then return end
	local frame = _G["SolarPowerConfigFrame"]
	if not frame then return end

	local scroll = CreateFrame("ScrollFrame", "SolarPowerConfigFrameScroll", frame)
	scroll:SetPoint("TOPLEFT", frame, "TOPLEFT", 8, -SOLARPOWER_CONFIG_SCROLL_TOP)
	scroll:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -8, SOLARPOWER_CONFIG_SCROLL_BOTTOM)
	scroll:EnableMouseWheel(true)
	scroll:SetScript("OnMouseWheel", SolarPowerConfigScroll_OnMouseWheel)

	local child = CreateFrame("Frame", "SolarPowerConfigFrameScrollChild", scroll)
	scroll:SetScrollChild(child)

	for i = 1, SOLARPOWER_MAXCLASSES do
		local group = _G["SolarPowerConfigFrameClassGroup" .. i]
		if group then
			group:SetParent(child)
		end
	end
	for i = 1, 8 do
		local player = _G["SolarPowerConfigFramePlayer" .. i]
		if player then
			player:SetParent(child)
		end
	end

	local group1 = _G["SolarPowerConfigFrameClassGroup1"]
	if group1 then
		group1:ClearAllPoints()
		group1:SetPoint("TOPLEFT", child, "TOPLEFT", SOLARPOWER_CONFIG_NAME_WIDTH, -SOLARPOWER_CONFIG_GRID_TOP_PADDING)
	end

	child:SetWidth(SOLARPOWER_CONFIG_GRID_WIDTH)
	child:SetHeight(400)
	scroll:UpdateScrollChildRect()

	self.configScroll = scroll
	self.configScrollChild = child

	frame:EnableMouseWheel(true)
	frame:SetScript("OnMouseWheel", function(_, delta)
		SolarPowerConfigScroll_OnMouseWheel(scroll, delta)
	end)

	self:InitConfigResize(frame)
end

function SolarPower:UpdateConfigScroll(contentHeight)
	local scroll = self.configScroll
	local child = self.configScrollChild
	if not scroll or not child then return end
	child:SetWidth(SOLARPOWER_CONFIG_GRID_WIDTH)
	child:SetHeight(contentHeight or child:GetHeight())
	scroll:UpdateScrollChildRect()
	local maxHScroll = math.max(0, child:GetWidth() - scroll:GetWidth())
	local maxVScroll = math.max(0, child:GetHeight() - scroll:GetHeight())
	local hScroll = scroll:GetHorizontalScroll()
	local vScroll = scroll:GetVerticalScroll()
	if hScroll > maxHScroll then
		scroll:SetHorizontalScroll(maxHScroll)
	end
	if vScroll > maxVScroll then
		scroll:SetVerticalScroll(maxVScroll)
	end
end

function SolarPower:Purge()
	SolarPower_Assignments[flavor] = nil
	SolarPower_NormalAssignments[flavor] = nil
	SolarPower_AuraAssignments[flavor] = nil
	SolarPower_Assignments[flavor] = {}
	SolarPower_NormalAssignments[flavor] = {}
	SolarPower_AuraAssignments[flavor] = {}
end

function SolarPowerConfig_Clear()
	if InCombatLockdown() then return false end
	SolarPower:ClearAssignments(UnitName("player"))
	if SolarPower:CheckRaidLeader(UnitName("player")) then
		SolarPower:SendMessage("CLEAR")
	end
end

function SolarPowerConfig_Options()

end

function SolarPower:Reset()
	local h = _G["SolarPowerFrame"]
	h:ClearAllPoints()
	h:SetPoint("CENTER", "UIParent", "CENTER", 0, 0)
	local c = _G["SolarPowerConfigFrame"]
	c:ClearAllPoints()
    c:SetPoint("CENTER", "UIParent", "CENTER", 0, 0)
	self.opt.configwidth = nil
	self.opt.configheight = nil
	self:UpdateLayout()
end

function SolarPowerConfig_Refresh()
	AllPallys = {}
	SyncList = {}
	SolarPower:ScanSpells()
	SolarPower:ScanInventory()
	SolarPower:SendSelf()
	SolarPower:SendMessage("REQ")
	SolarPower:UpdateLayout()
end

function SolarPowerConfig_Toggle(msg)
	if SolarPowerConfigFrame:IsVisible() then
		SolarPowerConfigFrame:Hide()
	else
		local c = _G["SolarPowerConfigFrame"]
		c:ClearAllPoints()
    	c:SetPoint("CENTER", "UIParent", "CENTER", 0, 0)
		SolarPowerConfigFrame:Show()
	end
end

function SolarPowerConfig_ShowCredits()
	GameTooltip:SetOwner(this, "ANCHOR_TOPLEFT")
	GameTooltip:SetText(SolarPower_Credits1, 1, 1, 1)
--   GameTooltip:AddLine(SolarPower_Credits2, 1, 1, 1)
--   GameTooltip:AddLine(SolarPower_Credits3)
--   GameTooltip:AddLine(SolarPower_Credits4, 0, 1 ,0)
--   GameTooltip:AddLine(SolarPower_Credits5)
	GameTooltip:Show()
end

function GetNormalBlessings(pname, class, tname)
	if SolarPower_NormalAssignments[flavor][pname] and SolarPower_NormalAssignments[flavor][pname][class] then
		local blessing = SolarPower_NormalAssignments[flavor][pname][class][tname]
		if blessing then
			return SolarPower.Spells[blessing]
		else
			return "(none)"
		end
	end
end

local function GetNormalBlessingsIndexFromName(blessing)
	for k, v in ipairs(SolarPower.Spells) do
		if v == blessing then
			return k
		end
	end
	return 0
end

function SetNormalBlessings(pname, class, tname, value)
	if not SolarPower_NormalAssignments[flavor][pname] then
		SolarPower_NormalAssignments[flavor][pname] = {}
	end
	if not SolarPower_NormalAssignments[flavor][pname][class] then
		SolarPower_NormalAssignments[flavor][pname][class] = {}
	end
	SolarPower:SendMessage("NASSIGN "..pname.." "..class.." "..tname.." "..value)  
	if value == 0 then value = nil end
	SolarPower_NormalAssignments[flavor][pname][class][tname] = value
end

function SolarPowerGrid_NormalBlessingMenu(btn, mouseBtn, pname, class)
	if InCombatLockdown() then return false end
	if (mouseBtn == "LeftButton") then
		local tempoptions = {
			type = "group",
			args = {
				close = {
					name = "Close",
					desc = "Closes the menu.",
					order = 10,
					type = "execute",
					func = function() dewdrop:Close() end
				}
			}
		}
		local pre, suf
		for pally in pairs(AllPallys) do
			local control
			control = SolarPower:CanControl(pally)
			if not control then
				pre = "|cff999999"
				suf = "|r"
			else
				pre = ""
				suf = ""
			end
			local blessings = {[1] = sformat("%s%s%s", pre, "(none)", suf)}
			local orderIndex = 2
			for index, blessing in ipairs(SolarPower.Spells) do
				if SolarPower:CanBuff(pally, index) then
					--if SolarPower:NeedsBuff(class, index, pname) then
						blessings[orderIndex] = sformat("%s%s%s", pre, blessing, suf)
						orderIndex = orderIndex + 1
					--end
				end
			end
			tempoptions.args[pally] = {
				name = sformat("%s%s%s", pre, pally, suf),
				type = "text",
				desc = pally,
				order = 5,
				get = function() return GetNormalBlessings(pally, class, pname) end,
				set = function(value) if control then
					value = GetNormalBlessingsIndexFromName(value)
					SetNormalBlessings(pally, class, pname, value + 0)
				end end,
				validate = blessings,
			}
		end
		dewdrop:Register(btn, "children",
			function(level, value) dewdrop:FeedAceOptionsTable(tempoptions) end,
			"dontHook", true,
			'point', "TOPLEFT",
			'relativePoint', "BOTTOMLEFT"
		)
		dewdrop:Open(btn)
	elseif (mouseBtn == "RightButton") then
		for pally in pairs(AllPallys) do
			if SolarPower_NormalAssignments[flavor][pally] and SolarPower_NormalAssignments[flavor][pally][class] and SolarPower_NormalAssignments[flavor][pally][class][pname] then
				SolarPower_NormalAssignments[flavor][pally][class][pname] = nil
				SolarPower:SendMessage("NASSIGN "..pally.." "..class.." "..pname.." 0")
			end
		end
	end
end

function SolarPowerPlayerButton_OnClick(btn, mouseBtn)
	if InCombatLockdown() then return false end
	local _, _, class, pnum = sfind(btn:GetName(), "SolarPowerConfigFrameClassGroup(.+)PlayerButton(.+)")
	local pname = getglobal("SolarPowerConfigFrameClassGroup"..class.."PlayerButton"..pnum.."Text"):GetText()
	class = tonumber(class)
	SolarPowerGrid_NormalBlessingMenu(btn, mouseBtn, pname, class)
end

function SolarPowerPlayerButton_OnMouseWheel(btn, arg1)
	if InCombatLockdown() then return false end
	local _, _, class, pnum = sfind(btn:GetName(), "SolarPowerConfigFrameClassGroup(.+)PlayerButton(.+)")
	local pname = getglobal("SolarPowerConfigFrameClassGroup"..class.."PlayerButton"..pnum.."Text"):GetText()
	class = tonumber(class)

	SolarPower:PerformPlayerCycle(arg1, pname, class)
end

function SolarPowerGridButton_OnClick(btn, mouseBtn)
	if InCombatLockdown() then return false end
	local _, _, pnum, class = sfind(btn:GetName(), "SolarPowerConfigFramePlayer(.+)Class(.+)")
	pnum = pnum + 0
	class = class + 0
	local pname = getglobal("SolarPowerConfigFramePlayer"..pnum.."Name"):GetText()
	if not SolarPower:CanControl(pname) then return false end

	if (mouseBtn == "RightButton") then
		SolarPower_Assignments[flavor][pname][class] = 0
		SolarPower:SendMessage("ASSIGN "..pname.." "..class.. " 0")
	else
		SolarPower:PerformCycle(pname, class)
	end
end

function SolarPowerGridButton_OnMouseWheel(btn, arg1)
	if InCombatLockdown() then return false end
	local _, _, pnum, class = sfind(btn:GetName(), "SolarPowerConfigFramePlayer(.+)Class(.+)")
	pnum = pnum + 0
	class = class + 0
	local pname = getglobal("SolarPowerConfigFramePlayer"..pnum.."Name"):GetText()
	if not SolarPower:CanControl(pname) then return false end

	if (arg1==-1) then  --mouse wheel down
		SolarPower:PerformCycle(pname, class)
	else
		SolarPower:PerformCycleBackwards(pname, class)
	end
end

function SolarPowerConfigFrame_MouseUp()
	if ( SolarPowerConfigFrame.isMoving ) then
		SolarPowerConfigFrame:StopMovingOrSizing()
		SolarPowerConfigFrame.isMoving = false
	end
	if ( SolarPowerConfigFrame.isSizing ) then
		SolarPowerConfigFrame:StopMovingOrSizing()
		SolarPowerConfigFrame.isSizing = false
		SolarPower:SaveConfigFrameSize()
	end
end

function SolarPowerConfigFrame_MouseDown(arg1)
	if ( ( ( not SolarPowerConfigFrame.isLocked ) or ( SolarPowerConfigFrame.isLocked == 0 ) ) and ( arg1 == "LeftButton" ) ) then
		SolarPowerConfigFrame:StartMoving()
		SolarPowerConfigFrame.isMoving = true
	end
end

local point, relativeTo, relativePoint, xOfs, yOfs, movingPlayerFrame
function PlayerButton_DragStart(frame)
	movingPlayerFrame = frame
	point, relativeTo, relativePoint, xOfs, yOfs = frame:GetPoint()
	frame:SetMovable(true)
	frame:StartMoving()
end

function PlayerButton_DragStop(frame)
	if movingPlayerFrame then
		frame:StopMovingOrSizing()
		for i = 1, SOLARPOWER_MAXCLASSES do
		    if MouseIsOver(getglobal("SolarPowerConfigFrameClassGroup"..i.."ClassButton")) then
			local _, _, pclass, pnum = sfind(movingPlayerFrame:GetName(), "SolarPowerConfigFrameClassGroup(.+)PlayerButton(.+)")
			pclass, pnum = tonumber(pclass), tonumber(pnum)
			local unit = classes[pclass][pnum]
			SolarPower:AssignPlayerAsClass(unit.name, pclass, i)
		    end
		end
		frame:SetPoint(point, relativeTo, relativePoint, xOfs, yOfs)
		frame:SetMovable(false)
		movingPlayerFrame = nil
	end
end

function SolarPowerConfigGrid_Update()
	if not initalized then SolarPower:ScanSpells() end
	if SolarPowerConfigFrame:IsVisible() then
		local i = 1
		local numPallys = 0
		local numMaxClass = 0
		local name, skills
		for i = 1, SOLARPOWER_MAXCLASSES do
			local fname = "SolarPowerConfigFrameClassGroup"..i
			if movingPlayerFrame and MouseIsOver(getglobal(fname.."ClassButton")) then
				getglobal(fname.."ClassButtonHighlight"):Show()
			else
				getglobal(fname.."ClassButtonHighlight"):Hide()
			end
			SolarPower:SetClassIcon(getglobal(fname.."ClassButtonIcon"), i)
			for j = 1, SOLARPOWER_MAXPERCLASS do
				local pbnt = fname.."PlayerButton"..j
				if classes[i] and classes[i][j] then
					local unit = classes[i][j]
					getglobal(pbnt.."Text"):SetText(unit.name)
					local normal, greater = SolarPower:GetSpellID(i, unit.name)
					local icon
					if normal ~= greater and movingPlayerFrame ~= getglobal(pbnt) then
						if normal ~= greater then
							getglobal(pbnt.."Icon"):SetTexture(SolarPower.NormalBlessingIcons[normal])
						else
							--getglobal("SolarPowerConfigFrameClassGroup"..i.."PlayerButton"..j.."Icon"):SetTexture(SolarPower.BlessingIcons[normal])
							getglobal(pbnt.."Icon"):SetTexture("")
						end
					else
						getglobal(pbnt.."Icon"):SetTexture("")
					end
					getglobal(pbnt):Show()
				else
					getglobal(pbnt):Hide()
				end
			end
			if classlist[i] then
				numMaxClass = math.max(numMaxClass, classlist[i])
			end
		end
		SolarPowerConfigFrame:SetScale(SolarPower.opt.configscale)
		for i, name in pairs(SyncList) do
			local fname = "SolarPowerConfigFramePlayer" .. i

			local SkillInfo = AllPallys[name]
			local BuffInfo = SolarPower_Assignments[flavor][name]
			local NormalBuffInfo = SolarPower_NormalAssignments[flavor][name]
	
			getglobal(fname .. "Name"):SetText(name)

			if SolarPower:CanControl(name) then
				getglobal(fname.."Name"):SetTextColor(1,1,1)
			else
				if SolarPower:CheckRaidLeader(name) then
					getglobal(fname.."Name"):SetTextColor(0,1,0)
				else
					getglobal(fname.."Name"):SetTextColor(1,0,0)
				end
			end
			getglobal(fname .. "Symbols"):SetText(SkillInfo.symbols)
			getglobal(fname .. "Symbols"):SetTextColor(1,1,0.5)

			for id = 1, SOLARPOWER_MAXCLASSES do
				local devotionIndex = BuffInfo and BuffInfo[id] or 0
				SolarPower:SetAssignmentIcon(getglobal(fname.."Class"..id.."Icon"), devotionIndex)
			end
			i = i + 1
			numPallys = numPallys + 1
		end
		local classAreaHeight = SOLARPOWER_CONFIG_GRID_TOP_PADDING
			+ SOLARPOWER_CONFIG_CLASS_HEADER_HEIGHT
			+ (numMaxClass * SOLARPOWER_CONFIG_CLASS_PLAYER_ROW_STEP)
			+ SOLARPOWER_CONFIG_HEADER_CLERIC_GAP
		local contentHeight = classAreaHeight
			+ (numPallys * SOLARPOWER_CONFIG_CLERIC_ROW_HEIGHT)
			+ SOLARPOWER_CONFIG_GRID_BOTTOM_PADDING
		SolarPower:ApplyConfigFrameSize(contentHeight)
		local scrollChild = SolarPower.configScrollChild or SolarPowerConfigFrame
		getglobal("SolarPowerConfigFramePlayer1"):SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 8, -classAreaHeight)
		SolarPower:UpdateConfigScroll(contentHeight)
		local lineHeight = SOLARPOWER_CONFIG_CLASS_HEADER_HEIGHT
			+ (numMaxClass * SOLARPOWER_CONFIG_CLASS_PLAYER_ROW_STEP)
			+ (numPallys * SOLARPOWER_CONFIG_CLERIC_ROW_HEIGHT)
		for i = 1, SOLARPOWER_MAXCLASSES do
			getglobal("SolarPowerConfigFrameClassGroup" .. i .. "Line"):SetHeight(lineHeight)
		end
		for i = 1, SOLARPOWER_MAXPERCLASS do
			local fname = "SolarPowerConfigFramePlayer" .. i
			if i <= numPallys then
				getglobal(fname):Show()
			else
				getglobal(fname):Hide()
			end
		end
		SolarPowerConfigFrameFreeAssign:SetChecked(SolarPower.opt.freeassign)
	end
end

--
-- Main functionality
--

function SolarPower:Report(type)
	if self:GetNumUnits() > 0 then
	if not type then
		if GetNumRaidMembers() > 0 then
			type = "RAID"
		else
			type = "PARTY"
		end
	end
		if SolarPower:CheckRaidLeader(self.player) then
			SendChatMessage(SOLARPOWER_ASSIGNMENTS1, type)
			local list = {}
			for name in pairs(AllPallys) do
				local blessings
				for i = 1, SOLARPOWER_MAXBLESSINGS do
					list[i] = 0
				end
				for id = 1, SOLARPOWER_MAXCLASSES do
					local bid = SolarPower_Assignments[flavor][name][id]
					if bid and bid > 0 then
						list[bid] = list[bid] + 1
					end
				end
				for id = 1, SOLARPOWER_MAXBLESSINGS do
					if (list[id] > 0) then
						if (blessings) then
							blessings = blessings .. ", "
						else
							blessings = ""
						end
      					local spell = SolarPower.Spells[id]
						blessings = blessings .. spell
					end
				end
				if not (blessings) then
					blessings = "Nothing"
				end
				SendChatMessage(name ..": ".. blessings, type)
			end
			SendChatMessage(SOLARPOWER_ASSIGNMENTS2, type)
		else
			self:Print(ERR_NOT_LEADER)
		end
	else
		self:Print(ERR_NOT_IN_RAID)
	end
end

function SolarPower:PerformCycle(name, class, skipzero)
	local massAssign = IsControlKeyDown()

	if not SolarPower_Assignments[flavor][name] then
		SolarPower_Assignments[flavor][name] = {}
	end
	if not SolarPower_Assignments[flavor][name][class] then
		cur=0
	else
		cur=SolarPower_Assignments[flavor][name][class]
	end
	SolarPower_Assignments[flavor][name][class] = 0

	for test = cur+1, SOLARPOWER_MAXBLESSINGS+1 do
		if SolarPower:CanBuff(name, test) and (SolarPower:NeedsBuff(class, test) or massAssign) then
			cur = test
			do break end
		end
	end

	if cur == SOLARPOWER_MAXBLESSINGS+1 then
		if skipzero then
			cur = 1
		else
			cur = 0
		end
	end

	if massAssign then
		for test = 1, SOLARPOWER_MAXCLASSES do
			SolarPower_Assignments[flavor][name][test] = cur
		end
		SolarPower:SendMessage("MASSIGN "..name.." "..cur)
	else
		SolarPower_Assignments[flavor][name][class] = cur
		SolarPower:SendMessage("ASSIGN "..name.." "..class.." "..cur)
	end
end

function SolarPower:PerformCycleBackwards(name, class, skipzero)
	local massAssign = IsControlKeyDown()

	if not SolarPower_Assignments[flavor][name] then
		SolarPower_Assignments[flavor][name] = {}
	end
	if not SolarPower_Assignments[flavor][name][class] then
		cur=SOLARPOWER_MAXBLESSINGS+1
	else
		cur=SolarPower_Assignments[flavor][name][class]
		if cur == 0 or skipzero and cur == 1 then cur = SOLARPOWER_MAXBLESSINGS+1 end
	end
	SolarPower_Assignments[flavor][name][class] = 0

	for test = cur-1, 0, -1 do
		cur = test
		if SolarPower:CanBuff(name, test) and (SolarPower:NeedsBuff(class, test) or massAssign) then
			do break end
		end
	end

	if massAssign then
		for test = 1, SOLARPOWER_MAXCLASSES do
			SolarPower_Assignments[flavor][name][test] = cur
		end
		SolarPower:SendMessage("MASSIGN "..name.." "..cur)
	else
		SolarPower_Assignments[flavor][name][class] = cur
		SolarPower:SendMessage("ASSIGN "..name.." "..class.." "..cur)
	end
end

function SolarPower:PerformPlayerCycle(arg1, pname, class)
	local blessing = 0
	local playername = SolarPower.player
	if SolarPower_NormalAssignments[flavor][playername] and SolarPower_NormalAssignments[flavor][playername][class] and SolarPower_NormalAssignments[flavor][playername][class][pname] then
		blessing = SolarPower_NormalAssignments[flavor][playername][class][pname]
	end

	local test = (blessing - arg1) % (SOLARPOWER_MAXBLESSINGS+1)
	while not (SolarPower:CanBuff(playername, test) and SolarPower:NeedsBuff(class, test, pname)) and test > 0 do
		test = (test - arg1) % (SOLARPOWER_MAXBLESSINGS+1)
		if test == blessing then
			test = 0
			break
		end
	end

	SetNormalBlessings(playername, class, pname, test)
end

function SolarPower:AssignPlayerAsClass(pname, pclass, tclass)
	local greater, target, targetsorted, freepallies =  {}, {}, {}, {}
	-- Find blessings we want
	for pally, classes in pairs(SolarPower_Assignments[flavor]) do
		if AllPallys[pally] and classes[tclass] and classes[tclass] > 0 then
			target[classes[tclass]] = pally
			tinsert(targetsorted, classes[tclass])
		end
	end
	-- Sort blessings because we want to look at might > wisdom > the rest
	tsort(targetsorted, function(a,b) return a == 2 or a == 1 and b ~= 2 end)
	-- Find greater blessings we have
	for pally, info in pairs(AllPallys) do
		if SolarPower_Assignments[flavor][pally] and SolarPower_Assignments[flavor][pally][pclass] then
			local blessing = SolarPower_Assignments[flavor][pally][pclass]
			greater[blessing] = pally
			if not target[blessing] then
				freepallies[pally] = info
			end
		else
			freepallies[pally] = info
		end
	end
	-- Find blessings we will have to assign
	for index, blessing in pairs(targetsorted) do
		if greater[blessing] then
			local pally = greater[blessing]
			-- Use greater blessing if already assigned
			if SolarPower_NormalAssignments[flavor][pally] and 
			   SolarPower_NormalAssignments[flavor][pally][pclass] and 
			   SolarPower_NormalAssignments[flavor][pally][pclass][pname] then
				SetNormalBlessings(pally, pclass, pname, 0)
			end
		else
			-- We got a blessing we want, find best paladin (greedy approach)
			local maxname, maxrank, maxtalent = nil, 0, 0
			local targetpally = target[blessing]
			for pally, blessinginfo in pairs(freepallies) do
				local blessinginfo = blessinginfo[blessing]
				local rank, talent = 0, 0
				if blessinginfo then
					rank, talent = blessinginfo.rank, blessinginfo.talent
				end
				if rank > maxrank or (rank == maxrank and talent > maxtalent) or pally == targetpally then
					maxname = pally
					maxrank = rank
					maxtalent = talent
				end
			end
			if maxname then
				freepallies[maxname] = nil
				SetNormalBlessings(maxname, pclass, pname, blessing)
			end
		end
	end
end

function SolarPower:CanBuff(name, test)
	if test==SOLARPOWER_MAXBLESSINGS+1 then
		return true
	end

	if (not AllPallys[name][test]) or (AllPallys[name][test].rank == 0) then
		return false
	end
	return true
end

function SolarPower:NeedsBuff(class, test, playerName)
	if test==SOLARPOWER_MAXBLESSINGS+1 or test==0 then
		return true
	end

	-- Legacy PallyPower smartbuffs used vanilla class IDs (warrior/mage/etc.).
	-- CoA class columns are not 1:1 with those IDs; all devotions are valid.
	if self.opt.smartbuffs and not self.IsCoA then
		if (class == 1 or class == 2 or (SolarPower.IsWrath and class == 10)) and test == 1 then
			return false
		end
		if (class == 3 or class == 7 or class == 8) and test == 2 then
			return false
		end
	end

	if playerName then
		for pname, classes in pairs(SolarPower_NormalAssignments[flavor]) do
			if AllPallys[pname] and pname ~= self.player then
				for class_id, tnames in pairs(classes) do
					for tname, blessing_id in pairs(tnames) do
						if blessing_id == test then
							return false
						end
					end
				end
			end
		end
	end

	for name, skills in pairs(SolarPower_Assignments[flavor]) do
		if (AllPallys[name]) and ((skills[class]) and (skills[class]==test)) then 
			return false 
		end
	end
	return true
end

function SolarPower:ScanSpells()
	self:Debug("Scan Spells -- begin")
	self:BuildSpellTables()
	local _, class = UnitClass("player")
	if class == "SUNCLERIC" then
		local RankInfo = {}
		for i = 1, SOLARPOWER_MAXBLESSINGS do
			local devotion = self.Devotions[i]
			local spellName, spellRank
			if devotion then
				for _, spellId in ipairs(devotion.spellIds) do
					spellName, spellRank = GetSpellInfo(spellId)
					if spellName then
						break
					end
				end
				if not spellName then
					spellName, spellRank = GetSpellInfo(devotion.name)
				end
			end
			if not spellRank or spellRank == "" then
				spellRank = "1"
			end
			local rank = tonumber(select(3, sfind(spellRank, "(%d+)"))) or 1
			if spellName then
				RankInfo[i] = { rank = rank, talent = 0 }
			end
		end

		self:SyncAdd(self.player)
		if not SolarPower_Assignments[flavor][self.player] then
			self:ApplyCoADefaultAssignments(self.player)
		end

		AllPallys[self.player] = RankInfo
		AllPallys[self.player].AuraInfo = {}
		PP_IsCleric = true
	else
		PP_IsCleric = false
	end
	initalized = true
	self:Debug("Scan Spells -- end")
end

function SolarPower:ScanInventory()
	self:Debug("Scan Inventory -- begin")
	if not PP_IsCleric then return end

	PP_Symbols = GetItemCount(21177)
	AllPallys[self.player].symbols = PP_Symbols
	self:Debug("Scan Inventory -- end")
end

function SolarPower:InventoryScan()
	self:ScanInventory()
	if self:GetNumUnits() > 0 and PP_IsCleric then
		self:SendMessage("SYMCOUNT " .. PP_Symbols)
	end
end

function SolarPower:SendSelf()
	self:Debug("Send self -- begin")
	if not initalized then SolarPower:ScanSpells() end
	if not AllPallys[self.player] then return end
--    local name = UnitName("player")
	local s

	local SkillInfo = AllPallys[self.player]
	s = ""
	for i = 1, SOLARPOWER_MAXBLESSINGS do
		if not SkillInfo[i] then
			s = s.."nn"
		else
			s = s .. SkillInfo[i].rank .. SkillInfo[i].talent
		end
	end
	s = s .. "@"

	if not SolarPower_Assignments[flavor][self.player] then
		SolarPower_Assignments[flavor][self.player] = {}
		for i = 1, SOLARPOWER_MAXCLASSES do
			SolarPower_Assignments[flavor][self.player][i] = 0
		end
	end

	local BuffInfo = SolarPower_Assignments[flavor][self.player]

	for i = 1, SOLARPOWER_MAXCLASSES do
		if not BuffInfo[i] or BuffInfo[i] == 0 then
			s = s .. "n"
		else
			s = s .. BuffInfo[i]
		end
	end

	self:SendMessage("SELF " .. s)

	s = ""
	local AuraInfo = AllPallys[self.player].AuraInfo
	for i = 1, SOLARPOWER_MAXAURAS do
		if not AuraInfo[i] then
			s = s.."nn"
		else
			s = s .. sformat("%x%x", AuraInfo[i].rank, AuraInfo[i].talent)
		end
	end

	if not SolarPower_AuraAssignments[flavor][self.player] then
		SolarPower_AuraAssignments[flavor][self.player] = 0
	end
	
	s = s .. "@" .. SolarPower_AuraAssignments[flavor][self.player]
	
	self:SendMessage("ASELF " .. s)

	local AssignList = {}
	local inraid = GetNumRaidMembers() > 0
	if SolarPower_NormalAssignments[flavor][self.player] then
		for class_id, tnames in pairs(SolarPower_NormalAssignments[flavor][self.player]) do
			for tname, blessing_id in pairs(tnames) do
				tinsert(AssignList, sformat("%s %s %s %s", self.player, class_id, tname, blessing_id))
			end
		end
	end
	local count = table.getn(AssignList)
	if count > 0 then
		local offset = 1
		repeat
			self:SendMessage("NASSIGN " .. table.concat(AssignList, "@", offset, min(offset + 4, count)))
			offset = offset + 5
		until offset > count
	end

	self:SendMessage("SYMCOUNT " .. PP_Symbols)

	if self.opt.freeassign then
		self:SendMessage("FREEASSIGN YES")
	else
		self:SendMessage("FREEASSIGN NO")
	end

	self:Debug("Send self -- end")
end

function SolarPower:SendMessage(msg)
	self:Debug("Sending message")
	local type
	local inInstance, instanceType = IsInInstance()
	if inInstance and instanceType == "pvp" then
		type = "BATTLEGROUND"
	else
		if GetNumRaidMembers() == 0 then
			type = "PARTY"
		else
			type = "RAID"
		end
	end
	SendAddonMessage(SolarPower.commPrefix, msg, type, self.player)
end

function SolarPower:SPELLS_CHANGED()
	self:ScanSpells()
	self:SendSelf()
end

function SolarPower:ACTIVE_TALENT_GROUP_CHANGED()
	local i, old, new
	local _, class=UnitClass("player")
	if (class == "SUNCLERIC") then
		if GetActiveTalentGroup() == 1 then
			old = "secondary"
			new = "primary"
		else
			old = "primary"
			new = "secondary"
		end

		for i = 1, SOLARPOWER_MAXCLASSES do
			self.opt.sets[old].buffs[i] = SolarPower_Assignments[flavor][self.player][i]
			SolarPower_Assignments[flavor][self.player][i] = self.opt.sets[new].buffs[i]
		end
		SolarPower:UpdateLayout()
	end
end

function SolarPower:CHAT_MSG_ADDON(prefix, message, distribution, sender)
	self:Debug("CHAT_MSG_ADDON event")
	if prefix == SolarPower.commPrefix and (distribution == "PARTY" or distribution == "RAID" or distribution == "BATTLEGROUND") then
		if not ChatControl[sender] then
			ChatControl[sender]={}
			ChatControl[sender].time=0
		end
		if message == "REQ" then
			if (GetTime() - ChatControl[sender].time) < 15 then
				return
			else
				ChatControl[sender].time = GetTime()
			end
		end
		self:ParseMessage(sender, message)
	end
end

function SolarPower:CHAT_MSG_SYSTEM()
	self:Debug("CHAT_MSG_SYSTEM event")
	if sfind(arg1, ERR_RAID_YOU_JOINED) then
		self:SendSelf()
		self:SendMessage("REQ")
	elseif sfind(arg1, ERR_RAID_YOU_LEFT) or sfind(arg1, ERR_LEFT_GROUP_YOU) or sfind(arg1, ERR_GROUP_DISBANDED) then
		AllPallys = {}
		SyncList = {}
		SolarPower:ScanSpells()
		SolarPower:ScanInventory()
		SolarPower:UpdateLayout()
	end
end

function SolarPower:PLAYER_REGEN_ENABLED()
	if PP_IsCleric then self:UpdateLayout() end
end

function SolarPower:CanControl(name)
	return (IsPartyLeader() or IsRaidLeader() or IsRaidOfficer() or (name==self.player) or (AllPallys[name] and AllPallys[name].freeassign == true))
end

function SolarPower:CheckRaidLeader(nick)
	--local unit = RL:GetUnitObjectFromName(nick)
	--return unit and unit.rank >= 1
	return leaders[nick]
end

function SolarPower:ClearAssignments(sender)
	local leader = self:CheckRaidLeader(sender)
	for name, skills in pairs(SolarPower_Assignments[flavor]) do
		if leader or name == sender then
			--self:Print("Clearing: %s", name)
			for i = 1, SOLARPOWER_MAXCLASSES do
				SolarPower_Assignments[flavor][name][i] = 0
			end
		end
	end
	for pname, classes in pairs(SolarPower_NormalAssignments[flavor]) do
		if leader or pname == sender then
			for class_id, tnames in pairs(classes) do
				for tname, blessing_id in pairs(tnames) do
					tnames[tname] = nil
				end
			end
		end
	end
	for name, auras in pairs(SolarPower_AuraAssignments[flavor]) do
		if leader or name == sender then
			SolarPower_AuraAssignments[flavor][name] = 0
		end
	end
end

function SolarPower:SyncClear()
	SyncList = {}
end

function SolarPower:SyncAdd(name)
	local chk = 0
	for i, v in ipairs(SyncList) do
		if v == name then
			chk = 1
		end
	end
	if chk == 0 then
		tinsert(SyncList, name)
		tsort(SyncList, function (a, b) return a < b end)
	end

	--for i, v in ipairs(SyncList) do
	--	self:Print(i, v)
	--end
end

function SolarPower:ParseMessage(sender, msg)
    --self:Print("Received from: %s, message: %s", sender, msg)
	if sender == self.player then return end

	local leader = self:CheckRaidLeader(sender)
	if msg == "REQ" then
		self:SendSelf()
	end

	if sfind(msg, "^SELF") then
		SolarPower_NormalAssignments[flavor][sender] = {}
		SolarPower_Assignments[flavor][sender] = {}
		AllPallys[sender] = {}

		self:SyncAdd(sender)

		_, _, numbers, assign = sfind(msg, "SELF ([0-9n]*)@([0-9n]*)")
		for i = 1, SOLARPOWER_MAXBLESSINGS do
			rank = ssub(numbers, (i - 1) * 2 + 1, (i - 1) * 2 + 1)
			talent = ssub(numbers, (i - 1) * 2 + 2, (i - 1) * 2 + 2)
			if rank ~= "n" then
				AllPallys[sender][i] = {}
				AllPallys[sender][i].rank = tonumber(rank)
				AllPallys[sender][i].talent = tonumber(talent)
			end
		end
		-- sort here
		if assign then
			for i = 1, SOLARPOWER_MAXCLASSES do
				tmp =ssub(assign, i, i)
				if tmp == "n" or tmp == "" then tmp = 0 end
				SolarPower_Assignments[flavor][sender][i] = tmp + 0
			end
		end
	end

	if sfind(msg, "^ASSIGN") then
		_, _, name, class, skill = sfind(msg, "^ASSIGN (.*) (.*) (.*)")
		if name ~= sender and not (leader or SolarPower.opt.freeassign) then return false end
		if not SolarPower_Assignments[flavor][name] then SolarPower_Assignments[flavor][name] = {} end
		class = class + 0
		skill = skill + 0
		SolarPower_Assignments[flavor][name][class] = skill
	end

	if sfind(msg, "^NASSIGN") then
		for pname, class, tname, skill in string.gmatch(ssub(msg, 9), "([^@]*) ([^@]*) ([^@]*) ([^@]*)") do
			if pname ~= sender and not (leader or SolarPower.opt.freeassign) then return end
			if not SolarPower_NormalAssignments[flavor][pname] then SolarPower_NormalAssignments[flavor][pname] = {} end
			class = class + 0
			if not SolarPower_NormalAssignments[flavor][pname][class] then SolarPower_NormalAssignments[flavor][pname][class] = {} end
			skill = skill + 0
			if skill == 0 then skill = nil end
			SolarPower_NormalAssignments[flavor][pname][class][tname] = skill
		end
	end

	if sfind(msg, "^MASSIGN") then
		_, _, name, skill = sfind(msg, "^MASSIGN (.*) (.*)")
		if name ~= sender and not (leader or SolarPower.opt.freeassign) then return false end
		if not SolarPower_Assignments[flavor][name] then SolarPower_Assignments[flavor][name] = {} end
		skill = skill + 0
		for i = 1, SOLARPOWER_MAXCLASSES do
			SolarPower_Assignments[flavor][name][i] = skill
		end
	end

	if sfind(msg, "^SYMCOUNT") then
		_, _, count = sfind(msg, "^SYMCOUNT ([0-9]*)")
		if AllPallys[sender] then
			AllPallys[sender].symbols = count
		else
			self:SendMessage("REQ")
		end
	end

	if sfind(msg, "^CLEAR") then
		if leader then
			self:ClearAssignments(sender)
		end
	end

	if msg == "FREEASSIGN YES" and AllPallys[sender] then
		AllPallys[sender].freeassign = true
	end
	if msg == "FREEASSIGN NO" and AllPallys[sender] then
		AllPallys[sender].freeassign = false
	end

	if sfind(msg, "^ASELF") then
		SolarPower_AuraAssignments[flavor][sender] = 0
		AllPallys[sender].AuraInfo = { }
		_, _, numbers, assign = sfind(msg, "ASELF ([0-9a-fn]*)@([0-9n]*)")
		for i = 1, SOLARPOWER_MAXAURAS do
			rank = ssub(numbers, (i - 1) * 2 + 1, (i - 1) * 2 + 1)
			talent = ssub(numbers, (i - 1) * 2 + 2, (i - 1) * 2 + 2)
			if rank ~= "n" then
				AllPallys[sender].AuraInfo[i] = { }
				AllPallys[sender].AuraInfo[i].rank = tonumber(rank,16)
				AllPallys[sender].AuraInfo[i].talent = tonumber(talent,16)
			end
		end
		if assign then
			if assign == "n" or assign == "" then
				assign = 0
			end
			SolarPower_AuraAssignments[flavor][sender] = assign + 0
		end
	end

	if sfind(msg, "^AASSIGN") then
		_, _, name, aura = sfind(msg, "^AASSIGN (.*) (.*)")
		if name ~= sender and not (leader or SolarPower.opt.freeassign) then return false end
		if not SolarPower_AuraAssignments[flavor][name] then SolarPower_AuraAssignments[flavor][name] = {} end
		aura = aura + 0
		SolarPower_AuraAssignments[flavor][name] = aura
	end

end

function SolarPower:FormatTime(time)
	if not time or time < 0 or time == 9999 then
		return ""
	end
	local mins = floor(time / 60)
	local secs = time - (mins * 60)
	return sformat("%d:%02d", mins, secs)
end

function SolarPower:GetClassID(class)
	for id, name in pairs(self.ClassID) do
		if (name==class) then
			return id
		end
	end
	return -1
end

function SolarPower:ShouldIDisplay()
	if GetNumRaidMembers() > 0 then
		return true
	end
	if GetNumPartyMembers() > 0 then
		return self.opt.ShowInParty
	end
	return self.opt.ShowWhenSingle
end

function SolarPower:GetNumUnits()
	if GetNumRaidMembers() > 0 then
		return GetNumRaidMembers()
	end
	if GetNumPartyMembers() > 0 then
		if self.opt.ShowInParty then
			return GetNumPartyMembers() + 1
		end
		return 0
	end
	if self.opt.ShowWhenSingle then
		return 1
	end
	return 0
end

function SolarPower:UpdateRoster()
	-- unregister events
	self:Debug("Update Roster")
	self:CancelScheduledEvent("SolarPowerUpdateButtons")

	local units
	local num = self:GetNumUnits()
	local isInRaid

	local skip = self.opt.extras
	local smartpets = self.opt.smartpets

	for i = 1, SOLARPOWER_MAXCLASSES do
		classlist[i] = 0
		classes[i] = {}
	end

	if num > 0 then
		num = 0
		if GetNumRaidMembers() == 0 then
			isInRaid = false
			units = party_units
		else
			isInRaid = true
			units = raid_units
		end

		twipe(roster)
		twipe(leaders)

		for _, unitid in ipairs(units) do
			--SolarPower:Print(unitid)
			if unitid and UnitExists(unitid) then
				local tmp = {}
				num = num + 1
				tmp.unitid = unitid
				tmp.name = UnitName(unitid)

				local isPet = unitid:find("pet")

				if isPet then
					tmp.class = "PET"
				else
					tmp.class = select(2, UnitClass(unitid))
				end

				if isInRaid then
					local n = select(3, unitid:find("(%d+)"))
					--SolarPower:Print("n="..n)
					tmp.rank, tmp.subgroup = select(2, GetRaidRosterInfo(n))
				else
					tmp.rank = UnitIsPartyLeader(unitid) and 2 or 0
					tmp.subgroup = 1
				end

				if tmp.rank > 0 then
					leaders[tmp.name] = true
				end

				if tmp.subgroup < 6 or not skip then
					if smartpets and isPet then
						local pclass = select(2, UnitClass(unitid))
						local family = UnitCreatureFamily(unitid)

						if pclass == "WARRIOR" then -- hunter pets
							tmp.class = pclass
						elseif pclass == "ROGUE" then -- dk ghoul
							tmp.class = pclass
						elseif pclass == "MAGE" then -- water elemental, imp
							if family == L["PET_IMP"] then
								tmp.class = "WARLOCK"
							else
								tmp.class = pclass
							end
						elseif pclass == "SUNCLERIC" then -- other warlock pets
							if family == L["PET_FELHUNTER"] or family == L["PET_SUCCUBUS"] then
								tmp.class = "WARLOCK"
							else
								tmp.class = "WARRIOR"
							end
						end

--						if family then
--							if family == L["PET_GHOUL"] then
--								tmp.class = "ROGUE"
--							elseif family == L["PET_IMP"] or family == L["PET_FELHUNTER"] or family == L["PET_SUCCUBUS"] then
--								tmp.class = "WARLOCK"
--							else
--								tmp.class = "WARRIOR"
--							end
--						end
					end

					--SolarPower:Print(tmp.name, tmp.class, tmp.rank, tmp.subgroup)

					tinsert(roster, tmp)

					for i = 1, SOLARPOWER_MAXCLASSES do
						if tmp.class == self.ClassID[i] then
							tmp.visible = false
							tmp.hasbuff = false
							tmp.hasclassbuff = false
							tmp.specialbuff = false
							tmp.dead = false
							classlist[i] = classlist[i] + 1
							tinsert(classes[i], tmp)
						end
					end
				end
			end
		end
	end

	self:UpdateLayout()

	if num > 0 and PP_IsCleric then
		-- register events
		self:ScheduleRepeatingEvent("SolarPowerUpdateButtons", self.ButtonsUpdate, 2.0, self)
	end

	self:Debug("Update Roster - end")
end

function SolarPower:ScanClass(classID)
	--    self:Print("Scanning class: %s -- begin", classID)

	local class = classes[classID]

	for playerID, unit in pairs(class) do
		if unit.unitid then
			local spellID, gspellID = self:GetSpellID(classID, unit.name)
			local spell = SolarPower.Spells[spellID]
			local spell2 = SolarPower.GSpells[spellID]
			local gspell = SolarPower.GSpells[gspellID]
			unit.visible = IsSpellInRange(spell, unit.unitid) == 1
			unit.dead = UnitIsDeadOrGhost(unit.unitid)
			unit.hasclassbuff = self:HasDevotion(gspellID, unit.unitid)
			unit.hasbuff = self:HasDevotion(spellID, unit.unitid)
			unit.specialbuff = spellID ~= gspellID and spellID ~= 0
		end
	end
end

function SolarPower:CreateLayout()
	self:Debug("Create Layout -- begin")

	local p = _G["SolarPowerFrame"]
	self.Header = p

    self.autoButton = CreateFrame("Button", "SolarPowerAuto", self.Header, "SecureHandlerShowHideTemplate, SecureHandlerEnterLeaveTemplate, SecureHandlerStateTemplate, SecureActionButtonTemplate, SolarPowerAutoButtonTemplate")
	self.autoButton:RegisterForClicks("LeftButtonDown", "RightButtonDown")

	self.classButtons = {}
	self.playerButtons = {}

	SecureHandlerExecute(self.autoButton, [[childs = table.new()]]);

	for cbNum = 1, SOLARPOWER_MAXCLASSES do
	-- create class buttons
		local cButton = CreateFrame("Button", "SolarPowerC" .. cbNum, self.Header, "SecureHandlerShowHideTemplate, SecureHandlerEnterLeaveTemplate, SecureHandlerStateTemplate, SecureActionButtonTemplate, SolarPowerButtonTemplate")
		--cButton:SetID(cbNum)
 		-- new show/hide functionality
 		SecureHandlerSetFrameRef(self.autoButton, "child", cButton)
	    SecureHandlerExecute(self.autoButton, [[
												local child = self:GetFrameRef("child")
												childs[#childs+1] = child;
											  ]])

	    SecureHandlerExecute(cButton, [[others = table.new()]])
		SecureHandlerExecute(cButton, [[childs = table.new()]])
	    cButton:SetAttribute("_onenter", [[
	                                          for _, other in ipairs(others) do
	                                             other:SetAttribute("state-inactive", self)
	                                          end
	                                          local leadChild;
	                                          for _, child in ipairs(childs) do
	                                              if child:GetAttribute("Display") == 1 then
	                                                  child:Show()
	                                                  if (leadChild) then
	                                                      leadChild:AddToAutoHide(child)
	                                                  else
	                                                      leadChild = child
	                                                      leadChild:RegisterAutoHide(2)
	                                                  end
	                                              end
	                                          end
	                                          if (leadChild) then
	                                              leadChild:AddToAutoHide(self)
	                                          end
	                                  ]])

	    cButton:SetAttribute("_onstate-inactive", [[
													childs[1]:Hide()
												 ]])
		cButton:RegisterForClicks("LeftButtonDown", "RightButtonDown")
		cButton:EnableMouseWheel(1)
        self.classButtons[cbNum] = cButton

		-- create player buttons
		self.playerButtons[cbNum] = {}
		local pButtons = self.playerButtons[cbNum]
        local leadChild
		for pbNum = 1, SOLARPOWER_MAXPERCLASS do -- create player buttons for each class
			local pButton = CreateFrame("Button","SolarPowerC".. cbNum .. "P" .. pbNum, UIParent, "SecureHandlerShowHideTemplate, SecureHandlerEnterLeaveTemplate, SecureActionButtonTemplate, SolarPowerPopupTemplate")
			--pButton:SetID(cbNum)
			pButton:SetParent(cButton)

			SecureHandlerSetFrameRef(cButton, "child", pButton)
	        SecureHandlerExecute(cButton, [[
												local child = self:GetFrameRef("child")
												childs[#childs+1] = child;
											  ]])
			if pbNum == 1 then
				SecureHandlerExecute(pButton, [[siblings = table.new()]])
				pButton:SetAttribute("_onhide", [[
												  for _, sibling in ipairs(siblings) do
													sibling:Hide()
												  end]])
				leadChild = pButton
			else
				SecureHandlerSetFrameRef(leadChild, "sibling", pButton)
	        	SecureHandlerExecute(leadChild, [[
												local sibling = self:GetFrameRef("sibling")
												siblings[#siblings+1] = sibling;
											  ]])
			end

			pButton:RegisterForClicks("LeftButtonDown", "RightButtonDown")
			pButton:EnableMouseWheel(1)
			pButton:Hide();
			pButtons[pbNum] = pButton
		end -- by pbNum
	end -- by classIndex

	for cbNum = 1, SOLARPOWER_MAXCLASSES do
		local cButton = self.classButtons[cbNum];
		for cbOther = 1, SOLARPOWER_MAXCLASSES do
			if (cbOther ~= cbNum) then
				local oButton = self.classButtons[cbOther];
 				SecureHandlerSetFrameRef(cButton, "other", oButton)
	        	--SecureHandlerExecute(cButton, [[tinsert(others, self:GetAttribute('frameref-other'));]]);
	        	SecureHandlerExecute(cButton, [[
												local other = self:GetFrameRef("other")
												others[#others+1] = other;
											  ]])
			end
		end
	end

	self:UpdateLayout()
	self:Debug("Create Layout -- end")
end

function SolarPower:CountClasses()
	local val = 0
	if not classes then return 0 end
	for i = 1, SOLARPOWER_MAXCLASSES do
		if classlist[i] and classlist[i] > 0 then
			val = val + 1
		end
	end
	return val
end

function SolarPower:UpdateLayout()
	self:Debug("Update Layout -- begin")
	if InCombatLockdown() then return false end

	SolarPowerFrame:SetScale(self.opt.buffscale)

	if self.opt.layout == "Standard" then

		local rows = self.opt.display.rows
		local columns = self.opt.display.columns
		local gapping = self.opt.display.gapping
		local buttonWidth = self.opt.display.buttonWidth
		local buttonHeight = self.opt.display.buttonHeight
		local centerShiftX = 0
		local centerShiftY = 0
		local point = "BOTTOMLEFT"
		local pointOpposite = "TOPLEFT"
		local x = (buttonWidth + gapping)
		local y = (buttonHeight + gapping)
		local displayedButtons = math.min(self:CountClasses(),rows, columns)
		local displayedColumns = math.min(displayedButtons, columns)
		local displayedRows = math.floor((displayedButtons - 1) / columns) + 1

		if (self.opt.display.alignClassButtons == "Top Right") then
			point = "BOTTOMLEFT"
			pointOpposite = "TOPLEFT"
		elseif (self.opt.display.alignClassButtons == "Top Left") then
			x = x * -1
			point = "BOTTOMRIGHT"
			pointOpposite = "TOPRIGHT"
		elseif (self.opt.display.alignClassButtons == "Bottom Left") then
			x = x * -1
			y = y * -1
			point = "TOPRIGHT"
			pointOpposite = "BOTTOMRIGHT"
		elseif (self.opt.display.alignClassButtons == "Bottom Right") then
			y = y * -1
			point = "TOPLEFT"
			pointOpposite = "BOTTOMLEFT"
		end

		for cbNum = 1, SOLARPOWER_MAXCLASSES do -- position class buttons
			local cButton = self.classButtons[cbNum]
			-- set visual attributes
			self:SetButton("SolarPowerC" .. cbNum)
			-- set position
			cButton.x = (math.fmod(cbNum - 1, columns) * x + centerShiftX)
			cButton.y = math.floor((cbNum - 1) / columns) * y + centerShiftY
			cButton:ClearAllPoints()
			cButton:SetPoint(point, self.Header, "CENTER", cButton.x, cButton.y)

			local pButtons = self.playerButtons[cbNum]
			for pbNum = 1, SOLARPOWER_MAXPERCLASS do -- position player buttons
				local pButton = pButtons[pbNum]
				self:SetPButton("SolarPowerC".. cbNum .. "P" .. pbNum)
				--pButton:SetAttribute("showstates", tostring(cbNum))
				pButton:ClearAllPoints()
				if (self.opt.display.alignPlayerButtons == "bottom") then
					pButton:SetPoint(	point, self.Header, "CENTER",
										cButton.x,
										cButton.y - pbNum * (buttonHeight + gapping)
									)
				elseif (self.opt.display.alignPlayerButtons == "left") then
					pButton:SetPoint(	point, self.Header, "CENTER",
										cButton.x - pbNum * (buttonWidth + gapping),
										cButton.y
									)
				elseif (self.opt.display.alignPlayerButtons == "right") then
					pButton:SetPoint(	point, self.Header, "CENTER",
										cButton.x + pbNum * (buttonWidth + gapping),
										cButton.y
									)
				elseif (self.opt.display.alignPlayerButtons == "top") then
					pButton:SetPoint(	point, self.Header, "CENTER",
										cButton.x,
										cButton.y + pbNum * (buttonHeight + gapping)
									)
				elseif (self.opt.display.alignPlayerButtons == "compact-right") then
					pButton:SetPoint(	point, self.Header, "CENTER",
										cButton.x + (buttonWidth + gapping),
										cButton.y + (pbNum - 1) * (buttonHeight + gapping)
									)
				elseif (self.opt.display.alignPlayerButtons == "compact-left") then
					pButton:SetPoint(	point, self.Header, "CENTER",
										cButton.x - (buttonWidth + gapping),
										cButton.y + (pbNum - 1) * (buttonHeight + gapping)
									)
				end
			end
		end

		local offset = 0
		local autob = self.autoButton
		autob:ClearAllPoints()
		autob:SetPoint(pointOpposite, self.Header, "CENTER", 0, offset)
		autob:SetAttribute("type", "spell")
		if self:GetNumUnits() > 0 and not self.opt.disabled and PP_IsCleric and (self.opt.autobuff.autobutton or self.opt.display.hideClassButtons) then
			autob:Show()
			offset = offset - y
		else
			autob:Hide()
		end

	else
	-- custom layout
		local x = self.opt.display.buttonWidth
		local y = self.opt.display.buttonHeight
		local point = "TOPLEFT"
		local pointOpposite = "BOTTOMLEFT"
		local layout = SolarPower.Layouts[self.opt.layout]

		for cbNum = 1, SOLARPOWER_MAXCLASSES do -- position class buttons
		    cx = layout.c[cbNum].x
		    cy = layout.c[cbNum].y
			local cButton = self.classButtons[cbNum]
			-- set visual attributes
			self:SetButton("SolarPowerC" .. cbNum)
			-- set position
			cButton.x = cx * x
			cButton.y = cy * y
			cButton:ClearAllPoints()
			cButton:SetPoint(point, self.Header, "CENTER", cButton.x, cButton.y)

			local pButtons = self.playerButtons[cbNum]
			for pbNum = 1, SOLARPOWER_MAXPERCLASS do -- position player buttons
			    px = layout.c[cbNum].p[pbNum].x
			    py = layout.c[cbNum].p[pbNum].y
				local pButton = pButtons[pbNum]
				self:SetPButton("SolarPowerC".. cbNum .. "P" .. pbNum)
			--pButton:SetAttribute("showstates", tostring(cbNum))
				pButton:ClearAllPoints()
				pButton:SetPoint(	point, self.Header, "CENTER",
									cButton.x + px * x,
									cButton.y + py * y
								)
			end
		end


		local ox = layout.ab.x * x
		local oy = layout.ab.y * y
		local autob = self.autoButton
 		autob:ClearAllPoints()
		autob:SetPoint(point, self.Header, "CENTER", ox, oy)
		autob:SetAttribute("type", "spell")
		if self:GetNumUnits() > 0 and not self.opt.disabled and PP_IsCleric and (self.opt.autobuff.autobutton or self.opt.display.hideClassButtons) then
			autob:Show()
		else
			autob:Hide()
		end
	end

	local cbNum = 0
	for classIndex = 1, SOLARPOWER_MAXCLASSES do
	local _, gspellID = SolarPower:GetSpellID(classIndex)
        if (classlist[classIndex] and classlist[classIndex] ~= 0 and (gspellID ~= 0 or SolarPower:NormalBlessingCount(classIndex) > 0)) then
			cbNum = cbNum + 1
			--self:Print("cbNum="..cbNum)
			local cButton = self.classButtons[cbNum]
			--cButton:Show()

	    	if cbNum == 1 then
				if self.opt.display.hideClassButtons then
					self.autoButton:SetAttribute("_onenter", [[
											  local leadChild;
	                                          for _, child in ipairs(childs) do
	                                              if child:GetAttribute("Display") == 1 then
	                                                  child:Show()
	                                                  if (leadChild) then
	                                                      leadChild:AddToAutoHide(child)
	                                                  else
	                                                      leadChild = child
	                                                      leadChild:RegisterAutoHide(5)
	                                                  end
	                                              end
	                                          end
	                                          if (leadChild) then
	                                              leadChild:AddToAutoHide(self)
	                                          end
	                                  ]])
	    			cButton:SetAttribute("_onhide", [[
										    	for _, other in ipairs(others) do
	                                            	other:Hide()
	                                          	end
													]])
				else
					self.autoButton:SetAttribute("_onenter", [[
	                                          for _, child in ipairs(childs) do
	                                              if child:GetAttribute("Display") == 1 then
	                                                  child:Show()
	                                              end
	                                          end
	                                  ]])

					cButton:SetAttribute("_onhide", nil)
				end
	  		end
	  		if not self.opt.display.hideClassButtons then
	  			cButton:Show()
	  		end
			cButton:SetAttribute("Display", 1)
			cButton:SetAttribute("classID", classIndex)
			cButton:SetAttribute("type1", "spell")
			cButton:SetAttribute("type2", "spell")
			local pButtons = self.playerButtons[cbNum]
			for pbNum = 1, math.min(classlist[classIndex], SOLARPOWER_MAXPERCLASS) do
				--self:Print("pbNum="..pbNum)
				local pButton = pButtons[pbNum]
				if not self.opt.display.hidePlayerButtons then
					pButton:SetAttribute("Display", 1)
				else
					pButton:SetAttribute("Display", 0)
				end
				pButton:SetAttribute("classID", classIndex)
				pButton:SetAttribute("playerID", pbNum)
				local unit  = self:GetUnit(classIndex, pbNum)
				--SolarPower:Print(unit.name)
				--SolarPower:Print(unit.unitid)
				local spellID, gspellID = self:GetSpellID(classIndex, unit.name)
				local spell = SolarPower.Spells[spellID]
				local gspell = SolarPower.GSpells[spellID]
				-- left click (target a specific player and do 15 minute buff)
				pButton:SetAttribute("type1", "spell")
				pButton:SetAttribute("unit1", unit.unitid)
				pButton:SetAttribute("spell1", gspell)
				-- right click (target a specific player and do 5 minute buff)
				pButton:SetAttribute("type2", "spell")
				pButton:SetAttribute("unit2", unit.unitid)
				pButton:SetAttribute("spell2", spell)
			end -- by pbnum
			for pbNum = classlist[classIndex]+1, SOLARPOWER_MAXPERCLASS do
				local pButton = pButtons[pbNum]
				pButton:SetAttribute("Display", 0)
				pButton:SetAttribute("classID", 0)
				pButton:SetAttribute("playerID", 0)
			end
		end
	end
	cbNum = cbNum + 1
	for i = cbNum, SOLARPOWER_MAXCLASSES do
		local cButton = self.classButtons[i]
		cButton:SetAttribute("Display", 0)
		cButton:SetAttribute("classID", 0)
		cButton:Hide()
		local pButtons = self.playerButtons[cbNum]
		for pbNum = 1, SOLARPOWER_MAXPERCLASS do
			local pButton = pButtons[pbNum]
			pButton:SetAttribute("Display", 0)
			pButton:SetAttribute("classID", 0)
			pButton:SetAttribute("playerID", 0)
			pButton:Hide()
		end
	end

	if not self.opt.display.flashBuffAutoButtons then
		self:StopAllAnimation()
	end

	self:ButtonsUpdate()
	self:UpdateAnchor(displayedButtons)

	self:Debug("Update Layout -- end")
end

function SolarPower:SetButton(baseName)
	local time = _G[baseName.."Time"]
	local text = _G[baseName.."Text"]

	if (self.opt.display.HideCountText) then
		text:Hide()
	else
		text:Show()
	end

	if (self.opt.display.HideTimerText) then
		time:Hide()
	else
		time:Show()
	end
end

function SolarPower:SetPButton(baseName)
	local rng = _G[baseName.."Rng"]
	local dead = _G[baseName.."Dead"]
	local name = _G[baseName.."Name"]

	if (self.opt.display.HideRngText) then
		rng:Hide()
	else
		rng:Show()
	end

	if (self.opt.display.HideDeadText) then
		dead:Hide()
	else
		dead:Show()
	end

	if (self.opt.display.HideNameText) then
		name:Hide()
	else
		name:Show()
	end
end

-- NoM0Re Edit
function SolarPower:GetClassColor(classFilename, fallback)
	local color = self.ClassColors[classFilename]
	if color then
		return { r = color.r, g = color.g, b = color.b, t = fallback and fallback.t or 0.5 }
	end
	return fallback
end

local AnimatedButtons = {}
local startTimeAnimation
local AnimationUpdateFrame = CreateFrame("Frame")
local hsvFrame = CreateFrame("Colorselect")

local function GetHSVTransition(perc, r1, g1, b1, a1, r2, g2, b2, a2)
	--get hsv color for colorA
	hsvFrame:SetColorRGB(r1, g1, b1)
	local h1, s1, v1 = hsvFrame:GetColorHSV() -- hue, saturation, value
	--get hsv color for colorB
	hsvFrame:SetColorRGB(r2, g2, b2)
	local h2, s2, v2 = hsvFrame:GetColorHSV() -- hue, saturation, value
	local h3 = floor(h1 - (h1 - h2) * perc)
	-- find the shortest arc through the color circle, then interpolate
	local diff = h2 - h1
	if diff < -180 then
		diff = diff + 360
	elseif diff > 180 then
		diff = diff - 360
	end
	h3 = (h1 + perc * diff) % 360
	local s3 = s1 - ( s1 - s2 ) * perc
	local v3 = v1 - ( v1 - v2 ) * perc
	--get the RGB values of the new color
	hsvFrame:SetColorHSV(h3, s3, v3)
	local r, g, b = hsvFrame:GetColorRGB()
	--interpolate alpha
	local a = a1 - ( a1 - a2 ) * perc
	--return the new color
	return r, g, b, a
end

local function UpdateFrameColor(progress, frame)
	local r1, g1, b1, a1 = SolarPower.opt.cBuffNeedAll.r, SolarPower.opt.cBuffNeedAll.g, SolarPower.opt.cBuffNeedAll.b, SolarPower.opt.cBuffNeedAll.t -- Start-Color White
	local r2, g2, b2, a2 = 1, 0, 0, 1  -- End-Color Red
	local r, g, b, a = GetHSVTransition(progress, r1, g1, b1, a1, r2, g2, b2, a2)
	frame:SetBackdropColor(r, g, b, a)
end

local function GetAnimationFrameProgress(startTime)
	local currentTime = GetTime()
	local duration = 0.5
	return (currentTime - startTime) / duration
end

local function UpdateFrame()
	local progress = GetAnimationFrameProgress(startTimeAnimation)
	for _, frame in ipairs(AnimatedButtons) do
		UpdateFrameColor(progress, frame)
	end
	if progress >= 1 then
		startTimeAnimation = GetTime()
	end
end

local function StartAnimation(button)
	if AnimatedButtons and next(AnimatedButtons) == nil then
		startTimeAnimation = GetTime()
		table.insert(AnimatedButtons, button)
		AnimationUpdateFrame:SetScript("OnUpdate", UpdateFrame)
	else
		for _, btn in ipairs(AnimatedButtons) do
			if btn:GetName() == button:GetName() then
				return
			end
		end
        table.insert(AnimatedButtons, button)
	end
end

local function StopAnimation(button)
    for i, btn in ipairs(AnimatedButtons) do
        if btn:GetName() == button:GetName() then
			table.remove(AnimatedButtons, i)
            break
        end
    end

    if AnimatedButtons and next(AnimatedButtons) == nil then
        AnimationUpdateFrame:SetScript("OnUpdate", nil)
    end
end

function SolarPower:StopAllAnimation()
	AnimatedButtons = {}
	AnimationUpdateFrame:SetScript("OnUpdate", nil)
end
-- NoM0Re Edit End
function SolarPower:UpdateButton(button, baseName, classID)
	--self:Print("Update Button: %s, Class: %s", baseName, classID)
	local button = _G[baseName]
	local classIcon = _G[baseName.."ClassIcon"]
	local buffIcon = _G[baseName.."BuffIcon"]
	local time = _G[baseName.."Time"]
	local time2 = _G[baseName.."Time2"]
	local text = _G[baseName.."Text"]

	local nneed = 0
	local nspecial = 0
	local nhave = 0
	local ndead = 0
	--self:Print("Scaninfo: %s", PP_ScanInfo[classID])
	for playerID, unit in pairs(classes[classID]) do
		if unit.visible then
			if not unit.hasclassbuff then
				if unit.specialbuff then
					nspecial = nspecial + 1
				else
					nneed = nneed + 1
				end
			else
				nhave = nhave + 1
			end
		else
			nhave = nhave + 1
		end

		if unit.dead then
			ndead = ndead + 1
		end
	end
	self:SetClassIcon(classIcon, classID)
	classIcon:SetVertexColor(1, 1, 1)
	local _, gspellID = SolarPower:GetSpellID(classID)
	buffIcon:SetTexture(self.BlessingIcons[gspellID])

	if InCombatLockdown() then
		buffIcon:SetVertexColor(0.4, 0.4, 0.4)
	else
		buffIcon:SetVertexColor(1, 1, 1)
	end

	local classExpire, classDuration, specialExpire, specialDuration = self:GetBuffExpiration(classID)
	time:SetText(self:FormatTime(classExpire))
	time:SetTextColor(self:GetSeverityColor(classExpire and classDuration and (classExpire/classDuration) or 0))
	time2:SetText(self:FormatTime(specialExpire))
	time2:SetTextColor(self:GetSeverityColor(specialExpire and specialDuration and (specialExpire/specialDuration) or 0))

	if (nneed+nspecial > 0) then
		text:SetText(nneed+nspecial)
	else
		text:SetText("")
	end
	-- NoM0Re Edit
	if (not InCombatLockdown()) then
		local unitid, _, gspell = SolarPower:GetUnitAndSpellSmart(classID, "LeftButton")

		if not unitid then
			gspell = "qq"
		end

		-- left click (find first nearby player and do 15 minute buff)
		button:SetAttribute("type", "spell")
		button:SetAttribute("spell1", gspell)
		button:SetAttribute("unit1", unitid)
	end

	local flash = self.opt.display.flashBuffAutoButtons
	local instanced = IsInInstance()
	if (nhave == 0) then
		if flash then
			if instanced then
				StartAnimation(button)
			else
				StopAnimation(button)
				self:ApplyBackdrop(button, self.opt.cBuffNeedAll)
			end
		else
			self:ApplyBackdrop(button, self.opt.cBuffNeedAll)
		end
	elseif (nneed > 0) then
		if flash then
			if instanced then
				StartAnimation(button)
			else
				StopAnimation(button)
				self:ApplyBackdrop(button, self.opt.cBuffNeedSome)
			end
		else
			self:ApplyBackdrop(button, self.opt.cBuffNeedSome)
		end
	elseif (nspecial > 0) then
		if flash then
			if instanced then
				StartAnimation(button)
			else
				StopAnimation(button)
				self:ApplyBackdrop(button, self.opt.cBuffNeedSpecial)
			end
		else
			self:ApplyBackdrop(button, self.opt.cBuffNeedSpecial)
		end
	else
		if flash then
			StopAnimation(button)
		end
		if self.opt.display.classColor then
			self:ApplyBackdrop(button, self:GetClassColor(self.ClassID[classID], self.opt.cBuffGood))
		else
			self:ApplyBackdrop(button, self.opt.cBuffGood)
		end
	end
	-- NoM0Re Edit End
	return classExpire, classDuration, specialExpire, specialDuration, nhave, nneed, nspecial
	--self:Print("Update button -- end")
end

function SolarPower:GetSeverityColor(percent)
	if (percent >= 0.5) then
		return (1.0-percent)*2, 1.0, 0.0
	else
		return 1.0, percent*2, 0.0
	end
end

function SolarPower:GetBuffExpiration(classID)
	local class = classes[classID]
	local classExpire, classDuration, specialExpire, specialDuration = 9999, 9999, 9999, 9999
	for playerID, unit in pairs(class) do
		if unit.unitid then
			local spellID, gspellID = self:GetSpellID(classID, unit.name)
			local remaining, duration = self:HasDevotion(gspellID, unit.unitid)
			if remaining then
				classExpire = min(classExpire, remaining)
				classDuration = min(classDuration, duration or remaining)
			end
			if spellID ~= gspellID and spellID ~= 0 then
				local specialRemaining, specialDur = self:HasDevotion(spellID, unit.unitid)
				if specialRemaining then
					specialExpire = min(specialExpire, specialRemaining)
					specialDuration = min(specialDuration, specialDur or specialRemaining)
				end
			end
		end
	end
	return classExpire, classDuration, specialExpire, specialDuration
end

function SolarPower:UpdatePButton(button, baseName, classID, playerID)
	--self:Print("Update PButton: %s, Class: %s, Player: %s", baseName, classID, playerID)
	local button = _G[baseName]
	local buffIcon = _G[baseName.."BuffIcon"]
	local rng  = _G[baseName.."Rng"]
	local dead = _G[baseName.."Dead"]
	local name = _G[baseName.."Name"]
	local time = _G[baseName.."Time"]

	local unit = classes[classID][playerID]
	if unit then
		local nneed = 0
		local nspecial = 0
		local nhave = 0
		local ndead = 0

		if unit.visible then
			if not unit.hasbuff then
				if unit.specialbuff then
					nspecial = 1
				end
			else
				nhave = 1
			end
		else
			nhave = 1
		end

		if unit.dead then
			ndead = 1
		end

		local spellID, gspellID = self:GetSpellID(classID, unit.name)
		buffIcon:SetTexture(self.BlessingIcons[spellID])
		buffIcon:SetVertexColor(1, 1, 1)

		time:SetText(self:FormatTime(unit.hasbuff))

		if (not InCombatLockdown()) then
			button:SetAttribute("spell1", SolarPower.GSpells[gspellID])
			button:SetAttribute("spell2", SolarPower.Spells[spellID])
		end

		if (nspecial == 1) then
  			self:ApplyBackdrop(button, self.opt.cBuffNeedSpecial)
		elseif (nhave == 0) then
   			self:ApplyBackdrop(button, self.opt.cBuffNeedAll)
		--elseif (nneed == 1) then
		--    button:SetBackdropColor(1.0, 1.0, 0.5, 0.5)
		else
			-- NoM0Re Edit
			if self.opt.display.classColor then
				self:ApplyBackdrop(button, self:GetClassColor(self.ClassID[classID], self.opt.cBuffGood))
			else
				self:ApplyBackdrop(button, self.opt.cBuffGood)
			end
			-- NoM0Re Edit End
		end

		if unit.hasbuff then
			buffIcon:SetAlpha(1)
			if not unit.visible then
				rng:SetVertexColor(1, 0, 0)
				rng:SetAlpha(1)
			else
				rng:SetVertexColor(0, 1, 0)
			rng:SetAlpha(1)
			end
			dead:SetAlpha(0)
		else
			buffIcon:SetAlpha(0.4)

			if not unit.visible then
				rng:SetVertexColor(1, 0, 0)
				rng:SetAlpha(1)
			else
				rng:SetVertexColor(0, 1, 0)
				rng:SetAlpha(1)
			end

			if unit.dead then
				dead:SetVertexColor(1, 0, 0)
				dead:SetAlpha(1)
			else
				dead:SetVertexColor(0, 1, 0)
				dead:SetAlpha(0)
			end
		end
		name:SetText(unit.name)

		if self.opt.display.nameClassColor then
			self:ApplyTextColor(name, SolarPower:GetClassColor(self.ClassID[classID], {r=1, g=1, b=1, t=1}))
		else
			self:ApplyTextColor(name, {r=1, g=1, b=1, t=1})
		end
	else
		self:ApplyBackdrop(button, self.opt.cBuffGood)
		buffIcon:SetAlpha(0)
		rng:SetAlpha(0)
		dead:SetAlpha(0)
	end
	--    self:Print("Update PopupButton -- end")
end

function SolarPower:ButtonsUpdate()
	local minClassExpire, minClassDuration, minSpecialExpire, minSpecialDuration, sumnhave, sumnneed, sumnspecial = 9999, 9999, 9999, 9999, 0, 0, 0
	for cbNum = 1, SOLARPOWER_MAXCLASSES do -- scan classes and if populated then assign textures, etc
		local cButton = self.classButtons[cbNum]
		local classIndex = cButton:GetAttribute("classID")
		if classIndex > 0 then
			self:ScanClass(classIndex) -- scanning for in-range and buffs
			local classExpire, specialExpire, nhave, nneed, nspecial
			classExpire, classDuration, specialExpire, specialDuration, nhave, nneed, nspecial = self:UpdateButton(cButton, "SolarPowerC"..cbNum, classIndex)
			minClassExpire = min(minClassExpire, classExpire)
			minSpecialExpire = min(minSpecialExpire, specialExpire)
			minClassDuration = min(minClassDuration, classDuration)
			minSpecialDuration = min(minSpecialDuration, specialDuration)
			sumnhave = sumnhave + nhave
			sumnneed = sumnneed + nneed
			sumnspecial = sumnspecial + nspecial
			local pButtons = self.playerButtons[cbNum]
			for pbNum = 1, SOLARPOWER_MAXPERCLASS do
				local pButton = pButtons[pbNum]
				local playerIndex = pButton:GetAttribute("playerID")
				if playerIndex > 0 then
					self:UpdatePButton(pButton, "SolarPowerC".. cbNum .."P".. pbNum, classIndex, playerIndex)
				end
			end -- by pbnum
		end -- class has players
	end  -- by cnum
	local autobutton = _G["SolarPowerAuto"]
	local time = _G["SolarPowerAutoTime"]
	local time2 = _G["SolarPowerAutoTime2"]
	local text = _G["SolarPowerAutoText"]
	-- NoM0Re Edit
	local flash = self.opt.display.flashBuffAutoButtons
	local instanced = IsInInstance()
	if (sumnhave == 0) then
		if flash then
			if instanced then
				StartAnimation(autobutton)
			else
				StopAnimation(autobutton)
				self:ApplyBackdrop(autobutton, self.opt.cBuffNeedSome)
			end
		else
			self:ApplyBackdrop(autobutton, self.opt.cBuffNeedSome)
		end
	elseif (sumnneed > 0) then
		if flash then
			if instanced then
				StartAnimation(autobutton)
			else
				StopAnimation(autobutton)
				self:ApplyBackdrop(autobutton, self.opt.cBuffNeedSome)
			end
		else
			self:ApplyBackdrop(autobutton, self.opt.cBuffNeedSome)
		end
	elseif (sumnspecial > 0) then
		if flash then
			if instanced then
				StartAnimation(autobutton)
			else
				StopAnimation(autobutton)
				self:ApplyBackdrop(autobutton, self.opt.cBuffNeedSpecial)
			end
		else
			self:ApplyBackdrop(autobutton, self.opt.cBuffNeedSpecial)
		end
	else
		if flash then
			StopAnimation(autobutton)
		end
		self:ApplyBackdrop(autobutton, self.opt.cBuffGood)
	end
	-- NoM0Re Edit End
	time:SetText(self:FormatTime(minClassExpire))
	time:SetTextColor(self:GetSeverityColor(minClassExpire and minClassDuration and (minClassExpire/minClassDuration) or 0))
	time2:SetText(self:FormatTime(minSpecialExpire))
	time2:SetTextColor(self:GetSeverityColor(minSpecialExpire and minSpecialDuration and (minSpecialExpire/minSpecialDuration) or 0))

	if (sumnneed+sumnspecial > 0) then
		text:SetText(sumnneed+sumnspecial)
	else
		text:SetText("")
	end
end

function SolarPower:UpdateAnchor(displayedButtons)
	SolarPowerAnchor:SetChecked(self.opt.display.frameLocked)
	if self.opt.display.hideDragHandle or self:GetNumUnits() == 0 then
		SolarPowerAnchor:Hide()
	else
		SolarPowerAnchor:Show()
	end
end

function SolarPower:NormalBlessingCount(classID)
	local nbcount = 0
	if classlist[classID] then
		for pbNum = 1, math.min(classlist[classID], SOLARPOWER_MAXPERCLASS) do
			local unit  = self:GetUnit(classID, pbNum)
			if unit and unit.name and
				SolarPower_NormalAssignments[flavor][self.player] and
				SolarPower_NormalAssignments[flavor][self.player][classID] and
				SolarPower_NormalAssignments[flavor][self.player][classID][unit.name] then
					nbcount = nbcount+1
			end
		end -- by pbnum
	end
	return nbcount
end

function SolarPower:GetSpellID(classID, playerName)
	local normal = 0
	local greater = 0
	if playerName and
	   SolarPower_NormalAssignments[flavor][self.player] and 
	   SolarPower_NormalAssignments[flavor][self.player][classID] and
	   SolarPower_NormalAssignments[flavor][self.player][classID][playerName] then
		normal = SolarPower_NormalAssignments[flavor][self.player][classID][playerName]
	end
	if SolarPower_Assignments[flavor][self.player] and SolarPower_Assignments[flavor][self.player][classID] then
		greater = SolarPower_Assignments[flavor][self.player][classID]
	end
	if normal == 0 then
		normal = greater
	end
	return normal, greater
end

function SolarPower:GetUnit(classID, playerID)
	return classes[classID][playerID]
end

function SolarPower:GetUnitAndSpellSmart(classID, mousebutton)
	local i, unit
	local class = classes[classID]

 	local spellID, gspellID = SolarPower:GetSpellID(classID)
	local spell, gspell
	if (mousebutton == "LeftButton") then
		gspell = SolarPower.GSpells[gspellID]
		for i, unit in pairs(class) do
			if IsSpellInRange(gspell, unit.unitid) == 1 then
				spellID, gspellID = SolarPower:GetSpellID(classID, unit.name)
				spell = SolarPower.Spells[spellID]
				gspell = SolarPower.GSpells[gspellID]
				return unit.unitid, spell, gspell
			end
		end
	elseif (mousebutton == "RightButton") then
		for i, unit in pairs(class) do
			spellID, gspellID = SolarPower:GetSpellID(classID, unit.name)
		 	spell = SolarPower.Spells[spellID]
			spell2 = SolarPower.GSpells[spellID]
			gspell = SolarPower.GSpells[gspellID]
			local buffExpire, buffDuration = self:IsBuffActive(spell, spell2, unit.unitid)
			if (not buffExpire or buffExpire/buffDuration < 0.5) and IsSpellInRange(spell, unit.unitid) == 1 then
				return unit.unitid, spell, gspell
			end
		end
	end
	return nil, "", ""
end

function SolarPower:IsBuffActive(spellName, gspellName, unitID, devotionIndex)
	if devotionIndex then
		return self:HasDevotion(devotionIndex, unitID)
	end
	local j = 1
	while UnitBuff(unitID, j) do
		local buffName, _, _, _, _, buffDuration, buffExpire = UnitBuff(unitID, j)
		if (buffName == spellName) or (buffName == gspellName) then
			if buffExpire then
				buffExpire = buffExpire - GetTime()
			end
			return buffExpire, buffDuration, buffName
		end
		j = j + 1
	end
	return nil
end

function SolarPower:ButtonPreClick(button, mousebutton)
	if (not InCombatLockdown()) then
		--local button = this
		local classID = button:GetAttribute("classID")
		local unitid, spell, gspell = SolarPower:GetUnitAndSpellSmart(classID, mousebutton)
		--local spell = SolarPower:GetSpellName(classID)
		--local gspell = L["SPELL_GTPREF"] .. spell .. L["SPELL_GTSUFF"]
		if not unitid then
			spell = "qq"
			gspell = "qq"
		end
		-- left click (find first nearby player and do 15 minute buff)
		button:SetAttribute("unit1", unitid)
		button:SetAttribute("spell1", gspell)
		-- right click (find first nearby player without buff and do a 5 minute buff)
		button:SetAttribute("unit2", unitid)
		button:SetAttribute("spell2", spell)
	end
end

function SolarPower:DewClick()
	dewdrop:Open(SolarPowerConfigFrame)
end

--
-- Drag Handle
--

-- Lock & Unlock the frame on left click, and toggle config dialog with right click
function SolarPower:ClickHandle(button, mousebutton)
	local function RelockActionBars()
		self.opt.display.frameLocked = true
		if (self.opt.display.LockBuffBars) then
			LOCK_ACTIONBAR = "1"
		end
		_G["SolarPowerAnchor"]:SetChecked(true)
	end

	if (mousebutton == "RightButton") then
		SolarPowerConfig_Toggle()
		button:SetChecked(self.opt.display.frameLocked)
	elseif (mousebutton == "LeftButton") then
		self.opt.display.frameLocked = not self.opt.display.frameLocked
		if (self.opt.display.frameLocked) then
			if (self.opt.display.LockBuffBars) then
				LOCK_ACTIONBAR = "1"
			end
		else
			if (self.opt.display.LockBuffBars) then
				LOCK_ACTIONBAR = "0"
			end
			self:ScheduleEvent("SolarPowerTemporaryUnlock", RelockActionBars, 30)
		end
	button:SetChecked(self.opt.display.frameLocked)
	end
end

-- Start dragging if not locked
function SolarPower:DragStart()
	if (not self.opt.display.frameLocked) then
		_G["SolarPowerFrame"]:StartMoving()
	end
end

-- End dragging
function SolarPower:DragStop()
	_G["SolarPowerFrame"]:StopMovingOrSizing()
end

function SolarPower:AutoBuff(mousebutton)
	if InCombatLockdown() then return end
	if not self.AutoBuffedList then
		self.AutoBuffedList = {}
	end
	local now = time()
	local minExpire, minUnit, minSpell = 9999, nil, nil
	for _, unit in ipairs(roster) do
		local classID = self:GetClassID(unit.class)
		if classID > 0 then
			local _, gspellID = self:GetSpellID(classID, unit.name)
			local spell = SolarPower.GSpells[gspellID]
			if spell and gspellID > 0 and IsSpellInRange(spell, unit.unitid) == 1 then
				local penalty = 0
				if self.AutoBuffedList[unit.name] and now - self.AutoBuffedList[unit.name] < 20 then
					penalty = SOLARPOWER_NORMALBLESSINGDURATION / 2
				end
				if self.PreviousAutoBuffedUnit and unit.name == self.PreviousAutoBuffedUnit.name then
					penalty = penalty + SOLARPOWER_NORMALBLESSINGDURATION
				end
				local buffExpire = self:HasDevotion(gspellID, unit.unitid)
				if (not buffExpire or buffExpire + penalty < minExpire and buffExpire < SOLARPOWER_NORMALBLESSINGDURATION) and minExpire > 0 then
					minExpire = (buffExpire or 0) + penalty
					minUnit = unit
					minSpell = spell
				end
			end
		end
	end
	if minExpire < 9999 and minUnit then
		local button = self.autoButton
		button:SetAttribute("unit", minUnit.unitid)
		button:SetAttribute("spell", minSpell)
		self.AutoBuffedList[minUnit.name] = now
		self.PreviousAutoBuffedUnit = minUnit
	end
end

function SolarPower:AutoBuffClear(mousebutton)
	if InCombatLockdown() then return end
	local button = self.autoButton
	button:SetAttribute("unit", nil)
	button:SetAttribute("spell", nil)
end

function SolarPower:SavePreset(preset)
    if not preset then return false end
	SolarPower_SavedPresets[preset] = {}
	self:Print("Saving preset: "..preset)
	for name in pairs(AllPallys) do
		self:Print("  Paladin: " .. name)
		SolarPower_SavedPresets[preset][name] = {}
	    local i
	    for i = 1, SOLARPOWER_MAXCLASSES do
			if not SolarPower_Assignments[flavor][name][i] then
				SolarPower_SavedPresets[preset][name][i] = 0
			else
				SolarPower_SavedPresets[preset][name][i] = SolarPower_Assignments[flavor][name][i]
			end
	    end
	end
	self:Print("Done.")
end

function SolarPower:LoadPreset(preset)
	if InCombatLockdown() then return false end
	--if not self:CheckRaidLeader(self.player) then return false end
	if SolarPower_SavedPresets[preset] then
	    self:Print("Loading preset: "..preset)
		for name in pairs(SolarPower_SavedPresets[preset]) do
			if not SolarPower_Assignments[flavor][name] then SolarPower_Assignments[flavor][name] = {} end
			self:Print("       Paladin: " .. name)
			local i
			for i = 1, SOLARPOWER_MAXCLASSES do
				SolarPower_Assignments[flavor][name][i] = SolarPower_SavedPresets[preset][name][i]
				SolarPower:SendMessage("ASSIGN "..name.." "..i.." "..SolarPower_SavedPresets[preset][name][i]) 
			end 
		end
		self:Print("Done.")
	else
		self:Print("No such preset name")
	end
end

function SolarPower:ApplySkin(skinname)
	local edge
	if self.opt.display.edges then
		edge = SolarPower.Edge
	else
		edge = nil
	end

    SolarPowerAuto:SetBackdrop({bgFile = SolarPower.Skins[skinname],
		                  edgeFile= edge,
						  tile=false, tileSize = 8, edgeSize = 8,
						  insets = { left = 0, right = 0, top = 0, bottom = 0}});
	for i = 1, SOLARPOWER_MAXCLASSES do
		local cBtn = SolarPower.classButtons[i]
		cBtn:SetBackdrop({bgFile = SolarPower.Skins[skinname],
		                  edgeFile= edge,
						  tile=false, tileSize = 8, edgeSize = 8,
						  insets = { left = 0, right = 0, top = 0, bottom = 0}});
		for j = 1, SOLARPOWER_MAXPERCLASS do
			local pBtn = SolarPower.playerButtons[i][j]
			pBtn:SetBackdrop({bgFile = SolarPower.Skins[skinname],
		                  edgeFile= edge,
						  tile=false, tileSize = 8, edgeSize = 8,
						  insets = { left = 0, right = 0, top = 0, bottom = 0}});
		end
    end
end

-- button coloring: preset
function SolarPower:ApplyBackdrop(button, preset)
	button:SetBackdropColor(preset["r"], preset["g"], preset["b"], preset["t"])
end

-- text coloring: preset
function SolarPower:ApplyTextColor(fontstring, preset)
	fontstring:SetTextColor(preset["r"], preset["g"], preset["b"], preset["t"])
end

-- Auto-Assign blessings by Maddeathelf
local WisdomPallys, MightPallys, KingsPallys, SalvPallys, LightPallys, SancPallys = {}, {}, {}, {}, {}, {}

function SolarPower:AutoAssign()

	SolarPowerConfig_Clear()
	WisdomPallys, MightPallys, KingsPallys, SalvPallys, LightPallys, SancPallys = {}, {}, {}, {}, {}, {}
	SolarPower:AutoAssignBlessings()

end

function SolarPower:CalcSkillRanks1(name)
	local wisdom, might, kings, salv, light, sanct
	if AllPallys[name][1] then
		wisdom = tonumber(AllPallys[name][1].rank) + tonumber(AllPallys[name][1].talent)/12
	else
		wisdom = 0
	end
	if AllPallys[name][2] then
		might = tonumber(AllPallys[name][2].rank) + tonumber(AllPallys[name][2].talent)/10
	else
		might = 0
	end
	if AllPallys[name][3] then
		kings = tonumber(AllPallys[name][3].rank)
	else
		kings = 0
	end

	if SolarPower.IsVanillaOrTBC then
		if AllPallys[name][4] then
			salv = tonumber(AllPallys[name][4].rank)
		else
			salv = 0
		end
		if AllPallys[name][5] then
			light = tonumber(AllPallys[name][5].rank)
		else
			light = 0
		end
		if AllPallys[name][6] then
			sanct = tonumber(AllPallys[name][6].rank)
		else
			sanct = 0
		end
	else
		if AllPallys[name][4] then
			sanct = tonumber(AllPallys[name][4].rank)
		else
			sanct = 0
		end
	end
	
	return wisdom, might, kings, salv, light, sanct
end

function SolarPower:AutoAssignBlessings()
	local clerics = {}
	for name in pairs(AllPallys) do
		tinsert(clerics, name)
	end
	if #clerics == 0 then
		return
	end
	tsort(clerics)
	for classId, classInfo in ipairs(self.CoAClasses) do
		local devotion = classInfo.defaultDevotion or 1
		local cleric = clerics[((classId - 1) % #clerics) + 1]
		if not SolarPower_Assignments[flavor][cleric] then
			SolarPower_Assignments[flavor][cleric] = {}
		end
		SolarPower_Assignments[flavor][cleric][classId] = devotion
		self:SendMessage("ASSIGN " .. cleric .. " " .. classId .. " " .. devotion)
	end
	self:ButtonsUpdate()
end

function SolarPower:SelectBuffsByClass(pallycount, class, prioritylist)
-- l2code i r noob.
    --self:Print(">Assignment for class: ".. class)
	local pallys = {}
	for name in pairs(AllPallys) do
		tinsert(pallys, name)
	end
	local bufftable = prioritylist

	if pallycount > 0 then
		local pallycounter = 1
		for i, nextspell in pairs(bufftable) do
			--self:Print(pallycounter, pallycount)
			if pallycounter <= pallycount then
				local buffer = SolarPower:BuffSelections(nextspell, class, pallys)
				for i, v in pairs(pallys) do
					if buffer == pallys[i] then
						--self:Print("removing buffer: " .. buffer)
						tremove(pallys, i)
					end
				end
				if buffer ~= "" then pallycounter = pallycounter + 1 end
			end
		end
	end

end

function SolarPower:BuffSelections(buff, class, pallys)
	--self:Print(">>Looking for buffer for: " .. buff)
	local t = {}
	if SolarPower.IsVanillaOrTBC then
		if buff == 1 then t = WisdomPallys end
		if buff == 2 then t = MightPallys end
		if buff == 3 then t = KingsPallys end
		if buff == 4 then t = SalvPallys end
		if buff == 5 then t = LightPallys end
		if buff == 6 then t = SancPallys end
	else
		if buff == 1 then t = WisdomPallys end
		if buff == 2 then t = MightPallys end
		if buff == 3 then t = KingsPallys end
		if buff == 4 then t = SancPallys end
	end

	local Buffer = ""
	local testrank = 0
	local testtalent = 0
	--self:Print("  before sort")
	--for i, v in ipairs(t) do
	--	self:Print("    " .. v.pallyname,v.skill, v.other)
	--end

	tsort(t, function(a, b) return a.skill > b.skill end)

	--self:Print("  after sort")
	--for i, v in ipairs(t) do
	--	self:Print("    " .. v.pallyname,v.skill, v.other)
	--end

	for i, v in ipairs(t) do
		if SolarPower:PallyAvailable(v.pallyname, pallys) and v.skill > 0 then
			--self:Print(">>>Selected Buffer: "..v.pallyname)
			Buffer = v.pallyname
			break
		end
	end

	--for i,v in pairs(t) do
--		if t[i].spellrank >= testrank and SolarPower:PallyAvailable(t[i].pallyname, pallys) then
			--testrank = t[i].spellrank
			--if t[i].spelltalents >= testtalent then
--				testtalent = t[i].spelltalents
				--Buffer = t[i].pallyname
			--end
		--end
	--end
	if Buffer ~= "" then
		SolarPower_Assignments[flavor][Buffer][class] = buff
		SolarPower:SendMessage("ASSIGN "..Buffer.." "..class.. " " ..buff)
	else end
	return Buffer
end

function SolarPower:PallyAvailable(pally, pallys)
	local available = false
	for i, v in pairs(pallys) do
		if pallys[i] == pally then available = true end
	end
	return available
end

