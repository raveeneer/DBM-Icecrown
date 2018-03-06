-- 2018-02-20 18:58:41
local mod	= DBM:NewMod("Putricide", "DBM-Icecrown", 2)
local L		= mod:GetLocalizedStrings()

mod:SetRevision(("$Revision: 4408 $"):sub(12, -3))
mod:SetCreatureID(36678)
mod:RegisterCombat("yell", L.YellPull)
mod:RegisterKill("yell", L.YellKill)
mod:SetMinSyncRevision(3860)
mod:SetUsedIcons(5, 6, 7, 8)

mod:RegisterEvents(
	"SPELL_CAST_START",
	"SPELL_CAST_SUCCESS",
	"SPELL_AURA_APPLIED",
	"SPELL_AURA_APPLIED_DOSE",
	"SPELL_AURA_REFRESH",
	"SPELL_AURA_REMOVED",
	"UNIT_HEALTH",
	"SPELL_SUMMON",
	"SPELL_DAMAGE",
	"CHAT_MSG_MONSTER_YELL",
	"CHAT_MSG_RAID_BOSS_EMOTE"
)

local warnSlimePuddle				= mod:NewSpellAnnounce(70341, 2)
local warnUnstableExperimentG		= mod:NewAnnounceCustom("WarnUnstableExperimentG", 5, 70351)
local warnUnstableExperimentO		= mod:NewAnnounce("WarnUnstableExperimentO", 3, 70351)
local warnVolatileOozeAdhesive		= mod:NewTargetAnnounce(70447, 3)
local warnGaseousBloat				= mod:NewTargetAnnounce(70672, 3)
local warnPhase2Soon				= mod:NewAnnounce("WarnPhase2Soon", 2)
local warnTearGas					= mod:NewSpellAnnounce(71617, 2)		-- Phase transition normal
local warnVolatileExperiment		= mod:NewSpellAnnounce(72840, 4)		-- Phase transition heroic
local warnMalleableGoo				= mod:NewSpellAnnounce(72295, 2)		-- Phase 2 ability
local warnChokingGasBomb			= mod:NewSpellAnnounce(71255, 3)		-- Phase 2 ability
local warnPhase3Soon				= mod:NewAnnounce("WarnPhase3Soon", 2)
local warnMutatedPlague				= mod:NewAnnounce("WarnMutatedPlague", 2, 72451, mod:IsTank() or mod:IsHealer()) -- Phase 3 ability
local warnUnboundPlague				= mod:NewTargetAnnounce(72856, 3)			-- Heroic Ability
local warnUnboundPlagueSoon			= mod:NewAnnounce("WarnUnboundPlageSoon", 4, 72856)

local specWarnVolatileOozeAdhesive	= mod:NewSpecialWarningYou(70447)
local specWarnGaseousBloat			= mod:NewSpecialWarningYou(70672)
local specWarnVolatileOozeOther		= mod:NewSpecialWarningTarget(70447, false)
local specWarnGaseousBloatOther		= mod:NewSpecialWarningTarget(70672, false)
local specWarnChokingGasBomb		= mod:NewSpecialWarningSpell(71255, mod:IsTank())
local specWarnMalleableGooCast		= mod:NewSpecialWarningSpell(72295, false)
local specWarnOozeVariable			= mod:NewSpecialWarningYou(70352)		-- Heroic Ability
local specWarnGasVariable			= mod:NewSpecialWarningYou(70353)		-- Heroic Ability
local specWarnUnboundPlague			= mod:NewSpecialWarningYou(72856)		-- Heroic Ability
local specWarnSlimePuddle			= mod:NewSpecialWarningMove(72869)		-- Slime Puddle

