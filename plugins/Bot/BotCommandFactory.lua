-- performs mapping of server messages onto calls to end client managers
BotCommandFactory = {
	commands = {}
}

function BotCommandFactory:registerCommand(cmdName, inst, func)
	self.commands[cmdName] = {inst = inst, func = func};
end

function BotCommandFactory:unRegisterCommand(cmdName)
    self.commands[cmdName] = nil;
end

function BotCommandFactory:runCommand(cmdData, ...)
	local cmdArr = split(cmdData, "%s", 1);
	local cmd = self.commands[cmdArr[1]];
	if not cmd and nil ~= cmdArr[1] then
        local modArr = split(cmdArr[1], "%.", 1);
        if #modArr>0 then
            self:tryLoadModule(modArr[1]);
            if #modArr>1 and modArr[2] == "init" then
                return; end;
        end;
        cmd = self.commands[cmdArr[1]];
    end;
	if not cmd then
		return eprint("No such command : " .. tostring(cmdArr[1])); end

	--cmd.func(cmd.inst, #cmdArr>1 and cmdArr[2] or nil)
    xpcall(function() cmd.func(cmd.inst, #cmdArr>1 and cmdArr[2] or nil); end, eprint);
end

function BotCommandFactory:tryLoadModule(mod)
    if nil == rawget(_G, mod) then
        local file = const_scripts_path .. mod .. ".lua";
        xpcall(function()
            dprint("Loading module : " .. mod);
            dofile(file);
            if nil ~= _G[mod] and _G[mod]["init"] ~= nil and type(_G[mod]["init"] == "function") then
                _G[mod]:init(); end;
        end, eprint);
    end;
end

function BotCommandFactory:unloadModule(mod)
    if nil ~= rawget(_G, mod) then
        package.loaded[mod] = nil
        _G[mod] = nil
    end
end
