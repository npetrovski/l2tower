-- Just another script to give Iss Buff.
-- uses the same algorithm as in IssBuff script

-- additional feature:
-- - iss can be automatically invited by another bot just before buff
-- For example: if you are hunting in party with two small level chars and you have iss.
-- You want him to be invited by someone from low level party

BSIssBuff = {
	oopMode = false;
	inviteMode = false;
	inviteName = "";
	requestParty = true;
	requestPartyName = "";

	cfgPartyBuffBySchedule = true;
	cfgCheckPartyBuff = true;
}

function BSIssBuff:init()
	BotCommandFactory:registerCommand("BSIssBuff.issBuffStart", self, self.cmdStart)
	BotCommandFactory:registerCommand("BSIssBuff.issBuffStop", self, self.cmdStop)
	BotCommandFactory:registerCommand("BSIssBuff.issBuffPause", self, self.cmdPause)
	BotCommandFactory:registerCommand("BSIssBuff.issBuffCfg", self, self.cmdSetCfg)
end

function BSIssBuff:cmdStart()
	if self.thread then
		return eprint("BSIssBuff: is already working")
	end
	dprint("IssBuff started")
	self.thread = CreateThread(self, self.threadProc)
end

function BSIssBuff:cmdStop()
	dprint("IssBuff stopped")
	StopThread(self.thread)
	self.thread = nil;
	BuffRenewLastUsage = {};
	for _,buffCfg in pairs(BuffsConfig) do
		buffCfg.lastUsed = 0;
	end
	UnlockPause();
end

function BSIssBuff:cmdPause()
	dprint("IssBuff paused")
	StopThread(self.thread)
	self.thread = nil;
	UnlockPause();
end

function BSIssBuff:cmdSetCfg(jsonCfg)	
	local cfg = json.decode(jsonCfg);
	self.oopMode = cfg.oopMode or false;
	self.inviteMode = cfg.inviteMode or false;
	self.inviteName = cfg.inviteName or "";
	self.requestParty = cfg.requestParty or false;
	self.requestPartyName = cfg.requestPartyName or "";
end

function BSIssBuff:threadProc()
	self:rescheduleBuffs();

	local timeDiv = 15;

	while EventsBus:waitOn("OnLTick1s") do
		timeDiv = timeDiv + 1;

		if timeDiv > 14 then
			timeDiv = 0;
			if self.cfgPartyBuffBySchedule 
			and self:issBuff() 
			and (self.oopMode or self.inviteMode or self.requestParty)
			then
				LeaveParty();
			end

			if self.cfgCheckPartyBuff and IsInParty() then
	    		self:checkPartyBuff();
	    	end
	    end
	end
end


-- in case party members already have some buff we are trying to init buff schedule according to them
function BSIssBuff:rescheduleBuffs()
	if not self.cfgPartyBuffBySchedule then
		return; end
	
	-- searching for minimal buff endTime in each category of buffs on all party members
	for _, buffCfg in pairs(BuffsConfig) do
		local minBuffEndTime = 4000000000; --4kkk lua doesn't have int.Max
		if buffCfg.isPersonal then
			for user in PartyWithMe() do
				local activeHarmonyEndTime = 0;
				for _,skillId in pairs(buffCfg.skillList) do
					activeHarmonyEndTime = math.max(activeHarmonyEndTime, safeIndex(user:GetBuff(skillId), "endTime") or 0);
				end
				minBuffEndTime = math.min(minBuffEndTime, activeHarmonyEndTime);
			end
		else
			for _,skillId in pairs(buffCfg.skillList) do
				for user in PartyWithMe() do
					minBuffEndTime = math.min(minBuffEndTime, safeIndex(user:GetBuff(skillId), "endTime") or 0);
				end
			end
		end
		if minBuffEndTime > 0 then
			buffCfg.lastUsed = minBuffEndTime - buffCfg.useInterval*1000
			printf("%s valid for ~%s min", buffCfg.name, math.floor((minBuffEndTime - GetTime()) / 1000 / 60))
		end
	end
end

function BSIssBuff:defineBuffBySummon(playerName)
	local playerPat = nil;
	local pets = GetPetList();
	for Apet in pets.list do
		if Apet:GetNickName() == playerName then
			playerPat = Apet;
			break;
		end
	end
	if playerPat ~= nil then
		if not PatsMasterBuff[playerPat:GetNpcId()] then
			eprint("Sum has unknown pet: " .. tostring(playerPat:GetNpcId()));
			return nil;
		end
		return PatsMasterBuff[playerPat:GetNpcId()];
	else
		eprint("No pets for " .. tostring(playerName));
	end
end

