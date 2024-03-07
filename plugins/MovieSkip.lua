local PLUGIN_NAME = 'MovieSkip';

function OnIncomingPacket(packet)
	if (nil ~= packet) then
		packet:SetOffset(0);
		local _id = packet:GetID();
		local _sub = packet:GetSubID();
		
		--
		-- ExStartScenePlayer
		--
		if (_id == 0xFE and _sub == 0x99) then
		
			packet:SetOffset(0);
			local _movieId = packet:ReadInt(4);
			SendEndScenePlayer(_movieId)
		end

	end
end;

function SendEndScenePlayer(movieId)
	if (movieId > 0) then
		local packet = PacketBuilder();

		packet:AppendInt(0xd0, 1);
		packet:AppendInt(0x5b, 2);
		packet:AppendInt(movieId, 4);
		SendPacket(packet);
		
		ShowToClient(PLUGIN_NAME, "** Movie scene " .. tostring(movieId) .. " skipped. **");
	end;
end;

