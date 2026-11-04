#!/bin/sh
#
# Brotli for the Document Server: precompressed .br files next to the static ones, and the nginx
# configuration that serves them.
#
#   1. Removes every .br whose source is gone or newer (a regenerated font, AllFonts.js, a theme).
#   2. Compresses the static files that have no .br yet: the generated fonts and any web file the
#      package did not ship compressed. Quality BROTLI_QUALITY, default 5: on fonts it is within 3 % of
#      quality 9 (98 against 95 MB for 200 MB of fonts) and takes seconds instead of a minute on 4 cores.
#      The web files of the package are already at quality 11 from the build.
#   3. Enables /etc/nginx/includes/ds-brotli.conf when the nginx brotli modules are loaded, and removes
#      it when they are not, so nginx never fails to start for an unknown directive.
#
# documentserver-generate-allfonts.sh runs it after every font generation. Run it by hand after
# installing the brotli modules later (apt install libnginx-mod-http-brotli-filter
# libnginx-mod-http-brotli-static brotli).
#
# Measured on a real 11-page document over a 50/10 Mbps home link: 3.7 MB less per first open, the
# document loaded 0.5 s sooner (BR-Office/br-office-server, bench/results/2026-11-04-brotli.md).
#
# Options: -r | --restart false   do not reload nginx

DIR="/var/www/M4_DS_PREFIX"
NGINX_ONLYOFFICE_PATH="/etc/M4_DS_PREFIX/nginx"
INCLUDE="/etc/nginx/includes/ds-brotli.conf"
QUALITY="${BROTLI_QUALITY:-5}"
RESTART_CONDITION=true

while [ "$1" != "" ]; do
	case $1 in
		-r | --restart )
			if [ "$2" != "" ]; then
				RESTART_CONDITION=$2
				shift
			fi
		;;
	esac
	shift
done

cd "$DIR" || exit 1
WEB_DIRS=""
for d in ./sdkjs ./web-apps ./sdkjs-plugins ./dictionaries ./fonts; do
	[ -d "$d" ] && WEB_DIRS="$WEB_DIRS $d"
done

# 1. stale .br: source removed, or rewritten after the .br was made
find $WEB_DIRS -type f -name '*.br' | while read -r BR; do
	SRC="${BR%.br}"
	if [ ! -e "$SRC" ] || [ "$SRC" -nt "$BR" ]; then
		rm -f "$BR"
	fi
done

# 2. compress what has no .br yet
if command -v brotli >/dev/null 2>&1; then
	JOBS=$(nproc 2>/dev/null || echo 2)
	echo -n "Compressing static files with brotli, please wait..."
	{
		find ./fonts -type f ! -name '*.*' -size +1k 2>/dev/null
		find $WEB_DIRS -type f -size +1k \( -name '*.js' -o -name '*.json' -o -name '*.htm' -o -name '*.html' \
			-o -name '*.css' -o -name '*.wasm' -o -name '*.dic' -o -name '*.aff' -o -name '*.svg' \) 2>/dev/null
	} | while read -r SRC; do
		[ -e "$SRC.br" ] || printf '%s\0' "$SRC"
	done | xargs -0 -r -P "$JOBS" -n 8 brotli -k -f -q "$QUALITY" --
	chown -R ds:ds ./fonts 2>/dev/null
	echo Done
else
	echo "brotli is not installed: static files stay gzip only (apt install brotli)"
fi

# 3. nginx configuration, only with the modules loaded
CHANGED=false
if grep -qs ngx_http_brotli_filter_module /etc/nginx/modules-enabled/*.conf \
	&& grep -qs ngx_http_brotli_static_module /etc/nginx/modules-enabled/*.conf; then
	if ! cmp -s "${NGINX_ONLYOFFICE_PATH}/ds-brotli.conf.tmpl" "$INCLUDE"; then
		cp -f "${NGINX_ONLYOFFICE_PATH}/ds-brotli.conf.tmpl" "$INCLUDE"
		CHANGED=true
	fi
elif [ -e "$INCLUDE" ]; then
	rm -f "$INCLUDE"
	CHANGED=true
fi

if [ "$RESTART_CONDITION" != "false" ] && [ "$CHANGED" = "true" ]; then
	if (pgrep -x "systemd" > /dev/null) && systemctl is-active --quiet nginx; then
		systemctl reload nginx
	elif service nginx status > /dev/null 2>&1; then
		service nginx reload
	fi
fi
