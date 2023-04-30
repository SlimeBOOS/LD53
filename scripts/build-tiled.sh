#!/bin/sh

tiled --export-map lua assets/world.tmx src/resources/world.lua
tiled --export-tileset lua assets/buildings.tsx src/resources/buildings.lua
tiled --export-tileset lua assets/city.tsx src/resources/city.lua
tiled --export-tileset lua assets/landscape.tsx src/resources/landscape.lua
tiled --export-tileset lua assets/cars.tsx src/resources/cars.lua

lua scripts/process-tilesets.lua src/resources/world.lua src/resources/city.lua src/resources/landscape.lua src/resources/buildings.lua src/resources/cars.lua
