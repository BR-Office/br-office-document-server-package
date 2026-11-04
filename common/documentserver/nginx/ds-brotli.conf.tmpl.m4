## Brotli compression for the Document Server.
## documentserver-static-brotli.sh copies this file to /etc/nginx/includes/ds-brotli.conf only when the
## nginx brotli modules are loaded (packages libnginx-mod-http-brotli-filter and
## libnginx-mod-http-brotli-static), so nginx never fails to start for an unknown directive.
##
## Static files have a precompressed .br next to them: web-apps and sdkjs at quality 11 from the package
## build, fonts at quality 5 from the font generation. Everything else is compressed on the fly.
## Browsers that do not accept brotli (or plain HTTP: browsers only ask for br over HTTPS) keep gzip.
brotli_static on;
brotli on;
brotli_comp_level 5;
brotli_min_length 1024;
brotli_types  text/plain
              text/xml
              text/css
              text/csv
              font/ttf
              application/xml
              application/javascript
              application/x-javascript
              application/json
              application/octet-stream
              application/x-font-ttf
              application/rtf
              application/wasm;
