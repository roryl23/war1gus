local STATE_VERSION = 1
local STATE_PLAYER = 2
local STATE_RACE = 3
local STATE_CYCLE = 4
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
local STATE_OWN_UNITS = 19
local STATE_OWN_BUILDINGS = 20
local STATE_ENEMY_UNITS = 21
local STATE_ENEMY_BUILDINGS = 22
local STATE_ENEMY_WORKERS = 23
local STATE_ENEMY_CITY_CENTERS = 24
local STATE_ENEMY_BARRACKS = 25
local STATE_ENEMY_LUMBER_MILLS = 26
local STATE_ENEMY_BLACKSMITHS = 27
local STATE_ENEMY_STABLES = 28
local STATE_ENEMY_SOLDIERS = 29
local STATE_ENEMY_SHOOTERS = 30
local STATE_ENEMY_CAVALRY = 31
local STATE_ENEMY_CATAPULTS = 32
local STATE_LEGAL_MASK_LOW = 33
local STATE_LEGAL_MASK_HIGH = 34

local ACTION_WAIT = 0
local ACTION_GATHER_GOLD = 1
local ACTION_GATHER_WOOD = 2
local ACTION_BUILD_TOWN_HALL = 3
local ACTION_TRAIN_WORKER = 4
local ACTION_BUILD_FARM = 5
local ACTION_BUILD_BARRACKS = 6
local ACTION_BUILD_LUMBER_MILL = 7
local ACTION_BUILD_BLACKSMITH = 8
local ACTION_BUILD_STABLES = 9
local ACTION_TRAIN_SOLDIER = 10
local ACTION_TRAIN_SHOOTER = 11
local ACTION_TRAIN_CAVALRY = 12
local ACTION_TRAIN_CATAPULT = 13
local ACTION_RESEARCH_WEAPON = 14
local ACTION_RESEARCH_ARMOR = 15
local ACTION_ATTACK_NEAREST_UNIT = 16
local ACTION_ATTACK_NEAREST_BUILDING = 17
local ACTION_ATTACK_WEAKEST_UNIT = 18
local ACTION_ATTACK_WEAKEST_BUILDING = 19
local ACTION_DEFEND_BASE = 20
local ACTION_EXPLORE = 21
local ACTION_PREPARE_BUILDING_SPACE = 22
local ACTION_REPAIR_BUILDING = 23

local UINT32_MAX = 4294967295

local HUMAN_UNITS = {
   worker = "unit-peasant",
   cityCenter = "unit-human-town-hall",
   farm = "unit-human-farm",
   barracks = "unit-human-barracks",
   lumberMill = "unit-human-lumber-mill",
   blacksmith = "unit-human-blacksmith",
   stables = "unit-human-stable",
   soldier = "unit-footman",
   shooter = "unit-archer",
   cavalry = "unit-knight",
   catapult = "unit-human-catapult",
   weaponUpgrade = "upgrade-sword1",
   armorUpgrade = "upgrade-human-shield1"
}

local ORC_UNITS = {
   worker = "unit-peon",
   cityCenter = "unit-orc-town-hall",
   farm = "unit-orc-farm",
   barracks = "unit-orc-barracks",
   lumberMill = "unit-orc-lumber-mill",
   blacksmith = "unit-orc-blacksmith",
   stables = "unit-orc-kennel",
   soldier = "unit-grunt",
   shooter = "unit-spearman",
   cavalry = "unit-raider",
   catapult = "unit-orc-catapult",
   weaponUpgrade = "upgrade-axe1",
   armorUpgrade = "upgrade-orc-shield1"
}

