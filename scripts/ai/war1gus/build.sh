#!/bin/bash

julia --threads=auto --optimize=3 --project compile.jl --incremental && \
chmod +x build/bin/War1gusAI