local timerGaseousBloat				= mod:NewTargetTimer(20, 70672)			-- Duration of debuff
local timerSlimePuddle				= mod:NewNextTimer(35, 70341)			-- 10s / 35s
local timerUnstableExperimentCD		= mod:NewCDTimer(35, 70351)			    -- 30-35s / 35-40s
local timerChokingGasBombCD			= mod:NewCDTimer(35, 71255)			    -- 35-40s / 35-40s
--local timerMalleableGooCD			= mod:NewCDTimer(25, 72295)				-- 25-30s
local timerMalleableGooCD			= mod:NewNextTimer(20, 72295) 			-- changed to stick 20s by Graal
local timerMutatedPlagueCD			= mod:NewCDTimer(10, 72451)				-- 10 to 11
local timerUnboundPlagueCD			= mod:NewNextTimer(90, 72856)			-- 20s / 90s
local timerUnboundPlague			= mod:NewBuffActiveTimer(12, 72856)		-- Heroic Ability: we can't keep the debuff 60 seconds, so we have to switch at 12-15 seconds. Otherwise the debuff does to much damage!

-- buffs from "Drink Me"
local timerMutatedSlash				= mod:NewTargetTimer(20, 70542)
local timerRegurgitatedOoze			= mod:NewTargetTimer(20, 70539)

local berserkTimer					= mod:NewBerserkTimer(600)

local soundGaseousBloat 			= mod:NewSound(72455)
local sound1 = "Interface\\AddOns\\DBM-Core\\sounds\\1.mp3"
local sound2 = "Interface\\AddOns\\DBM-Core\\sounds\\2.mp3"
local sound3 = "Interface\\AddOns\\DBM-Core\\sounds\\3.mp3"
local flasks = "Interface\\AddOns\\DBM-Core\\sounds\\flasks.mp3"
local malleable = "Interface\\AddOns\\DBM-Core\\sounds\\malleable.mp3"

mod:AddBoolOption("OozeAdhesiveIcon")
mod:AddBoolOption("GaseousBloatIcon")
mod:AddBoolOption("UnboundPlagueIcon")					-- icon on the player with active buff
mod:AddBoolOption("YellOnMalleableGoo", true, "announce")
mod:AddBoolOption("YellOnUnbound", true, "announce")
mod:AddBoolOption("SoundWarnMalleableGoo", true)
mod:AddBoolOption("SoundPreWarnMalleable", mod:IsRanged())
mod:AddBoolOption("SoundWarnFlasks", mod:IsTank() or mod:IsMelee())

local warned_preP2 = false
local warned_preP3 = false
local phase = 0
local unstable_experiment = 0

function mod:Malleable5Sec()
	PlaySoundFile(malleable, "Master")
end

function mod:Flasks10Sec()
	PlaySoundFile(flasks, "Master")
end

function mod:OnCombatStart(delay)
	berserkTimer:Start(-delay)
	timerSlimePuddle:Start(10-delay)
	timerUnstableExperimentCD:Start(30-delay)
	warned_preP2 = false
	warned_preP3 = false
	phase = 1
	unstable_experiment = 0
	if mod:IsDifficulty("heroic10") or mod:IsDifficulty("heroic25") then
		timerUnboundPlagueCD:Start(20-delay)
		warnUnboundPlagueSoon:Schedule(10)
	end
end

function mod:UnboundPlaguePassOn()
	SendChatMessage(L.YellUnbound10s, "YELL")
end

function mod:SPELL_CAST_START(args)
	if args:IsSpellID(70351, 71966, 71967, 71968) then 		-- Ooze warnings
		if unstable_experiment % 2 == 0 then
			warnUnstableExperimentG:Show() 					-- Green Ooze warning
		else
			warnUnstableExperimentO:Show() 					-- Orange Ooze warning
		end
		timerUnstableExperimentCD:Start()
		unstable_experiment = unstable_experiment + 1
	elseif args:IsSpellID(71617) then						-- PhaseChange normal version; Tear Gas; 24s delay on timers
		warnTearGas:Show()
		timerSlimePuddle:AddTime(24)
		if phase == 2 then
			timerUnstableExperimentCD:AddTime(24)
			timerMalleableGooCD:Start(25)
			if self.Options.SoundPreWarnMalleable then -- Malleable Goo voice pre-warning
				self:Unschedule(Malleable5Sec)
			end
			if self.Options.SoundWarnFlasks then
				self:Unschedule(Flasks10Sec)
			end
			timerChokingGasBombCD:Start(35)	
		elseif phase == 3 then
			timerUnstableExperimentCD:Cancel()
			timerMalleableGooCD:AddTime(19) 		-- -5 due to 20s timer for MG on Phase 3
			if self.Options.SoundPreWarnMalleable then -- Malleable Goo voice pre-warning
				self:Unschedule(Malleable5Sec)
			end
			if self.Options.SoundWarnFlasks then
				self:Unschedule(Flasks10Sec)
			end
			timerChokingGasBombCD:AddTime(24)	
		end
	end
