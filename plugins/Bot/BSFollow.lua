-- controlled by server config
-- follows path of target. (if you set offset to 0, then bot will accurately repeat path of his master)
-- also can repeat dialog action of the target. (target should have BSTeleport enabled)
BSFollow = {
  masterPath = {};
  slavePath = {};
  -- general settings
  pathDetailsMaxTrashhold = 700;
  pathDetailsMinTrashhold = 70;
  pointReachedTreshhold = 50;
  -- every time movement is started new follow dist will be selected
  minFollowDist = 100;
  maxFollowDist = 150;
  followDist = 0;
  
  keyPointShiftRangeMin = -40;
  keyPointShiftRangeMax = -80;
  keyPointShift = 1; -- updated every time when char reached keyPoint

  links = {}, -- links found in last dialog

  setups = {
    -- left side
    {
      keyPointShiftRangeMin = -35;
      keyPointShiftRangeMax = -40;
      minFollowDist = 100;
      maxFollowDist = 200;
    },
    {
      keyPointShiftRangeMin = -45;
      keyPointShiftRangeMax = -50;
      minFollowDist = 150;
      maxFollowDist = 220;
    },
    -- right side
    {
      keyPointShiftRangeMin = 35;
      keyPointShiftRangeMax = 40;
      minFollowDist = 150;
      maxFollowDist = 220;
    },
    {
      keyPointShiftRangeMin = 45;
      keyPointShiftRangeMax = 50;
      minFollowDist = 100;
      maxFollowDist = 200;
    },
  }
}


function BSFollow:init()
    math.randomseed(GetMe():GetId());
    BotCommandFactory:registerCommand("BSFollow.follow", self, self.cmdFollow)
    BotCommandFactory:registerCommand("BSFollow.stopFollow", self, self.cmdStopFollow)
    BotCommandFactory:registerCommand("BSFollow.dialogAction", self, self.cmdDialogAction)
    BotCommandFactory:tryLoadModule("BSTeleport")
    BotCommandFactory:tryLoadModule("LinkedList")
end

function BSFollow:reset()
  self.masterPath = LinkedList:new()
  self.slavePath = LinkedList:new()
  self.passedPath = LinkedList:new()
  if self.thread then
    StopThread(self.thread)
    self.thread = nil;
    StopThread(self.threadFollow)
    self.threadFollow = nil;
  end
  self.isMoving = false;
  self.lastPassedPoint = nil;
  self.targetId = nil;
end

function BSFollow:cmdStopFollow(jsonCfg)
  if self.thread then
    dprint("Stop follow")
  end
  self:reset();
end


function BSFollow:cmdFollow(jsonCfg)
  self:reset();

  local cfg = json.decode(jsonCfg);
  local setupId = cfg.pos or 1;
  local setup = self.setups[setupId]

  if not setup then
    return eprint("Follow incorrect setup"); 
  end

  for key,val in pairs(setup) do
    self[key] = val;
  end

  self.targetId = nil;
  local targetName = cfg.target 
  local players = GetPlayerList(); 
  for player in players.list do 
    if (player:GetName() == targetName)  then 
      self.targetId = player:GetId();
    end
  end

  if not self.targetId then
    eprint("Not able to find target to follow " .. tostring(targetName))
  else
    dprint("Following " .. targetName .. " setup:"..setupId)
  end

  --local cfg = json.decode(jsonCfg);
  -- self.targetId = GetTarget():GetId();--cfg.target or 0;

  self.followDist = math.random(self.minFollowDist, self.maxFollowDist);
  self.thread = CreateThread(self, self.threadProc)
  self.threadFollow = CreateThread(self, self.followProc)
end

function BSFollow:cmdDialogAction(jsonCfg)
  if  not self.thread then
    return;
  end

  local cfg = json.decode(jsonCfg);

  
  local lastPathPoint = self.masterPath:getLast() or {loc = GetMe():GetLocation(), dir = GetMe():GetRotation().Yaw}
  self.masterPath:addFirst({
        --listNext
        --listPrev
        loc = lastPathPoint.loc,
        dir = lastPathPoint.dir,
        pathDist = 0,
        isKeyPoint = false;
        type = "dialog",
        action = cfg.action, -- "openDialog", "selectDialogItem"
        param = cfg.param, -- according to action: npc to open dialog with; id of item in dialog;
      })
