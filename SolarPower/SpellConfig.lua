-- Devotion spell configuration for Project Ascension CoA Sun Cleric
SolarPower.Devotions = {
	{
		key = "dawn",
		name = "Devotion of Dawn",
		spellIds = { 572384 },
		icon = "Interface\\Icons\\Devotion_of_Radiance",
		duration = 1800,
	},
	{
		key = "grace",
		name = "Devotion of Grace",
		spellIds = { 800852, 30085 },
		icon = "Interface\\Icons\\Devotion_of_Grace",
		duration = 1800,
	},
	{
		key = "radiance",
		name = "Devotion of Radiance",
		spellIds = { 575040 },
		icon = "Interface\\Icons\\Devotion_of_Dawnbreak",
		duration = 1800,
	},
}

-- Build aura spellId -> devotion index lookup
SolarPower.DevotionBySpellId = {}
for index, devotion in ipairs(SolarPower.Devotions) do
	for _, spellId in ipairs(devotion.spellIds) do
		SolarPower.DevotionBySpellId[spellId] = index
	end
end

function SolarPower:GetDevotionName(index)
	local devotion = self.Devotions[index]
	return devotion and devotion.name or ""
end

function SolarPower:GetDevotionIcon(index)
	local devotion = self.Devotions[index]
	return devotion and devotion.icon or ""
end

local function devotionRemaining(duration, expirationTime)
	if expirationTime and expirationTime > 0 then
		return expirationTime - GetTime()
	end
	if duration and duration > 0 then
		return duration
	end
	return 0
end

local function devotionMatchesAura(devotion, name, spellId)
	if name == devotion.name then
		return true
	end
	if spellId then
		local auraSpellId = tonumber(spellId)
		if auraSpellId then
			for _, id in ipairs(devotion.spellIds) do
				if auraSpellId == id then
					return true
				end
			end
		end
	end
	for _, id in ipairs(devotion.spellIds) do
		local spellName = GetSpellInfo(id)
		if spellName and spellName == name then
			return true
		end
	end
	return false
end

function SolarPower:HasDevotion(devotionIndex, unitID)
	if not unitID or not devotionIndex or devotionIndex == 0 then
		return nil
	end
	local devotion = self.Devotions[devotionIndex]
	if not devotion then
		return nil
	end

	local j = 1
	while true do
		local name, _, _, _, _, duration, expirationTime = UnitBuff(unitID, j)
		if not name then
			break
		end
		if devotionMatchesAura(devotion, name, nil) then
			return devotionRemaining(duration, expirationTime), duration, name
		end
		j = j + 1
	end

	j = 1
	while true do
		local name, _, _, _, _, duration, expirationTime, _, _, _, spellId = UnitAura(unitID, j)
		if not name then
			break
		end
		if devotionMatchesAura(devotion, name, spellId) then
			return devotionRemaining(duration, expirationTime), duration, name
		end
		j = j + 1
	end
	return nil
end

function SolarPower:SetAssignmentIcon(texture, devotionIndex)
	if not texture then
		return
	end
	if devotionIndex and devotionIndex > 0 then
		texture:SetTexture(self.BlessingIcons[devotionIndex])
		texture:SetTexCoord(0, 1, 0, 1)
	else
		texture:SetTexture(nil)
	end
end

function SolarPower:BuildSpellTables()
	self.Spells = { [0] = "" }
	self.GSpells = { [0] = "" }
	self.BlessingIcons = { [-1] = "" }
	self.NormalBlessingIcons = { [-1] = "" }

	for index, devotion in ipairs(self.Devotions) do
		local spellName = devotion.name
		local infoName = GetSpellInfo(spellName)
		if infoName then
			spellName = infoName
		end
		self.Spells[index] = spellName
		self.GSpells[index] = spellName
		self.BlessingIcons[index] = devotion.icon
		self.NormalBlessingIcons[index] = devotion.icon
	end
end
