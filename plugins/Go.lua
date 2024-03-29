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

dofile(package.path .. "murmurhash3.lua");
local mmh3 = require("murmurhash3");

local PLUGIN_NAME = 'go';
local PLUGIN_TITLE = 'Teleport To Location';
local TEMPLATES_FOLDER = GetDir() .. 'plugins\\Go'
local CSV_FILE = GetDir() .. 'temp\\Go-Set.csv'
local MAX_ITEMS_PER_PAGE = 10;

local GAME_VER = 'H5';
local HtmlBuild = "";
local ShowHtmlStatus = false;

local PACKET_IDS = {
	["H5"] = {
		["Client"] = {
			["RequestBypassToServer"] = {0xA9, 0x00},
			["RequestTutorialPassCmdToServer"] = {0x86, 0x00}
		},
		["Server"] = {
			["TutorialShowHtml"] = {0xA6, 0x00},
			["NpcHtmlMessage"] = {0x19, 0x00},
			["TutorialEnableClientEvent"] = {0xA8, 0x00},
			["TutorialClose"] = {0xA9, 0x00},
			["PledgeCrest"] = {0x6A, 0x00},
		}		
	}
};

local PLUGIN_SETTINGS = {
	["use_tutorial_win"] = {
		["id"] = 1,
		["label"] = "Use tutorial window",
		["value"] = true
	}
};

function getSetting(name)
	for i, v in pairs(PLUGIN_SETTINGS) do
		if i == name then return v["value"]; end;
	end
	return nil;
end;

function OnCreate() 
	this:RegisterCommand(PLUGIN_NAME, CommandChatType.CHAT_ALLY, CommandAccessLevel.ACCESS_ME); 
	UnblockOutgoingPacket(0x86);
end;

function OnDestroy() this:UnregisterCommand(PLUGIN_NAME); end;

--
-- Read bypass command sent from NPC window
--
_G["OnCommand_" .. PLUGIN_NAME] = function (vCommandChatType, vNick, vCommandParams)
	local commands = {};
	if (vCommandParams:GetCount() > 0) then
		for i = 0, vCommandParams:GetCount() - 1 do
			table.insert(commands, vCommandParams:GetParam(i):GetStr(true))
		end;
	end;
	ProcessCommand(commands);
end;

--
-- Read bypass command sent from Tutorial window
--
function OnOutgoingPacket(packet) 
	if true == getSetting("use_tutorial_win") then
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
				if plugin == PLUGIN_NAME then ProcessCommand(commands); end;
			end;
			packet = nil;
		end;
	end;
end;

