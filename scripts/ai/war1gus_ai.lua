local STATE_GOLD = 5
local STATE_WOOD = 6
local STATE_SUPPLY = 7
local STATE_DEMAND = 8
local STATE_WORKERS = 9
local STATE_CITY_CENTERS = 10
local STATE_BARRACKS = 11
local STATE_LUMBER_MILLS = 12
local STATE_BLACKSMITHS = 13
local STATE_STABLES = 14
local STATE_SOLDIERS = 15
local STATE_SHOOTERS = 16
local STATE_CAVALRY = 17
local STATE_CATAPULTS = 18

local HUMAN_UNITS = {
   worker = "unit-peasant",
   cityCenter = "unit-human-town-hall",
   barracks = "unit-human-barracks",
   lumberMill = "unit-human-lumber-mill",
   blacksmith = "unit-human-blacksmith",
   stables = "unit-human-stable",
   soldier = "unit-footman",
   shooter = "unit-archer",
   cavalry = "unit-knight",
   catapult = "unit-human-catapult"
}

local ORC_UNITS = {
   worker = "unit-peon",
   cityCenter = "unit-orc-town-hall",
   barracks = "unit-orc-barracks",
   lumberMill = "unit-orc-lumber-mill",
   blacksmith = "unit-orc-blacksmith",
   stables = "unit-orc-kennel",
   soldier = "unit-grunt",
   shooter = "unit-spearman",
   cavalry = "unit-raider",
   catapult = "unit-orc-catapult"
}

local COLLECT_GOLD = {0, 60, 40, 0, 0, 0, 0}
local COLLECT_WOOD = {0, 40, 60, 0, 0, 0, 0}

local function ActiveUnitCount(playerIndex, ident)
   return GetPlayerData(playerIndex, "UnitTypesAiActiveCount", ident)
end

local function UnitIdentifiers(race)
   if race == race1 then
      return HUMAN_UNITS
   end
   return ORC_UNITS
end

local function War1gusAiState(playerIndex)
   local race = GetPlayerData(playerIndex, "RaceName")
   local raceId = 1
   if race == race1 then
      raceId = 0
   else
      race = race2
   end
   local units = UnitIdentifiers(race)

   return {
      1,
      playerIndex,
      raceId,
      GameCycle,
      GetPlayerData(playerIndex, "Resources", "gold"),
      GetPlayerData(playerIndex, "Resources", "wood"),
      GetPlayerData(playerIndex, "Supply"),
      GetPlayerData(playerIndex, "Demand"),
      ActiveUnitCount(playerIndex, units.worker),
      ActiveUnitCount(playerIndex, units.cityCenter),
      ActiveUnitCount(playerIndex, units.barracks),
      ActiveUnitCount(playerIndex, units.lumberMill),
      ActiveUnitCount(playerIndex, units.blacksmith),
      ActiveUnitCount(playerIndex, units.stables),
      ActiveUnitCount(playerIndex, units.soldier),
      ActiveUnitCount(playerIndex, units.shooter),
      ActiveUnitCount(playerIndex, units.cavalry),
      ActiveUnitCount(playerIndex, units.catapult)
   }
end

local function EnsureBuildingSpace(playerIndex, state)
   if state[STATE_CITY_CENTERS] == 0 then
      return
   end

   local generated = stratagus.gameData.AIState.war1gusRoadsGenerated
   if not generated[playerIndex] then
      GenerateRoads(true, false)
      generated[playerIndex] = true
   end
end

local function WorkerTarget(state)
   local target = state[STATE_CITY_CENTERS] * 8
   if target < 8 then
      target = 8
   end
   if target > 24 then
      target = 24
   end
   if state[STATE_WORKERS] > target then
      target = state[STATE_WORKERS]
   end
   return target
end

local function ForceSize(state)
   local target = math.floor(WorkerTarget(state) / 3)
   if target < 2 then
      return 2
   end
   if target > 8 then
      return 8
   end
   return target
end

local function FarmTarget(state)
   local target = math.floor((state[STATE_DEMAND] + 4) / 5)
   if target < 1 then
      return 1
   end
   return target
end

local function SetCollection(state)
   if state[STATE_WOOD] < state[STATE_GOLD] then
      AiSetCollect(COLLECT_WOOD)
   else
      AiSetCollect(COLLECT_GOLD)
   end
end

local function MaintainResourceManager(state)
   AiSet(AiCityCenter(), 1)
   AiSet(AiWorker(), WorkerTarget(state))
   AiSetBuildDepots(true)
   SetCollection(state)
   AiForceRole(0, "attack")
   AiForceRole(1, "attack")
   AiForceRole(2, "attack")
   AiForceRole(3, "defend")
