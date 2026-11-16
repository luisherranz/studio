#!/bin/sh
# Usage: site-runtime-probe.sh <Studio.app/Contents> <bundled|electron> <workdir> <port>
# Creates and starts a site with the packaged CLI in an isolated config, process-manager home and
# port range, with the chosen runtime, and reports the wall time of `create` and of a stop+start.
# Cleans up with `stop --all`.
C="$1"; MODE="$2"; W="$3"; PORT="$4"
rm -rf "$W"; mkdir -p "$W/config" "$W/pm" "$W/sites"
export DEV_CONFIG_DIR="$W/config" STUDIO_PROCESS_MANAGER_HOME="$W/pm" STUDIO_BASE_PORT="$PORT"
CLI="$C/Resources/cli/main.mjs"
if [ "$MODE" = electron ]; then
	export ELECTRON_RUN_AS_NODE=1
	RT="$C/MacOS/Studio"
else
	RT="$C/Resources/bin/node"
fi
now() { perl -MTime::HiRes=time -e 'printf "%.2f", time'; }
s=$(now)
"$RT" "$CLI" create --name probe --path "$W/sites/probe" --skip-browser --skip-log-details --avoid-telemetry > "$W/create.log" 2>&1
rc=$?
e=$(now)
echo "$MODE create+start exit=$rc seconds=$(echo "$e - $s" | bc)"
"$RT" "$CLI" stop --path "$W/sites/probe" --avoid-telemetry > /dev/null 2>&1
s=$(now)
"$RT" "$CLI" start --path "$W/sites/probe" --skip-browser --avoid-telemetry > "$W/start.log" 2>&1
rc=$?
e=$(now)
echo "$MODE start exit=$rc seconds=$(echo "$e - $s" | bc)"
code=$(curl -s -o /dev/null -w '%{http_code}' "http://localhost:$PORT/")
echo "$MODE http status: $code"
"$RT" "$CLI" stop --all --avoid-telemetry > /dev/null 2>&1
echo "$MODE ps: $(ps -axo command | grep -c "$W/pm" )"
du -sk "$W/config"/* "$W/config/server-files"/* 2>/dev/null
