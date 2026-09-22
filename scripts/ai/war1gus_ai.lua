local STATE_VERSION = 1
local STATE_PLAYER = 2
local STATE_RACE = 3
local STATE_CYCLE = 4
local STATE_GOLD = 5
local STATE_WOOD = 6
local STATE_SUPPLY = 7
local STATE_DEMAND = 8
local STATE_MAP_WIDTH = 9
local STATE_MAP_HEIGHT = 10
local STATE_ENTITY_COUNT = 11
local STATE_CANDIDATE_COUNT = 12
local STATE_OWN_ASSET = 13
local STATE_ENEMY_ASSET = 14
local STATE_TOTAL_GOLD = 15
local STATE_TOTAL_WOOD = 16
local STATE_TOTAL_KILLS = 17
local STATE_TOTAL_RAZINGS = 18
local STATE_REWARD_ENEMY_PROGRESS = 19
local STATE_REWARD_OWN_LOSS = 20
local STATE_REWARD_TIME = 21
local STATE_REWARD_TERMINAL = 22

local ENTITY_WORDS = 14
local CANDIDATE_WORDS = 12
local MAX_CANDIDATES = 512
local UINT32_MODULUS = 4294967296
local INT32_SIGN = 2147483648


local VERBOSE_LOGGING = os.getenv("WAR1GUS_AI_VERBOSE_LOG") == "1"
local KIND_WAIT = 0
local KIND_GATHER_GOLD = 1
local KIND_GATHER_WOOD = 2
local KIND_BUILD = 3
local KIND_TRAIN = 4
local KIND_RESEARCH = 5
local KIND_ATTACK_ENTITY = 6
local KIND_MOVE_GROUP = 7
local KIND_EXPLORE = 8
local KIND_REPAIR = 9
local KIND_FORMATION = 10
local KIND_DEFEND = 11
local KIND_CAST_SPELL = 12

local RELATION_OWN = 0
local RELATION_ENEMY = 1
local RELATION_NEUTRAL = 2

local RESOURCE_NONE = 0
local RESOURCE_GOLD = 1
local RESOURCE_WOOD = 2

local FORMATION_NONE = 0
local FORMATION_LINE = 1
local FORMATION_BOX = 2
local FORMATION_SPREAD = 3

local HUMAN_CITY_CENTERS = {
   "unit-human-town-hall",
   "unit-human-first-town-hall",
   "unit-human-stormwind-keep"
}

local ORC_CITY_CENTERS = {
   "unit-orc-town-hall",
   "unit-orc-first-town-hall",
   "unit-orc-blackrock-spire"
}

local HUMAN_TECH = {
   worker = "unit-peasant",
   cityCenter = "unit-human-town-hall",
   firstCityCenter = "unit-human-first-town-hall",
   cityCenters = HUMAN_CITY_CENTERS,
   buildings = {
      {ident = "unit-road", producers = HUMAN_CITY_CENTERS, road = true, maxCount = 12, bootstrapScore = 220},
      {ident = "unit-human-farm", producers = {"unit-peasant"}, demandDriven = true, maxCount = 12, bootstrapScore = 200},
      {ident = "unit-human-town-hall", producers = {"unit-peasant"}, cityCenter = true, maxCount = 3, bootstrapScore = 240},
      {ident = "unit-human-barracks", producers = {"unit-peasant"}, baseLimit = 1, workersPerAdditional = 12, maxCount = 3, bootstrapScore = 180},
      {ident = "unit-human-lumber-mill", producers = {"unit-peasant"}, maxCount = 1, bootstrapScore = 170},
      {ident = "unit-human-blacksmith", producers = {"unit-peasant"}, maxCount = 1, bootstrapScore = 160},
      {ident = "unit-human-church", producers = {"unit-peasant"}, baseLimit = 1, workersPerAdditional = 18, maxCount = 2, bootstrapScore = 150},
      {ident = "unit-human-stable", producers = {"unit-peasant"}, baseLimit = 1, workersPerAdditional = 18, maxCount = 2, bootstrapScore = 150},
      {ident = "unit-human-tower", producers = {"unit-peasant"}, baseLimit = 1, workersPerAdditional = 18, maxCount = 2, bootstrapScore = 150},
      {ident = "unit-wall", producers = HUMAN_CITY_CENTERS, maxCount = 16, bootstrapScore = 60}
   },
   training = {
      {ident = "unit-peasant", producers = {"unit-human-town-hall", "unit-human-stormwind-keep"}, bootstrapScore = 220},
      {ident = "unit-footman", producers = {"unit-human-barracks"}, bootstrapScore = 180},
      {ident = "unit-archer", producers = {"unit-human-barracks"}, bootstrapScore = 180},
      {ident = "unit-human-catapult", producers = {"unit-human-barracks"}, bootstrapScore = 180},
      {ident = "unit-knight", producers = {"unit-human-barracks"}, bootstrapScore = 180},
      {ident = "unit-cleric", producers = {"unit-human-church"}, bootstrapScore = 170},
      {ident = "unit-conjurer", producers = {"unit-human-tower"}, bootstrapScore = 170}
   },
   research = {
      {ident = "upgrade-sword1", producers = {"unit-human-blacksmith"}},
      {ident = "upgrade-sword2", producers = {"unit-human-blacksmith"}},
      {ident = "upgrade-human-shield1", producers = {"unit-human-blacksmith"}},
      {ident = "upgrade-human-shield2", producers = {"unit-human-blacksmith"}},
      {ident = "upgrade-arrow1", producers = {"unit-human-lumber-mill"}},
      {ident = "upgrade-arrow2", producers = {"unit-human-lumber-mill"}},
      {ident = "upgrade-horse1", producers = {"unit-human-stable"}},
      {ident = "upgrade-horse2", producers = {"unit-human-stable"}},
      {ident = "upgrade-healing", producers = {"unit-human-church"}},
      {ident = "upgrade-far-seeing", producers = {"unit-human-church"}},
      {ident = "upgrade-invisibility", producers = {"unit-human-church"}},
      {ident = "upgrade-scorpion", producers = {"unit-human-tower"}},
      {ident = "upgrade-rain-of-fire", producers = {"unit-human-tower"}},
      {ident = "upgrade-water-elemental", producers = {"unit-human-tower"}}
   },
   spells = {
      {ident = "spell-healing", casters = {"unit-cleric"}, upgrade = "upgrade-healing", mana = 2},
      {ident = "spell-far-seeing", casters = {"unit-cleric"}, upgrade = "upgrade-far-seeing", mana = 35, target = "position"},
      {ident = "spell-invisibility", casters = {"unit-cleric"}, upgrade = "upgrade-invisibility", mana = 40},
      {ident = "spell-summon-scorpions", casters = {"unit-conjurer"}, upgrade = "upgrade-scorpion", mana = 30},
      {ident = "spell-rain-of-fire", casters = {"unit-conjurer"}, upgrade = "upgrade-rain-of-fire", mana = 20},
      {ident = "spell-summon-elemental", casters = {"unit-conjurer"}, upgrade = "upgrade-water-elemental", mana = 60},
      {ident = "spell-poison", casters = {"unit-scorpion"}, mana = 0}
   }
}

