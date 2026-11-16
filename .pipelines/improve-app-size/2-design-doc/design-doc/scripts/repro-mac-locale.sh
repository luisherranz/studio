#!/bin/sh
# Usage: repro-mac-locale.sh <probe script> <Studio.app> <workdir>
# Re-runs the implementer's macOS locale probe for each case below: system languages, then the
# changes the probe applies (framework locale removed, app:<l> app-bundle lproj removed,
# link:<l> framework pack replaced by a symlink to en.lproj/locale.pak).
P="$1"; A="$2"; W="$3"
while read -r l changes; do
	[ -z "$l" ] && continue
	printf 'lang=(%s) changes=%s: ' "$l" "${changes:-none}"
	# shellcheck disable=SC2086
	sh "$P" "$A" "$W" "$l" $changes 2>&1 | tail -1
done <<'EOF'
fi
fi fi
fi,de
fi,de fi
fi,de fi app:fi
fi link:fi
fi,de link:fi
da
da da
da,es da
da,es link:da
es-MX
es-MX es
EOF
