#!/bin/bash

# usage: bash build.sh [Stratagus,War1gusAI,War1gus]
# if run with no stage specified, all builds will run

stage="${1:-}"
war1gus_root=$PWD

sync_runtime() {
  local data_dir="${WAR1GUS_DATA_DIR:-${XDG_DATA_HOME:-$HOME/.local/share}/stratagus/data.War1gus}"
  if [ ! -f "$data_dir/war1data" ]; then
    echo "Skipping runtime sync: no extracted war1data marker in $data_dir"
    return 0
  fi
  cmake "-DWAR1GUS_SOURCE_DIR=$war1gus_root" "-DWAR1GUS_DATA_DIR=$data_dir" \
    -P "$war1gus_root/cmake/sync-runtime.cmake"
}


git submodule init && \
git submodule sync && \
git submodule update --init third-party stratagus scripts/ai/war1gus && \
git -C scripts/ai/war1gus switch main && \
git -C scripts/ai/war1gus fetch origin main && \
git -C scripts/ai/war1gus merge --ff-only origin/main && \
git -C stratagus switch add-war1gus-ai && \
git -C stratagus fetch origin add-war1gus-ai && \
git -C stratagus merge --ff-only origin/add-war1gus-ai || exit $?

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
    -DBUILD_VENDORED_LUA=ON \
    -DBUILD_VENDORED_SDL=ON \
    -DBUILD_VENDORED_MEDIA_LIBS=ON \
    -DDOWNLOAD_FREEPATS=ON \
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
    -DSTRATAGUS=/usr/local/games/stratagus-dbg \
    -DENABLE_VENDORED_LIBS=OFF && \
  cmake --build build --config Release && \
  cmake -E copy_directory stratagus/build/freepats build/freepats && \
  cd build && sudo make install && sync_runtime
elif [ "$stage" = "Stratagus" ]; then
  cd stratagus && \
  git submodule init && \
  git submodule sync && \
  git submodule update && \
  mkdir -p build && cd build && \
  cmake .. \
    -DBUILD_VENDORED_LUA=ON \
    -DBUILD_VENDORED_SDL=ON \
    -DBUILD_VENDORED_MEDIA_LIBS=ON \
    -DDOWNLOAD_FREEPATS=ON \
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
    -DSTRATAGUS=/usr/local/games/stratagus \
    -DENABLE_VENDORED_LIBS=OFF && \
  cmake --build build --config Release && \
  cmake -E copy_directory stratagus/build/freepats build/freepats && \
  cd build && sudo make install && sync_runtime
fi
