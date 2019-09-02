
BSRenderMode = {
}

function BSRenderMode:init()
    BotCommandFactory:registerCommand("BSRenderMode.enable", self, self.cmdBlackEnable)
    BotCommandFactory:registerCommand("BSRenderMode.disable", self, self.cmdBlackDisable)
    BotCommandFactory:registerCommand("BSRenderMode.rmode", self, self.cmdSetRenderMode)
end

function BSRenderMode:cmdSetRenderMode(dto)
    local cfg = json.decode(dto);
    local mode = cfg.mode or 9;
    ClientExec("rmode " .. tostring(mode));
end

function BSRenderMode:cmdBlackEnable()
    --ClientExec("FixedDefaultCamera Up");
    --ClientExec("FixedDefaultCamera OnRelease MaxPressedTime=100.0");
    ClientExec("set Engine.LineagePlayerController MaxZoomingDist 65535");
    ClientExec("set Engine.LineagePlayerController MinZoomingDist -65535");
    ClientExec("rmode 1");
    ClientExec("set Engine.LineagePlayerController CameraViewHeightAdjust -65535");
end


function BSRenderMode:cmdBlackDisable()
    ClientExec("set Engine.LineagePlayerController MaxZoomingDist 2000");
    ClientExec("set Engine.LineagePlayerController MinZoomingDist -200");
    ClientExec("rmode 9");
    ClientExec("set Engine.LineagePlayerController CameraViewHeightAdjust 0");
end