local STATE_REWARD_ENEMY_PROGRESS = 19
local STATE_REWARD_OWN_LOSS = 20
local STATE_REWARD_TIME = 21
local STATE_REWARD_TERMINAL = 22

local UINT32_MODULUS = 4294967296
local INT32_SIGN = 2147483648
local MAX_ASYNC_RESPONSE_AGE = 499
local MAX_PAGE_CHOICES = 509 -- wait plus up to two navigation choices
local MAX_STATE_WORDS = 1048576 -- shared v3 frame cap with engine and server
local REJECTION_REWARD = -5
local VERBOSE_LOGGING = os.getenv("WAR1GUS_AI_VERBOSE_LOG") == "1"

local KIND_WAIT = 0
local KIND_ACTOR = 13
local KIND_ACTION = 14
local KIND_ENTITY = 15
local KIND_X = 16
local KIND_Y = 17
local KIND_PAGE = 18

local RELATION_OWN = 0
local RELATION_ENEMY = 1
local RELATION_NEUTRAL = 2
local RESOURCE_NONE = 0
local RESOURCE_GOLD = 1
local RESOURCE_WOOD = 2
local OPENING_MINE_RADIUS = 12 -- legal town-hall sites near a mine, never a substitute for the build rule
local OPENING_BUILD_TIMEOUT = 1800 -- release a worker whose hall order never finishes


-- These describe observations only; they do not restrict which actors can act.
local UNIT_ROLES = {
   ["unit-peasant"] = 1, ["unit-peon"] = 1,
   ["unit-human-town-hall"] = 2, ["unit-human-first-town-hall"] = 2,
   ["unit-human-stormwind-keep"] = 2, ["unit-orc-town-hall"] = 2,
   ["unit-orc-first-town-hall"] = 2, ["unit-orc-blackrock-spire"] = 2,
   ["unit-human-farm"] = 3, ["unit-orc-farm"] = 3,
   ["unit-human-barracks"] = 4, ["unit-orc-barracks"] = 4,
   ["unit-human-lumber-mill"] = 5, ["unit-orc-lumber-mill"] = 5,
   ["unit-human-blacksmith"] = 6, ["unit-orc-blacksmith"] = 6,
   ["unit-human-stable"] = 7, ["unit-orc-kennel"] = 7,
   ["unit-footman"] = 8, ["unit-grunt"] = 8,
   ["unit-archer"] = 9, ["unit-spearman"] = 9,
   ["unit-knight"] = 10, ["unit-raider"] = 10,
   ["unit-human-catapult"] = 11, ["unit-orc-catapult"] = 11,
   ["unit-human-church"] = 12, ["unit-orc-temple"] = 12,
   ["unit-human-tower"] = 13, ["unit-orc-tower"] = 13,
   ["unit-road"] = 14,
   ["unit-cleric"] = 15, ["unit-necrolyte"] = 15,
   ["unit-conjurer"] = 16, ["unit-warlock"] = 16,
   ["unit-sorceress"] = 16
}

-- Shared orders are offered for every actor, including buildings. The engine,
-- not this list, decides whether any particular actor may execute an order.
local PRIMITIVE_ACTIONS = {
   {verb = "stop", target = "none"},
   {verb = "stand-ground", target = "none"},
   {verb = "explore", target = "position"},
   {verb = "cancel-build", target = "none"},
   {verb = "cancel-research", target = "none"},
   {verb = "cancel-upgrade-to", target = "none"},
   {verb = "cancel-training", target = "none"},
   {verb = "move", target = "position"},
   {verb = "patrol", target = "position"},
   {verb = "attack-ground", target = "position"},
   {verb = "resource-location", target = "position"},
   {verb = "unload", target = "position"},
   {verb = "attack", target = "entity"},
   {verb = "follow", target = "entity"},
   {verb = "resource", target = "entity"},
   {verb = "repair", target = "entity"},
   {verb = "board", target = "entity"},
   {verb = "return-goods", target = "entity"}
}
local CATALOG_TARGETS = {
   ["build-at"] = "position", ["cast-position"] = "position",
   ["cast-unit"] = "entity", ["cast-self"] = "none", ["train"] = "none",
   ["research"] = "none", ["upgrade-to"] = "none"
}
local UNIT_METADATA = {}

local function Number(value)
   value = tonumber(value)
   if value == nil or value ~= value then return 0 end
   return value
end

local function UInt32(value)
   value = math.floor(Number(value)) % UINT32_MODULUS
   if value < 0 then value = value + UINT32_MODULUS end
   return value
end

local function NonNegativeWord(value)
   return UInt32(math.max(0, Number(value)))
end

local function Signed32(word)
   word = UInt32(word)
   if word >= INT32_SIGN then return word - UINT32_MODULUS end
   return word
end

local function Round(value)
   if value < 0 then return math.ceil(value - 0.5) end
   return math.floor(value + 0.5)
end

local function ClampReward(value)
   return math.max(-1000, math.min(1000, value))
end

local function JsonString(value)
   value = tostring(value)
   value = string.gsub(value, "\\", "\\\\")
   value = string.gsub(value, "\"", "\\\"")
   value = string.gsub(value, "\n", "\\n")
   value = string.gsub(value, "\r", "\\r")
   return "\"" .. value .. "\""
end

function War1gusAiLog(eventType, fields)
   local output = {"{\"type\":" .. JsonString(eventType)}
   for _, field in ipairs(fields or {}) do
      table.insert(output, ",\"" .. field.name .. "\":" .. field.value)
   end
   table.insert(output, "}")
   print(table.concat(output))
