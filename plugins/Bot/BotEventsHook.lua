-- for two needs:
-- - share one set of system callbacks among multiple logic modules
-- - implements multi-thread dispatching in order to have async calls
EventsBus = {
	eventsToHook = {
		"OnCreate",
		"OnLogin",
		"OnDestroy",
		"OnLogout",
		"OnLTick", -- 100ms
		"OnLTick1s",
		"OnLTick500ms",
		"OnMagicSkillLaunched", -- (user, target, skillId, skillLvl)
		"OnMyTargetSelected", -- (target)
		"OnDie", -- (user, spoiled)
		"OnChatUserMessage", -- (chatType, nick, msg)
		"OnTargetSelected",
		"OnTargetUnselected",
		"OnChatSystemMessage", -- (msgId, message)

		"OnDropItem",
		"OnPickupItem",
		"OnSpawnItem",
		"OnDeleteItem",
	},
	events = {}
}

local CurrentThread;

-- creates new thread that can use async call to EventsBus:waitOn(...)
function CreateThread(owner, threadProc, disposeMethod)
	local thread = {
		coroutine = coroutine.create(function () if threadProc then  threadProc(owner) end end);
		disposeMethod = function() if disposeMethod then disposeMethod(owner) end end;
	}
	RunThread(thread)
	return thread;
end

--- resumes passed thread, print crash error, set global CurrentThread
function RunThread(thread, ...)
	local prevThread = CurrentThread; -- this manipulation should allow threads stack
	CurrentThread = thread;
	local noError, res = coroutine.resume(thread.coroutine, ...);
	CurrentThread = prevThread;

	if not noError then
		dprint(res); end
	return res;
end

--- Remove thread from dispatch queue. This may cause memory leaks, but we don't care :)
function StopThread(thread)
	for _,waitersList in pairs(EventsBus.events) do
		for i=#waitersList, 1, -1 do
			local waiterHandle = waitersList[i];
			if waiterHandle.waiter == thread then
				waiterHandle.waiter = nil;
				table.remove(waitersList, i);
				return;
			end
		end
	end
end

function EventsBus:init()
	for _,eventName in pairs(self.eventsToHook) do
		self.events[eventName] = {};
		self:hookEvent(eventName);
	end
	EventsBus:addCallback("OnLTick500ms", ResumeThreadsByTimeout, true);
	EventsBus:addCallback("OnLogout", ClearThreads, true);
	EventsBus:addCallback("OnDestroy", ClearThreads, true);
end

-- @param immortal means that this callback will not be removed upon dispose of all callbacks
function EventsBus:addCallback(eventName, callback, immortal)
	if not (self.events[eventName] and "function" == type(callback)) then
		return eprint("addCallback() invalid input event:"..type(self.events[eventName]).. " callback:"..type(callback)) end
	
	local waiterHandle = {
			waiter = callback,
--			continueCondition=continueCondition,
			immortal = immortal,
		};
	table.insert(self.events[eventName], waiterHandle);
	
	return waiterHandle;
end

function EventsBus:removeCallback(eventName, waiterHandle)
	local waitersList = self.events[eventName];
	if not waitersList then
		return; end
		
	for i=#waitersList, 1, -1 do
		if waitersList[i] == waiterHandle then
			table.remove(waitersList, i);
		end
	end
end

-- TODO: refactor this function. Combine waitOnAction() with waitOn()
function EventsBus:waitOnAction(action, eventName, continueCondition, timeout)
	if "function" ~= type(action) then
		eprint("EventsBus:waitOnAction -> action is " .. type(action))
		return; end
	if not (self.events[eventName] and "table" == type(CurrentThread)) then
		eprint("error: waitOn invalid waiter on:" .. tostring(eventName) .. " in thread:" .. type(CurrentThread))
		return; end

	table.insert(self.events[eventName], 
		{ -- var WaiterHandle
			waiter = CurrentThread,
			continueCondition=continueCondition,
			timeoutAt = timeout and GetTime() + timeout or nil,
		});
	action();
	return coroutine.yield(true);
