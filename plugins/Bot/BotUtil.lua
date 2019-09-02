function printf(msg, ...)
    ShowToClient("IssBuff", string.format(msg, ...));
end

function split(pString, pPattern, maxNb)
    local Table = {} -- NOTE: use {n = 0} in Lua-5.0
    local fpat = "(.-)" .. pPattern
    local last_end = 1
    local s, e, cap = pString:find(fpat, 1)
    local n = 1;
    while s do
        if s ~= 1 or cap ~= "" then
            table.insert(Table, cap)
        end
        last_end = e + 1
        s, e, cap = pString:find(fpat, last_end)

        if (nil ~= maxNb and maxNb > 0 and n == maxNb) then break; end;
        n = n + 1;
    end
    if last_end <= #pString then
        cap = pString:sub(last_end)
        table.insert(Table, cap)
    end
    return Table
end

log = function(...)
    local resultLine = "";
    for i = 1, select("#", ...) do
        local line = select(i, ...);
        if (line == nil) then
            resultLine = resultLine .. " NIL";
        elseif type(line) == "table" then
            resultLine = resultLine .. " " .. createTableString(line) .. " ";
        elseif type(line) == "userdata" then
            resultLine = resultLine .. " " .. type(line);
        else
            resultLine = resultLine .. " " .. tostring(line);
        end;
    end;
    this:Log(resultLine);
    --dprint(resultLine);
end;

function createTableString(input)
    local shift = 0;
    local tablesOpened = {}
    local function innerCreateTableString(input)
        if type(input) == "table" then
            if (nil == tablesOpened[input]) then
                tablesOpened[input] = input;
                local result = { "Table: \n" };
                shift = shift + 1;
                for key, value in pairs(input) do
                    result[#result + 1] = string.rep("|   ", shift);
                    result[#result + 1] = string.format("[%s] = %s", tostring(key), innerCreateTableString(value));
                end;
                shift = shift - 1;
                return table.concat(result);
            else
                return "[RECURSIVE LINK]\n";
            end
        else
            return tostring(input) .. "\n";
        end;
    end

    ;
    return innerCreateTableString(input);
end

function table.contains(tbl, item)
    for _, v in pairs(tbl) do
        if v == item then
            return true;
        end
    end
    return false;
end

function table.any(tbl, compareFunction)
    for _, v in pairs(tbl) do
        if compareFunction(v) then
            return true;
        end
    end
    return false;
end

L2TowerPausedLock = 0;

-- L2Tower Pause is used in order to take full control over char (disable all scripts and L2Tower functionality)
function LockPause()
    L2TowerPausedLock = L2TowerPausedLock + 1

    if L2TowerPausedLock == 1 then
        L2TowerPaused = IsPaused();
        if not L2TowerPaused then
            dprint("lock Pause");
            SetPause(true);
        end
    end
end

function UnlockPause()
    L2TowerPausedLock = L2TowerPausedLock - 1

    if L2TowerPausedLock == 0 then
        if not L2TowerPaused then
            dprint("unlock");
            SetPause(false);
        end
    elseif L2TowerPausedLock < 0 then
        dprint("L2TowerPausedLock become negative");
        L2TowerPausedLock = 0;
    end
end

-- puts current coroutine to sleep for "timeout" ms
function ThreadSleepMs(timeout)
    local resumeAt = GetTime() + timeout;
    EventsBus:waitOn("OnLTick", function() return resumeAt < GetTime() end)
    return true;
end

-- puts current coroutine to sleep for "timeout" seconds.
function ThreadSleepS(timeout)
    local resumeAt = GetTime() + timeout * 1000;
    EventsBus:waitOn("OnLTick1s", function() return resumeAt < GetTime() end)
    return true;
end

function GetInfo()
    local me = GetMe();
    return {
        i = me:GetId(),
        n = me:GetName(),
        nn = me:GetNickName(),
        c = me:GetClass(),
        a = GetAccountName(),
        hp = tonumber(me:GetHpPercent()),
        mp = tonumber(me:GetMpPercent()),
    };
end

function SelectTargetByOId2(oId)
    ClearTargets();
    CancelTarget(false)
    if oId and oId > 0 then
        if CurrentThread then
            EventsBus:waitOnAction(function() TargetRaw(oId); end, "OnMyTargetSelected", function(target) return target:GetId() == oId end, 1000);
        else
            TargetRaw(oId)
        end
    end
    return true;
end

function SelectTargetByOId(oId)
    ClearTargets();
    CancelTarget(false)
    if oId and oId > 0 then
        TargetRaw(oId)
        if CurrentThread then
            EventsBus:waitOn("OnMyTargetSelected", function(target) return target:GetId() == oId end)
        end
    end
    return true;
end

function TalkByTarget(oId)
    ClearTargets();
    CancelTarget(false)
    if oId and oId > 0 then
        TargetRaw(oId)
        EventsBus:waitOn("OnMyTargetSelected", function(target) return target:GetId() == oId end)
        TargetRaw(oId)
    end
    return true;
end

function ValidateSkillUse(id, waitReuse, count, timeout)
    local skill = GetSkills():FindById(id)
    if not skill then
        iprint("Failed to cast skill (no skill):", id);
        return false;
    end

    while not skill:CanBeUsed() and count > 0 do
        ThreadSleepMs(timeout);
        count = count - 1;
    end

    if not skill:CanBeUsed() then
        iprint("Failed to cast skill (can't be used):", id);
        return false;
    end

    return true;
end

function CastSkill(id, count, timeout, waitReuse)
    if not ValidateSkillUse(id, waitReuse, count, timeout) then
        return false;
    end

    return CastSkillRaw(id, count, timeout);
end

function CastSkillRaw(id, count, timeout)
    local myId = GetMe():GetId();

    local res = EventsBus:waitOnAction(function() UseSkillRaw(id, false, false); end,
        "OnMagicSkillLaunched",
        function(user, target, skillId, skillLvl) return myId == user:GetId() and id == skillId; end, timeout);

    if res then
        return true;
    elseif count > 0 then
        return CastSkillRaw(id, (count - 1), timeout)
    end
    iprint("Failed to cast skill (some error):", id);
    return false;
end

-- @return false in case if some skill failed to cast or process has been stopped
function CastAllByList(list, count, timeout)
    if "table" ~= type(list) then return dprint("CastAllByList(list) - >> list not a table") end
    --CancelTarget(false)
    for _, id in pairs(list) do
        if not CastSkill(id, count, timeout) then
            return false;
        end
    end
    return true;
end

function MobsCount(range)
    local mobs = GetMonsterList()
    local i = 0
    for m in mobs.list do
        if m:GetDistance() <= range and m:GetHpPercent() ~= 0 then
            i = i + 1
        end
    end
    return i
end

function safeIndex(object, firstKey, ...)
    if ("table" == type(object) or "userdata" == type(object)) and "nil" ~= type(firstKey) then
        -- continue indexing
        return safeIndex(object[firstKey], ...);
    elseif not ("table" == type(object) or "userdata" == type(object)) and "nil" ~= type(firstKey) then
        -- hit missed subkey
        return nil;
    else -- either no value or no index; both situations treated as successful
        return object;
    end
end

function PartyWithMe()
    local partyTable = { GetMe() };
    local party = GetPartyList()
    for user in party.list do
        table.insert(partyTable, user)
    end
    local i, user;
    return function()
        i, user = next(partyTable, i)
        return user;
    end
end