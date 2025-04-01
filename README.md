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

This fork adds a self-training transformer model as an AI opponent.

#### Usage

This build has only been tested on Ubuntu 22.04.
Using another platform is left as an exercise for the reader,
but this will probably only work on Linux because the file
`/tmp/War1gusAI.out` is directly referenced in the code.

You'll need to follow the instructions above with War1gus first,
in order to generate all the files that the usage steps below
expect to run correctly.

* Install dependencies:
  * Stratagus build dependencies:
    * `brew install sdl2 sdl2_image sdl2_mixer sdl2_net libogg libvorbis`
    * `sudo apt-get install tolua++`
  * Julia Programming Language
    * Install juliaup: `curl -fsSL https://install.julialang.org | sh`
    * Install Julia 1.11.4 and instantiate project: `juliaup add 1.11.4 && juliaup override set 1.11.4 && julia --project -e 'using Pkg; Pkg.activate("."); Pkg.instantiate(); Pkg.update();'`
  * War1gus build dependencies:
    * [localexec](https://github.com/eriksank/localexec): `luarocks install localexec`
* Build, install, and run: `bash build.sh && ./build/war1gus`
