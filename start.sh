#!/bin/sh
# Owncast start script for Railway.
#
# Owncast has no environment-variable configuration: every setting lives in its
# SQLite database (/app/data/owncast.db), which upstream seeds with the public
# default admin password and stream key "abc123". This script:
#   * binds the web server to $PORT and RTMP to 1935 (the TCP proxy target),
#   * replaces the default admin password and stream key with the generated
#     OWNCAST_ADMIN_PASSWORD and OWNCAST_STREAM_KEY before anything listens,
#   * sets Owncast's server URL to the Railway domain,
#   * keeps all state on the /app/data volume (database, emoji, logs, HLS).
# Each value is applied once per change of its Railway variable (a fingerprint
# is kept on the volume), so a password or key changed later in Owncast's own
# admin is not reverted by the next deploy. Owncast's exit code is passed
# through (it is exec'd as PID 1), so Railway's ON_FAILURE policy restarts it after a crash.
set -eu

DATA=/app/data
STATE="$DATA/.railway"
PORT="${PORT:-8080}"
RTMP_PORT=1935

log() { printf 'railway-start: %s\n' "$*"; }
fp() { printf '%s' "$1" | sha256sum | cut -d' ' -f1; }

mkdir -p "$STATE"

# Never fall back to upstream's public defaults: if a variable was removed,
# use a random value kept on the volume and say so in the log.
kept() {
  f="$STATE/$1"
  if [ ! -s "$f" ]; then
    head -c 18 /dev/urandom | od -An -tx1 | tr -d ' \n' > "$f"
    chmod 600 "$f"
  fi
  cat "$f"
}
if [ -z "${OWNCAST_ADMIN_PASSWORD:-}" ]; then
  OWNCAST_ADMIN_PASSWORD="$(kept admin-password)"
  log "OWNCAST_ADMIN_PASSWORD is empty: using a random password stored in $STATE/admin-password"
fi
if [ -z "${OWNCAST_STREAM_KEY:-}" ]; then
  OWNCAST_STREAM_KEY="$(kept stream-key)"
  log "OWNCAST_STREAM_KEY is empty: using a random key stored in $STATE/stream-key"
fi
SERVER_URL=""
[ -n "${RAILWAY_PUBLIC_DOMAIN:-}" ] && SERVER_URL="https://${RAILWAY_PUBLIC_DOMAIN}"

set -- -webserverip 0.0.0.0 -webserverport "$PORT" -rtmpport "$RTMP_PORT"

ADMIN_FP="$(fp "$OWNCAST_ADMIN_PASSWORD")"
NEW_ADMIN=0
if [ "$(cat "$STATE/admin-password.fp" 2>/dev/null || true)" != "$ADMIN_FP" ]; then
  NEW_ADMIN=1
  set -- "$@" -adminpassword "$OWNCAST_ADMIN_PASSWORD"
  log "applying the admin password from OWNCAST_ADMIN_PASSWORD"
fi

KEY_FP="$(fp "$OWNCAST_STREAM_KEY")"
NEW_KEY=0
if [ "$(cat "$STATE/stream-key.fp" 2>/dev/null || true)" != "$KEY_FP" ]; then
  NEW_KEY=1
  # -streamkey makes this the only key RTMP accepts for this run, so the
  # default key is never usable, even before the API call below stores it.
  set -- "$@" -streamkey "$OWNCAST_STREAM_KEY"
  log "applying the stream key from OWNCAST_STREAM_KEY"
fi

NEW_URL=0
if [ -n "$SERVER_URL" ] && [ "$(cat "$STATE/server-url" 2>/dev/null || true)" != "$SERVER_URL" ]; then
  NEW_URL=1
fi

# POST a JSON body to Owncast's admin API with busybox wget (exit 0 on 2xx only).
post() {
  wget -q -O /dev/null -T 10 \
    --header "Authorization: Basic $AUTH" --header 'Content-Type: application/json' \
    --post-data "$2" "$API/$1"
}

configure() {
  API="http://127.0.0.1:${PORT}/api"
  AUTH="$(printf 'admin:%s' "$OWNCAST_ADMIN_PASSWORD" | base64 | tr -d '\n')"
  n=0
  until wget -q -O /dev/null -T 5 "$API/status" 2>/dev/null; do
    n=$((n + 1)); [ "$n" -ge 120 ] && { log "Owncast did not answer; settings retried next start"; return 0; }
    sleep 1
  done
  # -adminpassword is applied before the web server starts and Owncast exits
  # non-zero if that fails, so a live API means it took effect.
  [ "$NEW_ADMIN" = 1 ] && printf '%s' "$ADMIN_FP" > "$STATE/admin-password.fp"
  if [ "$NEW_KEY" = 1 ]; then
    if post admin/config/streamkeys "{\"value\":[{\"key\":\"$OWNCAST_STREAM_KEY\",\"comment\":\"From the OWNCAST_STREAM_KEY Railway variable\"}]}"; then
      printf '%s' "$KEY_FP" > "$STATE/stream-key.fp"
      log "stream key stored; the default key is gone"
    else
      log "could not store the stream key (still enforced for this run); retried next start"
    fi
  fi
  if [ "$NEW_URL" = 1 ]; then
    if post admin/config/serverurl "{\"value\":\"$SERVER_URL\"}"; then
      printf '%s' "$SERVER_URL" > "$STATE/server-url"
      log "server URL set to $SERVER_URL"
    else
      log "could not set the server URL; set it in Admin > Configuration > General"
    fi
  fi
}

if [ "$NEW_ADMIN" = 1 ] || [ "$NEW_KEY" = 1 ] || [ "$NEW_URL" = 1 ]; then
  configure &
fi

if [ -n "${RAILWAY_TCP_PROXY_DOMAIN:-}" ] && [ -n "${RAILWAY_TCP_PROXY_PORT:-}" ]; then
  log "RTMP ingest for OBS: rtmp://${RAILWAY_TCP_PROXY_DOMAIN}:${RAILWAY_TCP_PROXY_PORT}/live (stream key: the OWNCAST_STREAM_KEY variable)"
fi
log "starting Owncast: web on port $PORT, RTMP on port $RTMP_PORT"
cd /app
exec /app/owncast "$@"