local ORC_TECH = {
   worker = "unit-peon",
   cityCenter = "unit-orc-town-hall",
   firstCityCenter = "unit-orc-first-town-hall",
   cityCenters = ORC_CITY_CENTERS,
   buildings = {
      {ident = "unit-road", producers = ORC_CITY_CENTERS, road = true, maxCount = 12, bootstrapScore = 220},
      {ident = "unit-orc-farm", producers = {"unit-peon"}, demandDriven = true, maxCount = 12, bootstrapScore = 200},
      {ident = "unit-orc-town-hall", producers = {"unit-peon"}, cityCenter = true, maxCount = 3, bootstrapScore = 240},
      {ident = "unit-orc-barracks", producers = {"unit-peon"}, baseLimit = 1, workersPerAdditional = 12, maxCount = 3, bootstrapScore = 180},
      {ident = "unit-orc-lumber-mill", producers = {"unit-peon"}, maxCount = 1, bootstrapScore = 170},
      {ident = "unit-orc-blacksmith", producers = {"unit-peon"}, maxCount = 1, bootstrapScore = 160},
      {ident = "unit-orc-temple", producers = {"unit-peon"}, baseLimit = 1, workersPerAdditional = 18, maxCount = 2, bootstrapScore = 150},
      {ident = "unit-orc-kennel", producers = {"unit-peon"}, baseLimit = 1, workersPerAdditional = 18, maxCount = 2, bootstrapScore = 150},
      {ident = "unit-orc-tower", producers = {"unit-peon"}, baseLimit = 1, workersPerAdditional = 18, maxCount = 2, bootstrapScore = 150},
      {ident = "unit-wall", producers = ORC_CITY_CENTERS, maxCount = 16, bootstrapScore = 60}
   },
   training = {
      {ident = "unit-peon", producers = {"unit-orc-town-hall", "unit-orc-blackrock-spire"}, bootstrapScore = 220},
      {ident = "unit-grunt", producers = {"unit-orc-barracks"}, bootstrapScore = 180},
      {ident = "unit-spearman", producers = {"unit-orc-barracks"}, bootstrapScore = 180},
      {ident = "unit-orc-catapult", producers = {"unit-orc-barracks"}, bootstrapScore = 180},
      {ident = "unit-raider", producers = {"unit-orc-barracks"}, bootstrapScore = 180},
      {ident = "unit-necrolyte", producers = {"unit-orc-temple"}, bootstrapScore = 170},
      {ident = "unit-warlock", producers = {"unit-orc-tower"}, bootstrapScore = 170}
   },
   research = {
      {ident = "upgrade-axe1", producers = {"unit-orc-blacksmith"}},
      {ident = "upgrade-axe2", producers = {"unit-orc-blacksmith"}},
      {ident = "upgrade-orc-shield1", producers = {"unit-orc-blacksmith"}},
      {ident = "upgrade-orc-shield2", producers = {"unit-orc-blacksmith"}},
      {ident = "upgrade-spear1", producers = {"unit-orc-lumber-mill"}},
      {ident = "upgrade-spear2", producers = {"unit-orc-lumber-mill"}},
      {ident = "upgrade-wolves1", producers = {"unit-orc-kennel"}},
      {ident = "upgrade-wolves2", producers = {"unit-orc-kennel"}},
      {ident = "upgrade-raise-dead", producers = {"unit-orc-temple"}},
      {ident = "upgrade-dark-vision", producers = {"unit-orc-temple"}},
      {ident = "upgrade-unholy-armor", producers = {"unit-orc-temple"}},
      {ident = "upgrade-spider", producers = {"unit-orc-tower"}},
      {ident = "upgrade-poison-cloud", producers = {"unit-orc-tower"}},
      {ident = "upgrade-daemon", producers = {"unit-orc-tower"}}
   },
   spells = {
      {ident = "spell-raise-dead", casters = {"unit-necrolyte"}, upgrade = "upgrade-raise-dead", mana = 25},
      {ident = "spell-dark-vision", casters = {"unit-necrolyte"}, upgrade = "upgrade-dark-vision", mana = 35, target = "position"},
      {ident = "spell-unholy-armor", casters = {"unit-necrolyte"}, upgrade = "upgrade-unholy-armor", mana = 55},
      {ident = "spell-summon-spiders", casters = {"unit-warlock"}, upgrade = "upgrade-spider", mana = 30},
      {ident = "spell-poison-cloud", casters = {"unit-warlock"}, upgrade = "upgrade-poison-cloud", mana = 7},
      {ident = "spell-summon-daemon", casters = {"unit-warlock"}, upgrade = "upgrade-daemon", mana = 60},
      {ident = "spell-slow", casters = {"unit-spider"}, mana = 0}
   }
}

if preferences.RebalancedStats then
   table.insert(HUMAN_TECH.buildings, {ident = "unit-human-first-town-hall", producers = {"unit-peasant"}, initialCityCenter = true, bootstrapScore = 260})
   table.insert(HUMAN_TECH.buildings, {ident = "unit-human-guard-tower", producers = {"unit-peasant"}, maxCount = 4, bootstrapScore = 130})
   table.insert(HUMAN_TECH.training, {ident = "unit-sorceress", producers = {"unit-human-church"}, bootstrapScore = 170})
   for _, specification in ipairs({
      {ident = "upgrade-human-barding1", producers = {"unit-human-stable"}},
      {ident = "upgrade-human-barding2", producers = {"unit-human-stable"}},
      {ident = "upgrade-human-LightArmor1", producers = {"unit-human-blacksmith"}},
      {ident = "upgrade-human-LightArmor2", producers = {"unit-human-blacksmith"}},
      {ident = "upgrade-human-CatapultAmmo1", producers = {"unit-human-blacksmith"}},
      {ident = "upgrade-human-BuildingArmor1", producers = {"unit-human-lumber-mill"}},
      {ident = "upgrade-human-BuildingArmor2", producers = {"unit-human-lumber-mill"}},
      {ident = "upgrade-human-CatapultSpeed", producers = {"unit-human-lumber-mill"}},
      {ident = "upgrade-hail", producers = {"unit-human-church"}},
      {ident = "upgrade-freeze", producers = {"unit-human-tower"}}
   }) do
      table.insert(HUMAN_TECH.research, specification)
   end
   table.insert(HUMAN_TECH.spells, {ident = "spell-hail", casters = {"unit-sorceress"}, upgrade = "upgrade-hail", mana = 30})
   table.insert(HUMAN_TECH.spells, {ident = "spell-freeze", casters = {"unit-sorceress"}, upgrade = "upgrade-freeze", mana = 35})

   table.insert(ORC_TECH.buildings, {ident = "unit-orc-first-town-hall", producers = {"unit-peon"}, initialCityCenter = true, bootstrapScore = 260})
   table.insert(ORC_TECH.buildings, {ident = "unit-orc-watch-tower", producers = {"unit-peon"}, maxCount = 4, bootstrapScore = 130})
   for _, specification in ipairs({
      {ident = "upgrade-orc-saliva1", producers = {"unit-orc-kennel"}},
      {ident = "upgrade-orc-saliva2", producers = {"unit-orc-kennel"}},
      {ident = "upgrade-orc-LightArmor1", producers = {"unit-orc-blacksmith"}},
      {ident = "upgrade-orc-LightArmor2", producers = {"unit-orc-blacksmith"}},
      {ident = "upgrade-orc-CatapultAmmo1", producers = {"unit-orc-blacksmith"}},
      {ident = "upgrade-orc-BuildingArmor1", producers = {"unit-orc-lumber-mill"}},
      {ident = "upgrade-orc-BuildingArmor2", producers = {"unit-orc-lumber-mill"}},
      {ident = "upgrade-orc-CatapultSpeed", producers = {"unit-orc-lumber-mill"}}
   }) do
      table.insert(ORC_TECH.research, specification)
   end
