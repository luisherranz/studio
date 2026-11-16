#!/bin/sh
# Usage: runtime-probe.sh <Studio.app/Contents>
# Compares the bundled Node with the Electron binary run as Node: versions and
# start-up time of an empty script and of the bundled CLI's --version.
C="$1"
E="$C/MacOS/Studio"
N="$C/Resources/bin/node"
CLI="$C/Resources/cli/main.mjs"
echo "bundled node: $("$N" -p 'process.versions.node+" openssl="+process.versions.openssl+" v8="+process.versions.v8')"
echo "electron as node: $(ELECTRON_RUN_AS_NODE=1 "$E" -p 'process.versions.node+" electron="+process.versions.electron+" openssl="+(process.versions.openssl||"-")+" boringssl="+(process.versions.boringssl||"-")+" v8="+process.versions.v8')"
t() {
	label="$1"; shift
	start=$(perl -MTime::HiRes=time -e 'printf "%.3f", time')
	i=0
	while [ $i -lt 10 ]; do "$@" >/dev/null 2>&1; i=$((i+1)); done
	end=$(perl -MTime::HiRes=time -e 'printf "%.3f", time')
	echo "$label: $(echo "($end - $start) * 100" | bc) ms per run (10 runs)"
}
t "bundled node -e 0" "$N" -e 0
t "electron as node -e 0" env ELECTRON_RUN_AS_NODE=1 "$E" -e 0
t "bundled node cli --version" "$N" "$CLI" --version
t "electron as node cli --version" env ELECTRON_RUN_AS_NODE=1 "$E" "$CLI" --version
