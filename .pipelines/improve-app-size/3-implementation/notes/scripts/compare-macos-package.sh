#!/bin/sh
# Usage: compare-macos-package.sh <baseline out folder> <change out folder>
# Compares two `npm run make:macos-arm64` outputs (apps/studio/out): the app's bytes as the
# app-size metric sums them (tools/metrics/utils.ts getDirSize: lstat size of files and symlinks),
# its du -sk, the update zip, the DMG when present, and the parts the change touches.
for label in baseline change; do
	if [ "$label" = baseline ]; then O="$1"; else O="$2"; fi
	A="$O/Studio-darwin-arm64/Studio.app"
	R="$A/Contents/Resources"
	echo "== $label"
	node -e '
		const fs = require( "fs" ), path = require( "path" );
		const size = ( d ) => fs.readdirSync( d, { withFileTypes: true } ).reduce( ( t, e ) => {
			const p = path.join( d, e.name );
			return t + ( e.isDirectory() ? size( p ) : e.isFile() || e.isSymbolicLink() ? fs.lstatSync( p ).size : 0 );
		}, 0 );
		console.log( "app bytes (appSizeMac):", size( process.argv[ 1 ] ) );
	' "$A"
	echo "app KiB (du -sk): $(du -sk "$A" | cut -f1)"
	echo "update zip bytes: $(stat -f %z "$O"/make/zip/darwin/arm64/*.zip)"
	[ -f "$O/Studio-darwin-arm64.dmg" ] && echo "dmg bytes: $(stat -f %z "$O/Studio-darwin-arm64.dmg")"
	echo "Resources/cli/node_modules KiB: $(du -sk "$R/cli/node_modules" | cut -f1); maps+declarations: $(find "$R/cli/node_modules" -type f \( -name '*.map' -o -name '*.d.ts' -o -name '*.d.mts' -o -name '*.d.cts' \) | wc -l | tr -d ' ')"
	echo "Resources/app.asar bytes: $(stat -f %z "$R/app.asar")"
	echo "Resources/app.asar.unpacked: $(cd "$R/app.asar.unpacked" && find . -type f | tr '\n' ' ')"
	echo "Resources/php-bin: $(cd "$R/php-bin" && find . | sort | tr '\n' ' ')"
	echo "Resources/php-bin bytes: $(find "$R/php-bin" -type f -exec stat -f %z {} + | awk '{s+=$1}END{print s}')"
	echo "Electron Framework lproj count: $(ls -d "$A/Contents/Frameworks/Electron Framework.framework/Versions/A/Resources/"*.lproj | wc -l | tr -d ' '), locale packs linked: $(find "$A/Contents/Frameworks/Electron Framework.framework/Versions/A/Resources" -name locale.pak -type l | wc -l | tr -d ' ')"
	echo "update zip symbolic links: $(zipinfo "$O"/make/zip/darwin/arm64/*.zip | grep -c '^l')"
done