end

local UNIT_ROLES = {
   ["unit-peasant"] = "worker",
   ["unit-peon"] = "worker",
   ["unit-human-town-hall"] = "cityCenter",
   ["unit-human-first-town-hall"] = "cityCenter",
   ["unit-human-stormwind-keep"] = "cityCenter",
   ["unit-orc-town-hall"] = "cityCenter",
   ["unit-orc-first-town-hall"] = "cityCenter",
   ["unit-orc-blackrock-spire"] = "cityCenter",
   ["unit-human-farm"] = "farm",
   ["unit-orc-farm"] = "farm",
   ["unit-human-barracks"] = "barracks",
   ["unit-orc-barracks"] = "barracks",
   ["unit-human-lumber-mill"] = "lumberMill",
   ["unit-orc-lumber-mill"] = "lumberMill",
   ["unit-human-blacksmith"] = "blacksmith",
   ["unit-orc-blacksmith"] = "blacksmith",
   ["unit-human-stable"] = "stables",
   ["unit-orc-kennel"] = "stables",
   ["unit-human-church"] = "sanctuary",
   ["unit-orc-temple"] = "sanctuary",
   ["unit-human-tower"] = "mageTower",
   ["unit-orc-tower"] = "mageTower",
   ["unit-road"] = "road",
   ["unit-footman"] = "soldier",
   ["unit-grunt"] = "soldier",
   ["unit-archer"] = "shooter",
   ["unit-spearman"] = "shooter",
   ["unit-knight"] = "cavalry",
   ["unit-raider"] = "cavalry",
   ["unit-human-catapult"] = "catapult",
   ["unit-orc-catapult"] = "catapult",
   ["unit-cleric"] = "supportCaster",
   ["unit-necrolyte"] = "supportCaster",
   ["unit-conjurer"] = "combatCaster",
   ["unit-warlock"] = "combatCaster",
   ["unit-sorceress"] = "combatCaster"
}

local ROLE_CODES = {
   worker = 1,
   cityCenter = 2,
   farm = 3,
   barracks = 4,
   lumberMill = 5,
   blacksmith = 6,
   stables = 7,
   soldier = 8,
   shooter = 9,
   cavalry = 10,
   catapult = 11,
   sanctuary = 12,
   mageTower = 13,
   road = 14,
   supportCaster = 15,
   combatCaster = 16
}

local KIND_NAMES = {
   [KIND_WAIT] = "wait",
   [KIND_GATHER_GOLD] = "gather-gold",
   [KIND_GATHER_WOOD] = "gather-wood",
   [KIND_BUILD] = "build",
   [KIND_TRAIN] = "train",
   [KIND_RESEARCH] = "research",
   [KIND_ATTACK_ENTITY] = "attack-entity",
   [KIND_MOVE_GROUP] = "move-group",
   [KIND_EXPLORE] = "explore",
   [KIND_REPAIR] = "repair",
   [KIND_FORMATION] = "formation",
   [KIND_DEFEND] = "defend",
   [KIND_CAST_SPELL] = "cast-spell"
}

local UNIT_METADATA = {}
local UPGRADE_METADATA = {}

local function Number(value)
   value = tonumber(value)
   if value == nil or value ~= value then
      return 0
   end
   return value
end

local function UInt32(value)
   value = math.floor(Number(value))
   value = value % UINT32_MODULUS
   if value < 0 then
      value = value + UINT32_MODULUS
   end
   return value
end

local function NonNegativeWord(value)
   value = Number(value)
   if value < 0 then
      return 0
   end
   return UInt32(value)
end

local function SignedWord(value)
   return UInt32(value)
end

local function Signed32(word)
   word = UInt32(word)
   if word >= INT32_SIGN then
      return word - UINT32_MODULUS
   end
   return word
end

local function Round(value)
   if value < 0 then
      return math.ceil(value - 0.5)
   end
   return math.floor(value + 0.5)
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
   if fields ~= nil then
      for _, field in ipairs(fields) do
         table.insert(output, ",\"" .. field.name .. "\":" .. field.value)
      end
   end
   table.insert(output, "}")
   print(table.concat(output))
end


local function Xor32(left, right)
   left = UInt32(left)
   right = UInt32(right)
   local result = 0
   local bit = 1
   for _ = 1, 32 do
      local leftBit = left % 2
      local rightBit = right % 2
      if leftBit ~= rightBit then
         result = result + bit
      end
      left = math.floor(left / 2)
      right = math.floor(right / 2)
      bit = bit * 2
   end
   return result
end

local function MultiplyFNVPrime(value)
   local low = value % 65536
   local high = math.floor(value / 65536)
   local lowProduct = low * 403
   local resultLow = lowProduct % 65536
   local resultHigh = (math.floor(lowProduct / 65536) + low * 256 + high * 403) % 65536
   return resultLow + resultHigh * 65536
end

local function StableHash32(value)
   local hash = 2166136261
   for index = 1, string.len(value) do
      hash = MultiplyFNVPrime(Xor32(hash, string.byte(value, index)))
   end
   return hash
end

local function UpgradeMetadata(ident)
   local metadata = UPGRADE_METADATA[ident]
   if metadata == nil then
      local upgrade = CUpgrade:Get(ident)
      if upgrade == nil then
         return nil
      end
      metadata = {
         typeHash = StableHash32(ident),
         goldCost = Number(upgrade.Costs[1]),
         woodCost = Number(upgrade.Costs[2])
      }
      UPGRADE_METADATA[ident] = metadata
   end
   return metadata
end


local function SortBySlot(units)
   table.sort(units, function(left, right)
      return left.slot < right.slot
   end)
