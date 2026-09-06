#!/bin/bash
# Runs a local dedicated server and a client together against the real
# assets, each with its own scratch storage (so this never touches your real
# save) - for testing multiplayer/networked behavior locally instead of
# guessing from client-only or server-only testing.
#
# There's no CLI flag to auto-join a server - once both windows are up, use
# the client's in-game "Join Game" menu and connect to 127.0.0.1 (default
# port 21025).
#
# Usage: scripts/dev/run-dev-multiplayer.sh [-- extra args passed to both]
#
# Override OPENSTARBOUND_MP_SERVER_STORAGE / OPENSTARBOUND_MP_CLIENT_STORAGE
# to reuse a specific scratch world/character across runs instead of
# whatever's already in build/linux-dev/mp-*-storage.
set -euo pipefail
cd "$(dirname "$0")/../.."

SERVER_STORAGE="${OPENSTARBOUND_MP_SERVER_STORAGE:-build/linux-dev/mp-server-storage}"
CLIENT_STORAGE="${OPENSTARBOUND_MP_CLIENT_STORAGE:-build/linux-dev/mp-client-storage}"

echo "Starting server (storage: $SERVER_STORAGE)..."
OPENSTARBOUND_DEV_STORAGE="$SERVER_STORAGE" scripts/dev/run-dev.sh server -loglevel debug "$@" &
SERVER_PID=$!
trap 'kill "$SERVER_PID" 2>/dev/null || true' EXIT

echo "Waiting for the server to start listening..."
for _ in $(seq 1 60); do
  if ! kill -0 "$SERVER_PID" 2>/dev/null; then
    echo "error: server exited before it started listening - check build/linux-dev/starbound_server.log" >&2
    exit 1
  fi
  if grep -q "listening for incoming TCP connections" build/linux-dev/starbound_server.log 2>/dev/null; then
    break
  fi
  sleep 0.5
done

echo "Server is up. Starting client (storage: $CLIENT_STORAGE) - once loaded, use Join Game -> 127.0.0.1"
OPENSTARBOUND_DEV_STORAGE="$CLIENT_STORAGE" scripts/dev/run-dev.sh client -loglevel debug "$@"

echo "Client exited, stopping server..."
