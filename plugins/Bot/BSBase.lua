BSBase = {}

function BSBase:init()
	BotCommandFactory:registerCommand("BSBase.inviteUser", self, self.cmdInviteUser)
	BotCommandFactory:registerCommand("BSBase.acceptInvite", self, self.cmdAcceptInvite)
	BotCommandFactory:registerCommand("BSBase.getUserInfo", self, self.cmdGetUserInfo)
	BotCommandFactory:registerCommand("BSBase.setBotState", self, self.cmdSetBotState)
	BotCommandFactory:registerCommand("BSBase.executeScript", self, self.cmdExecuteScript)
	BotCommandFactory:registerCommand("BSBase.dismissParty", self, self.cmdDismissParty)
end

function BSBase:cmdInviteUser(dto)
	local cfg = json.decode(dto);
	local target = cfg.target or false;

	CreateThread(self, function ()
		Command("/invite "..target)
	end)
end

function BSBase:cmdAcceptInvite(dto)
	CreateThread(self, function ()
		AcceptPartyInvite(true);
	end)
end

function BSBase:cmdGetUserInfo(dto)
	SendServerMessage("MethodSetUserInfo", GetInfo());
end

function BSBase:cmdSetBotState(dto)
	local cfg = json.decode(dto);
	local state = not (cfg.pauseState or false);
	SetPause(state);
	iprint("L2Tower is now " .. (IsPaused() and "PAUSED" or "RESUMED"));
end

function BSBase:cmdExecuteScript(dto)
	local cfg = json.decode(dto);
	local script = cfg.script or false;
	if script then
		if (script:sub(1,1) == "/" or script:sub(1,1) == ".") then
			Command(script);
		elseif (script:sub(1,1) == ":") then
			if not IsPremium() then
                iprint("Premium license is required to run ClientExec.");
				return;
			end;
			iprint(script:sub(2));
			ClientExec(script:sub(2));
		else
			ProcessCommand(".scriptStart " .. script  .. ".lua");
		end;
	end;
end

function BSBase:cmdDismissParty(dto)
	if nil ~= GetPartyMaster() and GetPartyMaster():IsMe() then
		local pl = GetPartyList();
		if pl:GetCount() > 0 then
			for user in pl.list do
				if not user:IsMe() then
					KickPartyMember(user:GetName());
				end;
			end;
		end;
	end;
end