end

function mod:SPELL_CAST_SUCCESS(args)
	if args:IsSpellID(71255) then 							-- Choking Gas Bomb 
		warnChokingGasBomb:Show()
		specWarnChokingGasBomb:Show()
		timerChokingGasBombCD:Start()
		if self.Options.SoundWarnFlasks then -- Chocking Gas Bomb 10 sec. to voice warning
			self:ScheduleMethod(25, "Flasks10Sec")
		end
	elseif args:IsSpellID(72855, 72856, 72854, 70911) then 	-- Unbound Plague
		warnUnboundPlagueSoon:Schedule(80)
		timerUnboundPlagueCD:Start()
	end
end

function mod:SPELL_SUMMON(args)
	if args:IsSpellID(70342) then -- Slime Puddle
		warnSlimePuddle:Show()
		timerSlimePuddle:Start()
	end
end

function mod:SPELL_DAMAGE(args)
	if args:IsPlayer() and args:IsSpellID(72869, 70346, 72868, 72456) then		-- Slime Puddle spec warning damage
		specWarnSlimePuddle:Show()
	end
end

function mod:SPELL_AURA_APPLIED(args)
	if args:IsSpellID(70447, 72836, 72837, 72838) then 		-- Green Ooze target
		warnVolatileOozeAdhesive:Show(args.destName)
		specWarnVolatileOozeOther:Show(args.destName)
		if args:IsPlayer() then
			specWarnVolatileOozeAdhesive:Show()
		end
		if self.Options.OozeAdhesiveIcon then
			self:SetIcon(args.destName, 8, 8)
		end
	elseif args:IsSpellID(70672, 72455, 72832, 72833) then	-- Orange Ooze target
		warnGaseousBloat:Show(args.destName)
		specWarnGaseousBloatOther:Show(args.destName)
		timerGaseousBloat:Start(args.destName)
		if args:IsPlayer() then
			specWarnGaseousBloat:Show()
			soundGaseousBloat:Play()
		end
		if self.Options.GaseousBloatIcon then
			self:SetIcon(args.destName, 7, 20)
		end
	elseif args:IsSpellID(72451, 72463, 72671, 72672) then		-- Mutated Plague
		warnMutatedPlague:Show(args.spellName, args.destName, args.amount or 1)
		timerMutatedPlagueCD:Start()
	elseif args:IsSpellID(70542) then 							-- Mutated Slash
		timerMutatedSlash:Show(args.destName)
	elseif args:IsSpellID(70539, 72457, 72875, 72876) then 		-- Regurgitated Ooze
		timerRegurgitatedOoze:Show(args.destName)
	elseif args:IsSpellID(70352, 74118) then					-- Ooze Variable (attack green)
		if args:IsPlayer() then
			specWarnOozeVariable:Show()
		end
	elseif args:IsSpellID(70353, 74119) then					-- Gas Variable (attack orange)
		if args:IsPlayer() then
			specWarnGasVariable:Show()
		end
	elseif args:IsSpellID(72855, 72854, 72856, 70911) then	 	-- Unbound Plague
		
		warnUnboundPlague:Show(args.destName)
		if self.Options.UnboundPlagueIcon then
			self:SetIcon(args.destName, 5, 20)
		end
		if args:IsPlayer() then
			specWarnUnboundPlague:Show()
			timerUnboundPlague:Start()
			if self.Options.YellOnUnbound then
				SendChatMessage(L.YellUnbound, "SAY")
				--self:ScheduleMethod(10, "UnboundPlaguePassOn")					
			end
		end
	end
