-- 2018-02-09 13:46:35
local mod	= DBM:NewMod("Festergut", "DBM-Icecrown", 2)
local L		= mod:GetLocalizedStrings()

mod:SetRevision(("$Revision: 4404 $"):sub(12, -3))
mod:SetCreatureID(36626)
mod:RegisterCombat("yell", L.YellPull)
mod:SetUsedIcons(6, 7, 8)

mod:RegisterEvents(
	"SPELL_CAST_START",
	"SPELL_AURA_APPLIED",
	"SPELL_AURA_APPLIED_DOSE",
	"UNIT_SPELLCAST_SUCCEEDED",
	"SPELL_DAMAGE"
)

local warnInhaledBlight		= mod:NewAnnounce("InhaledBlight", 3, 71912)
local warnGastricBloat		= mod:NewAnnounce("WarnGastricBloat", 2, 72551, mod:IsTank() or mod:IsHealer())
local warnGasSpore			= mod:NewTargetAnnounce(69279, 4)
local warnVileGas			= mod:NewTargetAnnounce(73020, 3)
local warnMalleableGoo		= mod:NewTargetAnnounce(72549, 4)
local warnPungentBlight		= mod:NewPreWarnAnnounce(71219, 10, 3)

local specWarnPungentBlight	= mod:NewSpecialWarningSpell(71219)
local specWarnGasSpore		= mod:NewSpecialWarningYou(69279)
local specWarnVileGas		= mod:NewSpecialWarningYou(71218)
local specWarnMalleableGoo	= mod:NewSpecialWarningYou(72549)
local specWarnGastricBloat	= mod:NewSpecialWarningStack(72551, nil, 9)
local specWarnInhaled3		= mod:NewSpecialWarningStack(71912, mod:IsTank(), 3)

local timerGasSpore			= mod:NewBuffActiveTimer(12, 69279)
local timerVileGas			= mod:NewBuffActiveTimer(6, 71218, nil, mod:IsRanged()) 
local timerVileGasCD		= mod:NewCDTimer(28, 71218)			-- 30-40s / 28-35s
local timerGasSporeCD		= mod:NewCDTimer(40, 69279)			-- 20-25s / 40-45s
local timerPungentBlight	= mod:NewNextTimer(34, 71219)		-- 34s
local timerInhaledBlight	= mod:NewNextTimer(34, 71912)		-- 25-30s / 34s
local timerInhaledBlightCD  = mod:NewCDTimer(25, 71912)			-- 25-30s / 34s
local timerGastricBloat		= mod:NewTargetTimer(100, 72551, nil, mod:IsTank() or mod:IsHealer())	-- 100 Seconds until expired
local timerGastricBloatCD	= mod:NewCDTimer(15, 72551, nil, mod:IsTank() or mod:IsHealer()) 		-- 12.5-15s / 15-17.5s

local berserkTimer			= mod:NewBerserkTimer(300)

local warnGoo				= mod:NewSpellAnnounce(72549, 4)
local timerGooCD			= mod:NewCDTimer(15, 72549) -- 15-20s / 15-20s

local sound1 = "Interface\\AddOns\\DBM-Core\\sounds\\1.mp3"
local sound2 = "Interface\\AddOns\\DBM-Core\\sounds\\2.mp3"
local sound3 = "Interface\\AddOns\\DBM-Core\\sounds\\3.mp3"
local sound4 = "Interface\\AddOns\\DBM-Core\\sounds\\4.mp3"
local sound5 = "Interface\\AddOns\\DBM-Core\\sounds\\5.mp3"

mod:AddBoolOption("RangeFrame", mod:IsRanged())
mod:AddBoolOption("SetIconOnGasSpore", true)
mod:AddBoolOption("AnnounceSporeIcons", false)
mod:AddBoolOption("AchievementCheck", false, "announce")

local gasSporeTargets	= {}
local gasSporeIconTargets	= {}
local vileGasTargets	= {}
local malleableGooTargets = {}
local gasSporeCast 	= 0
local warnedfailed = false

