AUTOLOOT_CATEGORIES = {
    ["Valuables"] = {2148, 2152, 2160, 27635}, -- Gold, Platinum, Crystal, Diamond
    ["Stones"] = {26731, 26728, 26736, 26734, 26733, 26732, 26730, 26724, 26749, 26725, 26726, 26727, 26748},
    ["Potions"] = {27643, 27641, 27647, 27645},
    ["Others"] = {38787} -- Rare Candy
}

function Player:getAutolootCategories()
    local categories = {}
    for category, _ in pairs(AUTOLOOT_CATEGORIES) do
        table.insert(categories, category)
    end
    return categories
end

function Player:getAutolootItemsByCategory(category)
    local items = AUTOLOOT_CATEGORIES[category] or {}
    local result = {}
    for _, itemId in ipairs(items) do
        local it = ItemType(itemId)
        if it then
            table.insert(result, {id = it:getClientId(), name = it:getName()})
        end
    end
    return result
end

function Player:searchAutolootItems(search)
    local result = {}
    search = search:lower()
    -- This is a bit heavy, but since it's a small server it's fine. 
    -- In a real scenario, we'd have a pre-indexed list.
    for i = 1, 40000 do -- Check first 40k items
        local it = ItemType(i)
        if it and it:getName() ~= "" then
            if it:getName():lower():find(search) then
                table.insert(result, {id = it:getClientId(), name = it:getName()})
                if #result >= 50 then break end -- Limit results
            end
        end
    end
    return result
end