function BSIssBuff:getHarmonyForUser(user)
	local userClass = user:GetClass();
	local skillName = userClass == 145 and (self:defineBuffBySummon(user:GetName()) or "Wizard") or ClassesType[user:GetClass()];
	return BaffPersonal[skillName];
end

function BSIssBuff:buffPersonalByUser(user)
	local skillId = self:getHarmonyForUser(user);
	
	if ValidateSkillUse(skillId, true, 6, 500) then
		SelectTargetByOId2(user:GetId())
		CastSkillRaw(skillId, 4, 250)
		return true;
	end
end

function BSIssBuff:processPersonalBuffs()
	local target = GetTarget()
	local targetId = target and target:GetId() or 0;

	for user in PartyWithMe() do
		if not user:IsAlikeDeath() and user:GetDistance() < 1000 then
			if not self:buffPersonalByUser(user) then
				printf("Fail to buff user "..user:GetName())
			end
		else
			printf("Fail to buff user %s (dead %s, dist %s)", user:GetName(), user:IsAlikeDeath(), user:GetDistance());
		end
	end

	-- once buffs are finished target last target
	SelectTargetByOId2(targetId)

	return true;
end

function BSIssBuff:issBuff()
	-- define what to buff
	local buffsToProcess = {}; 
	for _, buffCfg in pairs(BuffsConfig) do
		local timeSinceUse = (GetTime() - buffCfg.lastUsed) / 1000;
		if -- use when there are no mobs around (assume: no battle)
			((timeSinceUse > (buffCfg.useInterval - buffCfg.saveInterval)) and (MobsCount(150) == 0))
		or  -- or use just before buffs disappear *personal buffs are excluded in this case in order to prevent mobs agro
			((timeSinceUse > buffCfg.useInterval - 10) and (not buffCfg.isPersonal))
		then
			table.insert(buffsToProcess, buffCfg);
		end
	end
	
	local wasProcessed = false;
	if #buffsToProcess > 0 then
		local buffProcessTime = GetTime();
		if self.inviteMode and not IsInParty() then
			Command("/invite "..self.inviteName)
			EventsBus:waitOn("OnLTick500ms", function () return IsInParty() end, 11000);
			if not IsInParty() then eprint("Fail to get party") return; end
		elseif self.requestParty and not IsInParty() then
			BotNetworkDispatcher:sendMessage({m="RequestPartyFrom",d={target=self.requestPartyName}})
			ThreadSleepMs(500)
			EventsBus:waitOn("OnLTick500ms", function () return IsInParty() or AcceptPartyInvite(true) end, 11000);
			if not IsInParty() then eprint("Fail to get party") return; end
		end

		LockPause();
		for _,buffCfg in pairs(buffsToProcess) do
			if buffCfg.isPersonal
			and self:processPersonalBuffs()
			or CastAllByList(buffCfg.skillList, 4, 500)
			then
				buffCfg.lastUsed = buffProcessTime;
				wasProcessed = true;
			else
				printf("Fail to buff %s", buffCfg.name)
			end
		end
		UnlockPause();
	end
	
	return wasProcessed
end

function IsInParty()
	return (GetPartyMaster() ~= nil);
end


-- we should not stuck on rebuffing some skill continuesly. So we save last use time per skill
BuffRenewLastUsage = {
	--[skillId] = lastUse
}

function BSIssBuff:ensureUserHasBuff(user, skillId, minTimeout, byUser)
	if user:IsAlikeDeath() or user:GetDistance() > 1000 then
		return; end

	local buff = user:GetBuff(skillId);
	local buffTimeElapsed = (not buff or buff.endTime - minTimeout*1000 < GetTime());
	if buffTimeElapsed
		and (not byUser 
			and (not BuffRenewLastUsage[skillId] or BuffRenewLastUsage[skillId] + 15*1000 < GetTime())
			or ( byUser and (not BuffRenewLastUsage[user:GetId()] or BuffRenewLastUsage[user:GetId()] + 15*1000 < GetTime())))
	then
		BuffRenewLastUsage[byUser and user:GetId() or skillId] = GetTime();

		-- in case of personal buffs we need to retarget last target after cast
		local targetId;
		if byUser then
			local target = GetTarget()
			targetId = target and target:GetId() or 0;
			SelectTargetByOId2(user:GetId())
		end

		CastSkill(skillId, 4, 500, true)

		if byUser then
			SelectTargetByOId2(targetId);
		end
	end
end

function BSIssBuff:checkPartyBuff()
	for _, buffCfg in pairs(BuffsConfig) do
		if buffCfg.isPersonal then
			for user in PartyWithMe() do
				local userHarmony;
				for _,skillId in pairs(buffCfg.skillList) do
					if user:GotBuff(skillId) then
						userHarmony = skillId;
					end
				end
				self:ensureUserHasBuff(user, userHarmony or self:getHarmonyForUser(user), buffCfg.minTimeout, true);
			end
		else
			for _,skillId in pairs(buffCfg.skillList) do
				for user in PartyWithMe() do
					self:ensureUserHasBuff(user, skillId, buffCfg.minTimeout);
				end
			end
		end
	end