end

local function ResourceKind(resource)
   if resource == "gold" then
      return RESOURCE_GOLD
   end
   if resource == "wood" or resource == "lumber" then
      return RESOURCE_WOOD
   end
   return RESOURCE_NONE
end

local function TypeMetadata(ident)
   local metadata = UNIT_METADATA[ident]
   if metadata == nil then
      metadata = {
         typeHash = StableHash32(ident),
         building = GetUnitTypeData(ident, "Building"),
         canAttack = GetUnitTypeData(ident, "CanAttack"),
         resource = GetUnitTypeData(ident, "GivesResource"),
         goldCost = Number(GetUnitTypeData(ident, "Costs", "gold")),
         woodCost = Number(GetUnitTypeData(ident, "Costs", "wood")),
         attackRange = Number(GetUnitTypeData(ident, "MaxAttackRange")),
         tileWidth = Number(GetUnitTypeData(ident, "TileWidth")),
         tileHeight = Number(GetUnitTypeData(ident, "TileHeight")),
         sightRange = 0
      }
      UNIT_METADATA[ident] = metadata
   end
   return metadata
end

local function UnitMetadata(slot, ident)
   local metadata = TypeMetadata(ident)
   if metadata.sightRange == 0 then
      metadata.sightRange = Number(GetUnitVariable(slot, "SightRange"))
   end
   return metadata
end

local function ReadUnit(slot)
   if not GetUnitVariable(slot, "Active") then
      return nil
   end

   local ident = GetUnitVariable(slot, "Ident")
   if ident == nil then
      return nil
   end

   local hitPoints = Number(GetUnitVariable(slot, "HitPoints"))
   if hitPoints <= 0 and ident ~= "unit-road" then
      return nil
   end

   local metadata = UnitMetadata(slot, ident)
   local attackRange = Number(GetUnitVariable(slot, "AttackRange"))
   local sightRange = Number(GetUnitVariable(slot, "SightRange"))
   if attackRange <= 0 then
      attackRange = metadata.attackRange
   end
   if sightRange <= 0 then
      sightRange = metadata.sightRange
   end

   return {
      slot = slot,
      owner = Number(GetUnitVariable(slot, "Player")),
      ident = ident,
      role = UNIT_ROLES[ident],
      idle = GetUnitVariable(slot, "Idle"),
      x = Number(GetUnitVariable(slot, "PosX")),
      y = Number(GetUnitVariable(slot, "PosY")),
      hitPoints = hitPoints,
      maxHitPoints = math.max(Number(GetUnitVariable(slot, "HitPoints", "Max")), 1),
      mana = Number(GetUnitVariable(slot, "Mana")),
      building = metadata.building,
      wall = GetUnitBoolFlag(slot, "Wall"),
      canAttack = metadata.canAttack,
      resource = metadata.resource,
      resourceKind = ResourceKind(metadata.resource),
      goldCost = metadata.goldCost,
      woodCost = metadata.woodCost,
      typeHash = metadata.typeHash,
      attackRange = attackRange,
      sightRange = sightRange
   }
end

local function IsEnemy(playerIndex, owner)
   if owner == playerIndex or Players[playerIndex] == nil or Players[owner] == nil then
      return false
   end
   return Players[playerIndex]:IsEnemy(Players[owner])
end

local function OnMapUnits(world, units)
   local result = {}
   for _, unit in ipairs(units) do
      if world.onMapSlots[unit.slot] then
         table.insert(result, unit)
      end
   end
   return result
end

local function NewWorldSnapshot(playerIndex)
   local world = {
      playerIndex = playerIndex,
      gold = Number(GetPlayerData(playerIndex, "Resources", "gold")),
      wood = Number(GetPlayerData(playerIndex, "Resources", "wood")),
      supply = Number(GetPlayerData(playerIndex, "Supply")),
      demand = Number(GetPlayerData(playerIndex, "Demand")),
      width = Number(Map.Info.MapWidth),
      height = Number(Map.Info.MapHeight),
      own = {},
      ownByIdent = {},
      ownTypeCounts = {},
      ownMobile = {},
      workers = {},
      cityCenters = {},
      roads = {},
      attackers = {},
      ownBuildings = {},
      enemy = {},
      enemyUnits = {},
      enemyBuildings = {},
      resources = {},
      entities = {},
      roleCounts = {}
   }

   for _, slot in ipairs(GetUnits("any")) do
      local unit = ReadUnit(slot)
      if unit ~= nil then
         if unit.role == "road" then
            table.insert(world.roads, unit)
         else
            local relation = nil
            if unit.owner == playerIndex then
               relation = RELATION_OWN
            elseif IsEnemy(playerIndex, unit.owner) then
               relation = RELATION_ENEMY
            elseif unit.resourceKind ~= RESOURCE_NONE then
               relation = RELATION_NEUTRAL
            end

            if relation ~= nil then
               unit.relation = relation
               table.insert(world.entities, unit)
               if relation == RELATION_OWN then
                  table.insert(world.own, unit)
                  if world.ownByIdent[unit.ident] == nil then
                     world.ownByIdent[unit.ident] = {}
                  end
                  table.insert(world.ownByIdent[unit.ident], unit)
                  world.ownTypeCounts[unit.ident] = (world.ownTypeCounts[unit.ident] or 0) + 1
                  if unit.role ~= nil then
                     world.roleCounts[unit.role] = (world.roleCounts[unit.role] or 0) + 1
                  end
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
                  end
               elseif relation == RELATION_ENEMY then
                  table.insert(world.enemy, unit)
                  if not unit.wall then
                     if unit.building then
                        table.insert(world.enemyBuildings, unit)
                     else
                        table.insert(world.enemyUnits, unit)
                     end
                  end
               else
                  table.insert(world.resources, unit)
               end
            end
         end
      end
   end

   SortBySlot(world.entities)
   for index, unit in ipairs(world.entities) do
      unit.entityIndex = index
   end
   SortBySlot(world.own)
   SortBySlot(world.ownMobile)
   SortBySlot(world.workers)
   SortBySlot(world.cityCenters)
   SortBySlot(world.roads)
   SortBySlot(world.attackers)
   SortBySlot(world.ownBuildings)
   SortBySlot(world.enemy)
   SortBySlot(world.enemyUnits)
   SortBySlot(world.enemyBuildings)
   SortBySlot(world.resources)

   world.onMapSlots = {}
   local anchor = world.resources[1] or world.ownBuildings[1] or world.enemyBuildings[1] or
      world.own[1] or world.enemy[1]
   if anchor ~= nil then
      world.onMapSlots[anchor.slot] = true
      local range = math.max(world.width, world.height)
      for _, allUnits in ipairs({true, false}) do
         for _, slot in ipairs(GetUnitsAroundUnit(anchor.slot, range, allUnits)) do
            world.onMapSlots[slot] = true
         end
      end
   end
   world.commandWorkers = OnMapUnits(world, world.workers)
   world.commandCityCenters = OnMapUnits(world, world.cityCenters)
   world.commandRoads = OnMapUnits(world, world.roads)
   world.commandAttackers = OnMapUnits(world, world.attackers)
   world.commandOwnBuildings = OnMapUnits(world, world.ownBuildings)
   world.commandEnemyUnits = OnMapUnits(world, world.enemyUnits)
   world.commandEnemyBuildings = OnMapUnits(world, world.enemyBuildings)
   world.commandResources = OnMapUnits(world, world.resources)
   return world
