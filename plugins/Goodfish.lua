local IsEnabled = false;
local PLUGIN_NAME = 'Goodfish';
local PLUGIN_DESCRIPTION = [[


===============================
= Use .goodfish command to enable or disable =
= the auto-fishing mode. Make sure you have   =
= equiped a rod and a lure.                             =
===============================

]]

function OnCreate() 
	this:RegisterCommand("goodfish", CommandChatType.CHAT_ALLY, CommandAccessLevel.ACCESS_ME); 
	ShowToClient(PLUGIN_NAME, PLUGIN_DESCRIPTION, 0x05); 
end;

function OnDestroy() this:UnregisterCommand("goodfish"); end;

function OnCommand_goodfish(vCommandChatType, vNick, vCommandParam)
    IsEnabled = not IsEnabled;
	ShowToClient(PLUGIN_NAME, (not IsEnabled) and "Disabled" or "Enabled");
	UseFishing()
end;

function OnIncomingPacket(packet)
	if (IsEnabled and nil ~= packet) then
		packet:SetOffset(0);
		local _id = packet:GetID();
		local _sub = packet:GetSubID();
		
		--
		-- ExFishingHpRegen
		--
		if (_id == 0xFE and _sub == 0x28) then
		
			packet:SetOffset(0);
			local _objId = packet:ReadInt(4);
			if (_objId == GetMe():GetId()) then
				
				packet:SetOffset(12);
				local mode = packet:ReadInt(1);
				packet:SetOffset(19);
				local deceptive = packet:ReadInt(1);
				
				if (deceptive == 0) then
					if (mode == 0) then
						UsePump()
					else
						UseReeling()
					end
				else
					if (mode == 0) then
						UseReeling()
					else
						UsePump()
					end

				end
			end
		end
		
		--
		-- ExFishingEnd
		--
		if (_id == 0xFE and _sub == 0x1F) then
			packet:SetOffset(0);
			local _objId = packet:ReadInt(4);
			if (_objId == GetMe():GetId()) then
				UseFishing()
			end
		end
	end
end;

function UsePump()
	UseSkillRaw(1313, false, false);
end;

function UseReeling()
	UseSkillRaw(1314, false, false);
end;

function UseFishing()
	UseSkillRaw(1312, false, false);
end;