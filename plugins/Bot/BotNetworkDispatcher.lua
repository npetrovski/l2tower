-- in order to send something to server call:
-- SendServerMessage((string) serverMethod, (table|string) data)

BotNetworkDispatcher = {
	messagesToSend = {},
	connection = nil,
    isConnected = false
}

function BotNetworkDispatcher:start()
	CreateThread(self, self.networkDispatcherThreadProc, self.dispose)
end

function BotNetworkDispatcher:sendMessage(msg)
	if "table" == type(msg) then
		msg = json.encode(msg)
	elseif "string" == type(msg) then
		-- OK
	else
		return eprint("BotNetworkDispatcher:sendMessage() incorrect message type: " .. type(msg));
	end
	table.insert(self.messagesToSend, msg)
end

function BotNetworkDispatcher:resetMessageQueue()
	self.messagesToSend = {};
	self:sendMessage(self:getLoginMessage());
end

function SendServerMessage(serverMethod, data)
	BotNetworkDispatcher:sendMessage({
		m = serverMethod,
		d = data
	});
end

function BotNetworkDispatcher:networkDispatcherThreadProc()
	if SERVER_RECONNECT then
		local timeDiv = 15;
		while EventsBus:waitOn("OnLTick1s") do
			timeDiv = timeDiv + 1;
			if timeDiv > 14 then
				timeDiv = 0;
				dprint("Reconnect")
				self:handleConnection();
			end
		end
	else
		self:handleConnection();
	end
end


function BotNetworkDispatcher:handleConnection()
	local c = socket.tcp();
	c:settimeout(1/1000);
	if 1 ~= c:connect(SERVER_ADDRESS, tonumber(SERVER_PORT)) then
		return;	end

    self.isConnected = true;
	self:resetMessageQueue();
	self.connection = c;
	while EventsBus:waitOn("OnLTick") do
		local s, status = c:receive("*l")
		if (s) then
			dprint("Process command: " .. s)
			BotCommandFactory:runCommand(s)
		end
		if status == "closed" or status == "Socket is not connected" then 
			dprint("Connection was closed")
            self.isConnected = false;
			break;
		end

		local messagesToSend = BotNetworkDispatcher.messagesToSend;
		if #messagesToSend > 0 then
			for _,message in ipairs(messagesToSend) do
				c:send(message.."\n\r")
			end
			BotNetworkDispatcher.messagesToSend = {};
		end
	end
end

-- called when this thread is going to be removed
function BotNetworkDispatcher:dispose()
	if self.connection then
		self.connection:close();
		self.connection = nil;
        self.isConnected = false;
	end
end

function BotNetworkDispatcher:getLoginMessage()
	return {
		m = "SignIn",
		d = GetInfo()
	}
end

