# Integration tests — shared CRS, two engines

A single **shared CRS + plugin** image (`crs/Dockerfile`) is consumed by two
backends so both parse byte-for-byte identical rules:

| Image               | Engine                              | Source                            | Port |
|---------------------|-------------------------------------|-----------------------------------|------|
| `vimbadmin-apache`  | Apache httpd + **ModSecurity v2**   | Debian `libapache2-mod-security2` | 8001 |
| `vimbadmin-nginx`   | Angie + **libmodsecurity3** (v3)    | `deb.myguard.nl` (prod mirror)    | 8002 |

The Angie image mirrors production (`eilandert/angie`, libmodsecurity3 3.0.14,
`angie-module-http-modsecurity`).

## The regression gate

Each backend runs its config check **at image build time**
(`apache2ctl -t` / `angie -t`). An invalid rule — bad transformation,
unresolved target, malformed regex — fails `docker build`, on **both**
engines, before any request is sent.

The CRS image (`crs/crs-main.conf`) scopes the plugin to the test host
(`ci.local`) and turns ON the opt-in positive-security layer so the deny
rules (`9529220`, `9529230`) are actually exercised.

## Run locally

From the repo root:

```bash
docker compose -f tests/integration/docker-compose.yml build
docker compose -f tests/integration/docker-compose.yml up -d apache nginx

# go-ftw v2 (https://github.com/coreruleset/go-ftw)
mkdir -p tests/logs/apache tests/logs/nginx && chmod 777 tests/logs/*

ftw run -d tests/regression --config tests/integration/.ftw.yml          # apache:8001
# edit .ftw.yml port->8002 + logfile->nginx for the Angie backend, or use
# the per-backend config the CI workflow generates.

docker compose -f tests/integration/docker-compose.yml down -t 0
```

CI runs each backend as its own workflow (so each gets its own badge):

- `.github/workflows/apache-modsecurity2.yml` — **Apache + ModSecurity v2**
- `.github/workflows/nginx-libmodsecurity3.yml` — **nginx + libmodsecurity3**

Both build the same shared `vimbadmin-crs` image, so they validate
byte-identical rules on the two engines.

## Security corpus

`.github/workflows/security-corpus.yml` runs an adversarial corpus
(`tests/security/`) against both engines:

- **`positive-security.yaml`** — disallowed parameter names and out-of-route
  probe paths that **must** trip the allowlist deny rules (`9529220`,
  `9529230`) when the positive-security layer is on.
- **`false-positives.yaml`** — legitimate ViMbAdmin traffic (login with a
  symbol-laden password + CSRF token, alias `goto` lists, free-text
  descriptions, `10GB` quotas) that **must NOT** trip any CRS rule.

Cross-engine on purpose: a bypass that only works on one engine still fails.

## Files

- `crs/Dockerfile` — installs the production CRS (`modsecurity-crs` from
  deb.myguard.nl, `CRS_DEB_VERSION`), re-homes it into `/opt/crs`, drops in
  `plugins/`, lays down the include chain.
- `crs/crs-main.conf` — the include order both engines load; scopes the plugin
  to `ci.local` and flips on the positive-security layer.
- `crs/modsecurity.conf` — `SecRuleEngine DetectionOnly`, serial audit log.
- `apache/Dockerfile`, `nginx/Dockerfile` — engine images, build-time `-t` gate.
- `docker-compose.yml`, `.ftw.yml` — orchestration + harness config.
