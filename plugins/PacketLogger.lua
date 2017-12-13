--
-- L2Tower Packet Logger Plugin (v2)
--
-- packets configurations borrowed from L2PacketHack
-- @Created by RAID
--
local isEnabled = false; -- Default is disabled

local logFile = GetDir() .. 'temp\\packets.log'; -- Location of the log file
local packetsConfig = GetDir() .. 'plugins\\PacketLogger\\PacketsHighFive.ini'; -- Packet configuration

-- Constants
local PLUGIN_NAME = 'PacketLogger';
local SOURCE_SERVER = 'server';
local SOURCE_CLIENT = 'client';

-- Error messages
local ERROR_LOADING_CONFIG = 'Cannot load packets configuration file: %s';
local ERROR_INVALID_CONFIG = 'Packets configuration is invalid!';
local ERROR_INVALID_LOGFILE = 'Error opening logfile %s';

PacketLogger = {
    packetsFormat = {},
    appenders = {}
};

-- Plugin hook: Create
function OnCreate() PacketLogger:init(); this:RegisterCommand("plog", CommandChatType.CHAT_ALLY, CommandAccessLevel.ACCESS_ME); end;

function OnDestroy() PacketLogger:Destroy(); this:UnregisterCommand("plog"); end;

function OnCommand_plog(vCommandChatType, vNick, vCommandParam)
    isEnabled = not isEnabled;
    ShowToClient(PLUGIN_NAME, (not isEnabled) and "OFF" or "ON");
end;

--
-- Plugin hook: Outgoing packets (client source)
--
function OnOutgoingPacket(packet) if isEnabled then PacketLogger:PacketHandler(SOURCE_CLIENT, packet); end  end;

--
-- Plugin hook: Incoming packets (server source)
--
function OnIncomingPacket(packet) if isEnabled then PacketLogger:PacketHandler(SOURCE_SERVER, packet); end  end;

--
-- Initialize packet logger
--
function PacketLogger:init()

    -- Reload packet structure configuration
    self:ReloadConfig(packetsConfig);

    if (nil == self.packetsFormat.client or nil == self.packetsFormat.server) then
        ShowToClient(PLUGIN_NAME, ERROR_INVALID_CONFIG);
        return;
    end;

    -- Set default appenders
    self:AddAppender({PacketLogger.FileAppender, PacketLogger.SplitFileAppender, PacketLogger.ScreenAppender});

    -- Outgoing packets unblock
    for id in pairs(self.packetsFormat.client) do UnblockOutgoingPacket(tonumber(string.sub(id, 0, 2), 16)); end;

    -- Incoming packets unblock
    for k in pairs(self.packetsFormat.server) do
        local id, exId = tonumber(string.sub(k, 0, 2), 16), 0xFF;
        PacketUnBlock(id, exId, 1);
        Event_PacketUnBlock(id, exId, 1);
    end;
end

--
-- Destructor
--
function PacketLogger:Destroy()
    self.packetsFormat = nil;
end;

--
-- Add log appender
--
-- @param appender void function(source, data)
-- @return self
--
function PacketLogger:AddAppender(appender)
    if (type(appender) == "function") then
        table.insert(self.appenders, appender);
    elseif (type(appender) == "table") then
        for _,v in ipairs(appender) do self:AddAppender(v) end
    end
    return self;
end

--
-- Console appender - prints log data to console.
--
-- @param channel The main source of the log-data (server, client)
-- @param data Log data
--
function PacketLogger:ConsoleAppender(source, data)
    if (type(data) == "table") then ShowToClient(PLUGIN_NAME, data.hexdata); end
end;

--
-- On-screen appender - prints log data to screen. Requires L2Tower Premium license
--
-- @param channel The main source of the log-data (server, client)
-- @param data Log data
--
function PacketLogger:ScreenAppender(source, data)
    assert(IsPremium(), "ScreenAppender requires L2Tower Premium license.");
    ShowOnScreen(1, 500, 1, string.format("%s (%s bytes) [%s,%s]:\n%s\n\n",
        data.sender,
        tostring(data.size),
        data.id,
        (data.info == nil) and "Unknown" or data.info,
        data.hexdata:gsub('('.. ('...'):rep(16) .. ')', "%1\n")
    ));
end;

