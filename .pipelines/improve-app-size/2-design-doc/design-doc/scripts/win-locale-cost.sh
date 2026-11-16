#!/bin/sh
# Usage: win-locale-cost.sh <dir holding locales/*.pak from electron-v44.9.1-win32-x64.zip>
# For the Electron locales Studio's matcher maps to English (all but English and the 25 that map
# to a translation), compares removing their packs with replacing each by a copy of en-US.pak:
# installed bytes, and bytes after deflate (zip -6, per file, as the zip-based packages compress)
# and after xz -6 (solid).
D="$1/locales"
keep='^(af|ar|ca|de|en-GB|en-US|es|es-419|fr|he|hu|id|it|ja|ko|ms|nl|pl|pt-BR|pt-PT|ru|sv|tr|uk|vi|zh-CN|zh-TW)\.pak$'
total=0; removed=0; n=0
for f in "$D"/*.pak; do
	b=$(stat -f %z "$f"); total=$((total+b))
	if ! basename "$f" | grep -Eq "$keep"; then removed=$((removed+b)); n=$((n+1)); fi
done
en=$(stat -f %z "$D/en-US.pak")
T=$(mktemp -d)
ls "$D" | grep -Ev "$keep" > "$T/list"
( cd "$D" && zip -q -6 "$T/removed.zip" -@ < "$T/list" )
mkdir "$T/copies"; while read -r f; do cp "$D/en-US.pak" "$T/copies/$f"; done < "$T/list"
( cd "$T/copies" && zip -q -6 "$T/copies.zip" * )
rx=$(cd "$D" && tar -cf - -T "$T/list" | xz -6 -T0 | wc -c | tr -d ' ')
cx=$(cd "$T/copies" && tar -cf - . | xz -6 -T0 | wc -c | tr -d ' ')
echo "packs=55 total=$total en-US.pak=$en"
echo "unmapped packs=$n bytes=$removed zip6=$(stat -f %z "$T/removed.zip") xz6=$rx"
echo "replaced by en-US copies: bytes=$((n*en)) zip6=$(stat -f %z "$T/copies.zip") xz6=$cx"
echo "net saving with copies: bytes=$((removed - n*en)) zip6=$(( $(stat -f %z "$T/removed.zip") - $(stat -f %z "$T/copies.zip") ))"
rm -rf "$T"