--
-- Prcess a bypass command. In this case we target a specific window page
--
function ProcessCommand(args)
	local page = (#args > 0) and table.remove(args, 1) or "index";

	if type(_G["OnPage_" .. page]) == "function" then
		_G["OnPage_" .. page](page, args);
	end;
end;

--
-- Show HTML window if ShowHtmlStatus is true - either NPC or Tutorial
--
function OnLTick()
    if (ShowHtmlStatus) then
        ShowHtmlStatus = false;
		if true == getSetting("use_tutorial_win") then
			-- TutorialShowHtml
			local packet = PacketBuilder();
			packet:AppendString(HtmlBuild);
			SendPacketToGame(0xA6, 0x00, packet);
		else
			-- NpcHtmlMessage
			local packet = PacketBuilder();
			packet:AppendInt(0, 4);
			packet:AppendString(HtmlBuild);
			packet:AppendInt(0, 4);
			SendPacketToGame(0x19, 0x00, packet);
			--ShowHtml(HtmlBuild);
		end;
    end;
end;

--
-- Controllers
--

function OnPage_index(page, args)
	local data = loadCoords();
	local pageNum = (#args > 0) and tonumber(args[1]) or 1;

	ShowMainDialog(page, data, pageNum);
end;

function OnPage_jump(page, args)
	local data = loadCoords();
	local id = tostring(args[1]);
	local confirm = tonumber(args[2]);
	local rec = findCoordsById(data, id);

	if (nil ~= rec) then
		if (1 == confirm) then
			RunEpicPort(rec);
		else
			ShowJumpDialog(page, rec);
		end;
	end;
end;

function OnPage_save(page, args)
	local data = loadCoords();
	if #args > 0 then
		local name = tostring(args[1]);
		addLocation(data, name);
		data = loadCoords();
	end;

	ShowMainDialog("index", data, 1);
end;

function OnPage_add(page, args)
	ShowAddDialog(page);
end;

function OnPage_settings(page, args)
	if #args > 1 then
		ShowSettingsDialog(page, tostring(args[1]), tostring(args[2]));
	end;
	ShowSettingsDialog(page, setting, value);
end;

function OnPage_remove(page, args)
	local data = loadCoords();
	local id = tostring(args[1]);
	local confirm = tonumber(args[2]);
	if (1 == confirm) then
		removeLocation(data, id);
		data = loadCoords();
		ShowMainDialog("index", data, 1);
	else
		local rec = findCoordsById(data, id);
		if (nil ~= rec) then
			ShowRemoveDialog(page, rec);
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
		["jump_action"] = buildAction(page, rec.id, 1)
	};
	ShowPage(page, ctx);

	local vector = FVector(tonumber(rec.x),tonumber(rec.y), tonumber(rec.z));
	ShowArrow(vector);
	ShowTrace(vector);
end;

function ShowRemoveDialog(page, rec)
	local ctx = {
		["layout"] = {
			["title"] = "Remove Location",
			["btn_label"] = "Back",
			["btn_action"] = buildAction()
		},
		["rec"] = rec,
		["remove_action"] = buildAction(page, rec.id, 1)
	};
	ShowPage(page, ctx);
end;

function ShowAddDialog(page, defaultName)
	local loc = GetMe():GetLocation();
	local ctx = {
		["layout"] = {
			["title"] = "Add Location",
			["btn_label"] = "Back",
			["btn_action"] = buildAction()
		},
		["save_action"] = buildAction("save", "$name"),
		["refresh_action"] = buildAction(page),
		["loc"] = {
			x = math.floor(loc.X),
			y = math.floor(loc.Y),
			z = math.floor(loc.Z),
		}
	};
	ShowPage(page, ctx);
end;

function ShowSettingsDialog(page, settingId, val)

	if nil ~= settingId and nil ~= val then
		for i, v in pairs(PLUGIN_SETTINGS) do
			if tostring(v["id"]) == settingId then 
				PLUGIN_SETTINGS[i]["value"] = toboolean(val);
			end;
		end
		
		-- Exception where we also change the windows
		if "1" == settingId and "0" == val then
			CloseTutorialWindow();
		end;
	end;

	local ctx = {
		["layout"] = {
			["title"] = "Settings",
			["btn_label"] = "Back",
			["btn_action"] = buildAction()
		},
		["rows"] = {}
	};

	for k, v in pairs(PLUGIN_SETTINGS) do
		table.insert(ctx["rows"], {
			["label"] = tostring(v["label"]),
			["value"] = v["value"],
			["cb_action"] = buildAction(page, v["id"], true == v["value"] and 0 or 1)
		});
	end

	ShowPage(page, ctx);
end;

function ShowMainDialog(page, data, pageNum)
	local ctx = {
		["layout"] = {
			["title"] = "Locations List",
			["btn_label"] = "Add",
			["btn_action"] = buildAction("add")
		},
		["settings_action"] = buildAction("settings"),
		["start_item"] = 0,
		["end_item"] = 0,
		["total_items"] = 0,
		["total_pages"] = 1,
		["first_action"] = nil,
		["last_action"] = nil,
		["prev_action"] = nil,
		["next_action"] = nil,
		["rows"] = {}
	};
	if (#data > 0) then
		data = table.reverse(data);

		-- Pagination
		if #data > MAX_ITEMS_PER_PAGE then
			local totalPages = math.ceil(#data / MAX_ITEMS_PER_PAGE);
			ctx["total_items"] = #data;
			ctx["total_pages"] = totalPages;
			ctx["current_page"] = pageNum;

			local startItem = ((pageNum - 1) * MAX_ITEMS_PER_PAGE) + 1;
			local endItem = ((pageNum - 1) * MAX_ITEMS_PER_PAGE) + MAX_ITEMS_PER_PAGE;
			if endItem > #data then endItem = #data; end;

			ctx["start_item"] = startItem;
			ctx["end_item"] = endItem;

			if pageNum > 1 then 
				ctx["first_action"] = buildAction(page, 1);
				ctx["prev_action"] = buildAction(page, pageNum - 1);	
			end;

			if pageNum < totalPages then 
				ctx["last_action"] = buildAction(page, totalPages);
				ctx["next_action"] = buildAction(page, pageNum + 1);
			end;

			data = table.slice(data, startItem, endItem);
		end;

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
	context.layout.show_close = true == getSetting("use_tutorial_win");

	local html = THtmlGenerator(PLUGIN_TITLE);
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
		end;
	end
	return action:GetAction();
end

function toboolean(str)
	local TRUE = {
		['1'] = true,
		['t'] = true,
		['T'] = true,
		['on'] = true,
		['On'] = true,
		['ON'] = true,
		['true'] = true,
		['TRUE'] = true,
		['True'] = true,
	};
	local FALSE = {
		['0'] = false,
		['f'] = false,
		['F'] = false,
		['off'] = false,
		['Off'] = false,
		['OFF'] = false,
		['false'] = false,
		['FALSE'] = false,
		['False'] = false,
	};

    if TRUE[str] == true then
        return true;
    elseif FALSE[str] == false then
        return false;
    else
        return nil;
    end
end

function table.fromString(str)
	local fields = {};
	for field in str:gmatch('([^,]+)') do
		fields[#fields + 1] = field;
	end
	return fields;
end

function table.reverse(tbl)
    for i = 1, math.floor(#tbl/2), 1 do
        tbl[i], tbl[#tbl-i+1] = tbl[#tbl-i+1], tbl[i];
    end
    return tbl;
end

function table.slice(tbl, first, last)
	local sliced = {};
	for i = first or 1, last or #tbl, 1 do
	  sliced[#sliced+1] = tbl[i];
	end
	return sliced;
end

function addLocation(data, name)
	local loc = GetMe():GetLocation();
	table.insert(data, {#data+1, name, math.floor(loc.X), math.floor(loc.Y),  math.floor(loc.Z) });
	saveCoords(data);
end

function removeLocation(data, id)
	for i = 1, #data do
		if (nil ~= data[i][1] and data[i][1] == id) then
			table.remove(data, i);
			break;
		end
	end

	saveCoords(data);
end

function loadCoords()
	local data = {};
	local f = io.open(CSV_FILE, "r")
	if (f ~= nil and io.close(f)) then
		for line in io.lines(CSV_FILE) do
			if (nil ~= line) then
				table.insert(data, table.fromString(line));
			end;
		end
	end;
	return data;
end;

function saveCoords(data)
    local file = assert(io.open(CSV_FILE, "w"));
	for i = 1, #data do
    	file:write(table.concat(data[i], ",") .. "\n");
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

--
-- Force close the Tutorial window
--
function CloseTutorialWindow()
	-- TutorialEnableClientEvent
	local tutorialEnableClientEvent = PacketBuilder();
	tutorialEnableClientEvent:AppendInt(0, 4);
	SendPacketToGame(0xA8, 0x00, tutorialEnableClientEvent);

	-- TutorialClose
	local tutorialClose = PacketBuilder();
	SendPacketToGame(0xA9, 0x00, tutorialClose);
end;

--
-- This most probably wont work on other servers, but it's just an example
--
function RunEpicPort(rec)
	ShowOnScreen(2, 1500, 1, string.format("Going to %s at %d, %d, %d", rec.name, rec.x, rec.y, rec.z));

	QuestReply(string.format(
		"_bbsscripts:Util:EpicGatekeeper %s %s %s 0", 
		tostring(rec.x), 
		tostring(rec.y), 
		tostring(rec.z))
	);
end;

---------------------------------------------
-------  Images
---------------------------------------------

local IMG_CACHE = {};
local SERVER_ID = 1; -- @todo obtain this dynamically

--
-- Read a binary file to a hex string
--
function readBinFile(path)
	local file = io.open(path, "rb")
	if not file then return nil end
	local content = file:read("*all")
	file:close()
	return (content:gsub('.', function(c)
		return string.format('%02X', string.byte(c))
	end))
end;

function img(name)

	if nil ~= IMG_CACHE[name] then
		return IMG_CACHE[name];
	else
		local imgFileName = string.format(TEMPLATES_FOLDER .. '\\img\\%s.dds', tostring(name));
		local bin = readBinFile(imgFileName);
		if nil ~= bin then
			local crestId = math.ceil(mmh3.murmurhash3(name) / 10) + 1000000000;

			-- PledgeCrest
			-- Send image to game client as a clan crest
			local packet = PacketBuilder();
			packet:AppendInt(crestId, 4);
			packet:AppendInt(#bin / 2, 4); -- size
			packet:AppendDataFromHexString(bin); --binary
			SendPacketToGame(0x6A, 0x00, packet);
	
			local crestName = string.format("Crest.crest_%s_%s", tostring(SERVER_ID), tostring(crestId));

			-- Add the crest to the cache
			IMG_CACHE[name] = crestName;
			
			return crestName;
		end;
	end

	return "";
end
