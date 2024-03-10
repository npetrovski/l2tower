--
-- This script is an illustrative example, designed to demonstrate two key concepts. 
-- The first involves utilizing a template engine to construct the UI for an 
-- L2Tower plugin, while the second concept focuses on leveraging the Tutorial 
-- Lineage 2 client UI window.
--
-- @author Nick
--

dofile(package.path .. "template.lua");
local template = require("template");

local USE_TUTORIAL_WIN = true;
local PLUGIN_NAME = 'go';
local TEMPLATES_FOLDER = GetDir() .. 'plugins\\Go'
local CSV_FILE = GetDir() .. 'temp\\Go-Set.csv'
local HtmlBuild = "";
local ShowHtmlStatus = false;

function OnCreate() 
	this:RegisterCommand(PLUGIN_NAME, CommandChatType.CHAT_ALLY, CommandAccessLevel.ACCESS_ME); 
	UnblockOutgoingPacket(0x86);
end;

function OnDestroy() this:UnregisterCommand(PLUGIN_NAME); end;

_G["OnCommand_" .. PLUGIN_NAME] = function(vCommandChatType, vNick, vCommandParam)
	local commands = {};
	if (vCommandParam:GetCount() > 0) then
		for i = 0, vCommandParam:GetCount() - 1 do
			table.insert(commands, vCommandParam:GetParam(i):GetStr(true))
		end;
	end;
	processCommand(commands);
end;

function processCommand(commands)
	local data = loadCoords();
	if #commands > 0 then
		local page = commands[1];

		if (page == "jump") then
			local id = tostring(commands[2]);
			local confirm = tonumber(commands[3]);
			local rec = findCoordsById(data, id);

			if (nil ~= rec) then
				if (1 == confirm) then
					epicPort(rec);
				else
					return ShowJumpDialog(page, rec);
				end;
			end;
		end;

		if (page == "remove") then
			local id = tostring(commands[2]);
			local confirm = tonumber(commands[3]);
			if (1 == confirm) then
				removeElement(data, id);
				data = loadCoords();
			else
				local rec = findCoordsById(data, id);
				if (nil ~= rec) then
					return ShowRemoveDialog(page, rec);
				end;
			end
		end;

		if (page == "add") then
			return ShowAddDialog("add");
		end;

		if (page == "save") then
			local name = tostring(commands[2]);
			addElement(data, name);
		end;
	end;
		
	ShowMainDialog("main", data);
end

function OnLTick()
    if (ShowHtmlStatus) then
        ShowHtmlStatus = false;
		if USE_TUTORIAL_WIN then
			local packet = PacketBuilder();
			packet:AppendString(HtmlBuild);
			SendPacketToGame(0xA6, 0x00, packet);
		else
			ShowHtml(HtmlBuild);
		end;
    end;
end;