function mod:ToPungentBlight5()
	PlaySoundFile(sound5, "Master")
end

function mod:ToPungentBlight4()
	PlaySoundFile(sound4, "Master")
end

function mod:ToPungentBlight3()
	PlaySoundFile(sound3, "Master")
end

function mod:ToPungentBlight2()
	PlaySoundFile(sound2, "Master")
end

function mod:ToPungentBlight1()
	PlaySoundFile(sound1, "Master")
end

do
	local function sort_by_group(v1, v2)
		return DBM:GetRaidSubgroup(UnitName(v1)) < DBM:GetRaidSubgroup(UnitName(v2))
	end
	function mod:SetSporeIcons()
		if DBM:GetRaidRank() > 0 then
			table.sort(gasSporeIconTargets, sort_by_group)
			local gasSporeIcon = 8
			for i, v in ipairs(gasSporeIconTargets) do
				if self.Options.AnnounceSporeIcons then
					SendChatMessage(L.SporeSet:format(gasSporeIcon, UnitName(v)), "RAID")
				end
				self:SetIcon(UnitName(v), gasSporeIcon, 12)
				gasSporeIcon = gasSporeIcon - 1
			end
			table.wipe(gasSporeIconTargets)
		end
	end
end

local function warnGasSporeTargets()
	warnGasSpore:Show(table.concat(gasSporeTargets, "<, >"))
	table.wipe(gasSporeTargets)
end

local function warnVileGasTargets()
	warnVileGas:Show(table.concat(vileGasTargets, "<, >"))
	table.wipe(vileGasTargets)
end

local function warnMalleableGooTargets()
	warnMalleableGoo:Show(table.concat(malleableGooTargets, "<, >"))
	table.wipe(malleableGooTargets)
end


function mod:OnCombatStart(delay)
	table.wipe(gasSporeTargets)
	table.wipe(vileGasTargets)
	table.wipe(malleableGooTargets)
	gasSporeIcon = 8
	gasSporeCast = 0
	warnedfailed = false

	berserkTimer:Start(-delay)
	timerInhaledBlightCD:Start(-delay)
	timerGasSporeCD:Start(20-delay)
	timerVileGasCD:Start(30-delay)
	timerGastricBloatCD:Start(12.5-delay)
	if self.Options.RangeFrame then
		DBM.RangeCheck:Show(8)
	end
	if mod:IsDifficulty("heroic10") or mod:IsDifficulty("heroic25") then
		timerGooCD:Start(15-delay)
	end
end

function mod:OnCombatEnd()
	if self.Options.RangeFrame then
		DBM.RangeCheck:Hide()
	end
	self:Unschedule(ToPungentBlight5)
	self:Unschedule(ToPungentBlight4)
	self:Unschedule(ToPungentBlight3)
	self:Unschedule(ToPungentBlight2)
	self:Unschedule(ToPungentBlight1)
	warnPungentBlight:Cancel()
end

function mod:SPELL_CAST_START(args)
	if args:IsSpellID(69195, 71219, 73031, 73032) then	-- Pungent Blight
		specWarnPungentBlight:Show()
		timerInhaledBlight:Start()
		timerGasSporeCD:Start(20)
	end
end