end

--dofile(package.path .. "..\\..\\scripts\\lib\\RuntimeLogs.lua");
--RuntimeLogs:interceptByName("BSIssBuff")

--------------------------------------
--------- Buff constants -------------

BaffPersonal = {
	Knight = 11523, -- Гармония Стража
	Warrior = 11524, -- Гармония Берсерка
	Wizard = 11525, -- Гармония Мага
};

Baff20min = {
	11522, -- Поэма Лютни
	11520, -- Поэма Гитары
	11518, -- Поэма Барабана
	11517, -- Поэма Рога
	11521, -- Поэма Арфы
	11519, -- Поэма Органа
	11567, -- Сопротивление Психическим Атакам
	11565, -- Сопротивление Стихиям
	11566, -- Сопротивление Божественному
};
Baff5min = {
	11530, -- Соната Движения
	11529, -- Соната Битвы
	11532, -- Соната Расслабления
};

BuffsConfig = {
	{	-- personal buffs are processed by separate function
		name = "harmony",
		lastUsed = 0,
		useInterval = 30 * 60,
		saveInterval = 2 * 60,
		minTimeout = 1 * 60,
		isPersonal = true,
		skillList = BaffPersonal;
	},
	{
		name = "poems",
		lastUsed = 0,
		useInterval = 30 * 60,
		saveInterval = 2 * 60,
		minTimeout = 1 * 60,
		skillList = Baff20min;
	},
	{
		name = "sonates",
		lastUsed = 0,
		useInterval = 5 * 60, -- in min
		saveInterval = 1 * 60,
		minTimeout = 1 * 60,
		skillList = Baff5min;
	},
};