local UNIT_ROLES = {
   ["unit-peasant"] = "worker",
   ["unit-peon"] = "worker",
   ["unit-human-town-hall"] = "cityCenter",
   ["unit-human-first-town-hall"] = "cityCenter",
   ["unit-human-stormwind-keep"] = "cityCenter",
   ["unit-orc-town-hall"] = "cityCenter",
   ["unit-orc-first-town-hall"] = "cityCenter",
   ["unit-orc-blackrock-spire"] = "cityCenter",
   ["unit-human-barracks"] = "barracks",
   ["unit-orc-barracks"] = "barracks",
   ["unit-human-lumber-mill"] = "lumberMill",
   ["unit-orc-lumber-mill"] = "lumberMill",
   ["unit-human-blacksmith"] = "blacksmith",
   ["unit-orc-blacksmith"] = "blacksmith",
   ["unit-human-stable"] = "stables",
   ["unit-orc-kennel"] = "stables",
   ["unit-footman"] = "soldier",
   ["unit-grunt"] = "soldier",
   ["unit-archer"] = "shooter",
   ["unit-spearman"] = "shooter",
   ["unit-knight"] = "cavalry",
   ["unit-raider"] = "cavalry",
   ["unit-human-catapult"] = "catapult",
   ["unit-orc-catapult"] = "catapult"
}

local ACTION_NAMES = {
   "wait",
   "gather-gold",
   "gather-wood",
   "build-town-hall",
   "train-worker",
   "build-farm",
   "build-barracks",
   "build-lumber-mill",
   "build-blacksmith",
   "build-stables",
   "train-soldier",
   "train-shooter",
   "train-cavalry",
   "train-catapult",
   "research-weapon",
   "research-armor",
   "attack-nearest-unit",
   "attack-nearest-building",
   "attack-weakest-unit",
   "attack-weakest-building",
   "defend-base",
   "explore",
   "prepare-building-space",
   "repair-building"
}

local function UInt32(value)
   value = tonumber(value) or 0
   if value <= 0 or value ~= value then
      return 0
   end
   value = math.floor(value)
   if value > UINT32_MAX then
      return UINT32_MAX
   end
   return value
end

local function ClampReward(value)
   if value < -1000 then
      return -1000
   end
   if value > 1000 then
      return 1000
   end
   return value
end

local function Round(value)
   if value < 0 then
      return math.ceil(value - 0.5)
   end
   return math.floor(value + 0.5)
end

local function UnitIdentifiers(race)
   if race == race1 then
      return HUMAN_UNITS
   end
   return ORC_UNITS
end

local function SortBySlot(units)
   table.sort(units, function(left, right)
      return left.slot < right.slot
   end)
end

local UNIT_METADATA = {}

local function UnitMetadata(slot, ident)
   local metadata = UNIT_METADATA[ident]
   if metadata == nil then
      metadata = {
         building = GetUnitBoolFlag(slot, "Building"),
         wall = GetUnitBoolFlag(slot, "Wall"),
         canAttack = GetUnitTypeData(ident, "CanAttack"),
         resource = GetUnitTypeData(ident, "GivesResource")
      }
      UNIT_METADATA[ident] = metadata
   end
   return metadata
end

local function ReadUnit(slot)
   local hitPoints = GetUnitVariable(slot, "HitPoints")
   if hitPoints == nil or hitPoints <= 0 or not GetUnitVariable(slot, "Active") then
      return nil
   end

   local ident = GetUnitVariable(slot, "Ident")
   if ident == nil then
      return nil
   end

   local metadata = UnitMetadata(slot, ident)

   return {
      slot = slot,
      owner = GetUnitVariable(slot, "Player"),
      ident = ident,
      role = UNIT_ROLES[ident],
      idle = GetUnitVariable(slot, "Idle"),
      x = GetUnitVariable(slot, "PosX"),
      y = GetUnitVariable(slot, "PosY"),
      hitPoints = hitPoints,
      maxHitPoints = GetUnitVariable(slot, "HitPoints", "Max"),
      building = metadata.building,
      wall = metadata.wall,
      canAttack = metadata.canAttack,
      resource = metadata.resource
   }
end

local function IsEnemy(playerIndex, owner)
   if owner == playerIndex or Players[playerIndex] == nil or Players[owner] == nil then
      return false
   end
   return Players[playerIndex]:IsEnemy(Players[owner])