--
-- File appender - append log data into a log file
--
-- @todo Keep the open file handler out of this function and use setvbuf(no) + flush. Close fh when turn off the plugin
-- @param channel The main source of the log-data (server, client)
-- @param data Log data
--
function PacketLogger:FileAppender(source, data)

    local fh = assert(io.open(logFile, "a"), string.format(ERROR_INVALID_LOGFILE, logFile));
    --fh:setvbuf("no");

    if (nil ~= fh) then

        fh:write(string.format("[%s] %s (%s bytes) [%s,%s]:\n%s\n\n",
            os.date("%d %b %H:%M:%S"),
            data.sender,
            tostring(data.size),
            data.id,
            (data.info == nil) and "Unknown" or data.info,
            data.hexdata
        ));

        --fh:flush();
        fh:close();
    end
end;

--
-- Split file appender - append log data into different log files
--
-- @todo Keep the open file handler out of this function and use setvbuf(no) + flush. Close fh when turn off the plugin
-- @param channel The main source of the log-data (server, client)
-- @param data Log data
--
function PacketLogger:SplitFileAppender(source, data)

    if (data.info ~= nil) then
        local packetName;
        assert(data.info:gsub("(%a+)%:.*"  , function(type, key)
            packetName = type;
        end), "Error parsing packet description");

        local tempLogFile = GetDir() .. 'temp\\packets-' .. source .. '-' .. packetName .. '.log'

        local fh = assert(io.open(tempLogFile, "a"), string.format(ERROR_INVALID_LOGFILE, tempLogFile));

        if (nil ~= fh) then

            fh:write(string.format("[%s] %s (%s bytes) [%s,%s]:\n%s\n\n",
                os.date("%d %b %H:%M:%S"),
                data.sender,
                tostring(data.size),
                data.id,
                (data.info == nil) and "Unknown" or data.info,
                data.hexdata
            ));

            fh:close();
        end
    end;
end;

--
-- Dispatch log data
--
-- @param channel The main source of the log-data (server, client)
-- @param ... Log data params
--
function PacketLogger:Log(channel, ...)
    for _,v in ipairs(self.appenders) do
        local co = coroutine.create(v);
        coroutine.resume(co, self, channel, ...);
    end
end

--
-- Single packet handler
--
-- @param source The main source of the log-data (server, client)
-- @param packet PacketReader
--
function PacketLogger:PacketHandler(source, packet)

    if nil ~= packet then

        packet:SetOffset(0);

        -- Read raw hex data
        local data, size = "", packet:Size();
        if (size > 0) then
            local i = 0;
            repeat
                packet:SetOffset(i);
                data = data .. string.format("%02X ", packet:ReadUInt(1));
                i = i + 1;
            until i >= size;
        end;


        -- Finding packet description
        local id = string.format("%02X",packet:GetID());
        local dpval = self.packetsFormat[source][id];
        if (nil == dpval and packet:GetSubID() > 0 and packet:GetSubID() < 0xFFFF) then
            id = id .. string.format("%02X",packet:GetSubID());
            dpval = self.packetsFormat[source][id];
        end;

        if (nil == dpval) then
            -- try to get the subID (1, 2 or 3 bytes)
            local offset = (SOURCE_CLIENT == source ) and 1 or 0; -- client packet includes ID as a first byte
            repeat
                packet:SetOffset(offset);
                id = id .. string.format("%02X", packet:ReadUInt(1));
                dpval = self.packetsFormat[source][id];
                offset = offset + 1;
            until offset >= 3 or nil ~= dpval;
        end

        self:Log(source, {sender = source, size = size, id = id, info = dpval, hexdata = data });
    end

end;

--
-- Read configuration file (.ini format)
-- ~Not in use
--
-- @param packet Received packet
-- @param info String. Structure information about the packet
--
function PacketLogger:ParsePacketInfo(packet, info)
    local struct = {};
    if (nil ~= info) then
        local fields = {}
        assert(info:gsub("(%a)%((.-)%)"  , function(type, key)
            table.insert(fields, {
                key = key,
                type = type
            })
        end), "Error parsing packet description");

        for _,v in pairs(fields) do
            ShowToClient(PLUGIN_NAME, v.key .. "  " .. v.type)
        end
    end

    return struct;
end

--
-- Read configuration file (.ini format)
--
-- @param configPath Configuration (.ini) file path
--
function PacketLogger:ReloadConfig(configPath)
    local file = assert(io.open(configPath, 'r'), string.format(ERROR_LOADING_CONFIG, configPath));
    local data = {};
    local section;
    for line in file:lines() do
        local tempSection = line:match('^%[([^%[%]]+)%]$');
        if (tempSection) then
            section = tonumber(tempSection) and tonumber(tempSection) or tempSection;
            data[section] = data[section] or {};
        end
        local param, value = line:match('^([%w|_]+)%s-=%s-(.+)$');
        if (param and value ~= nil) then
            data[section][tostring(param)] = tostring(value);
        end
    end
    file:close();
    self.packetsFormat = data;
end


