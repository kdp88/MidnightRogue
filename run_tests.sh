#!/usr/bin/env bash
# Run the full MidnightRogue test suite.
# Usage: ./run_tests.sh [luaunit args, e.g. -v]

set -e
cd "$(dirname "$0")"

LUA_PATH="C:\\Users\\kpasc\\.luarocks\\share\\lua\\5.4\\?.lua;C:\\Users\\kpasc\\.luarocks\\share\\lua\\5.4\\?\\init.lua;;" \
  lua tests/runner.lua "$@"
