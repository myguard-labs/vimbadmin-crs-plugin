# ---------------------------------------------------------------------------
# nginx + Coraza connector.
#
# Uses the same shared /opt/crs tree as the Apache and libmodsecurity3 images,
# but loads it through libnginx-mod-http-coraza + libcoraza from deb.myguard.nl.
# The Coraza packages are trixie/resolute-only, so this backend is trixie based.
# `nginx -t` is the build-time gate.
# ---------------------------------------------------------------------------
ARG CRS_IMAGE=vimbadmin-crs:latest
FROM ${CRS_IMAGE} AS crs

FROM debian:trixie-slim

RUN apt-get update \
 && apt-get install -y --no-install-recommends ca-certificates curl gnupg \
 && install -d -m 0755 /etc/apt/keyrings \
 && curl -fsSL https://deb.myguard.nl/deb.myguard.nl.gpg -o /tmp/mg.key \
 && (gpg --dearmor < /tmp/mg.key > /etc/apt/keyrings/deb.myguard.nl.gpg 2>/dev/null \
      || cp /tmp/mg.key /etc/apt/keyrings/deb.myguard.nl.gpg) \
 && echo 'deb [signed-by=/etc/apt/keyrings/deb.myguard.nl.gpg] https://deb.myguard.nl trixie main' \
      > /etc/apt/sources.list.d/myguard.list \
 && apt-get update \
 && apt-get install -y --no-install-recommends \
      nginx libnginx-mod-http-coraza libcoraza1 python3 \
 && rm -rf /var/lib/apt/lists/* /tmp/mg.key

# Identical CRS + plugin tree as the Apache and libmodsecurity3 images.
COPY --from=crs /opt/crs /opt/crs
COPY tests/integration/ok-server.py /usr/local/bin/ok-server.py

# Write a complete nginx.conf that loads only the Coraza connector and points
# it at the shared include chain.
RUN set -eu; \
    SO="$(find /usr/lib /usr/lib64 -name 'ngx_http_coraza_module.so' 2>/dev/null | head -n1)"; \
    test -n "$SO"; \
    mkdir -p /var/log/modsec /var/log/nginx; \
    : > /var/log/modsec/audit.log; \
    chown -R www-data:adm /var/log/modsec; \
    { \
      echo "load_module $SO;"; \
      echo 'user www-data;'; \
      echo 'worker_processes 1;'; \
      echo 'error_log /var/log/nginx/error.log notice;'; \
      echo 'pid /run/nginx.pid;'; \
      echo 'events { worker_connections 1024; }'; \
      echo 'http {'; \
      echo '    coraza on;'; \
      echo '    coraza_rules_file /opt/crs/crs-main.conf;'; \
      echo '    access_log /var/log/nginx/access.log;'; \
      echo '    server {'; \
      echo '        listen 80 default_server;'; \
      echo '        server_name ci.local;'; \
      echo '        location / {'; \
      echo '            proxy_pass http://127.0.0.1:18080;'; \
      echo '            proxy_set_header Host $host;'; \
      echo '        }'; \
      echo '    }'; \
      echo '}'; \
    } > /etc/nginx/nginx.conf

# BUILD-TIME GATE: full rule parse via nginx + Coraza. The connector builds
# WAFs in worker processes, so include a smoke request after `nginx -t`.
RUN nginx -t
RUN python3 /usr/local/bin/ok-server.py & backend_pid="$!"; \
    nginx; \
    for _ in 1 2 3 4 5; do \
      if curl --max-time 2 -fsS http://127.0.0.1/ >/dev/null; then \
        nginx -s quit; \
        kill "$backend_pid"; \
        wait "$backend_pid" || true; \
        exit 0; \
      fi; \
      tail -n 80 /var/log/nginx/error.log || true; \
      sleep 1; \
    done; \
    nginx -s quit || true; \
    kill "$backend_pid" || true; \
    wait "$backend_pid" || true; \
    exit 1

EXPOSE 80
STOPSIGNAL SIGQUIT
CMD ["/bin/sh", "-c", "chown -R www-data:adm /var/log/modsec; python3 /usr/local/bin/ok-server.py & exec nginx -g 'daemon off;'"]
