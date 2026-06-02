> 🔗 **ViMbAdmin:** [github.com/eilandert/vimbadmin](https://github.com/eilandert/vimbadmin)
>
> 📖 **Read the write-up:** [ViMbAdmin — a Postfix/Dovecot mailbox admin panel](https://deb.myguard.nl/2026/06/vimbadmin-postfix-dovecot-mailbox-admin-panel/)

# ViMbAdmin OWASP CRS Plugin

![Lint](https://github.com/eilandert/vimbadmin-crs-plugin/actions/workflows/lint.yml/badge.svg) ![Integration tests](https://github.com/eilandert/vimbadmin-crs-plugin/actions/workflows/integration.yml/badge.svg) ![Apache + ModSecurity v2](https://github.com/eilandert/vimbadmin-crs-plugin/actions/workflows/apache-modsecurity2.yml/badge.svg) ![nginx + libmodsecurity3](https://github.com/eilandert/vimbadmin-crs-plugin/actions/workflows/nginx-libmodsecurity3.yml/badge.svg) ![WAF security corpus](https://github.com/eilandert/vimbadmin-crs-plugin/actions/workflows/security-corpus.yml/badge.svg)

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
| `tx.vimbadmin-plugin_enabled` | `1` | Master on/off. |
| `tx.vimbadmin_host` | `^vimbadmin.example.com$` | **Set this** to your ViMbAdmin hostname(s) (anchored regex; the `.` is a bare wildcard — ModSecurity macro-expanded `@rx` does not round-trip `\.`/`[.]`). All rules are scoped to it so other vhosts are untouched. |
| `tx.vimbadmin-plugin_positive_security` | `0` | Turn the allowlist layer on (`1`) once you've tested it. |

## Roll-out

1. Install + set `tx.vimbadmin_host`. The exclusions are safe immediately.
2. Run CRS in **DetectionOnly** with `tx.vimbadmin-plugin_positive_security=1`
   and watch the audit log for `9529220` / `9529230` hits — those are
   arguments or paths missing from the allowlist. Add any legitimate ones
   you've added via custom plugins to the inline allowlist regex on rule
   `9529220` in `vimbadmin-after.conf`.
3. Flip CRS back to blocking mode.

Rule ID range: **9,529,000 – 9,529,999** (CRS-allocated block base 9,529,000).

## Continuous integration

Every push/PR runs five GitHub Actions workflows (each gets its own badge above):

| Workflow | What it does |
|---|---|
| **Lint** | Local rule-ID-range (9529000–9529999) / duplicate-ID / `@pmFromFile` / test-reference checks, then the official `coreruleset/crs-plugin-test-action` lint. |
| **Integration tests** | Plugin-structure gates (host gate present, opt-in allowlist, conditional config defaults, `ver:` on every rule) + the official CRS integration action. |
| **Apache + ModSecurity v2** | Builds a shared CRS+plugin image and runs the go-ftw regression suite on real Apache httpd + mod_security2 (`apache2ctl -t` gates parse). |
| **nginx + libmodsecurity3** | Same shared image on Angie + libmodsecurity3 3.0.14 — a production mirror (`angie -t` gates parse). |
| **WAF security corpus** | Cross-engine adversarial corpus: probes that must be blocked + legitimate traffic that must not be, on both engines. |

The dual-engine harness lives under [`tests/integration/`](tests/integration/);
go-ftw test cases under [`tests/regression/`](tests/regression/) and
[`tests/security/`](tests/security/).

## See also

- ViMbAdmin fork: <https://github.com/eilandert/ViMbAdmin>
- Hardened FPM pool, Angie vhost and the Snuffleupagus ruleset ship in that
  repo under `contrib/`.