end

--- this function will pause CurrentThread until specific event happen or timeout
function EventsBus:waitOn(eventName, continueCondition, timeout)
	if not (self.events[eventName] and "table" == type(CurrentThread)) then
		eprint("error: waitOn invalid waiter on:" .. tostring(eventName) .. " in thread:" .. type(CurrentThread))
		return; end

	table.insert(self.events[eventName], 
		{ -- var WaiterHandle
			waiter = CurrentThread,
			continueCondition=continueCondition,
			timeoutAt = timeout and GetTime() + timeout or nil,
		});
	return coroutine.yield(true);
end

------------------------------
-- private

function EventsBus:hookEvent(eventName)
	_G[eventName] = function(...) self:onEvent(eventName, ...) end
end

function EventsBus:onEvent(eventName, ...)
	local waitersList = self.events[eventName]
	for i=#waitersList, 1, -1 do
		local waiterHandle = waitersList[i];
		if "function" == type(waiterHandle.waiter) then
			if waiterHandle.waiter(...) then
				table.remove(waitersList, i); end
		elseif not waiterHandle.continueCondition or waiterHandle.continueCondition(...) then

			table.remove(waitersList, i);
			RunThread(waiterHandle.waiter, true, ...);
		end
	end
end

function ResumeThreadsByTimeout()
	for _,waitersList in pairs(EventsBus.events) do
		for i=#waitersList, 1, -1 do
			local waiterHandle = waitersList[i];
			if waiterHandle.timeoutAt ~= nil and waiterHandle.timeoutAt < GetTime() then
				table.remove(waitersList, i);
				RunThread(waiterHandle.waiter, false);
			end
		end
	end
end

function ClearThreads()
	for _,waitersList in pairs(EventsBus.events) do
		for i=#waitersList, 1, -1 do
			local waiterHandle = waitersList[i];
			if "table" == type(waiterHandle.waiter) then
				if waiterHandle.waiter.disposeMethod then
					waiterHandle.waiter.disposeMethod();
				end
				waiterHandle.waiter = nil;
			end
			if not waiterHandle.immortal then
				table.remove(waitersList, i);
			end
		end
	end
end

--[[
bsThreads = {}

function OnCreate()
	--Event called after plugin is loaded, you should setup here any default vars,
	--and register to any commands or [/b]other things.

	--BSTest:start()
	BotNetworkDispatcher:start()
end;

function OnDestroy()
	--Event called before plugin gets destroy, make sure you kill any threads what you created.
	BotNetworkDispatcher.isEnabled = false;
	BSTest.isEnabled = false;
end;

function OnLogout()
	BotNetworkDispatcher.isEnabled = false;
	BSTest.isEnabled = false;
end;

function OnLTick()
--function OnLTick1s()
	--Event called very 100ms, you can use it to check anything, don't put lot of code here.
	--This event is called only if user is loged in.
	local threads = bsThreads["OnLTick"];
	if not threads or #threads < 1 then
		return; end

	for i=#threads, 1, -1 do
		--Wdprint("on resuming thread")
		local thread = table.remove(threads, i)
		coroutine.resume(thread)
	end

end;

function WaitOnLTick(thread)
	if not bsThreads["OnLTick"] then
		bsThreads["OnLTick"] = {}; end

	table.insert(bsThreads["OnLTick"], thread)

	coroutine.yield(true)
end

]]

-- function OnTick500ms()
-- 	--Event called very 500ms, you can use it to check anything, don't put lot of code here.
-- 	--Event is called always, some data maybe unavaible when no user is logged in.
-- 	--Also calling some functions can make game crash (or force you to diconnect).
-- end;
 
