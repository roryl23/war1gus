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
    -- TODO: these initializations should be configurations
    --       in the menus, or perhaps map properties
    RevealMap("explored")
    local aiEngine = StartWar1gusAiEngine()

    if aiEngine.loop_funcs ~= nil then
        return AiLoop(aiEngine.loop_funcs, stratagus.gameData.AIState.loop_index)
    elseif aiEngine.thinking == false then
        -- TODO: generate gamestate from what can be seen by current units
        -- Generate current game state
        local otherPlayers = GetOtherPlayers()
        for playerId, player in ipairs(otherPlayers) do
            if player == nil then
                print("Player is nil!")
            else
                local unitPositions = GetAllUnitPositions(player)
                for unitId, position in pairs(unitPositions) do
                end
            end
        end
        -- Send current game state to engine
        aiEngine:send("gamestate test")
        aiEngine.thinking = true
    else
        local response = aiEngine:receive()
        if response ~= nil then
            aiEngine.thinking = false
            if debug then
                print("AI engine response: " .. response)
            end
            local responseChunk, err = loadstring(response)
            if not responseChunk then
                error("Error loading AI generated Lua code: " .. err)
            end
            local loopFuncs = responseChunk()
            if type(loopFuncs) ~= "table" then
                error("AI generated Lua code must return a table of step functions")
            end
            aiEngine.loop_funcs = loopFuncs
            stratagus.gameData.AIState.loop_index[AiPlayer() + 1] = 1
            return AiLoop(loopFuncs, stratagus.gameData.AIState.loop_index)
        end
    end
    -- No action taken, so sleep the AI for a bit.
    return AiSleep(5000)
end

DefineAi("war1gus-ai", "*", "war1gus-ai", War1gusAI)