end

local function NewWorldSnapshot(playerIndex)
   local world = {
      playerIndex = playerIndex,
      gold = GetPlayerData(playerIndex, "Resources", "gold"),
      wood = GetPlayerData(playerIndex, "Resources", "wood"),
      supply = GetPlayerData(playerIndex, "Supply"),
      demand = GetPlayerData(playerIndex, "Demand"),
      own = {},
      ownMobile = {},
      workers = {},
      cityCenters = {},
      barracks = {},
      blacksmiths = {},
      attackers = {},
      ownBuildings = {},
      enemyUnits = {},
      enemyBuildings = {},
      resources = {},
      counts = {
         ownUnits = 0,
         ownBuildings = 0,
         enemyUnits = 0,
         enemyBuildings = 0,
         own = {},
         enemy = {}
      }
   }

   for _, slot in ipairs(GetUnits("any")) do
      local unit = ReadUnit(slot)
      if unit ~= nil then
         local own = unit.owner == playerIndex
         local enemy = IsEnemy(playerIndex, unit.owner)
         if own or enemy then
            local counts = own and world.counts.own or world.counts.enemy
            if unit.role ~= nil then
               counts[unit.role] = (counts[unit.role] or 0) + 1
            end

            if not unit.wall then
               if unit.building then
                  if own then
                     world.counts.ownBuildings = world.counts.ownBuildings + 1
                  else
                     world.counts.enemyBuildings = world.counts.enemyBuildings + 1
                  end
               elseif own then
                  world.counts.ownUnits = world.counts.ownUnits + 1
               else
                  world.counts.enemyUnits = world.counts.enemyUnits + 1
               end
            end
         end

         if own then
            table.insert(world.own, unit)
            if unit.building then
               table.insert(world.ownBuildings, unit)
            else
               table.insert(world.ownMobile, unit)
               if unit.canAttack then
                  table.insert(world.attackers, unit)
               end
            end
            if unit.role == "worker" then
               table.insert(world.workers, unit)
            elseif unit.role == "cityCenter" then
               table.insert(world.cityCenters, unit)
            elseif unit.role == "barracks" then
               table.insert(world.barracks, unit)
            elseif unit.role == "blacksmith" then
               table.insert(world.blacksmiths, unit)
            end
         elseif enemy and not unit.wall then
            if unit.building then
               table.insert(world.enemyBuildings, unit)
            else
               table.insert(world.enemyUnits, unit)
            end
         elseif not own and unit.resource == "gold" then
            table.insert(world.resources, unit)
         end
      end
   end

   SortBySlot(world.own)
   SortBySlot(world.ownMobile)
   SortBySlot(world.workers)
   SortBySlot(world.cityCenters)
   SortBySlot(world.barracks)
   SortBySlot(world.blacksmiths)
   SortBySlot(world.attackers)
   SortBySlot(world.ownBuildings)
   SortBySlot(world.enemyUnits)
   SortBySlot(world.enemyBuildings)
   SortBySlot(world.resources)
   return world
end

local function DistanceSquared(first, second)
   local x = first.x - second.x
   local y = first.y - second.y
   return x * x + y * y
end

local function FirstUnit(units)
   return units[1]
end
local function IdleUnits(units)
   local idle = {}
   for _, unit in ipairs(units) do
      if unit.idle then
         table.insert(idle, unit)
      end
   end
   return idle
end

local function CanAfford(world, ident)
   return world.gold >= GetUnitTypeData(ident, "Costs", "gold") and
      world.wood >= GetUnitTypeData(ident, "Costs", "wood")
end

local function NearestPair(actors, targets)
   local result = nil
   for _, actor in ipairs(actors) do
      for _, target in ipairs(targets) do
         local distance = DistanceSquared(actor, target)
         if result == nil or distance < result.distance or
            (distance == result.distance and
             (actor.slot < result.actor.slot or
              (actor.slot == result.actor.slot and target.slot < result.target.slot))) then
            result = {actor = actor, target = target, distance = distance}
         end
      end
   end
   return result