end

function BSFollow:threadProc()
  while EventsBus:waitOn("OnLTick500ms") do
    self:updateMasterPath();
    self:updateSlavePath();
  end
end

function BSFollow:followProc()
  while EventsBus:waitOn("OnLTick") do
    self:follow();
  end
end

function BSFollow:getCurrentPathPoint()
  local point = self.slavePath:getLast();
  if not point then return; end
  
  if not point.shiftedLoc then
    point.shiftedLoc = self:buildShiftedLoc(point)
  end

  return point;
end

function BSFollow:isOnMove()
  return self.slavePath:getLast() ~= nil;
end

function BSFollow:checkUserIsStuck()
  local newUserLoc = GetMe():GetLocation();

  local userIsMooving = not self.lastUserLoc or GetDistanceVector(self.lastUserLoc, newUserLoc) > self.pointReachedTreshhold
  if userIsMooving then
    -- save new user loc
    self.lastUserLoc = newUserLoc;
    self.lastUserLocUpdateTime = GetTime();
    return;
  end

  local idleTime = GetTime() - self.lastUserLocUpdateTime
  if idleTime > 1000 then
    self.isMoving = false;
    self.lastUserLocUpdateTime = GetTime();
    return;
  end

  if self.passedPath:getLast() and idleTime > 3000 then
    self.useMinimalTreshhold = true;

    -- fix current point
    local currentPoint = self.slavePath:getLast()
    currentPoint.shiftedLoc = currentPoint.loc;
    
    -- create go back point
    local returnPoint = self.passedPath:popLast();
    returnPoint.shiftedLoc = returnPoint.loc;
    self.slavePath:addLast(returnPoint)

    self.lastPassedPoint = nil;
    self.lastUserLocUpdateTime = GetTime();
    return
  end
end

function BSFollow:follow()
  if not self:isOnMove() then
    -- and self.lastMasterMoveTime then
    -- local masterIdleTime = GetTime() - self.lastMasterMoveTime;
    -- if masterIdleTime > 1500 then
    --   local target = GetUserById(self.targetId);
    --   if target then
      
    --     local loc = self:buildPointAroundLoc(target:GetLocation(), target:GetRotation().Yaw)
    --     self.slavePath:addFirst({
    --       --listNext
    --       --listPrev
    --       loc = loc,
    --       dir = target:GetRotation().Yaw,
    --       shiftedLoc = loc,
    --       pathDist = passedDist,
    --       isKeyPoint = isAngleBreak;
    --     })
    --   end
    -- end
    return;
  end

  local currentPoint = self:getCurrentPathPoint();
  if currentPoint.type == "dialog" then
      self:processDialogAction(currentPoint);
  else
    self:checkUserIsStuck();

    local currentPoint = self:getCurrentPathPoint();
    self:goToPathPoint(currentPoint);
  end
end

local function saveLink(link)
  table.insert(BSFollow.links, link);
  return "";
end

function TalkThread()
  Talk()
end

function BSFollow:processDialogAction(dialogAction)
  if dialogAction.action == "openDialog" then
    dprint("open dialog")
    SelectTargetByOId(dialogAction.param);

    -- open dialog
    local oldHtml = GetDialogHtml() or "";
    this:StartThread("TalkThread");
    if not EventsBus:waitOn("OnLTick500ms", function () return oldHtml ~= GetDialogHtml() end, 5000) then
      eprint("Fail to open dialog");
    end

    self.slavePath:popLast();
    return;
  end

  -- get last menu items
  local html = GetDialogHtml() or "";
  self.links = {};
  html:gsub("bypass %-h (.-)\"", saveLink)

  if dialogAction.action == "selectDialogItem"
     and self.links and self.links[dialogAction.param]
  then
    dprint("making action ", self.links[dialogAction.param])
    QuestReply(self.links[dialogAction.param]);

  else
    eprint("unable to process dialog action");
  end

  self.slavePath:popLast();
end

