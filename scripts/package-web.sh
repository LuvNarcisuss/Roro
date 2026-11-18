#!/bin/sh
set -e
cd "$SRCROOT/.."
"$NODE_BINARY" scripts/package-web.mjs
