# ViMbAdmin OWASP CRS Plugin

A drop-in [OWASP CRS](https://coreruleset.org/) plugin that makes the Core
Rule Set play nicely with **[ViMbAdmin](https://github.com/eilandert/ViMbAdmin)**
— and, optionally, locks the admin panel down to a strict allowlist.

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
| `tx.vimbadmin_host` | `^vimbadmin\.example\.com$` | **Set this** to your ViMbAdmin hostname(s) (anchored regex). All rules are scoped to it so other vhosts are untouched. |
| `tx.vimbadmin_positive_security` | `0` | Turn the allowlist layer on (`1`) once you've tested it. |

## Roll-out

1. Install + set `tx.vimbadmin_host`. The exclusions are safe immediately.
2. Run CRS in **DetectionOnly** with `tx.vimbadmin_positive_security=1` and
   watch the audit log for `9508220` / `9508230` hits — those are arguments
   or paths missing from the allowlist. Add any legitimate ones you've added
   via custom plugins to the `tx.vimbadmin_allow_args` regex in
   `vimbadmin-after.conf`.
3. Flip CRS back to blocking mode.

Rule ID range: **9,508,000 – 9,508,999**.

## See also

- ViMbAdmin fork: <https://github.com/eilandert/ViMbAdmin>
- Hardened FPM pool, Angie vhost and the Snuffleupagus ruleset ship in that
  repo under `contrib/` and `snuffleupagus/`.
