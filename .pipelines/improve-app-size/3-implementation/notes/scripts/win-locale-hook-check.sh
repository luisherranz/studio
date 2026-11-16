#!/bin/sh
# Usage: win-locale-hook-check.sh <repo> <workdir>
# Downloads Electron 44.9.1 for win32-x64, applies apps/studio/forge.config.ts's afterExtract hook
# to it as the packaging does (loaded with jiti, as Electron Forge loads the config), and reports
# which packs became copies of en-US.pak and the locale packs' bytes before and after.
set -eu
REPO="$1"; W="$2"
rm -rf "$W"; mkdir -p "$W/electron"
curl -sSL -o "$W/electron.zip" https://github.com/electron/electron/releases/download/v44.9.1/electron-v44.9.1-win32-x64.zip
unzip -q "$W/electron.zip" -d "$W/electron"
before=$(find "$W/electron/locales" -type f -exec stat -f %z {} + | awk '{s+=$1}END{print s}')
( cd "$REPO" && node -e '
	const { createJiti } = require( "jiti" );
	createJiti( process.cwd() + "/package.json" )
		.import( "./apps/studio/forge.config.ts", { default: true } )
		.then( async ( config ) => {
			for ( const hook of config.packagerConfig.afterExtract ) {
				await hook( { buildPath: process.argv[ 1 ], platform: "win32", arch: "x64", electronVersion: "44.9.1" } );
			}
		} );
' "$W/electron" )
after=$(find "$W/electron/locales" -type f -exec stat -f %z {} + | awk '{s+=$1}END{print s}')
cd "$W/electron/locales"
copies=$(for f in *.pak; do [ "$f" != en-US.pak ] && cmp -s "$f" en-US.pak && echo "${f%.pak}"; done | tr '\n' ' ')
echo "packs: $(ls *.pak | wc -l | tr -d ' '), links: $(find . -type l | wc -l | tr -d ' '), copies of en-US.pak: $(echo $copies | wc -w | tr -d ' ')"
echo "copied: $copies"
echo "locale pack bytes: before=$before after=$after saved=$((before - after))"
