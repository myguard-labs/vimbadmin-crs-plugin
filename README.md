> 🔗 **ViMbAdmin:** [github.com/eilandert/vimbadmin](https://github.com/eilandert/vimbadmin)
>
> 📖 **Read the write-up:** [ViMbAdmin — a Postfix/Dovecot mailbox admin panel](https://deb.myguard.nl/2026/06/vimbadmin-postfix-dovecot-mailbox-admin-panel/)

# ViMbAdmin OWASP CRS Plugin

![Lint](https://github.com/myguard-labs/vimbadmin-crs-plugin/actions/workflows/lint.yml/badge.svg) ![Integration Tests](https://github.com/myguard-labs/vimbadmin-crs-plugin/actions/workflows/integration.yml/badge.svg) ![Apache/v2](https://github.com/myguard-labs/vimbadmin-crs-plugin/actions/workflows/apache-modsecurity2.yml/badge.svg) ![NGINX/v3](https://github.com/myguard-labs/vimbadmin-crs-plugin/actions/workflows/nginx-libmodsecurity3.yml/badge.svg) ![NGINX/Coraza](https://github.com/myguard-labs/vimbadmin-crs-plugin/actions/workflows/coraza.yml/badge.svg)

A drop-in [OWASP CRS](https://coreruleset.org/) plugin that makes the Core
Rule Set play nicely with **[ViMbAdmin](https://github.com/eilandert/ViMbAdmin)**
— and, optionally, locks the admin panel down to a strict allowlist.

> **Do you need this?** Probably not on its own. ViMbAdmin's request surface
> is small and fully known, so the **positive-security Angie/nginx vhost**
> shipped in the main repo (`contrib/angie/vimbadmin.conf`) already does the
> route/method/argument allowlisting at the edge, natively, with no
> ModSecurity dependency and no per-request CRS cost. That vhost is the
> recommended primary defence.
>
> This CRS plugin is **belt-and-braces**: run it *in addition* only if you
> already operate libmodsecurity + CRS and want signature scanning of the
> argument **values** the app accepts (SQLi/XSS payload heuristics) on top of
> the vhost's name/route allowlisting. If you don't already run ModSecurity,
> the vhost alone is the right answer.

It does two things:

1. **False-positive exclusions** (`vimbadmin-before.conf`) — surgical,
   host-scoped `ctl:ruleRemoveTargetByTag` exclusions so legitimate inputs
   (passwords with symbols, the CSRF token, comma-separated alias `goto`
   lists, free-text descriptions, `10GB`-style quotas) don't trip CRS.

2. **Positive security / allowlist** (`vimbadmin-after.conf`, **opt-in**) —
   *allow what ViMbAdmin uses, block everything else*. Any request argument
   whose **name** isn't one the app actually uses is denied, and any path
   outside ViMbAdmin's real route map is denied. This stops parameter
   smuggling, mass-assignment probing and the usual `/​.env` / `/wp-login.php`
   scanner noise regardless of payload.

## Requirements

- CRS Version 4.0 or newer
- ModSecurity compatible Web Application Firewall

## Install

Copy the three files into your CRS `plugins/` directory:

```
plugins/vimbadmin-config.conf
plugins/vimbadmin-before.conf
plugins/vimbadmin-after.conf
```

CRS loads `plugins/*-config.conf`, then `*-before.conf` (before the rules),
then `*-after.conf` (after the rules) automatically.

## Configure

Edit `vimbadmin-config.conf`:

| Variable | Default | Meaning |
|---|---|---|
| `tx.vimbadmin-plugin_enabled` | `0` | Master on/off. **OFF by default** — the plugin weakens CRS on the ViMbAdmin routes, so it must be enabled per vhost, not globally. Set to `1` only in the ViMbAdmin server/location block (see Roll-out). |
| `tx.vimbadmin-plugin_positive_security` | `0` | Turn the allowlist layer on (`1`) once you've tested it. |

Scoping is done entirely by the per-vhost enable flag — there is **no Host
gate**. Enable the plugin only where ViMbAdmin is served, e.g. (Angie /
NGINX/Angie + libmodsecurity3):

```nginx
location /vimbadmin/ {
    modsecurity on;
    modsecurity_rules '
        SecAction "id:9529001,phase:1,nolog,pass,setvar:tx.vimbadmin-plugin_enabled=1"
    ';
    # ...
}
```

On Apache/mod_security2, set the same variable inside the matching
`<Location>` / `<VirtualHost>` block.

## Roll-out

1. Install, then enable the plugin in the ViMbAdmin vhost/location only
   (`setvar:tx.vimbadmin-plugin_enabled=1`). The exclusions are safe
   immediately and never touch other vhosts on the same CRS engine.
2. Run CRS in **DetectionOnly** with `tx.vimbadmin-plugin_positive_security=1`
   and watch the audit log for `9529220` / `9529230` hits — those are
   arguments or paths missing from the allowlist. Add any legitimate ones
   you've added via custom plugins to the inline allowlist regex on rule
   `9529220` in `vimbadmin-after.conf`.
3. Flip CRS back to blocking mode.

Rule ID range: **9,529,000 – 9,529,999** (block base 9,529,000; free in the
[CRS plugin registry](https://github.com/coreruleset/plugin-registry),
pending formal assignment).

## Continuous integration

Every push/PR runs five GitHub Actions workflows (each gets its own badge above):

| Workflow | What it does |
|---|---|
| **Lint** | Local rule-ID-range (9529000–9529999) / duplicate-ID / `@pmFromFile` / test-reference checks, then the official `coreruleset/crs-plugin-test-action` lint. |
| **Integration Tests** | Plugin-structure gates (no host gate — scoping is the per-vhost enable flag, opt-in allowlist, conditional config defaults, `ver:` on every rule). |
| **Apache/v2** | Builds the shared CRS+plugin image and runs the common go-ftw regression + security suites on real Apache httpd + mod_security2 (`apache2ctl -t` gates parse). |
| **NGINX/v3** | Same shared image and same suites on Angie + libmodsecurity3 3.0.14 — a production mirror (`angie -t` gates parse). |
| **NGINX/Coraza** | Same shared image and same suites on nginx + `libnginx-mod-http-coraza` / `libcoraza1` (`nginx -t` gates parse). |

The three-engine harness lives under [`tests/integration/`](tests/integration/);
all engine workflows run the go-ftw cases under
[`tests/regression/`](tests/regression/) and [`tests/security/`](tests/security/).

## Disabling the plugin

Uncomment rule `9529010` inside `plugins/vimbadmin-config.conf`, or remove the
plugin files from the `plugins/` directory entirely.

## Reporting false positives

Open a new issue or pull request. For issues, include:

- CRS Version
- ModSecurity/Coraza Version
- modsec audit logs
- what caused the false positive

## See also

- ViMbAdmin fork: <https://github.com/eilandert/ViMbAdmin>
- Hardened FPM pool, Angie vhost and the Snuffleupagus ruleset ship in that
  repo under `contrib/`.
