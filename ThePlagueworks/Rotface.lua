-- 2018-02-09 13:46:21
local mod	= DBM:NewMod("Rotface", "DBM-Icecrown", 2)
local L		= mod:GetLocalizedStrings()

mod:SetRevision(("$Revision: 4408 $"):sub(12, -3))
mod:SetCreatureID(36627)
mod:SetUsedIcons(7, 8)
mod:RegisterCombat("yell", L.YellPull)

mod:RegisterEvents(
	"SPELL_CAST_START",
	"SPELL_AURA_APPLIED",
	"SPELL_AURA_APPLIED_DOSE",
	"SPELL_CAST_SUCCESS",
	"SPELL_AURA_REMOVED",
	"SPELL_DAMAGE",
	"SWING_DAMAGE",
	"CHAT_MSG_MONSTER_YELL"
)

local InfectionIcon	-- alternating between 2 icons (2 debuffs can be up at the same time in 25man at least)

local warnSlimeSpray			= mod:NewSpellAnnounce(69508, 2)
local warnMutatedInfection		= mod:NewTargetAnnounce(71224, 4)
local warnRadiatingOoze			= mod:NewSpellAnnounce(69760, 3)
local warnOozeSpawn				= mod:NewAnnounce("WarnOozeSpawn", 1)
local warnStickyOoze			= mod:NewSpellAnnounce(69774, 1)
local warnUnstableOoze			= mod:NewAnnounce("WarnUnstableOoze", 2, 69558)
local warnVileGas				= mod:NewTargetAnnounce(72272, 3)

local specWarnMutatedInfection	= mod:NewSpecialWarningYou(71224)
local specWarnStickyOoze		= mod:NewSpecialWarningMove(69774)
local specWarnOozeExplosion		= mod:NewSpecialWarningRun(69839)
local specWarnSlimeSpray		= mod:NewSpecialWarningSpell(69508, false)
local specWarnRadiatingOoze		= mod:NewSpecialWarningSpell(69760, not mod:IsTank())
local specWarnLittleOoze		= mod:NewSpecialWarning("SpecWarnLittleOoze")
local specWarnVileGas			= mod:NewSpecialWarningYou(72272)

local timerStickyOoze			= mod:NewNextTimer(15, 69774, nil, mod:IsTank())
local timerWallSlime			= mod:NewTimer(25, "NextPoisonSlimePipes", 69789) -- 8s / 25s
local timerSlimeSpray			= mod:NewNextTimer(20, 69508) -- 20s / 20s -- delay events 1s
local timerMutatedInfectionTar	= mod:NewTargetTimer(12, 71224)
local timerMutatedInfection 	= mod:NewNextTimer(14, 71224) -- 14s, 2s less every 90s until reach 6s
local timerOozeExplosion		= mod:NewCastTimer(4, 69839)
local timerVileGasCD			= mod:NewCDTimer(15, 72272) -- 15-20s / 15-20s

local soundMutatedInfection		= mod:NewSound(71224)
mod:AddBoolOption("RangeFrame", mod:IsRanged())
mod:AddBoolOption("InfectionIcon", true)
mod:AddBoolOption("TankArrow")

local RFVileGasTargets	= {}
local spamOoze = 0
local mutatedInfection = 14

local function warnRFVileGasTargets()
	warnVileGas:Show(table.concat(RFVileGasTargets, "<, >"))
	table.wipe(RFVileGasTargets)
end

function mod:hastenInfection()
	if mutatedInfection >= 8 then
		mutatedInfection = mutatedInfection - 2
	end
	self:ScheduleMethod(90, "hastenInfection")
end


function mod:OnCombatStart(delay)
	timerWallSlime:Start(8-delay)
	timerSlimeSpray:Start(-delay)
	timerMutatedInfection:Start(-delay)
	InfectionIcon = 8
	spamOoze = 0
	mutatedInfection = 14
	if mod:IsDifficulty("heroic10") or mod:IsDifficulty("heroic25") then
		timerVileGasCD:Start(-delay)
		if self.Options.RangeFrame then
			DBM.RangeCheck:Show(8)
		end
	end
	timerMutatedInfection:Start()
	self:ScheduleMethod(90, "hastenInfection")
end

function mod:OnCombatEnd()
	if self.Options.RangeFrame then
		DBM.RangeCheck:Hide()
	end
end

