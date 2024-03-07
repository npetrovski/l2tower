local IsEnabled = false;
local PLUGIN_NAME = 'port2';
local PLUGIN_DESCRIPTION = [[


===============================
= Use .port2 command to enable or disable =
===============================

]]

function OnCreate() 
	this:RegisterCommand("port2", CommandChatType.CHAT_ALLY, CommandAccessLevel.ACCESS_ME); 
	ShowToClient(PLUGIN_NAME, PLUGIN_DESCRIPTION, 0x05); 
	UnblockOutgoingPacket(tonumber(string.sub(0x0F, 0, 2), 16));	
end;

function OnDestroy() 
	this:UnregisterCommand("port2"); 
end;

function OnCommand_port2(vCommandChatType, vNick, vCommandParam)
    IsEnabled = not IsEnabled;
	ShowToClient(PLUGIN_NAME, (not IsEnabled) and "Disabled" or "Enabled");
end;

function OnOutgoingPacket(packet) 
	if IsEnabled then
		local _id = packet:GetID();
		
		if (_id == 0x0F) then
		    packet:SetOffset(1);
			
			local x = packet:ReadInt(4);
			local y = packet:ReadInt(4);
			local z = packet:ReadInt(4);
			
			QuestReply(string.format(
				"_bbsscripts:Util:EpicGatekeeper %s %s %s 0", 
				tostring(x), 
				tostring(y), 
				tostring(z))
			);	
		end
	end  
end;


