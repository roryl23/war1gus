#!/bin/bash

# usage: bash build.sh [Stratagus,War1gusAI,War1gus]
# if run with no stage specified, all builds will run

stage="${1:-}"

git submodule init && \
git submodule sync && \
git submodule update

if [ -z "$stage" ]; then
  root=$PWD

  # Stratagus
  cd stratagus && \
  git submodule init && \
  git submodule sync && \
  git submodule update && \
  mkdir -p build && cd build && \
  cmake .. \
    -DCMAKE_BUILD_TYPE=Debug \
    -DBUILD_VENDORED_LUA=OFF \
    -DBUILD_VENDORED_SDL=OFF \
    -DBUILD_VENDORED_MEDIA_LIBS=OFF \
    -DBUILD_TESTING=1 \
    -DENABLE_DEV=ON && \
  cmake --build . --config Debug && \
  sudo make install && cd $root && \
  # War1gusAI
  cd scripts/ai/war1gus && \
  bash build.sh && cd $root && \
  # War1gus
  cmake . -B build \
    -DCMAKE_FIND_FRAMEWORK=LAST \
    -DSTRATAGUS_INCLUDE_DIR=stratagus/gameheaders \
    -DSTRATAGUS=stratagus/build/stratagus-dbg \
    -DENABLE_VENDORED_LIBS=OFF && \
  cmake --build build --config Release && \
  cd build && sudo make install
elif [ "$stage" = "Stratagus" ]; then
  cd stratagus && \
  git submodule init && \
  git submodule sync && \
  git submodule update && \
  mkdir -p build && cd build && \
  cmake .. \
    -DBUILD_VENDORED_LUA=OFF \
    -DBUILD_VENDORED_SDL=OFF \
    -DBUILD_VENDORED_MEDIA_LIBS=OFF \
    -DBUILD_TESTING=1 \
    -DENABLE_DEV=ON \
    -DEAGER_LOAD=ON && \
  cmake --build . --config Release && \
  sudo make install
elif [ "$stage" = "War1gusAI" ]; then
  cd scripts/ai/war1gus && \
  bash build.sh
elif [ "$stage" = "War1gus" ]; then
  cmake . -B build \
    -DCMAKE_FIND_FRAMEWORK=LAST \
    -DSTRATAGUS_INCLUDE_DIR=stratagus/gameheaders \
    -DSTRATAGUS=stratagus/build/stratagus \
    -DENABLE_VENDORED_LIBS=OFF && \
  cmake --build build --config Release && \
  cd build && sudo make install
fi