function mod:SPELL_CAST_START(args)
	if args:IsSpellID(69508) then
		timerSlimeSpray:Start()
		warnSlimeSpray:Show()
		specWarnSlimeSpray:Show()

		timerWallSlime:AddTime(1)
		timerMutatedInfection:AddTime(1)
		timerVileGasCD:AddTime(1)

	elseif args:IsSpellID(69774) then
		timerStickyOoze:Start(5)
		warnStickyOoze:Show()
	elseif args:IsSpellID(69839) then --Unstable Ooze Explosion (Big Ooze)
		if GetTime() - spamOoze < 4 then --This will prevent spam but breaks if there are 2 oozes. GUID work is required
			specWarnOozeExplosion:Cancel()
		end
		if GetTime() - spamOoze < 4 or GetTime() - spamOoze > 5 then --Attempt to ignore a cast that may fire as an ooze is already exploding.
			timerOozeExplosion:Start()
			specWarnOozeExplosion:Schedule(4)
		end
		spamOoze = GetTime()
	end
end

function mod:SPELL_AURA_APPLIED(args)
	if args:IsPlayer() and args:IsSpellID(71208, 69778) then
		specWarnStickyOoze:Show()
	elseif args:IsSpellID(69760) then
		warnRadiatingOoze:Show()
	elseif args:IsSpellID(69558) then
		warnUnstableOoze:Show(args.spellName, args.destName, args.amount or 1)
	elseif args:IsSpellID(69674, 71224, 73022, 73023) then
		warnMutatedInfection:Show(args.destName)
		timerMutatedInfectionTar:Start(args.destName)
		timerMutatedInfection:Start(mutatedInfection)
		if args:IsPlayer() then
			specWarnMutatedInfection:Show()
			soundMutatedInfection:Play()
		end
		if self.Options.InfectionIcon then
			self:SetIcon(args.destName, InfectionIcon, 12)
			if InfectionIcon == 8 then	-- After ~3mins there is a chance 2 ppl will have the debuff, so we are alternating between 2 icons
				InfectionIcon = 7
			else
				InfectionIcon = 8
			end
		end
	elseif args:IsSpellID(72272, 72273, 69240, 71218, 73019, 73020) and args:IsDestTypePlayer() then	-- Vile Gas(Heroic Rotface only, 25 man spellid the same as 10?)
		RFVileGasTargets[#RFVileGasTargets + 1] = args.destName
		if args:IsPlayer() then
			specWarnVileGas:Show()
		end
		timerVileGasCD:Start()
		self:Unschedule(warnRFVileGasTargets)
		self:Schedule(2.5, warnRFVileGasTargets) -- Yes it does take this long to travel to all 3 targets sometimes, qq.
	end
end

mod.SPELL_AURA_APPLIED_DOSE = mod.SPELL_AURA_APPLIED

function mod:SPELL_CAST_SUCCESS(args)
	if args:IsSpellID(72272, 72273) then
		--timerVileGasCD:Start()
	end
end

function mod:SPELL_AURA_REMOVED(args)
	if args:IsSpellID(69674, 71224, 73022, 73023) then
		timerMutatedInfectionTar:Cancel(args.destName)
		warnOozeSpawn:Show()
		if self.Options.InfectionIcon then
			self:SetIcon(args.destName, 0)
		end
	end
end

function mod:SPELL_DAMAGE(args)
	if args:IsSpellID(69761, 71212, 73026, 73027) and args:IsPlayer() then
		specWarnRadiatingOoze:Show()
	elseif args:GetDestCreatureID() == 36899 and args:IsSrcTypePlayer() and not args:IsSpellID(53189, 53190, 53194, 53195) then--Any spell damage except for starfall (ranks 3 and 4)
--		self:ScheduleMethod(1, "SlimeTank")
		if args.sourceName ~= UnitName("player") then
			if self.Options.TankArrow then
				DBM.Arrow:ShowRunTo(args.sourceName, 0, 0)
			end
		end
	end
end

function mod:SWING_DAMAGE(args)
	if args:IsPlayer() and args:GetSrcCreatureID() == 36897 then --Little ooze hitting you
		specWarnLittleOoze:Show()
	elseif args:GetDestCreatureID() == 36899 and args:IsSrcTypePlayer() then
--		self:ScheduleMethod(1, "SlimeTank")
		if args.sourceName ~= UnitName("player") then
			if self.Options.TankArrow then
				DBM.Arrow:ShowRunTo(args.sourceName, 0, 0)
			end
		end
	end
end

function mod:CHAT_MSG_MONSTER_YELL(msg)
	if (msg == L.YellSlimePipes1 or msg:find(L.YellSlimePipes1)) or (msg == L.YellSlimePipes2 or msg:find(L.YellSlimePipes2)) then
		timerWallSlime:Start()
	end
end