end


local function WeakestPair(actors, targets)
   local result = nil
   for _, actor in ipairs(actors) do
      for _, target in ipairs(targets) do
         local distance = DistanceSquared(actor, target)
         if result == nil or
            target.hitPoints * result.target.maxHitPoints < result.target.hitPoints * target.maxHitPoints or
            (target.hitPoints * result.target.maxHitPoints == result.target.hitPoints * target.maxHitPoints and
             (distance < result.distance or
              (distance == result.distance and
               (actor.slot < result.actor.slot or
                (actor.slot == result.actor.slot and target.slot < result.target.slot))))) then
            result = {actor = actor, target = target, distance = distance}
         end
      end
   end
   return result
end

local function FindNearestForest(worker)
   local width = Map.Info.MapWidth
   local height = Map.Info.MapHeight
   local limit = math.max(width, height)
   local result = nil

   for radius = 0, limit do
      if result ~= nil and radius * radius > result.distance then
         break
      end

      local minX = math.max(0, worker.x - radius)
      local maxX = math.min(width - 1, worker.x + radius)
      local minY = math.max(0, worker.y - radius)
      local maxY = math.min(height - 1, worker.y + radius)
      local function consider(x, y)
         if GetTileTerrainHasFlag(x, y, "forest") then
            local dx = worker.x - x
            local dy = worker.y - y
            local distance = dx * dx + dy * dy
            if result == nil or distance < result.distance or
               (distance == result.distance and
                (y < result.y or (y == result.y and x < result.x))) then
               result = {x = x, y = y, distance = distance}
            end
         end
      end

      for x = minX, maxX do
         consider(x, minY)
         if maxY ~= minY then
            consider(x, maxY)
         end
      end
      for y = minY + 1, maxY - 1 do
         consider(minX, y)
         if maxX ~= minX then
            consider(maxX, y)
         end
      end
   end
   return result
end

local function WoodHarvestPlan(world)
   local result = nil
   for _, worker in ipairs(world.workers) do
      local forest = FindNearestForest(worker)
      if forest ~= nil and
         (result == nil or forest.distance < result.distance or
          (forest.distance == result.distance and
           (worker.slot < result.actor.slot or
            (worker.slot == result.actor.slot and
             (forest.y < result.position.y or
              (forest.y == result.position.y and forest.x < result.position.x)))))) then
         result = {actor = worker, position = forest, distance = forest.distance}
      end
   end
   return result
end

local function DirectPlan(actor, verb, argument)
   if actor == nil then
      return nil
   end
   return {kind = "direct", actor = actor, verb = verb, argument = argument}
end

