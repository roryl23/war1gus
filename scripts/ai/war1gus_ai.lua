function GetAllUnitPositions(player)
    local units = GetUnits(player)
    local positions = {}
    for i, unitId in ipairs(units) do
        local x = GetUnitVariable(unitId, "PosX")
        local y = GetUnitVariable(unitId, "PosY")
        positions[unitId] = {x = x, y = y}
    end
    return positions
end

function GetOtherPlayers()
    local me = AiPlayer()
    local otherPlayers = {}
    local maxPlayers = 16
    for i = 0, maxPlayers - 1 do
        if i ~= me then
            table.insert(otherPlayers, i)
        end
    end
    return otherPlayers
end

function War1gusAI()
    local debug = true
    if stratagus.gameData.AIEngine.thinking == false then
        -- Generate current game state
        local otherPlayers = GetOtherPlayers()
        for playerId, player in ipairs(otherPlayers) do
            if player == nil then
                print("Player is nil!")
            else
                local unitPositions = GetAllUnitPositions(player)
                for unitId, position in pairs(unitPositions) do
                    if debug then
                        print("Unit " .. unitId .. " is at (" .. position.x .. ", " .. position.y .. ")")
                    end
                end
            end
        end
        -- Send current game state to engine
        stratagus.gameData.AIEngine:send("position test")
        stratagus.gameData.AIEngine.thinking = true
    else
        local response = stratagus.gameData.AIEngine.receive()
        if response == nil then
            if debug then
                print("no output from AI engine yet...")
            end
        else
            stratagus.gameData.AIEngine.thinking = false
            if debug then
                print("AI engine response: " .. response)
            end
            local aiFunc, err = loadstring(response)
            if aiFunc then
                return function()
                    AiLoop(aiFunc, stratagus.gameData.AIState.loop_index)
                end
            else
                print("Error loading AI generated Lua code: " .. err)
            end
        end
    end
    return function()
        AiLoop({function() return true end}, stratagus.gameData.AIState.index)
    end
end

DefineAi("war1gus-ai", "*", "war1gus-ai", War1gusAI)
