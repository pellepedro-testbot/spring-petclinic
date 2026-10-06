#!/usr/bin/env bash
# Build Spring PetClinic from source and start it for Skyramp Testbot.
#
# Choice: docker compose (default). It builds the app image from this checkout with a
# multi-stage Dockerfile (repo's own ./mvnw), so the PR's code is what runs, isolates the
# JDK version from the runner, and makes teardown a single `compose down`.
# Fallback: PETCLINIC_RUNTIME=local builds the jar with ./mvnw on the host (needs Java 17+)
# and runs it in the background — useful when Docker is unavailable.
#
# Env: PETCLINIC_PORT (default 8080), PETCLINIC_RUNTIME (docker|local, default docker),
#      PETCLINIC_READY_TIMEOUT seconds (default 600).
# Idempotent: re-running rebuilds/restarts. Compatible with macOS /bin/bash 3.2.
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
PORT="${PETCLINIC_PORT:-8080}"
RUNTIME="${PETCLINIC_RUNTIME:-docker}"
TIMEOUT="${PETCLINIC_READY_TIMEOUT:-600}"
URL="http://localhost:${PORT}/actuator/health"
PIDFILE="$HERE/.petclinic.pid"
LOGFILE="$HERE/.petclinic.log"
export PETCLINIC_PORT="$PORT"

case "$RUNTIME" in
  docker)
    echo "Building + starting petclinic via docker compose on :$PORT ..."
    docker compose -f "$HERE/docker-compose.yml" up -d --build
    ;;
  local)
    if [ -f "$PIDFILE" ] && kill -0 "$(cat "$PIDFILE")" 2>/dev/null; then
      echo "Stopping previous local petclinic (pid $(cat "$PIDFILE"))"
      OLD="$(cat "$PIDFILE")"
      kill "$OLD" || true
      i=0; while kill -0 "$OLD" 2>/dev/null && [ "$i" -lt 30 ]; do sleep 1; i=$((i + 1)); done
    fi
    echo "Building petclinic jar with ./mvnw ..."
    (cd "$ROOT" && ./mvnw -B -q -DskipTests package)
    JAR="$(ls "$ROOT"/target/spring-petclinic-*.jar | grep -v -- '-plain' | head -n 1)"
    echo "Starting $JAR on :$PORT (log: $LOGFILE)"
    nohup java -jar "$JAR" --server.port="$PORT" >"$LOGFILE" 2>&1 &
    echo $! >"$PIDFILE"
    ;;
  *)
    echo "Unknown PETCLINIC_RUNTIME=$RUNTIME (use docker or local)" >&2
    exit 2
    ;;
esac

echo "Waiting for $URL (timeout ${TIMEOUT}s) ..."
elapsed=0
until curl -sf -m 5 -o /dev/null "$URL"; do
  if [ "$elapsed" -ge "$TIMEOUT" ]; then
    echo "petclinic not ready after ${TIMEOUT}s" >&2
    if [ "$RUNTIME" = docker ]; then
      docker compose -f "$HERE/docker-compose.yml" logs --tail 200 || true
    else
      tail -n 200 "$LOGFILE" || true
    fi
    exit 1
  fi
  sleep 3
  elapsed=$((elapsed + 3))
done
echo "petclinic ready after ~${elapsed}s: $(curl -s "$URL")"