end

local function EconomyAction(state)
   AiSet(AiWorker(), WorkerTarget(state))
end

local function SupplyAction(state)
   if state[STATE_DEMAND] + 2 >= state[STATE_SUPPLY] then
      AiSet(AiFarm(), FarmTarget(state))
   else
      EconomyAction(state)
   end
end

local function InfrastructureAction(state)
   if state[STATE_BARRACKS] == 0 then
      AiSet(AiBarracks(), 1)
   elseif state[STATE_LUMBER_MILLS] == 0 then
      AiSet(AiLumberMill(), 1)
   elseif state[STATE_BLACKSMITHS] == 0 then
      AiSet(AiBlacksmith(), 1)
   elseif state[STATE_STABLES] == 0 then
      AiSet(AiStables(), 1)
   else
      AiSet(AiBarracks(), 2)
   end
end

local function BlacksmithAction(state)
   if state[STATE_LUMBER_MILLS] == 0 then
      InfrastructureAction(state)
   else
      AiSet(AiBlacksmith(), 1)
   end
end

local function BasicForceAction(state)
   if state[STATE_BARRACKS] == 0 then
      InfrastructureAction(state)
   else
      local target = ForceSize(state)
      AiForce(0, {AiSoldier(), target, AiShooter(), target})
   end
end

local function CavalryForceAction(state)
   if state[STATE_BARRACKS] == 0 or state[STATE_LUMBER_MILLS] == 0 then
      InfrastructureAction(state)
   elseif state[STATE_BLACKSMITHS] == 0 then
      BlacksmithAction(state)
   elseif state[STATE_STABLES] == 0 then
      AiSet(AiStables(), 1)
   else
      AiForce(1, {AiCavalry(), ForceSize(state)})
   end
end

local function SiegeForceAction(state)
   if state[STATE_BARRACKS] == 0 or state[STATE_LUMBER_MILLS] == 0 then
      InfrastructureAction(state)
   elseif state[STATE_BLACKSMITHS] == 0 then
      BlacksmithAction(state)
   else
      AiForce(2, {AiCatapult(), math.max(1, math.floor(ForceSize(state) / 2))})
   end
end

local function AttackAction(state)
   local combatUnits = state[STATE_SOLDIERS] + state[STATE_SHOOTERS] +
      state[STATE_CAVALRY] + state[STATE_CATAPULTS]
   if combatUnits >= 6 and state[STATE_BARRACKS] > 0 then
      AiAttackWithForces({0, 1, 2})
   else
      BasicForceAction(state)
   end
end

local function ResearchAction(state)
   if state[STATE_BLACKSMITHS] == 0 then
      BlacksmithAction(state)
   else
      AiResearch(AiUpgradeWeapon1())
   end
end

local function DefendAction(state)
   if state[STATE_BLACKSMITHS] == 0 then
      BlacksmithAction(state)
   elseif state[STATE_SOLDIERS] + state[STATE_SHOOTERS] < 2 then
      AiSet(AiTower(), 1)
   else
      AiForce(3, {AiSoldier(), ForceSize(state), AiShooter(), ForceSize(state)})
   end
end

local War1gusAiActions = {
   EconomyAction,
   SupplyAction,
   InfrastructureAction,
   BlacksmithAction,
   BasicForceAction,
   CavalryForceAction,
   SiegeForceAction,
   AttackAction,
   ResearchAction,
   DefendAction
}
local War1gusAiActionNames = {
   "economy",
   "supply",
   "infrastructure",
   "blacksmith",
   "basic-force",
   "cavalry-force",
   "siege-force",
   "attack",
   "research",
   "defend"
}


function War1gusAI()
   local playerIndex = AiPlayer()
   local state = War1gusAiState(playerIndex)
   EnsureBuildingSpace(playerIndex, state)
   MaintainResourceManager(state)

   local handle = GetWar1gusAiProcessor(playerIndex, state)
   if handle == nil then
      EconomyAction(state)
      return
   end

   local action = AiProcessorStep(handle, 0, state)
   local execute = War1gusAiActions[action]
   local command = War1gusAiActionNames[action]
   if execute == nil then
      execute = EconomyAction
      command = "economy (fallback for " .. tostring(action) .. ")"
   end
   local lastCommand = stratagus.gameData.AIState.lastWar1gusAiCommand[playerIndex]
   if command ~= lastCommand then
      print("war1gus-ai player " .. playerIndex .. ": " .. command)
      stratagus.gameData.AIState.lastWar1gusAiCommand[playerIndex] = command
   end
   execute(state)
end

DefineAi("war1gus-ai", "*", "war1gus-ai", War1gusAI)