function OnOutgoingPacket(packet) 
	if USE_TUTORIAL_WIN then
		local _id = packet:GetID();
		
		-- RequestTutorialPassCmdToServer
		if (_id == 0x86) then
			packet:SetOffset(1);
			local link = packet:ReadString();

			local commands = {};
			for command in link:gmatch('([^%s]+)') do
				commands[#commands + 1] = command:gsub("[\'/]", '');
			end

			if #commands > 0 then
				local plugin = table.remove(commands, 1);
				if plugin == PLUGIN_NAME then processCommand(commands); end;
			end;
		end;
	end;
end;

function ShowJumpDialog(page, rec)
	local ctx = {
		["layout"] = {
			["title"] = "Jump To Location",
			["btn_label"] = "Back",
			["btn_action"] = buildAction()
		},
		["rec"] = rec,
		["jump_action"] = buildAction("jump", rec.id, 1)
	};
	ShowPage(page, ctx);
end;

function ShowRemoveDialog(page, rec)
	local ctx = {
		["layout"] = {
			["title"] = "Remove Location",
			["btn_label"] = "Back",
			["btn_action"] = buildAction()
		},
		["rec"] = rec,
		["remove_action"] = buildAction("remove", rec.id, 1)
	};
	ShowPage(page, ctx);
end;

function ShowAddDialog(page, defaultName)
	local loc = GetMe():GetLocation();
	local ctx = {
		["layout"] = {
			["title"] = "Add Current Location",
			["btn_label"] = "Back",
			["btn_action"] = buildAction()
		},
		["save_action"] = buildAction("save", "$name"),
		["refresh_action"] = buildAction("add"),
		["loc"] = {
			x = math.floor(loc.X),
			y = math.floor(loc.Y),
			z = math.floor(loc.Z),
		}
	};
	ShowPage(page, ctx);
end;

function ShowMainDialog(page, data)
	local ctx = {
		["layout"] = {
			["title"] = "Locations List",
			["btn_label"] = "Add",
			["btn_action"] = buildAction("add")
		},
		["rows"] = {}
	};
	if (#data > 0) then
		for c = 1, #data do
			local id = data[c][1];
			table.insert(ctx["rows"], {
				["name"] = tostring(data[c][2]),
				["action"] = buildAction("jump", id, 0),
				["remove_action"] = buildAction("remove", id, 0)
			});
		end;
	end;
	ShowPage(page, ctx);
end;

function ShowPage(page, context)
	local layoutFile = TEMPLATES_FOLDER .. '\\layout.htm';
	local viewFile = TEMPLATES_FOLDER .. '\\' .. page .. '.view.htm';
	local layout = template.new(layoutFile);
	context.layout.view = template.render(viewFile, context, "no-cache");
	context.layout.show_close = USE_TUTORIAL_WIN;

	local html = THtmlGenerator("Teleport To Location");
	html:AddHtml(layout:render(context.layout));
	HtmlBuild = html:GetString();
	ShowHtmlStatus = true;
end

function buildAction(...)
	local param = {...}
	local action = THtmlAction("/" .. PLUGIN_NAME);
	for i = 1, #param do
		if tostring(param[i]):sub(1, 1) == "$" then
			action:AddParam(param[i], true);
		else
			action:AddParam(param[i]);
		end	
	end
	return action:GetAction();
end

function splitByComma(str)
	local fields = {};
	for field in str:gmatch('([^,]+)') do
		fields[#fields + 1] = field;
	end
	return fields;
end

function addElement(data, name)
	local loc = GetMe():GetLocation();
	table.insert(data, {#data+1, name, math.floor(loc.X), math.floor(loc.Y),  math.floor(loc.Z) });
	saveCoords(data);
end

function removeElement(data, id)
	for i = 1, #data do
		if (nil ~= data[i][1] and data[i][1] == id) then
			table.remove(data, i);
			break;
		end
	end

	saveCoords(data);
end

function loadCoords()
	data = {};
	local f = io.open(CSV_FILE, "r")
	if (f ~= nil and io.close(f)) then
		for line in io.lines(CSV_FILE) do
			if (nil ~= line) then
				table.insert(data, splitByComma(line));
			end;
		end
	end;
	return data;
end;

function saveCoords(data)
    local file = assert(io.open(CSV_FILE, "w"));
	for i = 1, #data do
    	file:write(table.concat(data[i],",") .. "\n");
	end;
    file:close();
end;

function findCoordsById(data, id)
	for i = 1, #data do
	  if (data[i][1] == id) then
		return { 
			id = data[i][1], 
			name = data[i][2], 
			x = data[i][3], 
			y = data[i][4], 
			z = data[i][5] 
		};
	  end;
	end;
	return nil;
end;

function epicPort(rec)
	ShowOnScreen(2, 1500, 1, string.format("Going to %s at %d, %d, %d", rec.name, rec.x, rec.y, rec.z));

	QuestReply(string.format(
		"_bbsscripts:Util:EpicGatekeeper %s %s %s 0", 
		tostring(rec.x), 
		tostring(rec.y), 
		tostring(rec.z))
	);
end;
