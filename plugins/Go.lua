dofile(package.path .. "template.lua");
local template = require("template");

local PLUGIN_NAME = 'go';
local TEMPLATES_FOLDER = GetDir() .. 'plugins\\Go'
local CSV_FILE = GetDir() .. 'temp\\Go-Set.csv'
local HtmlBuild = "";
local ShowHtmlStatus = false;

function OnCreate() this:RegisterCommand(PLUGIN_NAME, CommandChatType.CHAT_ALLY, CommandAccessLevel.ACCESS_ME); end;

function OnDestroy() this:UnregisterCommand(PLUGIN_NAME); end;

_G["OnCommand_" .. PLUGIN_NAME] = function(vCommandChatType, vNick, vCommandParam)
	local data = loadCoords();
	if (vCommandParam:GetCount() > 0) then
		local command = vCommandParam:GetParam(0):GetStr(true);

		if (command == "jump") then
			local id = tostring(vCommandParam:GetParam(1):GetStr(true));
			local rec = findCoordsById(data, id);
			if (nil ~= rec) then
				epicPort(rec.x, rec.y, rec.z);
			end;
		end;

		if (command == "remove") then
			local id = tostring(vCommandParam:GetParam(1):GetStr(true));
			local confirmed = tonumber(vCommandParam:GetParam(2):GetInt());
			if (1 == confirmed) then
				removeElement(data, id);
				data = loadCoords();
			else
				local rec = findCoordsById(data, id);
				if (nil ~= rec) then
					return ShowRemoveDialog("remove", rec);
				end;
			end
		end;

		if (command == "add") then
			return ShowAddDialog("add");
		end;

		if (command == "save") then
			local name = tostring(vCommandParam:GetParam(1):GetStr(true));
			addElement(data, name);
		end;
	end;
		
	ShowMainDialog("main", data);
end;

function OnLTick500ms()
    if (ShowHtmlStatus) then
        ShowHtmlStatus = false;
        ShowHtml(HtmlBuild);
    end;
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
				["action"] = buildAction("jump", id),
				["remove_action"] = buildAction("remove", id, 0)
			});
		end;
	end;
	ShowPage(page, ctx);
end;

function ShowPage(page, context)
	local layoutFile = TEMPLATES_FOLDER .. '\\layout.htm';
	local file = TEMPLATES_FOLDER .. '\\' .. page .. '.view.htm';
	local layout = template.new(layoutFile);
	context.layout.view = template.render(file, context, "no-cache");

	local html = THtmlGenerator("Teleport To Location");
	html:AddHtml(layout:render(context.layout));
	HtmlBuild = html:GetString();
	ShowHtmlStatus = true;
end

function buildAction(...)
	local action = THtmlAction("/" .. PLUGIN_NAME);
	local param = {...}
   	for i = 1, #param do
		if tostring(param[i]):sub(1, 1) == "$" then
			action:AddParam(param[i], true);
		else
			action:AddParam(param[i]);
		end	
	end
	return action:GetAction();
end

function splitWithComma(str)
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
				table.insert(data, splitWithComma(line));
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

function epicPort(x, y, z)
	ShowToClient(PLUGIN_NAME, string.format("Going to %d, %d, %d", x, y, z), 0x05); 

	QuestReply(string.format(
		"_bbsscripts:Util:EpicGatekeeper %s %s %s 0", 
		tostring(x), 
		tostring(y), 
		tostring(z))
	);
end;