local function BuildActionPlans(world, units)
   local plans = {}
   local workers = IdleUnits(world.workers)
   local attackers = IdleUnits(world.attackers)
   local gold = NearestPair(workers, world.resources)
   local wood = WoodHarvestPlan({workers = workers})
   local attackUnit = NearestPair(attackers, world.enemyUnits)
   local attackBuilding = NearestPair(attackers, world.enemyBuildings)
   local weakestUnit = WeakestPair(attackers, world.enemyUnits)
   local weakestBuilding = WeakestPair(attackers, world.enemyBuildings)
   local defend = NearestPair(attackers, world.cityCenters)
   local repair = {}
   for _, building in ipairs(world.ownBuildings) do
      if building.hitPoints < building.maxHitPoints then
         table.insert(repair, building)
      end
   end
   local repairPair = NearestPair(workers, repair)
   local own = world.counts.own
   local hasSupply = world.demand < world.supply

   if gold ~= nil then
      plans[ACTION_GATHER_GOLD] = DirectPlan(gold.actor, "resource", gold.target.slot)
   end
   if wood ~= nil then
      plans[ACTION_GATHER_WOOD] = DirectPlan(
         wood.actor,
         "resource-location",
         {wood.position.x, wood.position.y}
      )
   end
   if (own.cityCenter or 0) == 0 and CanAfford(world, units.cityCenter) then
      plans[ACTION_BUILD_TOWN_HALL] = DirectPlan(FirstUnit(workers), "build", units.cityCenter)
   end
   if hasSupply and (own.worker or 0) < 8 and CanAfford(world, units.worker) then
      plans[ACTION_TRAIN_WORKER] = DirectPlan(FirstUnit(IdleUnits(world.cityCenters)), "train", units.worker)
   end
   if world.demand + 2 >= world.supply and CanAfford(world, units.farm) then
      plans[ACTION_BUILD_FARM] = DirectPlan(FirstUnit(workers), "build", units.farm)
   end
   if #world.cityCenters > 0 and (own.barracks or 0) == 0 and CanAfford(world, units.barracks) then
      plans[ACTION_BUILD_BARRACKS] = DirectPlan(FirstUnit(workers), "build", units.barracks)
   end
   if (own.barracks or 0) > 0 and (own.lumberMill or 0) == 0 and CanAfford(world, units.lumberMill) then
      plans[ACTION_BUILD_LUMBER_MILL] = DirectPlan(FirstUnit(workers), "build", units.lumberMill)
   end
   if (own.lumberMill or 0) > 0 and (own.blacksmith or 0) == 0 and CanAfford(world, units.blacksmith) then
      plans[ACTION_BUILD_BLACKSMITH] = DirectPlan(FirstUnit(workers), "build", units.blacksmith)
   end
   if (own.blacksmith or 0) > 0 and (own.stables or 0) == 0 and CanAfford(world, units.stables) then
      plans[ACTION_BUILD_STABLES] = DirectPlan(FirstUnit(workers), "build", units.stables)
   end
   local barracks = FirstUnit(IdleUnits(world.barracks))
   if hasSupply and CanAfford(world, units.soldier) then
      plans[ACTION_TRAIN_SOLDIER] = DirectPlan(barracks, "train", units.soldier)
   end
   if hasSupply and (own.lumberMill or 0) > 0 and CanAfford(world, units.shooter) then
      plans[ACTION_TRAIN_SHOOTER] = DirectPlan(barracks, "train", units.shooter)
   end
   if hasSupply and (own.stables or 0) > 0 and CanAfford(world, units.cavalry) then
      plans[ACTION_TRAIN_CAVALRY] = DirectPlan(barracks, "train", units.cavalry)
   end
   if hasSupply and (own.blacksmith or 0) > 0 and CanAfford(world, units.catapult) then
      plans[ACTION_TRAIN_CATAPULT] = DirectPlan(barracks, "train", units.catapult)
   end
   plans[ACTION_RESEARCH_WEAPON] = DirectPlan(FirstUnit(IdleUnits(world.blacksmiths)), "research", units.weaponUpgrade)
   plans[ACTION_RESEARCH_ARMOR] = DirectPlan(FirstUnit(IdleUnits(world.blacksmiths)), "research", units.armorUpgrade)
   if attackUnit ~= nil then
      plans[ACTION_ATTACK_NEAREST_UNIT] = DirectPlan(attackUnit.actor, "attack", attackUnit.target.slot)
   end
   if attackBuilding ~= nil then
      plans[ACTION_ATTACK_NEAREST_BUILDING] = DirectPlan(attackBuilding.actor, "attack", attackBuilding.target.slot)
   end
   if weakestUnit ~= nil then
      plans[ACTION_ATTACK_WEAKEST_UNIT] = DirectPlan(weakestUnit.actor, "attack", weakestUnit.target.slot)
   end
   if weakestBuilding ~= nil then
      plans[ACTION_ATTACK_WEAKEST_BUILDING] = DirectPlan(weakestBuilding.actor, "attack", weakestBuilding.target.slot)
   end
   if defend ~= nil then
      plans[ACTION_DEFEND_BASE] = DirectPlan(
         defend.actor,
         "move",
         {defend.target.x, defend.target.y}
      )
   end
   plans[ACTION_EXPLORE] = DirectPlan(FirstUnit(IdleUnits(world.ownMobile)), "explore")
   if #world.cityCenters > 0 and not stratagus.gameData.AIState.war1gusRoadsGenerated[world.playerIndex] then
      plans[ACTION_PREPARE_BUILDING_SPACE] = {kind = "roads"}
   end
   if repairPair ~= nil then
      plans[ACTION_REPAIR_BUILDING] = DirectPlan(repairPair.actor, "repair", repairPair.target.slot)
   end
   return plans
