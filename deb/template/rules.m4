#!/usr/bin/make -f
# -*- makefile -*-

export DH_VERBOSE=1

%:
	dh $@

override_dh_strip_nondeterminism:
	dh_strip_nondeterminism --exclude=.png

override_dh_shlibdeps:
	dh_shlibdeps --no-act

override_dh_strip:
	dh_strip -Xdocservice -Xconverter -Xmetrics -Xadminpanel -Xexample -Xjson -Xcore.node

execute_after_dh_fixperms:
	chmod o-rwx debian/M4_PACKAGE_NAME/etc/M4_DS_PREFIX/*.json

execute_before_dh_builddeb:
	# Brotli quality 11 next to every static web file the package ships, for nginx brotli_static: too slow
	# to do at install (about 0.3 MB/s), 25 % smaller than gzip on the editor's scripts. Files generated at
	# install (AllFonts.js, api.js, themes, fonts) are compressed by documentserver-static-brotli.sh.
	find debian/M4_PACKAGE_NAME/var/www/M4_DS_PREFIX/web-apps debian/M4_PACKAGE_NAME/var/www/M4_DS_PREFIX/sdkjs \
		debian/M4_PACKAGE_NAME/var/www/M4_DS_PREFIX/sdkjs-plugins -type f -size +1k \
		\( -name '*.js' -o -name '*.json' -o -name '*.htm' -o -name '*.html' -o -name '*.css' -o -name '*.wasm' -o -name '*.svg' \) \
		-print0 | xargs -0 -r -P $(shell nproc) -n 8 brotli -k -f -q 11 --
	hardlink --ignore-time debian/M4_PACKAGE_NAME/var/www/M4_DS_PREFIX/web-apps

override_dh_builddeb:
	dh_builddeb -- -z9 -Zxz --threads-max=$(shell nproc)

override_dh_systemd_enable:
	dh_systemd_enable --no-enable

override_dh_systemd_start:
	dh_systemd_start --no-start --no-restart-after-upgrade --no-stop-on-upgrade