ClassesType = {
	[17] = "Wizard",	-- Prophet
	[21] = "Warrior",	-- Swordsinger
	[34] = "Warrior",	-- Bladedancer
	[49] = "Wizard",	-- Orc Mystic
	[50] = "Wizard",	-- Orc Shaman
	[51] = "Wizard",	-- Overlord
	[52] = "Wizard",	-- Warcryer
	[98] = "Wizard",	-- Hierophant
	[100] = "Warrior",	-- Sword Muse
	[107] = "Warrior",	-- Spectral Dancer
	[115] = "Wizard",	-- Dominator
	[116] = "Wizard",	-- Doomcryer
	[144] = "Wizard",	-- Iss Enchanter
	[15] = "Wizard",	-- Cleric
	[16] = "Wizard",	-- Bishop
	[29] = "Wizard",	-- Elven Oracle
	[30] = "Wizard",	-- Elven Elder
	[97] = "Wizard",	-- Cardinal
	[42] = "Wizard",	-- Shillien Oracle
	[43] = "Wizard",	-- Shillien Elder
	[105] = "Wizard",	-- Eva's Saint
	[112] = "Wizard",	-- Shillien Saint
	[146] = "Wizard",	-- Aeore Healer
	[10] = "Wizard",	-- Human Mystic
	[11] = "Wizard",	-- Human Wizard
	[12] = "Wizard",	-- Sorceror
	[13] = "Wizard",	-- Necromancer
	[25] = "Wizard",	-- Elven Mystic
	[26] = "Wizard",	-- Elven Wizard
	[27] = "Wizard",	-- Spellsinger
	[38] = "Wizard",	-- Dark Mystic
	[39] = "Wizard",	-- Dark Wizard
	[40] = "Wizard",	-- Spellhowler
	[94] = "Wizard",	-- Archmage
	[95] = "Wizard",	-- Soultaker
	[103] = "Wizard",	-- Mystic Muse
	[110] = "Wizard",	-- Storm Screamer
	[143] = "Wizard",	-- Feoh Wizard
	[14] = "Warrior",	-- Warlock
	[28] = "Warrior",	-- Elemental Summoner
	[41] = "Warrior",	-- Phantom Summoner
	[96] = "Warrior",	-- Arcana Lord
	[104] = "Warrior",	-- Elemental Master
	[111] = "Warrior",	-- Spectral Master
	-- We try to determine Wynn Summoner's Harmony dynamically
	-- if there is no 'nil' then it will not dynamically assign
	-- and use whatever stands here instead, so you can force
	-- different buff or put it manually if dynamical doesn't work
	-- { [145], nil},	-- Wynn Summoner
	-- [145] = "Wizard",	-- Wynn Summoner
	-- [145] = "Warrior",	-- Wynn Summoner
	[0] = "Warrior",	-- Human Fighter
	[1] = "Warrior",	-- Warrior
	[2] = "Warrior",	-- Gladiator
	[3] = "Warrior",	-- Warlord
	[18] = "Warrior",	-- Elven Fighter
	[19] = "Warrior",	-- Elven Knight
	[31] = "Warrior",	-- Dark Fighter
	[44] = "Warrior",	-- Orc Fighter
	[45] = "Warrior",	-- Orc Raider
	[46] = "Warrior",	-- Destroyer
	[47] = "Warrior",	-- Monk
	[48] = "Warrior",	-- Tyrant
	[53] = "Warrior",	-- Dwarven Fighter
	[56] = "Warrior",	-- Artisan
	[57] = "Warrior",	-- Warsmith
	[88] = "Warrior",	-- Duelist
	[89] = "Warrior",	-- Dreadnought
	[113] = "Warrior",	-- Titan
	[114] = "Warrior",	-- Grand Khavatari
	[118] = "Warrior",	-- Maestro
	[123] = "Warrior",	-- Male Soldier
	[124] = "Warrior",	-- Female Soldier
	[125] = "Warrior",	-- Dragoon
	[126] = "Warrior",	-- Warder
	[127] = "Warrior",	-- Berserker
	[128] = "Warrior",	-- Male Soul Breaker
	[129] = "Warrior",	-- Female Soul Breaker
	[131] = "Warrior",	-- Doombringer
	[132] = "Warrior",	-- Male Soul Hound
	[133] = "Warrior",	-- Female Soul Hound
	[135] = "Warrior",	-- Inspector
	[136] = "Warrior",	-- Judicator
	[140] = "Warrior",	-- Tyrr Warrior
	[7] = "Warrior",	-- Rogue
	[8] = "Warrior",	-- Treasure Hunter
	[22] = "Warrior",	-- Elven Scout
	[23] = "Warrior",	-- Plainswalker
	[35] = "Warrior",	-- Assassin
	[36] = "Warrior",	-- Abyss Walker
	[54] = "Warrior",	-- Scavenger
	[55] = "Warrior",	-- Bounty Hunter
	[93] = "Warrior",	-- Adventurer
	[101] = "Warrior",	-- Wind Rider
	[108] = "Warrior",	-- Ghost Hunter
	[117] = "Warrior",	-- Fortune Seeker
	[141] = "Warrior",	-- Othell Rogue
	[9] = "Warrior",	-- Hawkeye
	[24] = "Warrior",	-- Silver Ranger
	[37] = "Warrior",	-- Phantom Ranger
	[92] = "Warrior",	-- Sagittarius
	[102] = "Warrior",	-- Moonlight Sentinel
	[109] = "Warrior",	-- Ghost Sentinel
	[130] = "Warrior",	-- Arbalester
	[134] = "Warrior",	-- Trickster
	[142] = "Warrior",	-- Yul Archer
	[4] = "Warrior",	-- Human Knight
	[5] = "Knight",	-- Paladin
	[6] = "Knight",	-- Dark Avenger
	[20] = "Knight",	-- Temple Knight
	[32] = "Warrior",	-- Palus Knight
	[33] = "Knight",	-- Shillien Knight
	[90] = "Knight",	-- Phoenix Knight
	[91] = "Knight",	-- Hell Knight
	[99] = "Knight",	-- Eva's Templar
	[106] = "Knight",	-- Shillien Templar
	[139] = "Knight",	-- Sigel Knight
}

PatsMasterBuff = {
	[14930] = "Warrior", -- Saber Tooth Cougar
	[14954] = "Warrior", -- Saber Tooth Cougar
	[14955] = "Warrior", -- Saber Tooth Cougar
	[14956] = "Warrior", -- Saber Tooth Cougar
	[14957] = "Warrior", -- Saber Tooth Cougar
	[14958] = "Warrior", -- Saber Tooth Cougar
	[14959] = "Warrior", -- Saber Tooth Cougar
	[14960] = "Warrior", -- Saber Tooth Cougar
	[14972] = "Warrior", -- Saber Tooth Cougar
	
	[14931] = "Wizard", -- Summon Soul Reaper
	[14961] = "Wizard", -- Summon Soul Reaper
	[14962] = "Wizard", -- Summon Soul Reaper
	[14963] = "Wizard", -- Summon Soul Reaper
	[14964] = "Wizard", -- Summon Soul Reaper
	[14965] = "Wizard", -- Summon Soul Reaper
	[14966] = "Wizard", -- Summon Soul Reaper
	[14967] = "Wizard", -- Summon Soul Reaper
	[14973] = "Wizard", -- Summon Soul Reaper
}