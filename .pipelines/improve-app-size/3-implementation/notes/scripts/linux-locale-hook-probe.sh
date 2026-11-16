#!/bin/sh
# Usage: linux-locale-hook-probe.sh <repo> <workdir>
# Downloads Electron 44.9.1 for linux-arm64, applies apps/studio/forge.config.ts's afterExtract hook
# to it as the packaging does (loaded with jiti, as Electron Forge loads the config), lists what the
# hook made of the locale packs, then runs a probe app on it in a node:24-bookworm container that
# prints app.getLocale() and a Chromium-localized string (the validation message of an empty
# required <input>) for several LANGUAGE lists.
set -eu
REPO="$1"; W="$2"
rm -rf "$W"; mkdir -p "$W/electron" "$W/app"
curl -sSL -o "$W/electron.zip" https://github.com/electron/electron/releases/download/v44.9.1/electron-v44.9.1-linux-arm64.zip
unzip -q "$W/electron.zip" -d "$W/electron"
( cd "$REPO" && node -e '
	const { createJiti } = require( "jiti" );
	createJiti( process.cwd() + "/package.json" )
		.import( "./apps/studio/forge.config.ts", { default: true } )
		.then( async ( config ) => {
			for ( const hook of config.packagerConfig.afterExtract ) {
				await hook( { buildPath: process.argv[ 1 ], platform: "linux", arch: "arm64", electronVersion: "44.9.1" } );
			}
		} );
' "$W/electron" )
echo "packs: $(ls "$W/electron/locales" | wc -l | tr -d ' '), links to en-US.pak: $(find "$W/electron/locales" -type l -lname en-US.pak | wc -l | tr -d ' ')"
echo "linked: $(cd "$W/electron/locales" && find . -type l | sed 's|./||; s|.pak$||' | sort | tr '\n' ' ')"
cat > "$W/app/package.json" <<'EOF'
{ "name": "locale-probe", "main": "main.js" }
EOF
cat > "$W/app/main.js" <<'EOF'
const { app, BrowserWindow } = require( 'electron' );
app.whenReady().then( async () => {
	const win = new BrowserWindow( { show: false } );
	await win.loadURL( 'data:text/html,<input required>' );
	const message = await win.webContents.executeJavaScript(
		'document.querySelector("input").validationMessage'
	);
	console.log( `getLocale=${ app.getLocale() } validationMessage=${ JSON.stringify( message ) }` );
	app.quit();
} );
EOF
cat > "$W/run.sh" <<'EOF'
set -eu
apt-get -o Acquire::Retries=3 update >/dev/null
apt-get install -y --no-install-recommends xvfb xauth libnss3 libatk1.0-0 libatk-bridge2.0-0 \
	libcups2 libdrm2 libgtk-3-0 libgbm1 libasound2 libxkbcommon0 libxcomposite1 libxdamage1 \
	libxfixes3 libxrandr2 libpango-1.0-0 libcairo2 libxss1 >/dev/null 2>&1
for language in fi fi:de de ca da:es sw en_GB; do
	out=$( env LANGUAGE="$language" xvfb-run -a /w/electron/electron --no-sandbox --disable-gpu /w/app 2>/dev/null | grep getLocale || true )
	echo "LANGUAGE=$language: $out"
done
EOF
docker run --rm -v "$W:/w" node:24-bookworm sh /w/run.sh