end

local function Xor32(left, right)
   left, right = UInt32(left), UInt32(right)
   local result, bit = 0, 1
   for _ = 1, 32 do
      if left % 2 ~= right % 2 then result = result + bit end
      left, right, bit = math.floor(left / 2), math.floor(right / 2), bit * 2
   end
   return result
end

local function StableHash32(value)
   local hash = 2166136261
   for index = 1, string.len(value) do
      hash = Xor32(hash, string.byte(value, index))
      local low = hash % 65536
      local high = math.floor(hash / 65536)
      local product = low * 403
      hash = product % 65536 +
         (math.floor(product / 65536) + low * 256 + high * 403) % 65536 * 65536
   end
   return hash
end

local function TypeMetadata(ident)
   local metadata = UNIT_METADATA[ident]
   if metadata == nil then
      metadata = {
         hash = StableHash32(ident),
         building = GetUnitTypeData(ident, "Building"),
         canAttack = GetUnitTypeData(ident, "CanAttack"),
         resource = GetUnitTypeData(ident, "GivesResource"),
         goldCost = Number(GetUnitTypeData(ident, "Costs", "gold")),
         woodCost = Number(GetUnitTypeData(ident, "Costs", "wood")),
         attackRange = Number(GetUnitTypeData(ident, "MaxAttackRange"))
      }
      UNIT_METADATA[ident] = metadata
   end
   return metadata
end

local function ResourceKind(resource)
   if resource == "gold" then return RESOURCE_GOLD end
   if resource == "wood" or resource == "lumber" then return RESOURCE_WOOD end
   return RESOURCE_NONE
end

local function ReadUnit(slot)
   local ident = GetUnitVariable(slot, "Ident")
   if ident == nil then return nil end
   local hp = Number(GetUnitVariable(slot, "HitPoints"))
   local metadata = TypeMetadata(ident)
   local attackRange = Number(GetUnitVariable(slot, "AttackRange"))
   if attackRange <= 0 then attackRange = metadata.attackRange end
   return {
      slot = slot, ident = ident,
      owner = Number(GetUnitVariable(slot, "Player")),
      x = Number(GetUnitVariable(slot, "PosX")),
      y = Number(GetUnitVariable(slot, "PosY")),
      hp = hp,
      maxHp = math.max(Number(GetUnitVariable(slot, "HitPoints", "Max")), 1),
      idle = GetUnitVariable(slot, "Idle"),
      building = metadata.building,
      wall = GetUnitBoolFlag(slot, "Wall"),
      canAttack = metadata.canAttack,
      resourceKind = ResourceKind(metadata.resource),
      goldCost = metadata.goldCost, woodCost = metadata.woodCost,
      hash = metadata.hash, attackRange = attackRange,
      sightRange = Number(GetUnitVariable(slot, "SightRange")),
      role = UNIT_ROLES[ident] or 0
   }
end

