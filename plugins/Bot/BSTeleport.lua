-- watches your dialog actions in order to force bots who are following you to repeat them
-- /wg  activate/deactivate 
BSTeleport = {}
BSTeleport_links = {}

function BSTeleport:reset()
    if self.thread then
        StopThread(self.thread)
        self.thread = nil;
    end
    self.lastHtml = nil;
    self.lastDialogNpc = nil;
end

function BSTeleport:init()
    this:RegisterCommand("dlgAct", CommandChatType.CHAT_ALLY, CommandAccessLevel.ACCESS_ME);
    this:RegisterCommand("html", CommandChatType.CHAT_ALLY, CommandAccessLevel.ACCESS_ME);
    this:RegisterCommand("wg", CommandChatType.CHAT_ALLY, CommandAccessLevel.ACCESS_ME);
end

function OnCommand_wg(vCommandChatType, vNick, vCommandParam)
    local self = BSTeleport;
    if self.thread then
        dprint("Stop watchgo");
        return self:reset();
    end
    dprint("Start watchgo");
    self.lastHtml = GetDialogHtml();
    self.thread = CreateThread(self, self.watchDialogProc);
end

function OnCommand_dlgAct(vCommandChatType, vNick, vCommandParam)
    local self = BSTeleport;

    if (vCommandParam:GetCount() == 1 and vCommandParam:GetParam(0) ~= nil) then
        local action = vCommandParam:GetParam(0):GetStr(true);
        log("click action ", action)
        action = tonumber(action);
        if nil ~= action and BSTeleport_links[action] then
            log(BSTeleport_links[action])
            SendServerMessage("followersDialogAction", { action = "selectDialogItem", param = action })
            QuestReply(BSTeleport_links[action])
            BSTeleport_links = {};
        end
    end;
end


function OnCommand_html(vCommandChatType, vNick, vCommandParam)
    dump(GetDialogHtml())
end


function dump(text)
    text = text or "none"
    local outputFile = GetDir() .. "\\html.txt"
    local f, err = io.open(outputFile, "w+")
    f:write(text)
    f:flush()
    f:close()
end

-- raplacing links in menues by buttons is possible, but ugly a bit
-- local htmlToShow, c = string.gsub(newHtml, "<a action=\"bypass %-h (.-)\".->(.-)</a>", buildButton)
-- local function buildButton(action, text)
--   text = text:gsub("\"", "\\\"")
--   return "<button action=\"bypass -h /dlgAct ".. action .."\" value=\"".. text .."\" width=300 height=15 back=\"true\" fore=\"true\">"
-- end

function BSTeleport:watchDialogProc()
    while EventsBus:waitOn("OnLTick500ms") do

        local newHtml = GetDialogHtml();
        if "" ~= newHtml and newHtml ~= self.lastHtml then
            dprint("new dialog appear")
            self.lastHtml = newHtml;
            BSTeleport_links = {};
            newHtml = newHtml:gsub("msg=\".-\"", "") -- remove popup msg

            local htmlToShow = string.gsub(newHtml, "bypass %-h (.-)\"", function(link)
                table.insert(BSTeleport_links, link);
                return "bypass -h //dlgAct '" .. #BSTeleport_links .. "'\"";
            end)

            local htmlToShow = string.gsub(htmlToShow, "<title>(.-)</title>", function(title)
                return "<title>" .. title .. " - Proxy</title>"
            end)

            dump(htmlToShow)

            ShowHtml(htmlToShow)
            local currentDialogNpc = GetTarget():GetId()

            if self.lastDialogNpc ~= currentDialogNpc then
                self.lastDialogNpc = currentDialogNpc;
                SendServerMessage("followersDialogAction", { action = "openDialog", param = GetTarget():GetId() })
            end
        end
    end
end
