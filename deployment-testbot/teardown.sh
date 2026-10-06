#!/usr/bin/env bash
# Stop Spring PetClinic started by setup.sh (both docker and local runtimes). Safe to re-run.
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
PIDFILE="$HERE/.petclinic.pid"

if command -v docker >/dev/null 2>&1; then
  docker compose -f "$HERE/docker-compose.yml" down --remove-orphans || true
fi
if [ -f "$PIDFILE" ]; then
  PID="$(cat "$PIDFILE")"
  if kill -0 "$PID" 2>/dev/null; then
    echo "Stopping local petclinic (pid $PID)"
    kill "$PID" || true
  fi
  rm -f "$PIDFILE"
fi
echo "Teardown complete"
