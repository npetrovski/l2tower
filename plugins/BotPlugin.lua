-- Loader of a plugin environment.
-- as far as we want to build a logic over multiple plugins we need to have all of them executed under one Lua environment.
-- so here we initialize all the stuff
SERVER_ADDRESS = "127.0.0.1"
SERVER_PORT = "8888"
SERVER_RECONNECT = true;

--if true then return; end

IsStarted = false;

IsDebugEnabled = true;

const_scripts_path = nil;
dprint = nil
iprint = nil;
eprint = nil;

function InitLA()
	const_scripts_path = package.path .. "..\\..\\plugins\\Bot\\";

	dofile(package.path .. "socket.lua");
	socket = require("socket")

	dofile(package.path .. "json.lua");
	json = require("json")

	iprint = function(...) ShowToClient("INFO", ({...})[1]); end
	dprint = function(...) if IsDebugEnabled then ShowToClient("DEBUG", ({...})[1]); end end
	eprint = function(...) ShowToClient("ERROR", ({...})[1]); end
end

function InitLua()

	IsDebugEnabled = true;

	dofile("L2TowerEnv.lua");
	const_scripts_path = GetDir() .. "\\Bot\\";

	socket = require("socket")

	dofile("json.lua");
	json = require("json")

    iprint = function(...) print("INFO ", ...) end
	dprint = function(...) if IsDebugEnabled then print("DEBUG ", ...) end end
	eprint = function(...) print("ERROR ", ...) end
end

if arg and arg[1] == "lua" then
	InitLua()
else
	InitLA()
end

local modules = {
	"BotEventsHook.lua", 
	"BotNetworkDispatcher.lua", 
	"BotCommandFactory.lua",
	"BotUtil.lua",
}
for _,file in pairs(modules) do xpcall(function() dofile(const_scripts_path .. file); end, dprint) end

EventsBus:init();

--- called for each user login
function Start()
	if IsStarted then
        return; end
	IsStarted = true;
	BotNetworkDispatcher:start();
end

EventsBus:addCallback("OnCreate", function ()
	if IsLogedIn() then Start(); end
end, true)

EventsBus:addCallback("OnLogin", function ()
	Start();
end, true)

EventsBus:addCallback("OnLogout", function ()
	IsStarted = false
end, true)

EventsBus:addCallback("OnDestroy", function ()
	IsStarted = false
end, true)







