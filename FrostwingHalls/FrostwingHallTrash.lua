-- check ids... 10hc ok, 10n ok, 
local mod	= DBM:NewMod("FrostwingHallTrash", "DBM-Icecrown", 4)
local L		= mod:GetLocalizedStrings()

mod:SetRevision(("$Revision: 4408 $"):sub(12, -3))

mod:RegisterEvents(
	"SPELL_AURA_APPLIED",
	"SPELL_AURA_REMOVED",
	"SPELL_DAMAGE",
	"CHAT_MSG_MONSTER_YELL",
	"SPELL_CAST_START",
	"SPELL_PERIODIC_DAMAGE",
	"SPELL_CAST_SUCCESS"
)

local warnConflag		= mod:NewTargetAnnounce(71785, 4)
local warnBanish		= mod:NewTargetAnnounce(71298, 3)

local specWarnGosaEvent	= mod:NewSpecialWarning("SpecWarnGosaEvent")
local specWarnBlade		= mod:NewSpecialWarningMove(70305)

local timerConflag		= mod:NewTargetTimer(10, 71785)
local timerBanish		= mod:NewTargetTimer(6, 71298)

-- Rimefang
local specWarnFrostPuddle	= mod:NewSpecialWarningMove(71380)		
local timerFrostBreathCD	= mod:NewCDTimer(20, 71386) -- 12-15s / 20-25s 
local timerIcyBlastCD		= mod:NewCDTimer(60, 69628) -- 30-35s / 60-70s
-- Spinestalker
local timerBellowingRoarCD  = mod:NewCDTimer(25, 36922) -- 20-25s / 25-30s
local timerCleaveCD			= mod:NewCDTimer(10, 40505) -- 10-15s / 10-15s
local timerTailSweepCD		= mod:NewCDTimer(22, 71369) -- 8-12s / 22-25s


mod:RemoveOption("HealthFrame")

function mod:SPELL_AURA_APPLIED(args)
	if args:IsSpellID(71785) then
		warnConflag:Show(args.destName)
		timerConflag:Start(args.destName)
	elseif args:IsSpellID(71298) then
		warnBanish:Show(args.destName)
		timerBanish:Start(args.destName)
	end
end

function mod:SPELL_PERIODIC_DAMAGE(args)
	if args:IsSpellID(71380) then
		specWarnFrostPuddle:Show()
	end
end

function mod:SPELL_CAST_START(args)
	if args:IsSpellID(71386) then
		timerFrostBreathCD:Start()
	elseif args:IsSpellID(36922) then
		timerBellowingRoarCD:Start()
	end
end

function mod:SPELL_CAST_SUCCESS(args)
	if args:IsSpellID(71369) then
		timerTailSweepCD:Start()
	elseif args:IsSpellID(40505) then
		timerCleaveCD:Start()
	end
end

function mod:SPELL_AURA_REMOVED(args)
	if args:IsSpellID(71785) then
		timerConflag:Cancel(args.destName)
	elseif args:IsSpellID(71298) then
		timerBanish:Cancel(args.destName)
	end
end

do 
	local lastBlade = 0
	function mod:SPELL_DAMAGE(args)
		if args:IsSpellID(70305) and args:IsPlayer() and time() - lastBlade > 2 then
			specWarnBlade:Show()
			lastBlade = time()
		end
	end
end

function mod:CHAT_MSG_MONSTER_YELL(msg)
	if msg == L.SindragosaEvent and mod:LatencyCheck() then
		self:SendSync("GauntletStart")
	end
end

function mod:OnSync(msg, arg)
	if msg == "GauntletStart" then
		specWarnGosaEvent:Show()
	end
end