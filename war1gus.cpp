/*
       _________ __                 __
      /   _____//  |_____________ _/  |______     ____  __ __  ______
      \_____  \\   __\_  __ \__  \\   __\__  \   / ___\|  |  \/  ___/
      /        \|  |  |  | \// __ \|  |  / __ \_/ /_/  >  |  /\___ |
     /_______  /|__|  |__|  (____  /__| (____  /\___  /|____//____  >
             \/                  \/          \//_____/            \/
  ______________________                           ______________________
                        T H E   W A R   B E G I N S
         Stratagus - A free fantasy real time strategy game engine

    war1gus.cpp - War1gus Game Launcher
    Copyright (C) 2010-2011  Pali Rohár <pali.rohar@gmail.com>
    Copyright (C) 2015 Tim Felgentreff <timfelgentreff@gmail.com>

    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 2 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program.  If not, see <http://www.gnu.org/licenses/>.

*/

#define GAME_NAME "War1gus"
#define GAME_CD "Warcraft I DOS DATA.WAR file or GoG installer exe"
#define GAME_CD_FILE_PATTERNS "DATA.WAR", "data.war", "setup*.exe"
#define GAME "war1gus"
#define EXTRACTOR_TOOL "war1tool"
#define EXTRACTOR_ARGS {"-v", NULL}
#define EXTRACTION_FILES "war1data"
#define CHECK_EXTRACTED_VERSION 1
#define __war1gus_contrib__                                                    \
  "campaigns", "campaigns", "contrib", "contrib", "maps", "maps", "shaders",   \
      "shaders", "scripts", "scripts", ":optional:", "music/TimGM6mb.sf2",     \
      "music/TimGM6mb.sf2"

#ifdef WIN32
#define CONTRIB_DIRECTORIES {__war1gus_contrib__, NULL}
#else
// for convenience during development, we also try to copy the system
// soundfont to the data directory on linux
#define CONTRIB_DIRECTORIES                                                    \
  {__war1gus_contrib__, "/usr/share/sounds/sf2/TimGM6mb.sf2",                  \
   "music/TimGM6mb.sf2", NULL}
#endif

const char *SRC_PATH() { return __FILE__; }

#ifdef WIN32
#define TITLE_PNG "%s\\graphics\\ui\\title_screen.png"
#else
#define TITLE_PNG "%s/graphics/ui/title_screen.png"
#endif

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static void SetWar1gusAiMode(const char *mode) {
#if defined(_WIN32) || defined(_WIN64)
  const int result = _putenv_s("WAR1GUS_AI_MODE", mode == nullptr ? "" : mode);
#else
  const int result = mode == nullptr ? unsetenv("WAR1GUS_AI_MODE")
                                     : setenv("WAR1GUS_AI_MODE", mode, 1);
#endif
  if (result != 0) {
    fprintf(stderr, "Unable to set WAR1GUS_AI_MODE\n");
    exit(EXIT_FAILURE);
  }
}

static void War1gusLauncherPreArguments(int &argc, char *argv[]) {
  bool train = false;
  bool resetTrain = false;
  bool leagueTrain = false;
  bool leagueEvaluate = false;
  int writeIndex = 1;

  for (int readIndex = 1; readIndex < argc; ++readIndex) {
    if (!strcmp(argv[readIndex], "--train")) {
      train = true;
    } else if (!strcmp(argv[readIndex], "--reset-train")) {
      resetTrain = true;
    } else if (!strcmp(argv[readIndex], "--league-train")) {
      leagueTrain = true;
    } else if (!strcmp(argv[readIndex], "--league-evaluate")) {
      leagueEvaluate = true;
    } else {
      argv[writeIndex++] = argv[readIndex];
    }
  }
  argc = writeIndex;
  argv[argc] = nullptr;

  const int aiModeCount =
      static_cast<int>(train) + static_cast<int>(resetTrain) +
      static_cast<int>(leagueTrain) + static_cast<int>(leagueEvaluate);
  if (aiModeCount > 1) {
    fprintf(stderr, "Only one AI mode may be selected: --train, --reset-train, "
                    "--league-train, or --league-evaluate\n");
    exit(EXIT_FAILURE);
  }

  SetWar1gusAiMode(leagueEvaluate ? "league-evaluate"
                   : leagueTrain  ? "league-train"
                   : resetTrain   ? "reset-train"
                   : train        ? "train"
                                  : nullptr);
}

#define GAME_LAUNCHER_PRE_ARGUMENT_HOOK(argc, argv)                            \
  War1gusLauncherPreArguments(argc, argv)
#define GAME_LAUNCHER_EXTRA_HELP                                               \
  "\t--train - train the shared War1gus AI policy\n"                           \
  "\t--reset-train - reset then train the shared War1gus AI policy\n"          \
  "\t--league-train - train the shared War1gus AI policy against a league\n"   \
  "\t--league-evaluate - evaluate the policy against a league without "        \
  "updates\n"

#include <stratagus-game-launcher.h>