end

local function DistanceSquared(first, second)
   local x = first.x - second.x
   local y = first.y - second.y
   return x * x + y * y
end

local function Distance(first, second)
   return math.floor(math.sqrt(DistanceSquared(first, second)) + 0.5)
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

local function ProducerUnits(world, identifiers)
   local producers = {}
   for _, ident in ipairs(identifiers) do
      for _, unit in ipairs(world.ownByIdent[ident] or {}) do
         if unit.idle and world.onMapSlots[unit.slot] then
            table.insert(producers, unit)
         end
      end
   end
   SortBySlot(producers)
   return producers
end

local function CanAfford(world, ident)
   local metadata = TypeMetadata(ident)
   return world.gold >= metadata.goldCost and world.wood >= metadata.woodCost
end

local function IsAllowed(world, ident)
   return GetPlayerData(world.playerIndex, "Allow", ident) == "A" and
      CheckDependency(world.playerIndex, ident)
end

local function CanProduce(world, ident)
   return IsAllowed(world, ident) and CanAfford(world, ident)
end

local function CanResearch(world, ident)
   local metadata = UpgradeMetadata(ident)
   return metadata ~= nil and
      IsAllowed(world, ident) and
      world.gold >= metadata.goldCost and
      world.wood >= metadata.woodCost
end

local function HasUpgrade(world, ident)
   return ident == nil or GetPlayerData(world.playerIndex, "Allow", ident) == "R"
end

local function AssetValue(units)
   local total = 0
   for _, unit in ipairs(units) do
      if not unit.wall then
         total = total + (unit.goldCost + unit.woodCost) * unit.hitPoints / unit.maxHitPoints
      end
   end
   return total
end

local function RewardBooks()
   return stratagus.gameData.AIState.war1gusRewardBookkeeping
end

local function RewardComponents(playerIndex, world, terminal)
   local enemyAsset = AssetValue(world.enemy)
   local ownAsset = AssetValue(world.own)
   local books = RewardBooks()
   local book = books[playerIndex]
   local components = {
      enemyProgress = 0,
      ownLoss = 0,
      time = 0,
      terminal = 0
   }
   local canStart = GetNumOpponents(playerIndex) > 0 or enemyAsset > 0

   if book == nil or not book.started then
      if canStart then
         book = {
            started = true,
            hadOpponent = true,
            initialEnemy = math.max(enemyAsset, 1),
            maxOwn = math.max(ownAsset, 1),
            previousEnemy = enemyAsset,
            previousOwn = ownAsset,
            previousTimeBucket = math.floor(GameCycle / 300)
         }
         books[playerIndex] = book
      end
   else
      components.enemyProgress = Round(
         600 * (book.previousEnemy - enemyAsset) / math.max(book.initialEnemy, 1)
      )
      book.maxOwn = math.max(book.maxOwn, ownAsset, 1)
      components.ownLoss = -Round(
         150 * math.max(book.previousOwn - ownAsset, 0) / book.maxOwn
      )
      local bucket = math.floor(GameCycle / 300)
      components.time = -math.max(bucket - book.previousTimeBucket, 0)
      book.previousEnemy = enemyAsset
      book.previousOwn = ownAsset
      book.previousTimeBucket = bucket
   end

   if terminal == "defeat" then
      components.terminal = -1000
   elseif terminal == "victory" then
      components.terminal = 1000
   end

   components.total = ClampReward(
      components.enemyProgress + components.ownLoss + components.time + components.terminal
   )
   return components, ownAsset, enemyAsset
end

local function TerminalOutcome(playerIndex, world)
   if Number(GetPlayerData(playerIndex, "TotalNumUnits")) == 0 then
      return "defeat"
   end
   local book = RewardBooks()[playerIndex]
   if book ~= nil and book.started and book.hadOpponent and GetNumOpponents(playerIndex) == 0 then
      return "victory"
   end
   return nil
end

local function EntityWords(unit)
   local flags = 0
   if unit.canAttack then
      flags = flags + 1
   end
   if unit.building then
      flags = flags + 2
   end
   if unit.wall then
      flags = flags + 4
   end
   if unit.idle then
      flags = flags + 8
   end
   return {
      NonNegativeWord(unit.slot),
      UInt32(unit.typeHash),
      NonNegativeWord(unit.relation),
      NonNegativeWord(ROLE_CODES[unit.role] or 0),
      NonNegativeWord(unit.x),
      NonNegativeWord(unit.y),
      NonNegativeWord(unit.hitPoints),
      NonNegativeWord(unit.maxHitPoints),
      NonNegativeWord(unit.goldCost),
      NonNegativeWord(unit.woodCost),
      NonNegativeWord(flags),
      NonNegativeWord(unit.resourceKind),
      NonNegativeWord(unit.attackRange),
      NonNegativeWord(unit.sightRange)
   }
end

local function AppendWords(destination, source)
   for _, word in ipairs(source) do
      table.insert(destination, word)
   end
end

local function CandidateSet()
   local records = {}
   local plans = {}

   local function append(kind, plan, fields)
      if #plans >= MAX_CANDIDATES then
         return false
      end
      fields = fields or {}
      plan = plan or {kind = "wait"}
      plan.candidateKind = kind
      table.insert(plans, plan)
      table.insert(records, {
         NonNegativeWord(kind),
         NonNegativeWord(fields.actor),
         NonNegativeWord(fields.target),
         UInt32(fields.auxiliaryHash or 0),
         NonNegativeWord(fields.x),
         NonNegativeWord(fields.y),
         NonNegativeWord(fields.groupSize),
         NonNegativeWord(fields.formation),
         NonNegativeWord(fields.cadence),
         NonNegativeWord(fields.distance),
         NonNegativeWord(fields.producerCount),
         NonNegativeWord(fields.bootstrapScore)
      })
      return true
   end

   append(KIND_WAIT, {kind = "wait"}, {cadence = 5})
   return records, plans, append
end

local function AddDirectCandidate(append, kind, actor, target, verb, argument, fields)
   if actor == nil then
      return false
   end
   fields = fields or {}
   fields.actor = actor.entityIndex
   if target ~= nil then
      fields.target = target.entityIndex
      if fields.distance == nil then
         fields.distance = Distance(actor, target)
      end
   end
   return append(kind, {
      kind = "direct",
      actor = actor,
      verb = verb,
      argument = argument
   }, fields)
