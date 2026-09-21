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

This fork adds an experimental Julia/Flux trajectory-PPO opponent. Stratagus
sends a variable-length protocol-v3 observation containing economy totals,
reward components, and one record per visible own, enemy, or resource entity.
Lua also supplies the exact legal candidate catalog for that decision. Each
candidate names its actor, optional target entity, optional map position,
group/formation metadata, cadence, and production context. The policy scores
that catalog directly instead of selecting from a fixed action list.

Candidates cover gathering, legal building placement, per-structure training
and research, repair, exploration, entity-targeted attacks, group movement,
defence, and formations. The engine validates and executes the selected
primitive command; Julia never emits Lua source.

#### Usage

The integration is currently Linux-focused. It launches the compiled Julia
application as a child process and uses Stratagus' `AiProcessor*` TCP API on
localhost.

First build and extract War1gus as described above, then initialize and compile
the AI application:

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

Select `war1gus-ai` for a computer player. The Lua integration starts
`scripts/ai/war1gus/build/bin/War1gusAI` when available, then falls back to the
installed game-data copy. Set `WAR1GUS_AI_BINARY` to use another executable.
The process starts on demand and closes when the game ends.

Normal launches perform deterministic inference from the saved policy.
`--train` enables stochastic online PPO updates; `--reset-train` removes the
current checkpoint before training. The checkpoint contains model, optimizer,
protocol, reward, catalog, and PPO compatibility metadata. Its default path is
`$XDG_STATE_HOME/war1gus/trajectory_ppo.jls`, or
`~/.local/state/war1gus/trajectory_ppo.jls` when `XDG_STATE_HOME` is unset.

For repeatable headless training, use the rollout coordinator. Training uses
one mutable policy seat, samples frozen opponents from a bounded snapshot
league, randomizes map/seat/seed schedules, and runs benchmark-speed matches:

```sh
julia --project=scripts/ai/war1gus scripts/ai/war1gus/orchestrate.jl train \
  --launcher "$PWD/build/war1gus" \
  --data-dir "$HOME/.local/share/stratagus/data.War1gus" \
  --rollout-config "$PWD/scripts/ai/war1gus/rollout.lua" \
  --map 'maps/GoldRushAI-Max-Observer(5).smp' \
  --matches 100 --workers 1 --timeout-cycles 18000 --seed 1 \
  --state-root "$PWD/ai-training" \
  --checkpoint "$PWD/ai-training/checkpoint.jls" \
  --output "$PWD/ai-training/train.jsonl" --reset
```

Training deliberately requires `--workers 1`: matches update one shared
checkpoint and league directory sequentially. Omit `--reset` to continue.

Evaluate the immutable trained checkpoint on maps excluded from training:

```sh
julia --project=scripts/ai/war1gus scripts/ai/war1gus/orchestrate.jl evaluate \
  --launcher "$PWD/build/war1gus" \
  --data-dir "$HOME/.local/share/stratagus/data.War1gus" \
  --rollout-config "$PWD/scripts/ai/war1gus/rollout.lua" \
  --held-out-map 'maps/Forest1AI-Observer(5).smp' \
  --matches 20 --workers 4 --timeout-cycles 18000 --seed 2 \
  --state-root "$PWD/ai-evaluation" \
  --checkpoint "$PWD/ai-training/checkpoint.jls" \
  --output "$PWD/ai-evaluation/evaluate.jsonl"
```

Evaluation is read-only and reports per-map outcomes, win rate, elimination
time, production, resource, and combat/asset-efficiency proxies as JSON Lines.
Pass `--league-snapshot PATH` to pin every frozen opponent to one compatible
snapshot instead of sampling the checkpoint's sibling `league/` directory.

Rewards use unit/building resource cost multiplied by remaining-health
fraction. Enemy asset loss is positive, own asset loss and elapsed-time buckets
are negative, and victory/defeat adds the terminal component. Every component,
network request/response, selected command, live training sample, PPO update,
league assignment, and episode finalization is logged as JSON. Set
`WAR1GUS_AI_LOG_PATH` to choose the file; stdout records include a `type` field.