end

function mod:SPELL_AURA_APPLIED_DOSE(args)
	if args:IsSpellID(72451, 72463, 72671, 72672) then	-- Mutated Plague
		warnMutatedPlague:Show(args.spellName, args.destName, args.amount or 1)
		timerMutatedPlagueCD:Start()
	elseif args:IsSpellID(70542) then
		timerMutatedSlash:Show(args.destName)
	end
end

function mod:SPELL_AURA_REFRESH(args)
	if args:IsSpellID(70539, 72457, 72875, 72876) then
		timerRegurgitatedOoze:Show(args.destName)
	elseif args:IsSpellID(70542) then
		timerMutatedSlash:Show(args.destName)
	end
end

function mod:SPELL_AURA_REMOVED(args)
	if args:IsSpellID(70447, 72836, 72837, 72838) then
		if self.Options.OozeAdhesiveIcon then
			self:SetIcon(args.destName, 0)
		end
	elseif args:IsSpellID(70672, 72455, 72832, 72833) then
		timerGaseousBloat:Cancel(args.destName)
		if self.Options.GaseousBloatIcon then
			self:SetIcon(args.destName, 0)
		end
	elseif args:IsSpellID(72855, 72854, 72856, 70911) then 				-- Unbound Plague
		timerUnboundPlague:Stop(args.destName)
		if self.Options.UnboundPlagueIcon then
			self:SetIcon(args.destName, 0)
		end
	elseif args:IsSpellID(70539, 72457, 72875, 72876) then
		timerRegurgitatedOoze:Cancel(args.destName)
	elseif args:IsSpellID(70542) then
		timerMutatedSlash:Cancel(args.destName)
	end
end

function mod:UNIT_HEALTH(uId)
	if phase == 1 and not warned_preP2 and self:GetUnitCreatureId(uId) == 36678 and UnitHealth(uId) / UnitHealthMax(uId) <= 0.83 then
		warned_preP2 = true
		warnPhase2Soon:Show()
		phase = 2	
	elseif phase == 2 and not warned_preP3 and self:GetUnitCreatureId(uId) == 36678 and UnitHealth(uId) / UnitHealthMax(uId) <= 0.38 then
		warned_preP3 = true
		warnPhase3Soon:Show()
		phase = 3	
	end
end

function mod:CHAT_MSG_RAID_BOSS_EMOTE(msg)
	if msg and msg:find(L.YellMalleableGoo) then -- Malleable Goo timer + warning
		if self.Options.SoundWarnMalleableGoo then
			PlaySoundFile("Interface\\AddOns\\DBM-Core\\sounds\\mirabelki.mp3", "Master")
		end
		if self.Options.SoundPreWarnMalleable then -- Malleable Goo voice pre-warning
			self:ScheduleMethod(15, "Malleable5Sec")
		end
		warnMalleableGoo:Show()
		specWarnMalleableGooCast:Show()		
		timerMalleableGooCD:Start()
	end
end

function mod:CHAT_MSG_MONSTER_YELL(msg)
	if (msg == L.YellPhaseChangeHC or msg:find(L.YellPhaseChangeHC)) then -- PhaseChange heroic version; 24s delay on timers + 25s heroic delay
		warnVolatileExperiment:Show()
		if phase == 2 then
			timerUnstableExperimentCD:AddTime(49)
		else
			timerUnstableExperimentCD:Cancel()
		end
		if self.Options.SoundPreWarnMalleable then -- Malleable Goo voice pre-warning
			self:Unschedule(Malleable5Sec)
		end
		if self.Options.SoundWarnFlasks then
			self:Unschedule(Flasks10Sec)
		end
		timerUnboundPlagueCD:AddTime(49)
		timerSlimePuddle:AddTime(49)
		if phase == 2 then
			timerChokingGasBombCD:Start(60)
			timerMalleableGooCD:Start(50)
		elseif phase == 3 then
			timerChokingGasBombCD:AddTime(49)
			timerMalleableGooCD:AddTime(49)
		end
		warnUnboundPlagueSoon:Cancel()
	end
end