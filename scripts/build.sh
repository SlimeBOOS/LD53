#!/bin/sh

BUILD_NAME="ludum-dare-53"
ZIP_OPTIONS="-x '*.xcf' -x '*.kra'"

# Remove existing contents
rm -r build
mkdir build

# Build project
echo Building tiled maps...
./scripts/build-tiled.sh
echo Building project...
cd src
zip -q $ZIP_OPTIONS -r ../build/$BUILD_NAME.love *
cd - > /dev/null

# Jobs done
echo Done.
