-- under development
-- main goal: there should be one single brain that says who should pickup what.
-- particularly this brain should balance players mp picking up recharge herb

BSPickup = {
    dumpData = false;
    logCallbacks = nil;
    logFilePath = nil;
    logFile = nil;
}

function BSPickup:reset()
    if self.logFile then
        io.close(self.logFile)
    end
    if self.dumpData then
        self.dumpData = false;
        self:stopLogDrop();
    end

    self.logFilePath = nil;
    self.logFile = nil;
end

function BSPickup:init()
    BotCommandFactory:registerCommand("BSPickup.setPickupSettings", self, self.cmdSetPickupSettings)
end

function BSPickup:cmdSetPickupSettings(jsonCfg)
    local cfg = json.decode(jsonCfg);
    local dump = cfg.dump;

    if dump and not self.dumpData then
        self.dumpData = true;
        self:startLogDrop()
    elseif not dump and self.dumpData then
        self.dumpData = false;
        self:stopLogDrop()
    end
end

do -- Logging drop

    function BSPickup:startLogDrop(...)
        self.logFilePath = ...;

        self.logFilePath =  GetDir() .. "temp\\drop.log";

        self.logCallbacks = {};
        self.logCallbacks["OnDropItem"] = EventsBus:addCallback("OnDropItem", function(user, item) self:logDrop("OnDropItem", item, user); end)
        self.logCallbacks["OnPickupItem"] = EventsBus:addCallback("OnPickupItem", function(user, item) self:logDrop("OnPickupItem", item, user); end)
        self.logCallbacks["OnSpawnItem"] = EventsBus:addCallback("OnSpawnItem", function(item) self:logDrop("OnSpawnItem", item); end)
        self.logCallbacks["OnDeleteItem"] = EventsBus:addCallback("OnDeleteItem", function(item) self:logDrop("OnDeleteItem", item); end)
    end

    function BSPickup:stopLogDrop()
        for eventName, handler in pairs(self.logCallbacks) do
            EventsBus:removeCallback(eventName, handler);
        end
    end

    function BSPickup:getLogFile()
        if not self.logFile then
            self.logFile = io.open(self.logFilePath, "a+");
        end
        return self.logFile;
    end

    function BSPickup:logDrop(method, item, user)
        local msg = string.format("%s  itemId:%s  nameId:%s  name:%s  type:%s  ", method, item:GetId(), item:GetNameId(), item:GetName(), item:GetType())
        if user then
            msg = msg .. "user:" .. user:GetName();
        end

        local file = self:getLogFile();
        file:write(msg .. "\n");
        file:flush();
--        file:close();
    end
end
