#!/bin/sh
# Usage: offline-first-run-probe.sh <Studio.app/Contents> <workdir> <port> <Studio locale>
# Runs a packaged Studio's CLI on its bundled Node, as a first run with a fresh config folder,
# process-manager home and port range, under a sandbox-exec profile that blocks every outgoing
# connection except to localhost: creates a site with Studio's language set to <locale>, reads its
# PHP version, WordPress version and language, imports a one-post WXR file and lists its posts.
# Reports the config folder's contents and stops the probe's daemon and sites with `stop --all`.
C="$1"; W="$2"; PORT="$3"; LOCALE="$4"
rm -rf "$W"; mkdir -p "$W/config" "$W/pm" "$W/sites"
export DEV_CONFIG_DIR="$W/config" STUDIO_PROCESS_MANAGER_HOME="$W/pm" STUDIO_BASE_PORT="$PORT"
printf '{"version":1,"locale":"%s"}\n' "$LOCALE" > "$W/config/shared.json"
cat > "$W/probe.xml" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<rss version="2.0" xmlns:excerpt="http://wordpress.org/export/1.2/excerpt/" xmlns:content="http://purl.org/rss/1.0/modules/content/" xmlns:wfw="http://wellformedweb.org/CommentAPI/" xmlns:dc="http://purl.org/dc/elements/1.1/" xmlns:wp="http://wordpress.org/export/1.2/">
<channel>
	<title>Probe</title>
	<link>http://example.com</link>
	<wp:wxr_version>1.2</wp:wxr_version>
	<wp:base_site_url>http://example.com</wp:base_site_url>
	<wp:base_blog_url>http://example.com</wp:base_blog_url>
	<item>
		<title>Offline import probe</title>
		<dc:creator><![CDATA[admin]]></dc:creator>
		<content:encoded><![CDATA[Imported without a network connection.]]></content:encoded>
		<wp:post_id>4242</wp:post_id>
		<wp:post_date>2026-11-16 12:00:00</wp:post_date>
		<wp:post_name>offline-import-probe</wp:post_name>
		<wp:status>publish</wp:status>
		<wp:post_type>post</wp:post_type>
	</item>
</channel>
</rss>
EOF
NODE="$C/Resources/bin/node"; CLI="$C/Resources/cli/main.mjs"
OFFLINE='(version 1)(allow default)(deny network-outbound (remote ip "*:*"))(allow network-outbound (remote ip "localhost:*"))'
offline() { sandbox-exec -p "$OFFLINE" "$@"; }
SITE="$W/sites/probe"
echo "offline curl https://wordpress.org: $(offline curl -s -o /dev/null -w '%{http_code}' --max-time 10 https://wordpress.org/ || true)"
offline "$NODE" "$CLI" site create --name probe --path "$SITE" --skip-browser --avoid-telemetry > "$W/create.log" 2>&1
echo "site create exit=$?"
echo "http status: $(curl -s -o /dev/null -w '%{http_code}' "http://localhost:$PORT/")"
echo "php: $(offline "$NODE" "$CLI" wp --path "$SITE" eval 'echo PHP_VERSION;' --avoid-telemetry 2>/dev/null | tail -1)"
echo "wordpress: $(offline "$NODE" "$CLI" wp --path "$SITE" core version --avoid-telemetry 2>/dev/null | tail -1)"
echo "WPLANG: $(offline "$NODE" "$CLI" wp --path "$SITE" option get WPLANG --avoid-telemetry 2>/dev/null | tail -1)"
offline "$NODE" "$CLI" import "$W/probe.xml" --path "$SITE" --avoid-telemetry > "$W/import.log" 2>&1
echo "import exit=$?"
echo "posts: $(offline "$NODE" "$CLI" wp --path "$SITE" post list --field=post_title --avoid-telemetry 2>/dev/null | tr '\n' '|')"
echo "config folder (du -sk, KiB):"
du -sk "$W/config/php-bin" "$W/config/php-bin"/* "$W/config/server-files"/* 2>/dev/null
ls -la "$W/config/php-bin"/*/ 2>/dev/null
offline "$NODE" "$CLI" stop --all --avoid-telemetry > /dev/null 2>&1
echo "stopped: $(curl -s -o /dev/null -w '%{http_code}' "http://localhost:$PORT/" || true)"
