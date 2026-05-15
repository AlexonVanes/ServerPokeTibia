
function onLogin(player)
	player:forceReturnPokemonOnLogin()
	player:loginHandler()
	player:forceReturnPokemonOnLogin()
	player:migratePokeballsToBallpack()
	player:updateStoredPokemonList()
	player:sendPassData()
	return true
end