end

local function ClampPosition(world, x, y)
   x = math.max(0, math.min(world.width - 1, math.floor(x)))
   y = math.max(0, math.min(world.height - 1, math.floor(y)))
   return x, y
end

local function FindNearestForest(worker, world)
   local limit = math.max(world.width, world.height)
   local result = nil
   for radius = 0, limit do
      if result ~= nil and radius * radius > result.distance then
         break
      end
      local minX = math.max(0, worker.x - radius)
      local maxX = math.min(world.width - 1, worker.x + radius)
      local minY = math.max(0, worker.y - radius)
      local maxY = math.min(world.height - 1, worker.y + radius)
      local function consider(x, y)
         if GetTileTerrainHasFlag(x, y, "forest") then
            local dx = worker.x - x
            local dy = worker.y - y
            local distance = dx * dx + dy * dy
            if result == nil or distance < result.distance or
               (distance == result.distance and (y < result.y or (y == result.y and x < result.x))) then
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

local function ClosestUnit(origin, units)
   local result = nil
   for _, unit in ipairs(units) do
      local distance = DistanceSquared(origin, unit)
      if result == nil or distance < result.distance or
         (distance == result.distance and unit.slot < result.unit.slot) then
         result = {unit = unit, distance = distance}
      end
   end
   return result
end


local function BuildingCount(world, specification)
   if specification.road then
      return #world.roads
   end
   return world.ownTypeCounts[specification.ident] or 0
end


