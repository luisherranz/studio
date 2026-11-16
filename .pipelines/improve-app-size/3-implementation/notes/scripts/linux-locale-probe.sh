#!/bin/sh
# Runs inside a node:24-bookworm container (linux arm64), as root:
#   docker run --rm -v <this folder>:/probe node:24-bookworm sh /probe/linux-locale-probe.sh
# Downloads Electron 44.9.1 for linux-arm64 and, for each case, launches a probe app that prints
# app.getLocale() and a Chromium-localized string (the validation message of an empty required
# <input>), with the given LANG and LANGUAGE, after removing the given locales/<locale>.pak files
# ("link:<locale>" replaces the pack with a symlink to en-US.pak instead).
set -eu
apt-get -o Acquire::Retries=3 update >/dev/null
apt-get install -y --no-install-recommends xvfb xauth unzip curl ca-certificates libnss3 libatk1.0-0 \
	libatk-bridge2.0-0 libcups2 libdrm2 libgtk-3-0 libgbm1 libasound2 libxkbcommon0 libxcomposite1 \
	libxdamage1 libxfixes3 libxrandr2 libpango-1.0-0 libcairo2 libxss1 >/dev/null 2>&1
cd /tmp
curl -sSL -o electron.zip https://github.com/electron/electron/releases/download/v44.9.1/electron-v44.9.1-linux-arm64.zip
mkdir -p app
cat > app/package.json <<'EOF'
{ "name": "locale-probe", "main": "main.js" }
EOF
cat > app/main.js <<'EOF'
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
run() {
	lang="$1"; language="$2"; shift 2
	rm -rf electron; mkdir electron; unzip -q electron.zip -d electron
	for l in "$@"; do
		case "$l" in
			link:*) l=${l#link:}; rm -f "electron/locales/$l.pak"; ln -s en-US.pak "electron/locales/$l.pak" ;;
			*) rm -f "electron/locales/$l.pak" ;;
		esac
	done
	out=$( env LANG="$lang" LANGUAGE="$language" xvfb-run -a electron/electron --no-sandbox --disable-gpu app 2>/dev/null | grep getLocale || true )
	echo "LANG=$lang LANGUAGE=${language:-unset} removed=${*:-none}: $out"
}
run fi_FI.UTF-8 ""
run fi_FI.UTF-8 "" fi
run fi_FI.UTF-8 "fi:de"
run fi_FI.UTF-8 "fi:de" fi
run de_DE.UTF-8 "" fi
run ca_ES.UTF-8 ""
run en_US.UTF-8 "" fi
run fi_FI.UTF-8 "" link:fi
run fi_FI.UTF-8 "fi:de" link:fi
ls electron/locales | wc -l
