#!/bin/sh
# Usage: mac-locale-probe.sh <Studio.app> <workdir> <system language> [framework locale to remove...]
# Copies the app, replaces its app.asar with a probe app that prints app.getLocale() and a
# Chromium-localized string (the validation message of an empty required <input>), removes the
# given locales' packs from the Electron framework (with their gendered variants), and launches
# it with the system language overridden through -AppleLanguages. An "app:<locale>" argument
# removes the app bundle's own Contents/Resources/<locale>.lproj instead, and "link:<locale>"
# replaces the framework packs with symlinks to the English pack.
APP="$1"; W="$2"; LANG_ARG="$3"; shift 3
rm -rf "$W"; mkdir -p "$W"
cp -cR "$APP" "$W/Studio.app"
C="$W/Studio.app/Contents"
R="$C/Frameworks/Electron Framework.framework/Versions/A/Resources"
for l in "$@"; do
	case "$l" in app:*) l=${l#app:}; rm -rf "$C/Resources/$l.lproj"; continue;; esac
	case "$l" in link:*) l=${l#link:}
		for d in "$l" "${l}_FEMININE" "${l}_MASCULINE" "${l}_NEUTER"; do
			rm -rf "$R/$d.lproj"; mkdir "$R/$d.lproj"; ln -s ../en.lproj/locale.pak "$R/$d.lproj/locale.pak"
		done
		continue;; esac
	rm -rf "$R/$l.lproj" "$R/${l}_FEMININE.lproj" "$R/${l}_MASCULINE.lproj" "$R/${l}_NEUTER.lproj"
done
rm -rf "$C/Resources/app.asar" "$C/Resources/app.asar.unpacked"
mkdir -p "$C/Resources/app"
cat > "$C/Resources/app/package.json" <<'EOF'
{ "name": "locale-probe", "main": "main.js" }
EOF
cat > "$C/Resources/app/main.js" <<'EOF'
const { app, BrowserWindow } = require( 'electron' );
app.whenReady().then( async () => {
	const win = new BrowserWindow( { show: false } );
	await win.loadURL( 'data:text/html,<input required>' );
	const message = await win.webContents.executeJavaScript(
		'document.querySelector("input").validationMessage'
	);
	console.log( `getLocale=${ app.getLocale() } preferred=${ app.getPreferredSystemLanguages().join( ',' ) } validationMessage=${ JSON.stringify( message ) }` );
	app.quit();
} );
EOF
"$C/MacOS/Studio" -AppleLanguages "($LANG_ARG)" 2>/dev/null | grep getLocale