local function NewWorldSnapshot(playerIndex)
   local world = {
      playerIndex = playerIndex,
      gold = Number(GetPlayerData(playerIndex, "Resources", "gold")),
      wood = Number(GetPlayerData(playerIndex, "Resources", "wood")),
      supply = Number(GetPlayerData(playerIndex, "Supply")),
      demand = Number(GetPlayerData(playerIndex, "Demand")),
      width = Number(Map.Info.MapWidth), height = Number(Map.Info.MapHeight),
      entities = {}, own = {}, enemy = {}, bySlot = {},
      ownAssets = {}, enemyAssets = {}, hasHall = false
   }
   for _, slot in ipairs(GetUnits("any")) do
      local unit = ReadUnit(slot)
      if unit ~= nil then
         if unit.owner == playerIndex then
            if unit.role == 2 then world.hasHall = true end
            unit.relation = RELATION_OWN
            world.ownAssets[#world.ownAssets + 1] = unit
         elseif Players[playerIndex] ~= nil and Players[unit.owner] ~= nil and
            Players[playerIndex]:IsEnemy(Players[unit.owner]) then
            unit.relation = RELATION_ENEMY
            world.enemyAssets[#world.enemyAssets + 1] = unit
         else
            unit.relation = RELATION_NEUTRAL
         end
         -- Cargo still counts toward owned/enemy assets, but only units that
         -- the host confirms alive on the map become observable actors/targets.
         if AiUnitOnMap(slot) and unit.x >= 0 and unit.y >= 0 and
            unit.x < world.width and unit.y < world.height then
            if unit.relation == RELATION_OWN then
               world.own[#world.own + 1] = unit
            elseif unit.relation == RELATION_ENEMY then
               world.enemy[#world.enemy + 1] = unit
            end
            world.entities[#world.entities + 1] = unit
            world.bySlot[unit.slot] = unit
         end
      end
   end
   table.sort(world.entities, function(a, b) return a.slot < b.slot end)
   table.sort(world.own, function(a, b) return a.slot < b.slot end)
   for index, unit in ipairs(world.entities) do unit.entityIndex = index end
   local locks = stratagus.gameData.AIState.war1gusOpeningBuilders
   local lock = locks and locks[playerIndex]
   if lock ~= nil then
      local builder = world.bySlot[lock.slot]
      local owned = false
      for _, unit in ipairs(world.ownAssets) do
         if unit.slot == lock.slot then owned = true; break end
      end
      local hall = "unit-" .. GetPlayerData(playerIndex, "RaceName") .. "-town-hall"
      local completed = GetPlayerData(playerIndex, "UnitTypesAiActiveCount", lock.type) > 0 or
         GetPlayerData(playerIndex, "UnitTypesAiActiveCount", hall) > 0
      if completed or not owned or (builder ~= nil and builder.idle and not world.hasHall) or
         GameCycle - lock.cycle >= OPENING_BUILD_TIMEOUT then
         locks[playerIndex] = nil
      else
         world.openingBuilder = lock.slot
      end
   end
   return world
end

local function AssetValue(units)
   local total = 0
   for _, unit in ipairs(units) do
      if not unit.wall then
         total = total + (unit.goldCost + unit.woodCost) * unit.hp / unit.maxHp
      end
   end
   return total
end

local function RewardBooks()
   return stratagus.gameData.AIState.war1gusRewardBookkeeping
end

local function RewardComponents(playerIndex, world, terminal)
   local enemyAsset, ownAsset = AssetValue(world.enemyAssets), AssetValue(world.ownAssets)
   local gold = math.max(0, Number(GetPlayerData(playerIndex, "TotalResources", "gold")))
   local wood = math.max(0, Number(GetPlayerData(playerIndex, "TotalResources", "wood")))
   local kills = math.max(0, Number(GetPlayerData(playerIndex, "TotalKills")))
   local razings = math.max(0, Number(GetPlayerData(playerIndex, "TotalRazings")))
   local books = RewardBooks()
   local book = books[playerIndex]
   local components = {enemyProgress = 0, ownLoss = 0, time = 0, terminal = 0}
   local canStart = GetNumOpponents(playerIndex) > 0 or enemyAsset > 0
   if book == nil or not book.started then
      if canStart then
         book = {
            started = true, hadOpponent = true,
            initialEnemy = math.max(enemyAsset, 1), maxOwn = math.max(ownAsset, 1),
            previousEnemy = enemyAsset, previousOwn = ownAsset,
            previousTimeBucket = math.floor(GameCycle / 300),
            initialGold = gold, initialWood = wood,
            previousGold = gold, previousWood = wood,
            previousKills = kills, previousRazings = razings
         }
         books[playerIndex] = book
      end
   else
      components.enemyProgress = Round(
         600 * (book.previousEnemy - enemyAsset) / math.max(book.initialEnemy, 1))
      book.maxOwn = math.max(book.maxOwn, ownAsset, 1)
      components.ownLoss = -Round(
         150 * math.max(book.previousOwn - ownAsset, 0) / book.maxOwn)
      local bucket = math.floor(GameCycle / 300)
      components.time = -math.max(bucket - book.previousTimeBucket, 0)
      book.previousEnemy, book.previousOwn, book.previousTimeBucket =
         enemyAsset, ownAsset, bucket

      -- Older saved reward books begin tracking these counters at this observation.
      if book.previousGold == nil then
         book.initialGold, book.initialWood = gold, wood
         book.previousGold, book.previousWood = gold, wood
         book.previousKills, book.previousRazings = kills, razings
      end
      local previousResourceScore = math.floor(
         (book.previousGold - book.initialGold + book.previousWood - book.initialWood) / 100)
      -- Rebase drops without erasing previously earned whole or fractional progress.
      if gold < book.previousGold then
         book.initialGold = book.initialGold - (book.previousGold - gold)
      end
      if wood < book.previousWood then
         book.initialWood = book.initialWood - (book.previousWood - wood)
      end
      local resourceScore = math.floor(
         (gold - book.initialGold + wood - book.initialWood) / 100)
      -- The four-word reward header bundles positive events with enemy progress.
      components.enemyProgress = components.enemyProgress + resourceScore - previousResourceScore +
         10 * math.max(kills - book.previousKills, 0) +
         50 * math.max(razings - book.previousRazings, 0)
      book.previousGold, book.previousWood = gold, wood
      book.previousKills, book.previousRazings = kills, razings
   end
   if terminal == "defeat" then components.terminal = -1000 end
   if terminal == "victory" then components.terminal = 1000 end
   components.total = ClampReward(
      components.enemyProgress + components.ownLoss + components.time + components.terminal)
   return components, ownAsset, enemyAsset
end

local function TerminalOutcome(playerIndex)
   if Number(GetPlayerData(playerIndex, "TotalNumUnits")) == 0 then return "defeat" end
   local book = RewardBooks()[playerIndex]
   if book ~= nil and book.started and book.hadOpponent and GetNumOpponents(playerIndex) == 0 then
      return "victory"
   end
   return nil
end

local function EntityWords(unit)
   local flags = 0
   if unit.canAttack then flags = flags + 1 end
   if unit.building then flags = flags + 2 end
   if unit.wall then flags = flags + 4 end
   if unit.idle then flags = flags + 8 end
   return {
      NonNegativeWord(unit.slot), UInt32(unit.hash), NonNegativeWord(unit.relation),
      NonNegativeWord(unit.role), NonNegativeWord(unit.x), NonNegativeWord(unit.y),
      NonNegativeWord(unit.hp), NonNegativeWord(unit.maxHp),
      NonNegativeWord(unit.goldCost), NonNegativeWord(unit.woodCost),
      NonNegativeWord(flags), NonNegativeWord(unit.resourceKind),
      NonNegativeWord(unit.attackRange), NonNegativeWord(unit.sightRange)
   }
end

local function AppendWords(destination, source)
   for _, word in ipairs(source) do destination[#destination + 1] = word end
end

local function ActionIdentity(action)
   return StableHash32(action.verb .. ":" .. (action.argument or ""))
end

local function ActionsForActor(playerIndex, actor)
   local actions = {}
   for _, action in ipairs(PRIMITIVE_ACTIONS) do
      actions[#actions + 1] = action
   end
   for _, entry in ipairs(AiActionCatalog(playerIndex)) do
      if entry.actor == actor.ident then
         local target = CATALOG_TARGETS[entry.verb]
         if target ~= nil then
            actions[#actions + 1] = {
               verb = entry.verb, argument = entry.argument, target = target
            }
         end
      end
   end
   return actions
end

local function ActorStillPresent(world, original)
   local actor = original and world.bySlot[original.slot]
   if actor ~= nil and actor.owner == world.playerIndex and
      actor.ident == original.ident then
      return actor
   end
   return nil
end

local function TargetStillPresent(world, original)
   local target = original and world.bySlot[original.slot]
   if target ~= nil and target.owner == original.owner and
      target.ident == original.ident then
      return target
   end
   return nil
end
local function OpeningWorker(world, actor)
   return actor ~= nil and actor.owner == world.playerIndex and
      actor.role == 1 and not world.hasHall
end

local function OpeningHallAction(action)
   return action ~= nil and action.verb == "build-at" and
      (action.argument == "unit-human-first-town-hall" or
       action.argument == "unit-orc-first-town-hall" or
       action.argument == "unit-human-town-hall" or
       action.argument == "unit-orc-town-hall")
end

local function GoldMines(world)
   local mines = {}
   for _, unit in ipairs(world.entities) do
      if unit.resourceKind == RESOURCE_GOLD then mines[#mines + 1] = unit end
   end
   return mines
end

local function NearGoldMine(mines, x, y)
   for _, mine in ipairs(mines) do
      if math.abs(x - mine.x) <= OPENING_MINE_RADIUS and
         math.abs(y - mine.y) <= OPENING_MINE_RADIUS then
         return true
      end
   end
   return false
end

local function NearestGoldMineDistance(mines, actor)
   local nearest
   for _, mine in ipairs(mines) do
      local distance = math.max(math.abs(actor.x - mine.x), math.abs(actor.y - mine.y))
      if nearest == nil or distance < nearest then nearest = distance end
   end
   return nearest
end

local function LocalOpeningSite(mines, actor, nearestMineDistance, x, y)
   return nearestMineDistance ~= nil and
      math.max(math.abs(actor.x - x), math.abs(actor.y - y)) <= nearestMineDistance + 8 and
      NearGoldMine(mines, x, y)
end

local function OpeningSites(playerIndex, world, stage)
   local sites = stage.openingSites
   if sites ~= nil and sites.width == world.width and sites.height == world.height then
      return sites
   end
   sites = {width = world.width, height = world.height, xs = {}, byX = {}}
   for x = 0, world.width - 1 do
      local ys = {}
      for y = 0, world.height - 1 do
         if AiCanBuildAt(playerIndex, stage.actor.slot, stage.action.argument, {x, y}) then
            ys[#ys + 1] = y
         end
      end
      if #ys > 0 then
         sites.xs[#sites.xs + 1] = x
         sites.byX[x] = ys
      end
   end
   stage.openingSites = sites
   return sites
end

local function OpeningSiteLegal(playerIndex, stage, x, y)
   return AiCanBuildAt(playerIndex, stage.actor.slot, stage.action.argument, {x, y})
end

local function NewStage(stage, world)
   if stage == nil or stage.kind == "actor" then
      return {kind = "actor", page = stage and stage.page or 0}
   end
   if stage.openingBuild and world.hasHall then
      return {kind = "actor", page = 0}
   end
   local actor = ActorStillPresent(world, stage.actor)
   if actor == nil then return {kind = "actor", page = 0} end
   stage.actor = actor
   if stage.kind ~= "action" and stage.action == nil then
      return {kind = "actor", page = 0}
   end
   return stage
end

local function StageOptions(playerIndex, world, stage)
   local options = {}
   local actorIndex = stage.actor and stage.actor.entityIndex or 0
   local actionHash = stage.action and ActionIdentity(stage.action) or 0
   if stage.kind == "actor" then
      for _, actor in ipairs(world.own) do
         if actor.slot ~= world.openingBuilder then
            options[#options + 1] = {
               kind = KIND_ACTOR, actor = actor.entityIndex, value = actor,
               hash = actor.hash, preferred = OpeningWorker(world, actor) and 1 or 0
            }
         end
      end
   elseif stage.kind == "action" then
      for _, action in ipairs(ActionsForActor(playerIndex, stage.actor)) do
         options[#options + 1] = {
            kind = KIND_ACTION, actor = actorIndex, value = action,
            hash = ActionIdentity(action),
            preferred = OpeningWorker(world, stage.actor) and OpeningHallAction(action) and 1 or 0
         }
      end
   elseif stage.kind == "entity" then
      for _, entity in ipairs(world.entities) do
         options[#options + 1] = {
            kind = KIND_ENTITY, actor = actorIndex, target = entity.entityIndex,
            hash = actionHash, value = entity
         }
      end
   elseif stage.kind == "x" then
      if stage.openingBuild then
         local sites = OpeningSites(playerIndex, world, stage)
         local mines = GoldMines(world)
         local nearestMineDistance = NearestGoldMineDistance(mines, stage.actor)
         for _, x in ipairs(sites.xs) do
            local legal, preferred = false, false
            if nearestMineDistance ~= nil then
               for _, y in ipairs(sites.byX[x]) do
                  if LocalOpeningSite(mines, stage.actor, nearestMineDistance, x, y) and
                     OpeningSiteLegal(playerIndex, stage, x, y) then
                     legal, preferred = true, true
                     break
                  end
               end
            end
            if not legal then
               for _, y in ipairs(sites.byX[x]) do
                  if OpeningSiteLegal(playerIndex, stage, x, y) then
                     legal = true
                     break
                  end
               end
            end
            if legal then
               options[#options + 1] = {
                  kind = KIND_X, actor = actorIndex, hash = actionHash,
                  x = x, value = x, preferred = preferred and 2 or 0
               }
            end
         end
      else
         for x = 0, world.width - 1 do
            options[#options + 1] = {
               kind = KIND_X, actor = actorIndex, hash = actionHash,
               x = x, value = x
            }
         end
      end
   elseif stage.kind == "y" then
      if stage.openingBuild then
         local ys = OpeningSites(playerIndex, world, stage).byX[stage.x] or {}
         local mines = GoldMines(world)
         local nearestMineDistance = NearestGoldMineDistance(mines, stage.actor)
         for _, y in ipairs(ys) do
            if OpeningSiteLegal(playerIndex, stage, stage.x, y) then
               options[#options + 1] = {
                  kind = KIND_Y, actor = actorIndex, hash = actionHash,
                  x = stage.x, y = y, value = y,
                  preferred = LocalOpeningSite(mines, stage.actor, nearestMineDistance, stage.x, y)
                     and 2 or 0
               }
            end
         end
      else
         for y = 0, world.height - 1 do
            options[#options + 1] = {
               kind = KIND_Y, actor = actorIndex, hash = actionHash,
               x = stage.x, y = y, value = y
            }
         end
      end
   end
   return options
end

local function CandidateWords(option)
   return {
      NonNegativeWord(option.kind), NonNegativeWord(option.actor),
      NonNegativeWord(option.target), UInt32(option.hash),
      NonNegativeWord(option.x), NonNegativeWord(option.y),
      option.preferred or 0, 0, 0, 0, 0, 0
   }
end

local function StageCandidates(playerIndex, world, stage)
   local options = StageOptions(playerIndex, world, stage)
   local maxCandidates = math.floor((MAX_STATE_WORDS - 22 - 14 * #world.entities) / 12)
   if maxCandidates < 1 or (maxCandidates == 1 and #options > 0) or
      (maxCandidates == 2 and #options > 1) then
      error("v3 observation cannot represent all entities and paged choices")
   end
   local pageSize = math.max(1, math.min(MAX_PAGE_CHOICES, maxCandidates - 3))
   local forwardOnly = maxCandidates == 3
   local lastPage = math.max(0, math.ceil(#options / pageSize) - 1)
   stage.page = math.max(0, math.min(stage.page or 0, lastPage))
   local plans = {{kind = KIND_WAIT}}
   local records = {CandidateWords(plans[1])}
   local first = stage.page * pageSize + 1
   for index = first, math.min(first + pageSize - 1, #options) do
      local option = options[index]
      plans[#plans + 1], records[#records + 1] = option, CandidateWords(option)
   end
   if stage.page > 0 and not forwardOnly then
      local previous = {kind = KIND_PAGE, actor = stage.actor and stage.actor.entityIndex,
         hash = stage.action and ActionIdentity(stage.action),
         x = stage.page, value = stage.page - 1}
      plans[#plans + 1], records[#records + 1] = previous, CandidateWords(previous)
   end
   if stage.page < lastPage or (forwardOnly and lastPage > 0) then
      local destination = stage.page < lastPage and stage.page + 1 or 0
      local nextPage = {kind = KIND_PAGE, actor = stage.actor and stage.actor.entityIndex,
         hash = stage.action and ActionIdentity(stage.action),
         x = destination + 1, value = destination}
      plans[#plans + 1], records[#records + 1] = nextPage, CandidateWords(nextPage)
   end
   return records, plans
end

local function PlayerTotals(playerIndex, name, resource)
   if resource ~= nil then
      return NonNegativeWord(GetPlayerData(playerIndex, name, resource))
   end
   return NonNegativeWord(GetPlayerData(playerIndex, name))
end

local function AccrueReward(playerIndex, components)
   local deferred = stratagus.gameData.AIState.war1gusDeferredReward
   local accrued = deferred[playerIndex] or {
      enemyProgress = 0, ownLoss = 0, time = 0, terminal = 0
   }
   accrued.enemyProgress = accrued.enemyProgress + components.enemyProgress
   accrued.ownLoss = accrued.ownLoss + components.ownLoss
   accrued.time = accrued.time + components.time
   accrued.terminal = accrued.terminal + components.terminal
   deferred[playerIndex] = accrued
end

local function BuildObservation(playerIndex, world, stage, terminal)
   local components, ownAsset, enemyAsset = RewardComponents(playerIndex, world, terminal)
   local aiState = stratagus.gameData.AIState
   local deferred = aiState.war1gusDeferredReward
   if deferred == nil then
      deferred = {}
      aiState.war1gusDeferredReward = deferred
   end
   local records, plans = {}, {}
   if stage ~= nil then
      records, plans = StageCandidates(playerIndex, world, stage)
   end
   if stage ~= nil and stage.kind ~= "actor" then
      AccrueReward(playerIndex, components)
      components.enemyProgress, components.ownLoss = 0, 0
      components.time, components.terminal, components.total = 0, 0, 0
   else
      local accrued = deferred[playerIndex]
      if accrued ~= nil then
         components.enemyProgress = components.enemyProgress + accrued.enemyProgress
         components.ownLoss = components.ownLoss + accrued.ownLoss
         components.time = components.time + accrued.time
         components.terminal = components.terminal + accrued.terminal
      end
      deferred[playerIndex] = nil
      local penalties = aiState.war1gusRejectionPenalty
      if penalties ~= nil then
         components.time = components.time + (penalties[playerIndex] or 0)
         penalties[playerIndex] = nil
      end
      components.total = ClampReward(components.enemyProgress + components.ownLoss +
         components.time + components.terminal)
   end
   local raceId = GetPlayerData(playerIndex, "RaceName") == race1 and 0 or 1
   local state = {
      3, NonNegativeWord(playerIndex), NonNegativeWord(raceId),
      NonNegativeWord(GameCycle), NonNegativeWord(world.gold), NonNegativeWord(world.wood),
      NonNegativeWord(world.supply), NonNegativeWord(world.demand),
      NonNegativeWord(world.width), NonNegativeWord(world.height),
      NonNegativeWord(#world.entities), NonNegativeWord(#records),
      NonNegativeWord(Round(ownAsset)), NonNegativeWord(Round(enemyAsset)),
      PlayerTotals(playerIndex, "TotalResources", "gold"),
      PlayerTotals(playerIndex, "TotalResources", "wood"),
      PlayerTotals(playerIndex, "TotalKills"), PlayerTotals(playerIndex, "TotalRazings"),
      UInt32(components.enemyProgress), UInt32(components.ownLoss),
      UInt32(components.time), UInt32(components.terminal)
   }
   for _, entity in ipairs(world.entities) do AppendWords(state, EntityWords(entity)) end
   for _, record in ipairs(records) do AppendWords(state, record) end
   return state, plans, components
end

function War1gusAiFinalState(playerIndex, terminal)
   local world = NewWorldSnapshot(playerIndex)
   return BuildObservation(playerIndex, world, nil, terminal or TerminalOutcome(playerIndex))
end

function War1gusAiTerminalReward(playerIndex, state)
   if type(state) ~= "table" then state = War1gusAiFinalState(playerIndex) end
   return ClampReward(Signed32(state[STATE_REWARD_ENEMY_PROGRESS]) +
      Signed32(state[STATE_REWARD_OWN_LOSS]) + Signed32(state[STATE_REWARD_TIME]) +
      Signed32(state[STATE_REWARD_TERMINAL]))
end

local function IsEnded(playerIndex)
   return stratagus.gameData.AIState.war1gusAiEnded[playerIndex] == true
end

local function EndPlayer(playerIndex, terminal)
   if IsEnded(playerIndex) then return end
   local server = stratagus.gameData.War1gusAiServer
   local pending = server and server.pending[playerIndex]
   if pending ~= nil then
      War1gusAiLog("war1gus-ai.discard", {
         {name = "player", value = tostring(playerIndex)},
         {name = "sequence", value = tostring(pending.sequence)},
         {name = "observation_cycle", value = tostring(pending.cycle)},
         {name = "response_cycle", value = tostring(GameCycle)},
         {name = "reason", value = JsonString("terminal")}
      })
   end
   local state = War1gusAiFinalState(playerIndex, terminal)
   local reward = War1gusAiTerminalReward(playerIndex, state)
   War1gusAiLog("war1gus-ai.reward", {
      {name = "player", value = tostring(playerIndex)},
      {name = "enemy_progress", value = tostring(Signed32(state[STATE_REWARD_ENEMY_PROGRESS]))},
      {name = "own_loss", value = tostring(Signed32(state[STATE_REWARD_OWN_LOSS]))},
      {name = "time", value = tostring(Signed32(state[STATE_REWARD_TIME]))},
      {name = "terminal", value = tostring(Signed32(state[STATE_REWARD_TERMINAL]))},
      {name = "total", value = tostring(reward)}
   })
   EndWar1gusAiProcessor(playerIndex, reward, state)
   War1gusAiLog("war1gus-ai.lifecycle", {
      {name = "player", value = tostring(playerIndex)},
      {name = "event", value = JsonString(terminal)},
      {name = "reward", value = tostring(reward)}
   })
end

local function FinalizeEndedPlayers()
   local server = stratagus.gameData.War1gusAiServer
   if server == nil then return end
   local playerIndexes = {}
   for playerIndex, _ in pairs(server.handles) do
      playerIndexes[#playerIndexes + 1] = playerIndex
   end
   for _, playerIndex in ipairs(playerIndexes) do
      local terminal = TerminalOutcome(playerIndex)
      if terminal ~= nil then EndPlayer(playerIndex, terminal) end
   end
end

local function CommandArgument(action, target)
   if action.target == "entity" then
      if action.verb == "cast-unit" then
         return {spell = action.argument, target = target}
      end
      return target
   end
   if action.target == "position" then
      if action.verb == "build-at" then
         return {type = action.argument, x = target[1], y = target[2]}
      elseif action.verb == "cast-position" then
         return {spell = action.argument, x = target[1], y = target[2]}
      end
      return target
   end
   return action.argument
end

local function PublishSelection(playerIndex, sequence, stage, target, world)
   local actor = ActorStillPresent(world, stage.actor)
   if actor == nil then return false, "stale-actor" end
   if stage.action.target == "entity" then
      local entity = TargetStillPresent(world, target)
      if entity == nil then return false, "stale-target" end
      target = entity.slot
   end
   local command = {
      actor = actor.slot, verb = stage.action.verb,
      argument = CommandArgument(stage.action, target)
   }
   if AiPublishCommandBatch(playerIndex, sequence, {command}) then
      if stage.openingBuild then
         local mines = GoldMines(world)
         if LocalOpeningSite(mines, actor,
            NearestGoldMineDistance(mines, actor), target[1], target[2]) then
            local aiState = stratagus.gameData.AIState
            aiState.war1gusOpeningBuilders = aiState.war1gusOpeningBuilders or {}
            aiState.war1gusOpeningBuilders[playerIndex] = {
               slot = actor.slot, type = stage.action.argument, cycle = GameCycle
            }
         end
      end
      return true
   end
   return false, "publication-rejected"
end

local function NextStage(playerIndex, stage, choice, sequence, world)
   if choice.kind == KIND_WAIT then return nil, true, true end
   if choice.kind == KIND_PAGE then
      stage.page = choice.value
      return stage, false, true
   end
   if stage.kind == "actor" and choice.kind == KIND_ACTOR then
      local actor = ActorStillPresent(world, choice.value)
      if actor == nil then return nil, false, false end
      return {kind = "action", actor = actor, page = 0}, false, true
   end
   if stage.kind == "action" and choice.kind == KIND_ACTION then
      local action = choice.value
      local nextStage = {
         kind = action.target, actor = stage.actor, action = action, page = 0,
         openingBuild = OpeningWorker(world, stage.actor) and OpeningHallAction(action)
      }
      if action.target == "position" then nextStage.kind = "x" end
      if action.target == "none" then
         local accepted, reason = PublishSelection(playerIndex, sequence, nextStage, nil, world)
         return nil, true, accepted, reason
      end
      return nextStage, false, true
   end
   if stage.kind == "entity" and choice.kind == KIND_ENTITY then
      local accepted, reason = PublishSelection(playerIndex, sequence, stage, choice.value, world)
      return nil, true, accepted, reason
   end
   if stage.kind == "x" and choice.kind == KIND_X then
      if stage.openingSites ~= nil then
         local ys = stage.openingSites.byX[choice.value] or {}
         local legal = false
         for _, y in ipairs(ys) do
            if OpeningSiteLegal(playerIndex, stage, choice.value, y) then
               legal = true
               break
            end
         end
         if not legal then return nil, false, false end
      end
      return {kind = "y", actor = stage.actor, action = stage.action,
         openingBuild = stage.openingBuild, openingSites = stage.openingSites,
         x = choice.value, page = 0}, false, true
   end
   if stage.kind == "y" and choice.kind == KIND_Y then
      local accepted, reason = PublishSelection(playerIndex, sequence, stage,
         {stage.x, choice.value}, world)
      return nil, true, accepted, reason
   end
   return nil, false, false
end

local function LogReward(playerIndex, components)
   if not VERBOSE_LOGGING then return end
   War1gusAiLog("war1gus-ai.reward", {
      {name = "player", value = tostring(playerIndex)},
      {name = "enemy_progress", value = tostring(components.enemyProgress)},
      {name = "own_loss", value = tostring(components.ownLoss)},
      {name = "time", value = tostring(components.time)},
      {name = "terminal", value = tostring(components.terminal)},
      {name = "total", value = tostring(components.total)}
   })
end

function War1gusAI()
   if not AiExternalDecisionAuthority() then return end
   local playerIndex = AiPlayer()
   FinalizeEndedPlayers()
   if IsEnded(playerIndex) then return end
   local world = NewWorldSnapshot(playerIndex)
   local terminal = TerminalOutcome(playerIndex)
   if terminal ~= nil then
      EndPlayer(playerIndex, terminal)
      return
   end

   local aiState = stratagus.gameData.AIState
   local stages = aiState.war1gusSelectionStages
   if stages == nil then
      stages = {}
      aiState.war1gusSelectionStages = stages
   end
   local async = War1gusAiAsyncMode()
   local server = stratagus.gameData.War1gusAiServer
   local pending = async and server and server.pending[playerIndex] or nil
   local selected, plans, sequence, stage
   if pending ~= nil then
      if pending.server ~= server or pending.epoch ~= server.epoch or
         server.handles[playerIndex] ~= pending.handle then
         War1gusAiLog("war1gus-ai.discard", {
            {name = "player", value = tostring(playerIndex)},
            {name = "sequence", value = tostring(pending.sequence)},
            {name = "observation_cycle", value = tostring(pending.cycle)},
            {name = "response_cycle", value = tostring(GameCycle)},
            {name = "reason", value = JsonString("epoch-changed")}
         })
         server.pending[playerIndex] = nil
         stages[playerIndex] = nil
         return
      end
      if (GameCycle < pending.cycle or GameCycle - pending.cycle > MAX_ASYNC_RESPONSE_AGE)
         and not pending.expired then
         pending.expired = true
         War1gusAiLog("war1gus-ai.discard", {
            {name = "player", value = tostring(playerIndex)},
            {name = "sequence", value = tostring(pending.sequence)},
            {name = "observation_cycle", value = tostring(pending.cycle)},
            {name = "response_cycle", value = tostring(GameCycle)},
            {name = "reason", value = JsonString("response-expired")}
         })
         -- Drain the old response before requesting another sequence.
      end
      if pending.failed then
         local restarted = AiProcessorBegin(
            pending.handle, pending.reward, pending.state, #pending.plans)
         if restarted == nil then return end
         if restarted ~= pending.sequence then
            War1gusAiLog("war1gus-ai.discard", {
               {name = "player", value = tostring(playerIndex)},
               {name = "sequence", value = tostring(pending.sequence)},
               {name = "observation_cycle", value = tostring(pending.cycle)},
               {name = "response_cycle", value = tostring(GameCycle)},
               {name = "reason", value = JsonString("retry-sequence-mismatch")}
            })
            stages[playerIndex] = nil
            EndWar1gusAiProcessor(playerIndex)
            return
         end
         pending.failed = false
         return
      end
      local status
      status, sequence, selected = AiProcessorPoll(pending.handle)
      if status == "pending" then return end
      if status == "failed" then
         pending.failed = true
         return
      end
      if status ~= "ready" or sequence ~= pending.sequence then
         War1gusAiLog("war1gus-ai.discard", {
            {name = "player", value = tostring(playerIndex)},
            {name = "sequence", value = tostring(pending.sequence)},
            {name = "observation_cycle", value = tostring(pending.cycle)},
            {name = "response_cycle", value = tostring(GameCycle)},
            {name = "reason", value = JsonString(status ~= "ready" and "poll-status" or "sequence-mismatch")}
         })
         stages[playerIndex] = nil
         EndWar1gusAiProcessor(playerIndex)
         return
      end
      server.pending[playerIndex] = nil
      if pending.expired then
         stages[playerIndex] = nil
         return
      end
      plans, stage = pending.plans, pending.stage
      War1gusAiLog("war1gus-ai.response", {
         {name = "player", value = tostring(playerIndex)},
         {name = "sequence", value = tostring(sequence)},
         {name = "observation_cycle", value = tostring(pending.cycle)},
         {name = "response_cycle", value = tostring(GameCycle)},
         {name = "latency", value = tostring(GameCycle - pending.cycle)},
         {name = "selection", value = JsonString(tostring(selected))}
      })
   else
      stage = NewStage(stages[playerIndex], world)
      stages[playerIndex] = stage
      local state, components
      state, plans, components = BuildObservation(playerIndex, world, stage, nil)
      LogReward(playerIndex, components)
      local handle = GetWar1gusAiProcessor(playerIndex, state)
      if handle == nil then
         if stage.kind == "actor" then AccrueReward(playerIndex, components) end
         War1gusAiLog("war1gus-ai.lifecycle", {
            {name = "player", value = tostring(playerIndex)},
            {name = "event", value = JsonString("processor-unavailable")}
         })
         return
      end
      if async then
         sequence = AiProcessorBegin(handle, components.total, state, #plans)
         if type(sequence) ~= "number" or sequence ~= math.floor(sequence) or
            sequence < 0 or sequence >= UINT32_MODULUS then
            if stage.kind == "actor" then AccrueReward(playerIndex, components) end
            return
         end
         server = stratagus.gameData.War1gusAiServer
         server.pending[playerIndex] = {
            server = server, epoch = server.epoch, handle = handle,
            reward = components.total, state = state, plans = plans,
            stage = stage, sequence = sequence, cycle = GameCycle
         }
         War1gusAiLog("war1gus-ai.request", {
            {name = "player", value = tostring(playerIndex)},
            {name = "sequence", value = tostring(sequence)},
            {name = "observation_cycle", value = tostring(GameCycle)},
            {name = "candidate_count", value = tostring(#plans)}
         })
         return
      end
      selected, sequence = AiProcessorStep(handle, components.total, state, #plans)
   end

   if type(selected) ~= "number" or selected ~= math.floor(selected) or
      selected < 1 or selected > #plans then
      if async then
         War1gusAiLog("war1gus-ai.discard", {
            {name = "player", value = tostring(playerIndex)},
            {name = "sequence", value = tostring(sequence)},
            {name = "observation_cycle", value = tostring(pending.cycle)},
            {name = "response_cycle", value = tostring(GameCycle)},
            {name = "reason", value = JsonString("invalid-selection")}
         })
      end
      War1gusAiLog("war1gus-ai.action", {
         {name = "player", value = tostring(playerIndex)},
         {name = "event", value = JsonString("invalid-selection")},
         {name = "selection", value = JsonString(tostring(selected))},
         {name = "candidate_count", value = tostring(#plans)}
      })
      stages[playerIndex] = nil
      return
   end

   local nextStage, completed, accepted, reason =
      NextStage(playerIndex, stage, plans[selected], sequence, world)
   stages[playerIndex] = nextStage
   if completed and reason == "publication-rejected" then
      local penalties = aiState.war1gusRejectionPenalty
      if penalties == nil then
         penalties = {}
         aiState.war1gusRejectionPenalty = penalties
      end
      penalties[playerIndex] = math.max(-1000, (penalties[playerIndex] or 0) + REJECTION_REWARD)
   end
   if async and not accepted then
      War1gusAiLog("war1gus-ai.discard", {
         {name = "player", value = tostring(playerIndex)},
         {name = "sequence", value = tostring(sequence)},
         {name = "observation_cycle", value = tostring(pending.cycle)},
         {name = "response_cycle", value = tostring(GameCycle)},
         {name = "reason", value = JsonString(reason or "stale-selection")}
      })
   end
   if VERBOSE_LOGGING then
      War1gusAiLog("war1gus-ai.action", {
         {name = "player", value = tostring(playerIndex)},
         {name = "candidate", value = tostring(selected - 1)},
         {name = "kind", value = tostring(plans[selected].kind)},
         {name = "accepted", value = tostring(accepted)}
      })
   end
end

DefineAi("war1gus-ai", "*", "war1gus-ai", War1gusAI, 5)