end

local function BuildLegalMask(plans)
   local mask = 1
   for action = ACTION_GATHER_GOLD, ACTION_REPAIR_BUILDING do
      if plans[action] ~= nil then
         mask = mask + 2 ^ action
      end
   end
   return mask
end

local function Count(counts, role)
   return counts[role] or 0
end

local function War1gusAiObservation(playerIndex)
   local race = GetPlayerData(playerIndex, "RaceName")
   local raceId = 1
   if race == race1 then
      raceId = 0
   else
      race = race2
   end
   local world = NewWorldSnapshot(playerIndex)
   local plans = BuildActionPlans(world, UnitIdentifiers(race))
   local own = world.counts.own
   local enemy = world.counts.enemy
   local state = {
      2,
      UInt32(playerIndex),
      raceId,
      UInt32(GameCycle),
      UInt32(GetPlayerData(playerIndex, "Resources", "gold")),
      UInt32(GetPlayerData(playerIndex, "Resources", "wood")),
      UInt32(GetPlayerData(playerIndex, "Supply")),
      UInt32(GetPlayerData(playerIndex, "Demand")),
      UInt32(Count(own, "worker")),
      UInt32(Count(own, "cityCenter")),
      UInt32(Count(own, "barracks")),
      UInt32(Count(own, "lumberMill")),
      UInt32(Count(own, "blacksmith")),
      UInt32(Count(own, "stables")),
      UInt32(Count(own, "soldier")),
      UInt32(Count(own, "shooter")),
      UInt32(Count(own, "cavalry")),
      UInt32(Count(own, "catapult")),
      UInt32(world.counts.ownUnits),
      UInt32(world.counts.ownBuildings),
      UInt32(world.counts.enemyUnits),
      UInt32(world.counts.enemyBuildings),
      UInt32(Count(enemy, "worker")),
      UInt32(Count(enemy, "cityCenter")),
      UInt32(Count(enemy, "barracks")),
      UInt32(Count(enemy, "lumberMill")),
      UInt32(Count(enemy, "blacksmith")),
      UInt32(Count(enemy, "stables")),
      UInt32(Count(enemy, "soldier")),
      UInt32(Count(enemy, "shooter")),
      UInt32(Count(enemy, "cavalry")),
      UInt32(Count(enemy, "catapult")),
      UInt32(BuildLegalMask(plans)),
      0
   }
   return state, plans
end

function War1gusAiFinalState(playerIndex)
   local state = War1gusAiObservation(playerIndex)
   return state
end

local function Masses(state)
   return UInt32(state[STATE_ENEMY_UNITS]) + 2 * UInt32(state[STATE_ENEMY_BUILDINGS]),
      UInt32(state[STATE_OWN_UNITS]) + 2 * UInt32(state[STATE_OWN_BUILDINGS])
end

local function RewardBook(playerIndex, state)
   local enemyMass, ownMass = Masses(state)
   local books = stratagus.gameData.AIState.war1gusRewardBookkeeping
   local book = books[playerIndex]
   if book == nil then
      book = {
         initialEnemy = enemyMass,
         initialOwn = ownMass,
         previousEnemy = enemyMass,
         previousOwn = ownMass
      }
      books[playerIndex] = book
      return nil, enemyMass, ownMass
   end
   return book, enemyMass, ownMass
end

local function UpdateRewardBook(book, enemyMass, ownMass)
   book.previousEnemy = enemyMass
   book.previousOwn = ownMass
