#!/bin/sh
# Usage: prune-estimate.sh <Studio.app/Contents> <asar-extract-dir> <outdir>
# Measures raw and compressed (zip -6, xz -6) bytes of the candidate removals:
# source maps and type declarations in the CLI's node_modules, the build-only
# packages in app.asar, and the Electron locale packs Studio's matcher never picks.
C="$1"; X="$2"; O="$3"
rm -rf "$O"; mkdir -p "$O"
NM="$C/Resources/cli/node_modules"
( cd "$NM" && find . -type f \( -name '*.map' -o -name '*.d.ts' -o -name '*.d.mts' -o -name '*.d.cts' \) > "$O/cli-list.txt" )
( cd "$X/node_modules" && find . -type f \( -name '*.map' -o -name '*.d.ts' -o -name '*.d.mts' -o -name '*.d.cts' \) > "$O/asar-decl-list.txt" )
( cd "$X/node_modules" && find sentry @sentry/bundler-plugins oxc-parser @oxc-parser @oxc-project -type f 2>/dev/null > "$O/asar-tools-list.txt" )
R="$C/Frameworks/Electron Framework.framework/Versions/A/Resources"
keep='^(af|ar|ca|de|en|en_GB|es|es_419|fr|he|hu|id|it|ja|ko|ms|nl|pl|pt_BR|pt_PT|ru|sv|tr|uk|vi|zh_CN|zh_TW)(_FEMININE|_MASCULINE|_NEUTER)?\.lproj$'
( cd "$R" && ls -d *.lproj | grep -Ev "$keep" > "$O/lproj-list.txt" )
measure() {
	label="$1"; dir="$2"; list="$3"
	raw=$(cd "$dir" && tr '\n' '\0' < "$list" | xargs -0 stat -f %z | awk '{s+=$1}END{print s+0}')
	n=$(wc -l < "$list" | tr -d ' ')
	zipb=$(cd "$dir" && rm -f "$O/$label.zip" && zip -q -6 -r "$O/$label.zip" -@ < "$list" && stat -f %z "$O/$label.zip")
	xzb=$(cd "$dir" && tar -cf - -T "$list" | xz -6 -T0 | wc -c | tr -d ' ')
	echo "$label entries=$n raw=$raw zip6=$zipb xz6=$xzb"
}
measure cli-maps-decls "$NM" "$O/cli-list.txt"
measure asar-maps-decls "$X/node_modules" "$O/asar-decl-list.txt"
measure asar-build-tools "$X/node_modules" "$O/asar-tools-list.txt"
measure electron-lproj-unpicked "$R" "$O/lproj-list.txt"
