function onUse(player, item, fromPosition, target, self, toPosition, isHotkey)
    if type(target) ~= "userdata" then return true end

    if target ~= item and target:isCreature() ~= true then return false end

    if target:isCreature() then
        if target:isPlayer() then
            -- Se o alvo é um jogador (incluindo o próprio jogador), abrir a pokedex
            -- Enviar a lista de pokémons descobertos primeiro
            sendDexLists(player)
            
            -- Depois abrir a pokedex
            local buffer = {
                action = "openPokedex"
            }
            local msg = NetworkMessage()
            msg:addByte(50)
            msg:addByte(80)
            msg:addString(json.encode(buffer))
            msg:sendToPlayer(player)
            
            return true
        end
        
        if not target:isMonster() then
            return true
        end
        local name = capitalizeFirstLetter(target:getName())

		if not reverse_pokemons["Bulbasaur"] then
			loadDexInfos()
		end

		local pokemonId = reverse_pokemons[name]
		if not pokemonId then error("Faltando na dex: " .. name) return true  end
		local storage = pokemonId + BASE_STORAGE_DEX

		if player:getStorageValue(storage) == 1 then
       		sendPokedex(player, name)
		else
        	player:getPosition():sendMagicEffect(15)
			player:setStorageValue(storage, 1)
			sendUpdateDex(player, pokemonId)
			player:sendTextMessage(MESSAGE_STATUS_CONSOLE_BLUE, string.format("Parabens, voce descobriu o %s", name))
		end
    end
    return true
end