local function BuildSpecificationEnabled(world, specification)
   if specification.initialCityCenter then
      return preferences.RebalancedStats and #world.cityCenters == 0
   end
   if specification.cityCenter then
      if #world.cityCenters == 0 then
         return not preferences.RebalancedStats
      end
      return preferences.AllowMultipleTownHalls == true and #world.cityCenters < specification.maxCount
   end
   if specification.demandDriven and world.demand < world.supply then
      return false
   end
   local limit = specification.maxCount
   if specification.workersPerAdditional ~= nil then
      limit = math.min(
         limit,
         specification.baseLimit + math.floor(#world.workers / specification.workersPerAdditional)
      )
   end
   return limit == nil or BuildingCount(world, specification) < limit
end

local function AddBuildCandidates(world, tech, append)
   local buildCount = 0
   for _, specification in ipairs(tech.buildings) do
      if BuildSpecificationEnabled(world, specification) and CanProduce(world, specification.ident) then
         local metadata = TypeMetadata(specification.ident)
         local producers = ProducerUnits(world, specification.producers)
         for producerIndex, producer in ipairs(producers) do
            if producerIndex > 16 or buildCount >= 128 then
               break
            end
            if not AddDirectCandidate(
               append,
               KIND_BUILD,
               producer,
               nil,
               "build",
               specification.ident,
               {
                  auxiliaryHash = metadata.typeHash,
                  x = producer.x,
                  y = producer.y,
                  cadence = 30,
                  producerCount = #producers,
                  bootstrapScore = specification.bootstrapScore or 150
               }
            ) then
               return
            end
            buildCount = buildCount + 1
         end
      end
   end
end

local function AddTrainCandidates(world, tech, append)
   if world.demand >= world.supply then
      return
   end
   for _, specification in ipairs(tech.training) do
      if CanProduce(world, specification.ident) then
         local metadata = TypeMetadata(specification.ident)
         local producers = ProducerUnits(world, specification.producers)
         for producerIndex, producer in ipairs(producers) do
            if producerIndex > 24 then
               break
            end
            if not AddDirectCandidate(append, KIND_TRAIN, producer, nil, "train", specification.ident, {
               auxiliaryHash = metadata.typeHash,
               cadence = 30,
               producerCount = #producers,
               bootstrapScore = specification.bootstrapScore or 180
            }) then
               return
            end
         end
      end
   end
end

local function AddResearchCandidates(world, tech, append)
   for _, specification in ipairs(tech.research) do
      if CanResearch(world, specification.ident) then
         local metadata = UpgradeMetadata(specification.ident)
         local producers = ProducerUnits(world, specification.producers)
         for producerIndex, producer in ipairs(producers) do
            if producerIndex > 16 then
               break
            end
            if not AddDirectCandidate(append, KIND_RESEARCH, producer, nil, "research", specification.ident, {
               auxiliaryHash = metadata.typeHash,
               cadence = 30,
               producerCount = #producers,
               bootstrapScore = 90
            }) then
               return
            end
         end
      end
   end
end

local function AddMacroCandidates(world, tech, append)
   AddBuildCandidates(world, tech, append)
   AddTrainCandidates(world, tech, append)
   AddResearchCandidates(world, tech, append)
end
local function StrategicSpellPositions(world)
   local maxX = math.max(world.width - 1, 0)
   local maxY = math.max(world.height - 1, 0)
   local xCoordinates = {
      math.floor(maxX / 4),
      math.floor(maxX / 2),
      math.floor(3 * maxX / 4)
   }
   local yCoordinates = {
      math.floor(maxY / 4),
      math.floor(maxY / 2),
      math.floor(3 * maxY / 4)
   }
   local positions = {}
   local seen = {}
   for _, y in ipairs(yCoordinates) do
      for _, x in ipairs(xCoordinates) do
         local key = x .. ":" .. y
         if not seen[key] then
            seen[key] = true
            table.insert(positions, {x = x, y = y})
         end
      end
   end
   return positions
end


local function AddSpellCandidates(world, tech, append)
   for _, specification in ipairs(tech.spells) do
      if HasUpgrade(world, specification.upgrade) then
         local casters = ProducerUnits(world, specification.casters)
         local positions = specification.target == "position" and StrategicSpellPositions(world) or nil
         for casterIndex, caster in ipairs(casters) do
            if casterIndex > 32 then
               break
            end
            if caster.mana >= specification.mana then
               if positions ~= nil then
                  for _, position in ipairs(positions) do
                     if not AddDirectCandidate(
                        append,
                        KIND_CAST_SPELL,
                        caster,
                        nil,
                        "cast-position",
                        {spell = specification.ident, x = position.x, y = position.y},
                        {
                           auxiliaryHash = StableHash32(specification.ident),
                           x = position.x,
                           y = position.y,
                           cadence = 5,
                           producerCount = #casters,
                           bootstrapScore = 110
                        }
                     ) then
                        return
                     end
                  end
               elseif not AddDirectCandidate(
                  append,
                  KIND_CAST_SPELL,
                  caster,
                  nil,
                  "cast-auto",
                  specification.ident,
                  {
                     auxiliaryHash = StableHash32(specification.ident),
                     cadence = 5,
                     producerCount = #casters,
                     bootstrapScore = 130
                  }
               ) then
                  return
               end
            end
         end
      end
   end
end

local function AddGatherCandidates(world, append)
   local goldMines = {}
   for _, resource in ipairs(world.commandResources) do
      if resource.resourceKind == RESOURCE_GOLD then
         table.insert(goldMines, resource)
      end
   end
   for workerIndex, worker in ipairs(IdleUnits(world.commandWorkers)) do
      if workerIndex > 32 then
         break
      end
      local mine = ClosestUnit(worker, goldMines)
      if mine ~= nil then
         if not AddDirectCandidate(append, KIND_GATHER_GOLD, worker, mine.unit, "resource", mine.unit.slot, {
            cadence = 30,
            bootstrapScore = 100
         }) then
            return
         end
      end
      local forest = FindNearestForest(worker, world)
      if forest ~= nil then
         if not AddDirectCandidate(append, KIND_GATHER_WOOD, worker, nil, "resource-location", {forest.x, forest.y}, {
            x = forest.x,
            y = forest.y,
            cadence = 30,
            distance = math.floor(math.sqrt(forest.distance) + 0.5),
            bootstrapScore = 100
         }) then
            return
         end
      end
   end
end

local function AttackGroup(attackers, target)
   local group = {}
   for _, actor in ipairs(attackers) do
      table.insert(group, actor)
   end
   return {
      kind = "group",
      actors = group,
      verb = "attack",
      targetSlot = target.slot
   }
end

local function MoveGroup(attackers, x, y)
   local group = {}
   for _, actor in ipairs(attackers) do
      table.insert(group, actor)
   end
   return {
      kind = "group",
      actors = group,
      verb = "move",
      position = {x = x, y = y}
   }
end

local function FormationPositions(world, actors, target, formation)
   local positions = {}
   local count = #actors
   local columns = math.max(1, math.ceil(math.sqrt(count)))
   for index = 1, count do
      local offsetX = 0
      local offsetY = 0
      if formation == FORMATION_LINE then
         offsetX = index - math.ceil(count / 2)
      elseif formation == FORMATION_BOX then
         offsetX = (index - 1) % columns - math.floor(columns / 2)
         offsetY = math.floor((index - 1) / columns) - math.floor(columns / 2)
      else
         offsetX = ((index - 1) % 3 - 1) * 3
         offsetY = (math.floor((index - 1) / 3) - 1) * 3
      end
      local x, y = ClampPosition(world, target.x + offsetX, target.y + offsetY)
      positions[index] = {x = x, y = y}
   end
   return positions
end

local function AddMicroCandidates(world, append)
   local workers = IdleUnits(world.commandWorkers)
   local attackers = world.commandAttackers

   local damagedBuildings = {}
   for _, building in ipairs(world.commandOwnBuildings) do
      if building.hitPoints < building.maxHitPoints then
         table.insert(damagedBuildings, building)
      end
   end
   for workerIndex, worker in ipairs(workers) do
      if workerIndex > 32 then
         break
      end
      local damaged = ClosestUnit(worker, damagedBuildings)
      if damaged ~= nil then
         if not AddDirectCandidate(append, KIND_REPAIR, worker, damaged.unit, "repair", damaged.unit.slot, {
            cadence = 5,
            bootstrapScore = 140
         }) then
            return
         end
      end
   end

   local targets = {}
   for _, target in ipairs(world.commandEnemyUnits) do
      table.insert(targets, target)
   end
   for _, target in ipairs(world.commandEnemyBuildings) do
      table.insert(targets, target)
   end

   for actorIndex, actor in ipairs(attackers) do
      if actorIndex > 64 then
         break
      end
      local target = ClosestUnit(actor, targets)
      if target ~= nil then
         if not AddDirectCandidate(append, KIND_ATTACK_ENTITY, actor, target.unit, "attack", target.unit.slot, {
            cadence = 5,
            bootstrapScore = target.unit.building and 160 or 200
         }) then
            return
         end
      end
   end

   local groupTarget = attackers[1] ~= nil and ClosestUnit(attackers[1], targets) or nil
   if #attackers > 1 and groupTarget ~= nil then
      if not append(KIND_ATTACK_ENTITY, AttackGroup(attackers, groupTarget.unit), {
         actor = attackers[1].entityIndex,
         target = groupTarget.unit.entityIndex,
         groupSize = #attackers,
         cadence = 5,
         distance = Distance(attackers[1], groupTarget.unit),
         bootstrapScore = groupTarget.unit.building and 180 or 240
      }) then
         return
      end
   end

   local base = world.commandCityCenters[1]
   if base ~= nil then
      for actorIndex, actor in ipairs(attackers) do
         if actorIndex > 64 then
            break
         end
         if not AddDirectCandidate(append, KIND_DEFEND, actor, base, "move", {base.x, base.y}, {
            x = base.x,
            y = base.y,
            cadence = 5,
            bootstrapScore = 80
         }) then
            return
         end
      end
      if #attackers > 1 then
         if not append(KIND_DEFEND, MoveGroup(attackers, base.x, base.y), {
            actor = attackers[1].entityIndex,
            target = base.entityIndex,
            x = base.x,
            y = base.y,
            groupSize = #attackers,
            cadence = 5,
            distance = Distance(attackers[1], base),
            bootstrapScore = 100
         }) then
            return
         end
      end
   end

   if groupTarget ~= nil and #attackers > 1 then
      local target = groupTarget.unit
      if not append(KIND_MOVE_GROUP, MoveGroup(attackers, target.x, target.y), {
         actor = attackers[1].entityIndex,
         target = target.entityIndex,
         x = target.x,
         y = target.y,
         groupSize = #attackers,
         cadence = 5,
         distance = Distance(attackers[1], target),
         bootstrapScore = 160
      }) then
         return
      end
      for _, formation in ipairs({FORMATION_LINE, FORMATION_BOX, FORMATION_SPREAD}) do
         if not append(KIND_FORMATION, {
            kind = "formation",
            actors = attackers,
            positions = FormationPositions(world, attackers, target, formation)
         }, {
            actor = attackers[1].entityIndex,
            target = target.entityIndex,
            x = target.x,
            y = target.y,
            groupSize = #attackers,
            formation = formation,
            cadence = 5,
            distance = Distance(attackers[1], target),
            bootstrapScore = 120
         }) then
            return
         end
      end
   end

   local explorePoints = {
      {x = 0, y = 0},
      {x = world.width - 1, y = 0},
      {x = 0, y = world.height - 1},
      {x = world.width - 1, y = world.height - 1}
   }
   for actorIndex, actor in ipairs(attackers) do
      if actorIndex > 64 then
         break
      end
      local point = explorePoints[(actorIndex - 1) % #explorePoints + 1]
      if not AddDirectCandidate(append, KIND_EXPLORE, actor, nil, "explore", nil, {
         x = point.x,
         y = point.y,
         cadence = 5,
         bootstrapScore = 40
      }) then
         return
      end
   end
end

local function RaceState(playerIndex)
   local race = GetPlayerData(playerIndex, "RaceName")
   if race == race1 then
      return 0, HUMAN_TECH
   end
   return 1, ORC_TECH
end

local function PlayerTotals(playerIndex, name, resource)
   if resource ~= nil then
      return NonNegativeWord(GetPlayerData(playerIndex, name, resource))
   end
   return NonNegativeWord(GetPlayerData(playerIndex, name))
end

local function ShouldEmitMacro(playerIndex)
   local macroCycles = stratagus.gameData.AIState.war1gusLastMacroCycle
   local previousCycle = macroCycles[playerIndex]
   if previousCycle == nil or GameCycle - previousCycle >= 30 then
      macroCycles[playerIndex] = GameCycle
      return true
   end
   return false
end

local function BuildObservation(playerIndex, world, includeCandidates, terminal)
   local raceId, tech = RaceState(playerIndex)
   local components, ownAsset, enemyAsset = RewardComponents(playerIndex, world, terminal)
   local records = {}
   local plans = {}

   if includeCandidates then
      local append
      records, plans, append = CandidateSet()
      if ShouldEmitMacro(playerIndex) then
         AddMacroCandidates(world, tech, append)
         AddGatherCandidates(world, append)
      end
      AddMicroCandidates(world, append)
      AddSpellCandidates(world, tech, append)
   end

   local state = {
      3,
      NonNegativeWord(playerIndex),
      NonNegativeWord(raceId),
      NonNegativeWord(GameCycle),
      NonNegativeWord(world.gold),
      NonNegativeWord(world.wood),
      NonNegativeWord(world.supply),
      NonNegativeWord(world.demand),
      NonNegativeWord(world.width),
      NonNegativeWord(world.height),
      NonNegativeWord(#world.entities),
      NonNegativeWord(#records),
      NonNegativeWord(Round(ownAsset)),
      NonNegativeWord(Round(enemyAsset)),
      PlayerTotals(playerIndex, "TotalResources", "gold"),
      PlayerTotals(playerIndex, "TotalResources", "wood"),
      PlayerTotals(playerIndex, "TotalKills"),
      PlayerTotals(playerIndex, "TotalRazings"),
      SignedWord(components.enemyProgress),
      SignedWord(components.ownLoss),
      SignedWord(components.time),
      SignedWord(components.terminal)
   }

   for _, entity in ipairs(world.entities) do
      AppendWords(state, EntityWords(entity))
   end
   for _, record in ipairs(records) do
      AppendWords(state, record)
   end

   return state, plans, components
end

function War1gusAiFinalState(playerIndex, terminal)
   local world = NewWorldSnapshot(playerIndex)
   if terminal == nil then
      terminal = TerminalOutcome(playerIndex, world)
   end
   local state = BuildObservation(playerIndex, world, false, terminal)
   return state
end

function War1gusAiTerminalReward(playerIndex, state)
   if type(state) ~= "table" then
      state = War1gusAiFinalState(playerIndex, TerminalOutcome(playerIndex, NewWorldSnapshot(playerIndex)))
   end
   return ClampReward(
      Signed32(state[STATE_REWARD_ENEMY_PROGRESS]) +
      Signed32(state[STATE_REWARD_OWN_LOSS]) +
      Signed32(state[STATE_REWARD_TIME]) +
      Signed32(state[STATE_REWARD_TERMINAL])
   )
end

local function IsEnded(playerIndex)
   return stratagus.gameData.AIState.war1gusAiEnded[playerIndex] == true
end

local function EndPlayer(playerIndex, terminal)
   if IsEnded(playerIndex) then
      return
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
   if server == nil then
      return
   end
   local playerIndexes = {}
   for playerIndex, _ in pairs(server.handles) do
      table.insert(playerIndexes, playerIndex)
   end
   for _, playerIndex in ipairs(playerIndexes) do
      local world = NewWorldSnapshot(playerIndex)
      local terminal = TerminalOutcome(playerIndex, world)
      if terminal ~= nil then
         EndPlayer(playerIndex, terminal)
      end
   end
end

local function ExecutePlan(playerIndex, plan)
   if plan == nil or plan.kind == "wait" then
      return true
   end
   if plan.kind == "direct" then
      if plan.argument == nil then
         return AiDirectCommand(playerIndex, plan.actor.slot, plan.verb)
      end
      return AiDirectCommand(playerIndex, plan.actor.slot, plan.verb, plan.argument)
   end
   local issued = false
   if plan.kind == "group" then
      for _, actor in ipairs(plan.actors) do
         local accepted
         if plan.targetSlot ~= nil then
            accepted = AiDirectCommand(playerIndex, actor.slot, plan.verb, plan.targetSlot)
         else
            accepted = AiDirectCommand(playerIndex, actor.slot, plan.verb, {plan.position.x, plan.position.y})
         end
         issued = accepted or issued
      end
      return issued
   end
   if plan.kind == "formation" then
      for index, actor in ipairs(plan.actors) do
         local position = plan.positions[index]
         local accepted = AiDirectCommand(playerIndex, actor.slot, "move", {position.x, position.y})
         issued = accepted or issued
      end
      return issued
   end
   return false
end

local function LogReward(playerIndex, components)
   if not VERBOSE_LOGGING then
      return
   end
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
   local playerIndex = AiPlayer()
   FinalizeEndedPlayers()
   if IsEnded(playerIndex) then
      return
   end

   local world = NewWorldSnapshot(playerIndex)
   local terminal = TerminalOutcome(playerIndex, world)
   if terminal ~= nil then
      EndPlayer(playerIndex, terminal)
      return
   end

   local state, plans, components = BuildObservation(playerIndex, world, true, nil)
   LogReward(playerIndex, components)
   local handle = GetWar1gusAiProcessor(playerIndex, state)
   if handle == nil then
      War1gusAiLog("war1gus-ai.lifecycle", {
         {name = "player", value = tostring(playerIndex)},
         {name = "event", value = JsonString("processor-unavailable")}
      })
      return
   end

   local selected = AiProcessorStep(handle, components.total, state, #plans)
   if type(selected) ~= "number" or selected ~= math.floor(selected) or selected < 1 or selected > #plans then
      War1gusAiLog("war1gus-ai.action", {
         {name = "player", value = tostring(playerIndex)},
         {name = "event", value = JsonString("invalid-selection")},
         {name = "selection", value = JsonString(tostring(selected))},
         {name = "candidate_count", value = tostring(#plans)}
      })
      return
   end

   local plan = plans[selected]
   local accepted = ExecutePlan(playerIndex, plan)
   if VERBOSE_LOGGING then
      War1gusAiLog("war1gus-ai.action", {
         {name = "player", value = tostring(playerIndex)},
         {name = "candidate", value = tostring(selected - 1)},
         {name = "kind", value = JsonString(KIND_NAMES[plan.candidateKind])},
         {name = "accepted", value = tostring(accepted)}
      })
   end
end

DefineAi("war1gus-ai", "*", "war1gus-ai", War1gusAI, 5)
