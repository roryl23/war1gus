--       _________ __                 __                               
--      /   _____//  |_____________ _/  |______     ____  __ __  ______
--      \_____  \\   __\_  __ \__  \\   __\__  \   / ___\|  |  \/  ___/
--      /        \|  |  |  | \// __ \|  |  / __ \_/ /_/  >  |  /\___ \ 
--     /_______  /|__|  |__|  (____  /__| (____  /\___  /|____//____  >
--             \/                  \/          \//_____/            \/ 
--  ______________________                           ______________________
--                        T H E   W A R   B E G I N S
--         Stratagus - A free fantasy real time strategy game engine
--
--      ai.lua - Define the AI.
--
--      (c) Copyright 2000-2013 by Lutz Sammer, Jimmy Salmon, and Joris Dauphin
--
--      This program is free software; you can redistribute it and/or modify
--      it under the terms of the GNU General Public License as published by
--      the Free Software Foundation; either version 2 of the License, or
--      (at your option) any later version.
--  
--      This program is distributed in the hope that it will be useful,
--      but WITHOUT ANY WARRANTY; without even the implied warranty of
--      MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
--      GNU General Public License for more details.
--  
--      You should have received a copy of the GNU General Public License
--      along with this program; if not, write to the Free Software
--      Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
--
--      $Id$


--(define (ai:sleep) () #t)

race1 = "human"
race2 = "orc"

DefineAiHelper(
   {"unit-equiv", "unit-human-town-hall", "unit-human-stormwind-keep"}
)
DefineAiHelper(
   {"unit-equiv", "unit-orc-town-hall", "unit-orc-blackrock-spire"}
)

--
--  City-center of the current race.
--
function AiCityCenter()
   if (AiGetRace() == race1) then
      return "unit-human-town-hall"
   else
      return "unit-orc-town-hall"
   end
end

--
--  instant build City-center of the current race.
--
function AiStartCityCenter()
   if (AiGetRace() == race1) then
      return "unit-human-first-town-hall"
   else
      return "unit-orc-first-town-hall"
   end
end

--
--  Worker of the current race.
--
function AiWorker()
   if (AiGetRace() == race1) then
      return "unit-peasant"
   else
      return "unit-peon"
   end
end

--
--  Farm of the current race.
--
function AiFarm()
   if (AiGetRace() == race1) then
      return "unit-human-farm"
   else
      return "unit-orc-farm"
   end
end

--
--  Lumber mill of the current race.
--
function AiLumberMill()
   if (AiGetRace() == race1) then
      return "unit-human-lumber-mill"
   else
      return "unit-orc-lumber-mill"
   end
end

--
--  Tower of the current race.
--
function AiTower()
   if (AiGetRace() == race1) then
      return "unit-human-guard-tower"
   else
      return "unit-orc-watch-tower"
   end
end


--
--  Blacksmith of the current race.
--
function AiBlacksmith()
   if (AiGetRace() == race1) then
      return "unit-human-blacksmith"
   else
      return "unit-orc-blacksmith"
   end
end

--
--  Upgrade armor 1 of the current race.
--
function AiUpgradeArmor1()
   if (AiGetRace() == race1) then
      return "upgrade-human-shield1"
   else
      return "upgrade-orc-shield1"
   end
end

--
--  Upgrade armor 2 of the current race.
--
function AiUpgradeArmor2()
   if (AiGetRace() == race1) then
      return "upgrade-human-shield2"
   else
      return "upgrade-orc-shield2"
   end
end

--
--  Upgrade weapon 1 of the current race.
--
function AiUpgradeWeapon1()
   if (AiGetRace() == race1) then
      return "upgrade-sword1"
   else
      return "upgrade-axe1"
   end
end

--
--  Upgrade weapon 2 of the current race.
--
function AiUpgradeWeapon2()
   if (AiGetRace() == race1) then
      return "upgrade-sword2"
   else
      return "upgrade-axe2"
   end
end

--
--  Upgrade missile 1 of the current race.
--
function AiUpgradeMissile1()
   if (AiGetRace() == race1) then
      return "upgrade-arrow1"
   else
      return "upgrade-spear1"
   end
end

--
--  Upgrade missile 2 of the current race.
--
function AiUpgradeMissile2()
   if (AiGetRace() == race1) then
      return "upgrade-arrow2"
   else
      return "upgrade-spear2"
   end
end

--  Upgrade building armor of the current race.
--
function AiUpgradeBuilding1()
   if (AiGetRace() == race1) then
      return "upgrade-human-BuildingArmor1"
   else
      return "upgrade-orc-BuildingArmor1"
   end
end

--  Upgrade building armor 2 of the current race.
--
function AiUpgradeBuilding2()
   if (AiGetRace() == race1) then
      return "upgrade-human-BuildingArmor2"
   else
      return "upgrade-orc-BuildingArmor2"
   end
end

--
--  Upgrade light armor 1 of the current race.
--
function AiUpgradeLightArmor1()
   if (AiGetRace() == race1) then
      return "upgrade-human-LightArmor1"
   else
      return "upgrade-orc-LightArmor1"
   end
end

--
--  Upgrade light armor 2 of the current race.
--
function AiUpgradeLightArmor2()
   if (AiGetRace() == race1) then
      return "upgrade-human-LightArmor2"
   else
      return "upgrade-orc-LightArmor2"
   end
end

--
--  Upgrade catapult weapon 1 of the current race.
--
function AiUpgradeCatapult1()
   if (AiGetRace() == race1) then
      return "upgrade-human-CatapultAmmo1"
   else
      return "upgrade-orc-CatapultAmmo1"
   end
end

--
--  Upgrade catapult weapon 2 of the current race.
--
function AiUpgradeCatapult2()
   if (AiGetRace() == race1) then
      return "upgrade-human-CatapultAmmo2"
   else
      return "upgrade-orc-CatapultAmmo2"
   end
end

--
--  Upgrade catapult speed of the current race.
--
function AiUpgradeCatapultSpeed1()
   if (AiGetRace() == race1) then
      return "upgrade-human-CatapultSpeed"
   else
      return "upgrade-orc-CatapultSpeed"
   end
end

--
--  Upgrade cavalry speed of the current race.
--
function AiUpgradeCavalrySpeed1()
   if (AiGetRace() == race1) then
      return "upgrade-horse1"
   else
      return "upgrade-wolves1"
   end
end

--
--  Upgrade cavalry speed 2 of the current race.
--
function AiUpgradeCavalrySpeed2()
   if (AiGetRace() == race1) then
      return "upgrade-horse2"
   else
      return "upgrade-wolves2"
   end
end

--
--  Upgrade cavalry ability of the current race.
--
function AiUpgradeCavalrySkill1()
   if (AiGetRace() == race1) then
      return "upgrade-human-barding1"
   else
      return "upgrade-orc-saliva1"
   end
end

--
--  Upgrade cavalry ability 2 of the current race.
--
function AiUpgradeCavalrySkill2()
   if (AiGetRace() == race1) then
      return "upgrade-human-barding2"
   else
      return "upgrade-orc-saliva2"
   end
end

--
--  Stables of the current race.
--
function AiStables()
   if (AiGetRace() == race1) then
      return "unit-human-stable"
   else
      return "unit-orc-kennel"
   end
end

--
--  Temple of the current race.
--
function AiTemple()
   if (AiGetRace() == race1) then
      return "unit-human-church"
   else
      return "unit-orc-temple"
   end
end

--
--  Mage tower of the current race.
--
function AiMageTower()
   if (AiGetRace() == race1) then
      return "unit-human-tower"
   else
      return "unit-orc-tower"
   end
end

--
--  Barracks of the current race.
--
function AiBarracks()
   if (AiGetRace() == race1) then
      return "unit-human-barracks"
   else
      return "unit-orc-barracks"
   end
end

--
--  Soldier of the current race.
--
function AiSoldier()
   if (AiGetRace() == race1) then
      return "unit-footman"
   else
      return "unit-grunt"
   end
end

--
--  Shooter of the current race.
--
function AiShooter()
   if (AiGetRace() == race1) then
      return "unit-archer"
   else
      return "unit-spearman"
   end
end

--
--  Cavalry of the current race.
--
function AiCavalry()
   if (AiGetRace() == race1) then
      return "unit-knight"
   else
      return "unit-raider"
   end
end

--
-- Supporting mage
--
function AiMage()
   if (AiGetRace() == race1) then
      return "unit-cleric"
   else
      return "unit-necrolyte"
   end
end

--
--  Summoner of the current race.
--
function AiSummoner()
   if (AiGetRace() == race1) then
      return "unit-conjurer"
   else
      return "unit-warlock"
   end
end

--
--  Catapult of the current race.
--
function AiCatapult()
   if (AiGetRace() == race1) then
      return "unit-human-catapult"
   else
      return "unit-orc-catapult"
   end
end

--
--  1st spell of the cleric/necrolyte of the current race.
--
function AiMageSpell1()
   if (AiGetRace() == race1) then
      return "upgrade-far-seeing"
   else
      return "upgrade-dark-vision"
   end
end

--
--  2nd spell of the cleric/necrolyte of the current race.
--
function AiMageSpell2()
   if (AiGetRace() == race1) then
      return "upgrade-healing"
   else
      return "upgrade-raise-dead"
   end
end

--
--  3rd spell of the cleric/necrolyte of the current race.
--
function AiMageSpell3()
   if (AiGetRace() == race1) then
      return "upgrade-invisibility"
   else
      return "upgrade-unholy-armor"
   end
end

--
--  1st spell of the summoners of the current race.
--
function AiSummonerSpell1()
   if (AiGetRace() == race1) then
      return "upgrade-scorpion"
   else
      return "upgrade-spider"
   end
end

--
--  2nd spell of the summoners of the current race.
--
function AiSummonerSpell2()
   if (AiGetRace() == race1) then
      return "upgrade-rain-of-fire"
   else
      return "upgrade-poison-cloud"
   end
end

--
--  3th spell of the summoners of the current race.
--
function AiSummonerSpell3()
   if (AiGetRace() == race1) then
      return "upgrade-water-elemental"
   else
      return "upgrade-daemon"
   end
end

--
--  Some functions used by Ai
--

local WAR1GUS_AI_RELATIVE_BINARY = "scripts/ai/war1gus/build/bin/War1gusAI"
local function War1gusAiHost()
   local host = preferences.War1gusAiHost
   if type(host) ~= "string" or host == "" or #host > 253
      or host:match("^[A-Za-z0-9%.%-]+$") == nil
      or host:match("^%.") ~= nil or host:match("%.$") ~= nil or host:match("%.%.") ~= nil then
      error("invalid War1gusAiHost: expected a hostname or IPv4 address")
   end
   for label in host:gmatch("[^%.]+") do
      if #label > 63 or label:match("^[A-Za-z0-9]") == nil
         or label:match("[A-Za-z0-9]$") == nil
         or label:match("^[A-Za-z0-9%-]+$") == nil then
         error("invalid War1gusAiHost: expected a hostname or IPv4 address")
      end
   end
   return host
end
local function War1gusAiPortValue(name, value)
   if type(value) == "string" and value:match("^%d+$") == nil then
      error("invalid " .. name .. ": " .. tostring(value))
   end
   if type(value) ~= "number" and type(value) ~= "string" then
      error("invalid " .. name .. ": " .. tostring(value))
   end
   local port = tonumber(value)
   if port == nil or port ~= math.floor(port) or port < 1 or port > 65535 then
      error("invalid " .. name .. ": " .. tostring(value))
   end
   return port
end
local function War1gusAiPort()
   local configuredPort = os.getenv("WAR1GUS_AI_PORT")
   if configuredPort ~= nil and configuredPort ~= "" then
      return War1gusAiPortValue("WAR1GUS_AI_PORT", configuredPort)
   end
   return War1gusAiPortValue("War1gusAiPort", preferences.War1gusAiPort)
end
local function War1gusAiEndpoint()
   return War1gusAiHost(), War1gusAiPort()
end
local function War1gusAiMode()
   local mode = os.getenv("WAR1GUS_AI_MODE")
   if mode == nil or mode == "" then
      return nil
   end
   if mode ~= "train" and mode ~= "reset-train" and mode ~= "league-train" and mode ~= "league-evaluate" then
      error("invalid WAR1GUS_AI_MODE: " .. mode)
   end
   return mode
end
local war1gusAiMode = War1gusAiMode()
function War1gusAiAsyncMode()
   return war1gusAiMode == nil
end
local war1gusAiEpoch = 0
local function War1gusAiFileExists(path)
   local file = io.open(path, "rb")
   if file == nil then
      return false
   end
   file:close()
   return true
end



local function War1gusAiBinary()
   local configuredBinary = os.getenv("WAR1GUS_AI_BINARY")
   if configuredBinary ~= nil and configuredBinary ~= "" then
      if not War1gusAiFileExists(configuredBinary) then
         error("WAR1GUS_AI_BINARY is not accessible: " .. configuredBinary)
      end
      return configuredBinary
   end
   if War1gusAiFileExists(WAR1GUS_AI_RELATIVE_BINARY) then
      return WAR1GUS_AI_RELATIVE_BINARY
   end
   local libraryBinary = LibraryPath() .. "/" .. WAR1GUS_AI_RELATIVE_BINARY
   if War1gusAiFileExists(libraryBinary) then
      return libraryBinary
   end
   return WAR1GUS_AI_RELATIVE_BINARY
end
local function CreateAiGameData()
   if stratagus == nil then
      stratagus = {}
   end
   if stratagus.gameData == nil then
      stratagus.gameData = {}
   end
   if stratagus.gameData.AIState == nil then
      stratagus.gameData.AIState = {}
   end
   local aiState = stratagus.gameData.AIState
   if aiState.index == nil then
      aiState.index = {1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1}
   end
   if aiState.loop_index == nil then
      aiState.loop_index = {1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1}
   end
   if aiState.war1gusRewardBookkeeping == nil then
      aiState.war1gusRewardBookkeeping = {}
   end
   if aiState.war1gusAiEnded == nil then
      aiState.war1gusAiEnded = {}
   end
end



local function War1gusAiTerminalState(state)
   local entityCount = math.max(0, math.floor(tonumber(state[11]) or 0))
   local wordCount = 22 + 14 * entityCount
   local terminalState = {}
   for index = 1, wordCount do
      terminalState[index] = state[index]
   end
   terminalState[12] = 0
   return terminalState
end

local function ClearWar1gusSelectionState()
   local aiState = stratagus.gameData.AIState
   if aiState ~= nil then
      aiState.war1gusSelectionStages = nil
      aiState.war1gusDeferredReward = nil
      aiState.war1gusRejectionPenalty = nil
   end
end

local function CloseWar1gusAiServer()
   if stratagus == nil or stratagus.gameData == nil then
      return
   end

   local server = stratagus.gameData.War1gusAiServer
   if server == nil then
      ClearWar1gusSelectionState()
      return
   end

   server.epoch = server.epoch + 1
   for playerIndex, handle in pairs(server.handles) do
      if War1gusAiAsyncMode() then
         local pending = server.pending[playerIndex]
         if pending ~= nil and War1gusAiLog ~= nil then
            War1gusAiLog("war1gus-ai.discard", {
               {name = "player", value = tostring(playerIndex)},
               {name = "sequence", value = tostring(pending.sequence)},
               {name = "observation_cycle", value = tostring(pending.cycle)},
               {name = "response_cycle", value = tostring(GameCycle or 0)},
               {name = "reason", value = "\"map-cleanup\""}
            })
         end
         pcall(AiProcessorCancel, handle)
         pcall(AiProcessorEnd, handle)
      else
         local state = server.states[playerIndex]
         if War1gusAiFinalState ~= nil then
            local ok, finalState = pcall(War1gusAiFinalState, playerIndex)
            if ok and type(finalState) == "table" then
               state = finalState
            end
         end
         if type(state) == "table" then
            local terminalState = War1gusAiTerminalState(state)
            local ok, delivered = pcall(
               AiProcessorEnd, handle, War1gusAiTerminalReward(playerIndex, terminalState), terminalState
            )
            if (not ok or not delivered) and War1gusAiLog ~= nil then
               War1gusAiLog("war1gus-ai.lifecycle", {
                  {name = "player", value = tostring(playerIndex)},
                  {name = "event", value = "\"terminal-delivery-failed\""}
               })
            end
         else
            pcall(AiProcessorEnd, handle)
         end
      end
   end
   server.handles = {}
   server.pending = {}
   server.states = {}
   ClearWar1gusSelectionState()
   server.process:close()
   stratagus.gameData.War1gusAiServer = nil
end

function StartWar1gusAiServer()
   CreateAiGameData()
   local server = stratagus.gameData.War1gusAiServer
   if server == nil then
      local mode = war1gusAiMode
      local host, port = War1gusAiEndpoint()
      local command = string.format(
         "%q --host %s --port %d%s",
         War1gusAiBinary(),
         host,
         port,
         mode == nil and "" or " --" .. mode
      )
      local process = io.popen(command, "w")
      if process == nil then
         return nil
      end
      if war1gusAiMode == "reset-train" then
         war1gusAiMode = "train"
      end
      war1gusAiEpoch = war1gusAiEpoch + 1
      server = {
         process = process,
         host = host,
         port = port,
         epoch = war1gusAiEpoch,
         handles = {},
         pending = {},
         states = {}
      }
      stratagus.gameData.War1gusAiServer = server
   end
   return server
end

function GetWar1gusAiProcessor(playerIndex, state)
   CreateAiGameData()
   if stratagus.gameData.AIState.war1gusAiEnded[playerIndex] then
      return nil
   end
   local server = StartWar1gusAiServer()
   if server == nil then
      return nil
   end

   local handle = server.handles[playerIndex]
   if handle == nil then
      handle = AiProcessorSetup(server.host, server.port)
      if handle == nil then
         return nil
      end
      server.handles[playerIndex] = handle
   end
   server.states[playerIndex] = state
   return handle
end

function EndWar1gusAiProcessor(playerIndex, reward, state)
   CreateAiGameData()
   local aiState = stratagus.gameData.AIState
   if aiState.war1gusAiEnded[playerIndex] then
      return false
   end
   aiState.war1gusAiEnded[playerIndex] = true
   if aiState.war1gusSelectionStages ~= nil then
      aiState.war1gusSelectionStages[playerIndex] = nil
   end
   if aiState.war1gusDeferredReward ~= nil then
      aiState.war1gusDeferredReward[playerIndex] = nil
   end
   if aiState.war1gusRejectionPenalty ~= nil then
      aiState.war1gusRejectionPenalty[playerIndex] = nil
   end

   local server = stratagus.gameData.War1gusAiServer
   if server == nil then
      return false
   end
   local handle = server.handles[playerIndex]
   if handle == nil then
      return false
   end
   server.handles[playerIndex] = nil
   server.pending[playerIndex] = nil
   server.states[playerIndex] = nil
   if War1gusAiAsyncMode() then
      pcall(AiProcessorCancel, handle)
      pcall(AiProcessorEnd, handle)
   else
      local ok, delivered = pcall(AiProcessorEnd, handle, reward, state)
      if (not ok or not delivered) and War1gusAiLog ~= nil then
         War1gusAiLog("war1gus-ai.lifecycle", {
            {name = "player", value = tostring(playerIndex)},
            {name = "event", value = "\"terminal-delivery-failed\""}
         })
      end
   end
   return true
end

local function CleanAiGameData()
   if stratagus ~= nil and stratagus.gameData ~= nil then
      CloseWar1gusAiServer()
      stratagus.gameData.AIState = nil
   end
end

function ReInitAiGameData()
   CleanAiGameData()
   CreateAiGameData()
end

function DebugMessage(message)
   message = "Game cycle(" .. GameCycle .. "):".. message
   --	AddMessage(message)
   DebugPrint(message .. "\n")
end

function AiLoop(loop_funcs, indexes)
   local playerIndex = AiPlayer() + 1

   while (true) do
      local func = loop_funcs[indexes[playerIndex]]
      local ret = false
      if (func == nil) then
         AddMessage("BUG: Please file a bug 'AI loop broken' with the level and this number: " .. indexes[playerIndex])
         indexes[playerIndex] = 0
      else
         ret = func()
      end
      if (ret == true) then
         break
      elseif ret == false or ret == nil then
         indexes[playerIndex] = indexes[playerIndex] + 1
      else
         indexes[playerIndex] = indexes[playerIndex] + ret
      end
   end
   return true
end

--
--  Load the actual individual scripts.
--
ReInitAiGameData()
Load("scripts/ai/passive.lua")
Load("scripts/ai/land_attack.lua")
Load("scripts/ai/campaign.lua")
Load("scripts/ai/war1gus_ai.lua")
