

local SYSMSG_REC_SUCCESSFULL = 830;
local SYSMSG_REC_EXHAUSED = 3206;
local SYSMSG_REC_FULL = 1188;

BSRecommend = {
    enabled = false,

    retry_interval = 120000, -- 2 minutes
    targetUser = nil, -- target player to recommend (user)
    maxrecs = {}, -- players with maximum recommendations (table)
    originalTarget = nil, -- target to restore the selection
    callbacks = {},
    noMoreRecs = nil,
    currentTime = nil
}

function BSRecommend:init()
    BotCommandFactory:registerCommand("BSRecommend.autoRecommend", self, self.cmdAutoRecommend)
end


---
-- Restore original target
---
function BSRecommend:RestoreOriginalTarget()
    ClearTargets();
    if (nil ~= self.originalTarget and GetMe():GetTarget() ~= self.originalTarget) then
        TargetRaw(self.originalTarget);
    end;
end

---
-- Target and recommend a player
---
function BSRecommend:RecommendPlayer()
    if (GetMe():GetTarget() ~= self.targetUser:GetId()) then
        Command("/target " .. self.targetUser:GetName()) ;
    end;
    Command("/evaluate " .. self.targetUser:GetName());
end

---
-- Check if player can be recommended
-- @param playerName
--
function BSRecommend:CanBeRecommended(playerName)
    if (nil ~= self.maxrecs[playerName] and self.maxrecs[playerName] + self.retry_interval > GetTime()) then
        return false;
    end;
    return true;
end

---
-- Try finding closest party player who can be recommended
---
function BSRecommend:FindClosestPartyPlayer()
    local me = GetMe();
    local partylist = GetPartyList();
    local closest;
    local member;

    for member in partylist.list do
        if (not member:IsMe() and member:GetRangeTo(me) < 800 and self:CanBeRecommended(member:GetName())) then
            if ( nil == closest or (nil ~= closest and member:GetRangeTo(me) < closest:GetRangeTo(me)) ) then
                closest = member;
            end;
        end;
    end;

    return closest;
end;

---
-- Try recommend a party player
---
function BSRecommend:TryRecommend()
    self.currentTime = GetTime();

    if (nil ~= self.noMoreRecs and self.noMoreRecs + self.retry_interval > self.currentTime) then
        return; -- wait, no recommendations yet
    end;

    if (nil == self.originalTarget) then
        self.originalTarget = GetMe():GetTarget();
    end;

    self.noMoreRecs = nil; -- reset timestamp

    self.targetUser = self:FindClosestPartyPlayer();
    if (nil ~= self.targetUser) then
        self:RecommendPlayer();
    end;
end;

function BSRecommend:cmdAutoRecommend(dto)
    local cfg = json.decode(dto);
    self.enabled = (cfg.enabled or false);

    if self.enabled then
        iprint("BSRecommend started.");

        self.callbacks = {};
        self.callbacks["OnChatSystemMessage"] = EventsBus:addCallback("OnChatSystemMessage", function(msgId, message)

            if (msgId == SYSMSG_REC_SUCCESSFULL) then -- successfully rec
                --
            end;

            if (msgId == SYSMSG_REC_EXHAUSED) then -- no more recommendations left
                self.noMoreRecs = GetTime();
                self:RestoreOriginalTarget();
            end;

            if (msgId == SYSMSG_REC_FULL) then -- max recommendations reached (recs >= 255)
                if (nil ~= self.targetUser) then
                    self.maxrecs[self.targetUser:GetName()] = GetTime();
                end;
                self:RestoreOriginalTarget();
            end;

        end);

        self.callbacks["OnLTick500ms"] = EventsBus:addCallback("OnLTick500ms", function()
            self:TryRecommend();
        end);

    else
        self:dispose();
    end
end

function BSRecommend:dispose()
    for eventName, handler in pairs(self.callbacks) do
        EventsBus:removeCallback(eventName, handler);
    end

    self:RestoreOriginalTarget();

    self.maxrecs = {};
    self.originalTarget = nil;
    self.targetUser = nil;

    iprint("BSRecommend stopped.");
end