-- function OnLTick500ms()
-- 	--Event called very 500ms, you can use it to check anything, don't put lot of code here.
-- 	--This event is called only if user is loged in.
-- end;
 --[[


 
function OnDestroy()
	--Event called before plugin gets destroy, make sure you kill any threads what you created.
end;
 
function OnTick()
	--Event called very 100ms, you can use it to check anything, don't put lot of code here.
	--Event is called always, some data maybe unavaible when no user is logged in.
	--Also calling some functions can make game crash (or force you to diconnect).
end;
 

function OnTick1s()
	--Event called very 1s, you can use it to check anything, don't put lot of code here.
	--Event is called always, some data maybe unavaible when no user is logged in.
	--Also calling some functions can make game crash (or force you to diconnect).
end;
 
function OnLTick1s()
	--Event called very 1s, you can use it to check anything, don't put lot of code here.
	--This event is called only if user is loged in.
	--dprint("TEST")
end;
 
function OnLogin(username)
	--Event called after user login	
end;
 
function OnLogout()
	--Event called before user logout
end;
 
function OnAttackCanceled(user)
	--Event called when some player/npc cancel his attack.
end;
 
function OnAttack(user, target)
	--Event called when some player/npc attack other.
end;
 
function OnAttacked(user, target)
	--Event called when some player/npc attacked other.
end;
 
function OnAutoAttackStart(user, target)
	--Event called when some player/npc activate auto attack.
end;
 
function OnUserInfo(user)
	--Event called when we get some info about ourself
end;
 
function OnCharInfo(player)
	--Event called when we get some info about someother players (he spawn)
end;
 
function OnNpcInfo(npc)
	--Event called when we get some info about some npc/monster (he spawn)
end;
 
function OnDeleteUser(user)
	--Event called when some npc/player/user dissaper from map.
end;
 
function OnDie(user, spoiled)
	--Event called when some npc/player/user die.
end;
 
function OnRevive(user)
	--Event called when some npc/player/user revive.
end;
 
function OnMagicSkillCanceled(user)
	--Event called when some npc/player/user cancel magic skill.
end;
 
function OnMagicSkillLaunched(user, target, skillId, skillLvl)
	--Event called when some npc/player/user casted magic skill on someone other. 
	--For AOE skills this event will be called for every target.
end;
 
function OnMagicSkillUse(user, target, skillId, skillLvl, skillHitTime, skillReuseTime)
	--Event called when some npc/player/user start cast magic skill on someone other. hit time and reuse time is in miliseconds
end;
 
function OnTargetSelected(user, target)
	--Event called when some npc/player/user select target.
end;
 
function OnMyTargetSelected(target)
	--Event called when our target got change.
end;
 
function OnTargetUnselected(user)
	--Event called when some npc/player/we cancel target.
end;
 
function OnChangeMoveType(user)
	--Event called when some npc/player/we change move type from walk to run for example.
end;
 
function OnChangeWaitType(user)
	--Event called when some npc/player/we change wait type from sit to stand for example.
end;
 
function OnChatUserMessage(chatType, nick, msg)
	--Event called someone say something on chat. chatType is a EChatType enum.
end;
 
function OnChatSystemMessage(id, msg)
	--Event called some system message show up on chat (id - integer, msg - string).
end;

function OnDropItem(user, item)
    --Event called when item get dropped, second argument is ItemData object.
end;

function OnPickupItem(user, item)
    --Event called when someone pickup item, second argument is ItemData object.
end;

function OnSpawnItem(item)
    --Event called when item spawns, first argument is ItemData object.
end;

function OnDeleteItem(item)
    --Event called when item gots deleted - because we went out o range for example, first argument is ItemData object.
end;

function OnMoveToLocation(user, oldLocation, newLocation)
   -- user = User, oldLocation = FVector, newLocation = FVector
   --Event called when user move somwhere (movetolocation, flytolocation, jumptolocation)
end;

function OnTeleportToLocation(user, oldLocation, newLocation)
   -- user = User, oldLocation = FVector, newLocation = FVector
   --Event called when user teleports
end;

function OnStopMove(user, location)
   -- user = User, location = FVector
   --Event called when user stop moving.
end;

function OnDisconnect(mode)
   --mode == 1 or 2
end;
]]