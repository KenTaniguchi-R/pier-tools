#!/bin/sh
set -eu

PORT="${1:-}"
if [ -z "$PORT" ]; then
  echo "usage: kill-port <port>" >&2
  exit 2
fi

PIDS="$(lsof -ti:"$PORT" 2>/dev/null || true)"
if [ -z "$PIDS" ]; then
  echo "no process on port $PORT"
  exit 0
fi

# shellcheck disable=SC2086
echo "killing pid(s):" $PIDS
echo "$PIDS" | xargs kill -9
echo "done."