end

local function War1gusAiStepReward(playerIndex, state)
   local book, enemyMass, ownMass = RewardBook(playerIndex, state)
   if book == nil then
      return 0
   end

   local enemyDelta = book.previousEnemy - enemyMass
   local ownLoss = math.max(book.previousOwn - ownMass, 0)
   local idlePenalty = 0
   if enemyDelta <= 0 and ownLoss <= 0 then
      idlePenalty = 2
   end
   local reward = Round(
      800 * enemyDelta / math.max(book.initialEnemy, 1) -
      350 * ownLoss / math.max(book.initialOwn, 1) -
      idlePenalty
   )
   UpdateRewardBook(book, enemyMass, ownMass)
   return ClampReward(reward)
end

function War1gusAiTerminalReward(playerIndex, state)
   if type(state) ~= "table" then
      state = War1gusAiFinalState(playerIndex)
   end

   local book, enemyMass, ownMass = RewardBook(playerIndex, state)
   local reward = 0
   if book ~= nil then
      local enemyDelta = book.previousEnemy - enemyMass
      local ownLoss = math.max(book.previousOwn - ownMass, 0)
      reward = Round(
         800 * enemyDelta / math.max(book.initialEnemy, 1) -
         350 * ownLoss / math.max(book.initialOwn, 1)
      )
      UpdateRewardBook(book, enemyMass, ownMass)
   end

   if GetPlayerData(playerIndex, "TotalNumUnits") == 0 then
      reward = reward - 1000
   elseif enemyMass == 0 and GetNumOpponents(playerIndex) == 0 then
      reward = reward + 1000
   end
   return ClampReward(reward)
end

local function IsLegal(mask, action)
   return math.floor(mask / (2 ^ action)) % 2 == 1
end

local function LogCommand(playerIndex, command)
   local commands = stratagus.gameData.AIState.lastWar1gusAiCommand
   if commands[playerIndex] ~= command then
      print("war1gus-ai player " .. playerIndex .. ": " .. command)
      commands[playerIndex] = command
   end
end

local function WaitWithLog(playerIndex, message)
   print("war1gus-ai player " .. playerIndex .. ": " .. message .. "; wait")
end

local function ExecuteAction(playerIndex, action, plans)
   if action == ACTION_WAIT then
      return true
   end

   local plan = plans[action]
   if plan == nil then
      return false
   end
   if plan.kind == "roads" then
      GenerateRoads(true, false)
      stratagus.gameData.AIState.war1gusRoadsGenerated[playerIndex] = true
      return true
   end
   if plan.argument == nil then
      return AiDirectCommand(playerIndex, plan.actor.slot, plan.verb)
   end
   return AiDirectCommand(playerIndex, plan.actor.slot, plan.verb, plan.argument)
end

function War1gusAI()
   local playerIndex = AiPlayer()
   local state, plans = War1gusAiObservation(playerIndex)
   local reward = War1gusAiStepReward(playerIndex, state)
   local handle = GetWar1gusAiProcessor(playerIndex, state)
   if handle == nil then
      WaitWithLog(playerIndex, "server unavailable")
      return
   end

   local action = AiProcessorStep(handle, reward, state)
   if type(action) ~= "number" or action ~= math.floor(action) or action < 1 or action > #ACTION_NAMES then
      WaitWithLog(playerIndex, "invalid server action " .. tostring(action))
      return
   end

   local wireAction = action - 1
   if not IsLegal(state[STATE_LEGAL_MASK_LOW], wireAction) then
      WaitWithLog(playerIndex, "illegal server action " .. ACTION_NAMES[action])
      return
   end

   if ExecuteAction(playerIndex, wireAction, plans) then
      LogCommand(playerIndex, ACTION_NAMES[action])
   else
      WaitWithLog(playerIndex, "rejected server action " .. ACTION_NAMES[action])
   end
end

DefineAi("war1gus-ai", "*", "war1gus-ai", War1gusAI)
