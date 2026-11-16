#!/bin/sh
# Usage: lproj.sh <Studio.app/Contents>
C="$1"
R="$C/Frameworks/Electron Framework.framework/Versions/A/Resources"
du -sk "$R"
ls -d "$R"/*.lproj | wc -l
keep='^(af|ar|ca|de|en|en_GB|es|es_419|fr|he|hu|id|it|ja|ko|ms|nl|pl|pt_BR|pt_PT|ru|sv|tr|uk|vi|zh_CN|zh_TW)(_FEMININE|_MASCULINE|_NEUTER)?\.lproj$'
tot=0
rmb=0
for d in "$R"/*.lproj; do
	b=$(find "$d" -type f -exec stat -f %z {} + | awk '{s+=$1}END{print s+0}')
	n=$(basename "$d")
	if ! echo "$n" | grep -Eq "$keep"; then
		rmb=$((rmb+b))
	fi
	tot=$((tot+b))
done
echo "lproj total bytes=$tot removable(non-Studio-language) bytes=$rmb"
ls "$R/de.lproj" "$R/de_FEMININE.lproj"
ls -d "$C"/Resources/*.lproj | wc -l