function BSFollow:goToPathPoint(currentPoint)
  local distToPoint = GetDistanceVector(currentPoint.shiftedLoc, GetMe():GetLocation());
  local pointReachedTreshhold = self.useMinimalTreshhold and 15 or self.pointReachedTreshhold
  if distToPoint < pointReachedTreshhold then
    -- point reached
    self.isMoving = true;
    self.useMinimalTreshhold = false;
    self.passedPath:addLast(self.slavePath:popLast());
    local nextPathPoint = self:getCurrentPathPoint();
    if not nextPathPoint then -- end of path
      self.isMoving = false;
      return;
    end
    local l = nextPathPoint.shiftedLoc
    MoveToNoWait(l.X, l.Y, l.Z)
  elseif distToPoint > 2500  then
    dprint("point is too far to be part of path")
    self.slavePath:popLast()
  elseif not self.isMoving then
    self.isMoving = true;
    local l = currentPoint.shiftedLoc
    MoveToNoWait(l.X, l.Y, l.Z)
  end
end

function BSFollow:updateMasterPath()
  local target = GetUserById(self.targetId);
  if target then
    local lastPathPoint = self.masterPath:getLast() or {loc = GetMe():GetLocation(), dir = GetMe():GetRotation().Yaw}

    local newLoc = target:GetLocation();
    local passedDist = GetDistanceVector(lastPathPoint.loc, newLoc);

    local newDir = target:GetRotation().Yaw;
    local isAngleBreak = math.abs(math.abs(newDir) - math.abs(lastPathPoint.dir)) > 30 
    if 
      not self.isMoving and GetDistanceVector(newLoc, GetMe():GetLocation()) > self.maxFollowDist
      or (passedDist > self.pathDetailsMaxTrashhold or ( isAngleBreak and passedDist>self.pathDetailsMinTrashhold))
    then
      self.lastMasterMoveTime = GetTime();
      self.masterPath:addFirst({
        --listNext
        --listPrev
        loc = newLoc,
        dir = newDir,
        pathDist = passedDist,
        isKeyPoint = isAngleBreak;
      })
    end
  end
end

function BSFollow:updateSlavePath()
  local curSlaveHead = self.slavePath:getFirst();
  local newSlaveHead = nil;
  local distToSlave = 0;

  -- locate new slave path head
  for pathPoint in self.masterPath:iterate() do
    if pathPoint == curSlaveHead then
      break; end

    if pathPoint.type == "dialog" then
      newSlaveHead = pathPoint
      break;
    elseif distToSlave + pathPoint.pathDist > self.followDist then
      newSlaveHead = pathPoint.listPrev
      break
    else
      distToSlave = distToSlave + pathPoint.pathDist;
    end
  end

  -- copy master path to slave
  if newSlaveHead and curSlaveHead ~= newSlaveHead then
    if not curSlaveHead then
      self.followDist = math.random(self.minFollowDist, self.maxFollowDist);
      dprint("following on dist " .. self.followDist)
      -- pause on start of new path
      -- local delay = math.random(1,5);
      -- ThreadSleepS(delay);
    end

    for pathPoint in self.masterPath:iterateRev() do
      dprint("new Slave point")
      self.slavePath:addFirst(self.masterPath:popLast())
      if pathPoint == newSlaveHead then
        break; end
    end
  end
end

function BSFollow:buildShiftedLoc(pathPoint)
  local shiftedDir = math.rad(pathPoint.dir - 90)
  if pathPoint.isKeyPoint then
    self.keyPointShift = math.random(self.keyPointShiftRangeMin, self.keyPointShiftRangeMax)
  end
  local x = pathPoint.loc.X + self.keyPointShift*math.cos(shiftedDir)
  local y = pathPoint.loc.Y + self.keyPointShift*math.sin(shiftedDir)
  return FVector(x,y,pathPoint.loc.Z);
end

function BSFollow:buildPointAroundLoc(point, dir)
  local shiftedDir = math.rad(dir - math.random(0,180))
  
  local pointShift = math.random(self.keyPointShiftRangeMin, self.keyPointShiftRangeMax+30)

  local x = point.X + pointShift*math.cos(shiftedDir)
  local y = point.Y + pointShift*math.sin(shiftedDir)
  return FVector(x,y,point.Z);
end
