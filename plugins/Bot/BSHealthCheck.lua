
BSHealthCheck = {
    lastHp = nil,
    lastMp = nil
};

function BSHealthCheck:init()
    CreateThread(self, self.check)
end

function BSHealthCheck:check()
    local me = GetMe();
    while true do
        if BotNetworkDispatcher.isConnected then
            if (me:GetHp() ~= self.lastHp or me:GetMp() ~= self.lastMp) then
                self.lastHp = me:GetHp();
                self.lastMp = me:GetMp();
                SendServerMessage("MethodSetUserInfo", GetInfo());
            end;
        end;
        ThreadSleepS(5);
    end;
end;

