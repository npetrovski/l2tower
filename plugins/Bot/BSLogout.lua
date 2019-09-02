-- 101 in battle

BSLogout = {
    delay = 5;
}

function BSLogout:init()
    BotCommandFactory:registerCommand("BSLogout.logout", self, self.cmdLogout)
end

function BSLogout:cmdLogout(dto)
    if nil ~= dto then
        local cfg = json.decode(dto);
        self.delay = cfg.delay or self.delay;
    end;
    CreateThread(self, self.delayLogout)
end

function BSLogout:delayLogout()
    while EventsBus:waitOn("OnLTick1s") do
        if self.delay <= 0 then
            LogOut();
        end
		
		if (self.delay < 10) then
			KillMe(); -- force kill L2
		end
        local msg = string.format("Logout in %s seconds !", tostring(self.delay));
        if IsPremium() then ShowOnScreen(2, 900, 1, msg) else iprint(msg) end;

        self.delay = self.delay - 1;
    end
end