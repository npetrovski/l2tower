-- under development

BSAssist = {
	enabled = false;
}

function BSAssist:init()
	BotCommandFactory:registerCommand("BSAssist.assist", self, self.cmdAssist)
	BotCommandFactory:registerCommand("BSAssist.startAssist", self, self.cmdStartAssist)
	BotCommandFactory:registerCommand("BSAssist.stopAssist", self, self.cmdStopAssist)
	this:RegisterCommand("assist", CommandChatType.CHAT_ALLY, CommandAccessLevel.ACCESS_ME);
end

function OnCommand_assist(vCommandChatType, vNick, vCommandParam)
	local target = GetTarget()
	local targetId = target and target:GetId() or 0;
	
	BotNetworkDispatcher:sendMessage({
		m = "Assist",
		d = {
			target = targetId,
		}
	});
	
end;

function BSAssist:cmdAssist(jsonCfg)
	local cfg = json.decode(jsonCfg);
	SelectTargetByOId(cfg.target);
end


function BSAssist:cmdStartAssist(jsonCfg)
	local cfg = json.decode(jsonCfg);
	self.master = cfg.master;
	
	self.masterId = -1;
	local players = GetPlayerList();
	for player in players.list do
		if (player:GetName() == self.master)  then 
			self.masterId = player:GetId();
		end
	end
	if (self.masterId == -1) then
		eprint("Assist: unable to find master");
		return;
	end

	
	if not self.enabled then
		self:startAssist()
	end
	
	self.enabled = true;
end

function BSAssist:startAssist()
	iprint("Assist " .. self.master .. " started");
	self.assistCallbacks = {}
	self.assistCallbacks["OnTargetSelected"] = 
		EventsBus:addCallback("OnTargetSelected", 
			function(user, target)
				-- dprint("OnTargetSelected")
				if user:GetId() == self.masterId then
					self:masterTargetChanged(user, target)
				end
			end
		);
	self.assistCallbacks["OnTargetUnselected"] = 
		EventsBus:addCallback("OnTargetUnselected", 
			function(user)
				if user:GetId() == self.masterId then
					self:masterTargetCleared(user, target)
				end
			end
		);
end

function BSAssist:cmdStopAssist()
	if not self.enabled then
		return; end

	iprint("Assist " .. self.master .. " stopped");
		
	self.enabled = false;
	for eventName,handler in pairs(self.assistCallbacks) do
		EventsBus:removeCallback(eventName, handler);
	end
end

function BSAssist:masterTargetChanged(master, target)
	local targetId = target:GetId();
	if  targetId ~= GetMe():GetTarget() then
		-- if not master:IsInCombat() then
			SelectTargetByOId(targetId);
		-- end
	end
end

function BSAssist:masterTargetCleared(master)
	SelectTargetByOId(0);
end

