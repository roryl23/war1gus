# About War1gus

<img src="./war1gus.png" width="100" align="right" />

War1gus is a re-implementation of **Warcraft: Orcs & Humans** that that can be played on modern platforms with the [Stratagus engine](https://github.com/Wargus/stratagus). The game uses graphics and sounds from the original Warcraft, but improves the gameplay mechanisms with many modern conveniences that the Stratagus engine allows, such as modern mouse controls, named groups, larger group selection, more player factions in multiplayer games, a map editor, and multiple towns. 

You can find more details at [stratagus.com](https://stratagus.com/war1gus.html) 

### Nightly builds

These are builds from our CI runs. Since they are built every time a commit is made, they may be unstable. 

- [Windows Installer](https://github.com/Wargus/war1gus/releases/tag/master-builds)
- [Ubuntu/Debian Packages](https://launchpad.net/~stratagus/+archive/ubuntu/ppa) 
- [macOS App Bundles](https://github.com/Wargus/war1gus/actions/workflows/macos.yml?query=branch%3Amaster)

### Extracting data for macOS

In order to play War1gus you first need to extract the game data from your Warcraft installer. The built-in extractor tool is currently not working correctly on macOS, but
[this third-party script](https://github.com/shinra-electric/Stratagus-Data-Extractor-Script) can be used while fixes are being worked on. <br>

Run the script in the same folder as your game data and the War1gus app. **It only needs to be run once**. 

It will not be needed in the future when the built-in extractor is fixed. 

### Build status

Windows: <a href="https://ci.appveyor.com/project/timfel/war1gus"><img width="100" src="https://ci.appveyor.com/api/projects/status/github/Wargus/war1gus?branch=master&svg=true"></a>

Linux: [![Build Status](https://travis-ci.org/Wargus/war1gus.svg?branch=master)](https://travis-ci.org/Wargus/war1gus)

macOS: ![Build Status](https://github.com/Wargus/war1gus/actions/workflows/macos.yml/badge.svg)


### Join the community
[![Join the chat at https://gitter.im/Wargus](https://badges.gitter.im/Join%20Chat.svg)](https://gitter.im/Wargus?utm_source=badge&utm_medium=badge&utm_campaign=pr-badge&utm_content=badge)

[![Discord](https://img.shields.io/discord/780082494447288340?style=flat-square&logo=discord&label=discord)](https://discord.gg/dQGxaw3QfB)


### Gallery
<img width="800" src="https://user-images.githubusercontent.com/93911529/157967177-0eab04af-a704-415d-8f6f-294d0e5aaed0.png">


### War1gus AI

This fork adds an experimental Julia/Flux actor-critic policy as an AI
opponent. The policy receives economy, infrastructure, army, and enemy-force
state from Stratagus and selects one of 24 primitive commands: gathering,
building, training, research, movement, repair, exploration, or an explicit
target-class attack. Lua resolves actors and targets deterministically, then
the engine executes the selected command directly. A producer-supplied legal
mask prevents unavailable commands without running a second strategic policy.

#### Usage

The integration is currently Linux-focused. It launches the compiled Julia
application as a child process and uses Stratagus' `AiProcessor*` TCP API on
localhost. It does not exchange commands through temporary files or execute
model-generated Lua.

First build and extract War1gus as described above. Install Julia 1.12 with
`juliaup`, then initialize the AI source, a `main`-tracking submodule, and
build the AI application:

```sh
git submodule update --init scripts/ai/war1gus
cd scripts/ai/war1gus
julia --project -e 'using Pkg; Pkg.instantiate()'
bash build.sh
```

Build and run War1gus from the repository root:

```sh
bash build.sh War1gus
./build/war1gus
```

Select `war1gus-ai` for a computer player. The Lua integration starts the
repository build at `scripts/ai/war1gus/build/bin/War1gusAI` when it is
available, then falls back to the installed game-data copy. Set
`WAR1GUS_AI_BINARY` to use another executable explicitly. The process starts on
demand and closes when the game ends.

Normal launches perform deterministic inference from the saved policy:

```sh
./build/war1gus
```

Enable online self-play training for every selected `war1gus-ai` player with:

```sh
./build/war1gus --train
```

Continue training loads both model and optimizer state from
`$XDG_STATE_HOME/war1gus/actor_critic.jls`, or
`~/.local/state/war1gus/actor_critic.jls` when `XDG_STATE_HOME` is unset.
Start again from the seeded initial policy and discard that checkpoint with:

```sh
./build/war1gus --reset-train
```

`--reset-train` implies training and is consumed by the first AI process in
that launcher session; later matches continue with `--train` instead of
resetting the first match's updates. Each AI connection attributes the next
signed reward to its previous state and action. Rewards are normalized toward
eliminating all enemy non-wall units and buildings: enemy losses are positive,
own losses and idle steps are negative, and victory or defeat supplies the
terminal bonus. Resource collection and production do not directly create
reward. Transitions from all AI players enter one ordered 32-sample queue; the
triggering connection performs one shared actor-critic batch update.
The server withholds action responses only while that update is running.
Stratagus checks for a response every 1000 milliseconds and reconnects after
an actual socket failure, so gameplay pauses instead of dropping or duplicating
the decision during a live update.