function mod:SPELL_DAMAGE(args)
	if args:IsSpellID(72550, 72297, 72548, 72549) and args:IsDestTypePlayer() then   -- Malleable Goo
        malleableGooTargets[#malleableGooTargets + 1] = args.destName
        if args:IsPlayer() then
            specWarnMalleableGoo:Show()
        end
        timerGooCD:Start()
        self:Unschedule(warnMalleableGooTargets)
        self:Schedule(0.1, warnMalleableGooTargets)
    end
end

function mod:SPELL_AURA_APPLIED(args)
	if args:IsSpellID(69279) then	-- Gas Spore
		if timerVileGasCD:IsStarted() and (timerVileGasCD:GetTime() + 20) > timerVileGasCD:Time() then
			timerVileGasCD:Start(20)
		elseif not timerVileGasCD:IsStarted() then
			timerVileGasCD:Start(20)
		end
		--timerVileGasCD:Start(20)
		gasSporeTargets[#gasSporeTargets + 1] = args.destName
		gasSporeCast = gasSporeCast + 1
		if (gasSporeCast < 9 and (mod:IsDifficulty("normal25") or mod:IsDifficulty("heroic25"))) or (gasSporeCast < 6 and (mod:IsDifficulty("normal10") or mod:IsDifficulty("heroic10"))) then
			timerGasSporeCD:Start()
		elseif (gasSporeCast >= 9 and (mod:IsDifficulty("normal25") or mod:IsDifficulty("heroic25"))) or (gasSporeCast >= 6 and (mod:IsDifficulty("normal10") or mod:IsDifficulty("heroic10"))) then
			timerGasSporeCD:Start(50)--Basically, the third time spores are placed on raid, it'll be an extra 10 seconds before he applies first set of spores again.
			gasSporeCast = 0
		end
		if args:IsPlayer() then
			specWarnGasSpore:Show()
		end
		if self.Options.SetIconOnGasSpore then
			table.insert(gasSporeIconTargets, DBM:GetRaidUnitId(args.destName))
			if ((mod:IsDifficulty("normal25") or mod:IsDifficulty("heroic25")) and #gasSporeIconTargets >= 3) or ((mod:IsDifficulty("normal10") or mod:IsDifficulty("heroic10")) and #gasSporeIconTargets >= 2) then
				self:SetSporeIcons()--Sort and fire as early as possible once we have all targets.
			end
		end
		self:Unschedule(warnGasSporeTargets)
		if #gasSporeTargets >= 3 then
			warnGasSporeTargets()
		else
			timerGasSpore:Start()
			self:Schedule(0.1, warnGasSporeTargets)
		end
	elseif args:IsSpellID(69166, 71912) then	-- Inhaled Blight
		warnInhaledBlight:Show(args.amount or 1)
		if (args.amount or 1) >= 3 then
			specWarnInhaled3:Show(args.amount)
			warnPungentBlight:Schedule(24)
			self:ScheduleMethod(29, "ToPungentBlight5")
			self:ScheduleMethod(30, "ToPungentBlight4")
			self:ScheduleMethod(31, "ToPungentBlight3")
			self:ScheduleMethod(32, "ToPungentBlight2")
			self:ScheduleMethod(33, "ToPungentBlight1")
			timerPungentBlight:Start()
		end
		if (args.amount or 1) <= 2 then	--Prevent timer from starting after 3rd stack since he won't cast it a 4th time, he does Pungent instead.
			timerInhaledBlight:Start()
		end
	elseif args:IsSpellID(72219, 72551, 72552, 72553) then	-- Gastric Bloat
		warnGastricBloat:Show(args.spellName, args.destName, args.amount or 1)
		timerGastricBloat:Start(args.destName)
		timerGastricBloatCD:Start()
		if args:IsPlayer() and (args.amount or 1) >= 9 then
			specWarnGastricBloat:Show(args.amount)
		end
	elseif args:IsSpellID(69240, 71218, 73019, 73020) and args:IsDestTypePlayer() then	-- Vile Gas
		vileGasTargets[#vileGasTargets + 1] = args.destName
		if args:IsPlayer() then
			specWarnVileGas:Show()
		end
		timerVileGas:Start()
		self:Unschedule(warnVileGasTargets)
		self:Schedule(0.1, warnVileGasTargets)
	elseif args:IsSpellID(69291, 72101, 72102, 72103) then	--Inoculated
		if args:IsDestTypePlayer() then
			if self.Options.AchievementCheck and DBM:GetRaidRank() > 0 and not warnedfailed then
				if (args.amount or 1) == 3 then
					SendChatMessage(L.AchievementFailed:format(args.destName, (args.amount or 1)), "RAID_WARNING")
					warnedfailed = true
				end
			end
		end
	end
end

mod.SPELL_AURA_APPLIED_DOSE = mod.SPELL_AURA_APPLIED


