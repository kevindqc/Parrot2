local Parrot = Parrot

local mod = Parrot:NewModule("Cooldowns", "LibRockEvent-1.0", "LibRockTimer-1.0")

local L = LibStub("AceLocale-3.0"):GetLocale("Parrot_Cooldowns")

local newList, del = Rock:GetRecyclingFunctions("Parrot", "newList", "del")

function mod:OnEnable()
	self:ResetSpells()

	self:AddRepeatingTimer(0.1, "OnUpdate")
	self:AddEventListener("SPELLS_CHANGED", "ResetSpells")
	self:AddEventListener("SPELL_UPDATE_COOLDOWN", "ResetCooldownState")
end

Parrot:RegisterCombatEvent{
	category = "Notification",
	subCategory = L["Cooldowns"],
	name = "Skill cooldown finish",
	localName = L["Skill cooldown finish"],
	defaultTag = L["[[Skill] ready!]"],
	tagTranslations = {
		Skill = 1,
		Icon = 2,
	},
	tagTranslationHelp = {
		Skill = L["The name of the spell or ability which is ready to be used."],
	},
	color = "ffffff", -- white
	sticky = false,
}

local cooldowns = {}
local spellNameToID = {}
local spellNameToTree = {}

function mod:ResetCooldownState()
	local GCD = 1.5

	-- 18 is melee ... as of WoW 3.0 this is the same value as for ranged and spell
	-- local GCD = 1.5 / (1 + GetCombatRatingBonus(18) / 100);

	-- 3018 = ranged shoot
	-- 5019 = wand shoot
	if spellNameToID[GetSpellInfo(3018)] then
		local _, shootCooldown = GetSpellCooldown(GetSpellInfo(3018))
		if shootCooldown > GCD then
			GCD = shootCooldown
		end
	end

	for name, id in pairs(spellNameToID) do
		local start, duration = GetSpellCooldown(id, "spell")
		cooldowns[name] = start > 0 and duration > GCD
	end

end
function mod:ResetSpells()
	for k in pairs(spellNameToID) do
		spellNameToID[k] = nil
	end
	for k in pairs(cooldowns) do
		cooldowns[k] = nil
	end
	for i = 1, GetNumSpellTabs() do
		local _, _, offset, num = GetSpellTabInfo(i)
		for j = 1, num do
			local id = offset+j
			local spell = GetSpellName(id, "spell")
			spellNameToID[spell] = id
			spellNameToTree[spell] = i
		end
	end

	self:ResetCooldownState()
end

local groups = {
	--[BSL["Freezing Trap"]]
	[GetSpellInfo(14311)] = L["Frost traps"],
	--[BSL["Frost Trap"]]
	[GetSpellInfo(13809)] = L["Frost traps"],
-- 	[BSL["Snake Trap"]]
-- leave commented for now until another spell shares the CD
--	[GetSpellInfo(34600)] = L["Nature Traps"],

--  [BSL["Immolation Trap"]]
	[GetSpellInfo(27023)] = L["Fire traps"],
-- 	[BSL["Explosive Trap"]]
	[GetSpellInfo(27025)] = L["Fire traps"],
-- Black Arrow
	[GetSpellInfo(63668)] = L["Fire traps"],	

-- 	[BSL["Frost Shock"]]
	[GetSpellInfo(25464)] = L["Shocks"],
-- 	[BSL["Flame Shock"]]
	[GetSpellInfo(25457)] = L["Shocks"],
	--[BSL["Earth Shock"]]
	[GetSpellInfo(25454)] = L["Shocks"],

	-- Judgement of Justice
	[GetSpellInfo(53407)] = L["Judgements"],
	-- Judgement of Light
	[GetSpellInfo(20271)] = L["Judgements"],
	-- Judgement of Wisdom
	[GetSpellInfo(53408)] = L["Judgements"],
}

function mod:OnUpdate()
	local GCD = 1.5
	-- 3018 = ranged shoot
	-- 5019 = wand shoot
	if spellNameToID[GetSpellInfo(3018)] then
		local _, shootCooldown = GetSpellCooldown(spellNameToID[GetSpellInfo(3018)], "spell")
		if shootCooldown > GCD then
			GCD = shootCooldown
		end
	end
	local groupsToTrigger = newList()
	local spellsToTrigger = newList()
	local treeCount = newList()
	for name, id in pairs(spellNameToID) do
		local old = cooldowns[name]
		local start, duration = GetSpellCooldown(id, "spell")
		local check = start > 0 and duration > GCD
		cooldowns[name] = check
		if not check and old then
			spellsToTrigger[name] = id
            if not groups[name] then
				local tree = spellNameToTree[name]
				treeCount[tree] = (treeCount[tree] or 0) + 1
			end
			Parrot:FirePrimaryTriggerCondition("Spell ready", name)
		end
	end
	for tree, num in pairs(treeCount) do
		if num >= 3 then
			for name in pairs(spellsToTrigger) do
				if tree == spellNameToTree[name] then
					spellsToTrigger[name] = nil
				end
			end
			local name, texture = GetSpellTabInfo(tree)
			local info = newList(L["%s Tree"]:format(name), texture)
			Parrot:TriggerCombatEvent("Notification", "Skill cooldown finish", info)
			info = del(info)
		end
	end
	treeCount = del(treeCount)
	for name in pairs(spellsToTrigger) do
		if groups[name] then
			groupsToTrigger[groups[name]] = true
			spellsToTrigger[name] = nil
		end
	end
	for name in pairs(groupsToTrigger) do
		local info = newList(name)
		Parrot:TriggerCombatEvent("Notification", "Skill cooldown finish", info)
		info = del(info)
	end
	groupsToTrigger = del(groupsToTrigger)
	for name, id in pairs(spellsToTrigger) do
		local info = newList(name, GetSpellTexture(id, "spell"))
		Parrot:TriggerCombatEvent("Notification", "Skill cooldown finish", info)
		info = del(info)
	end
	spellsToTrigger = del(spellsToTrigger)
end

Parrot:RegisterPrimaryTriggerCondition {
	subCategory = L["Cooldowns"],
	name = "Spell ready",
	localName = L["Spell ready"],
	param = {
		type = 'string',
		usage = L["<Spell name>"],
	},
}

Parrot:RegisterSecondaryTriggerCondition {
	subCategory = L["Cooldowns"],
	name = "Spell ready",
	localName = L["Spell ready"],
	param = {
		type = 'string',
		usage = L["<Spell name>"],
	},
	check = function(param)
		if(tonumber(param)) then
			param = GetSpellInfo(param)
		end

		return (GetSpellCooldown(param) == 0)
	end,
}

Parrot:RegisterSecondaryTriggerCondition {
	subCategory = L["Cooldowns"],
	name = "Spell usable",
	localName = L["Spell usable"],
	param = {
		type = 'string',
		usage = L["<Spell name>"],
	},
	check = function(param)
		if(tonumber(param)) then
			param = GetSpellInfo(param)
		end

		return IsUsableSpell(param)
	end,
}
