# Coraza v3 compatibility helper

`main.go` loads ruleset files into `coraza.NewWAF()` and exits 1 on any
load failure; `-tx tests.json` replays JSON-defined transactions and asserts
which rule IDs fire. Run from `plugins/` so relative `@pmFromFile` /
`@ipMatchFromFile` paths resolve:

    cd plugins && go run ../tests/coraza *.conf

CI now uses `.github/workflows/coraza.yml` to run nginx + Coraza through the
same integration harness as the other engines. This helper remains useful for
quick local parser checks. Vendored copy of the waf-rulesets
coraza-compat-probe — keep the pinned coraza version in `go.mod` in sync
across the CRS plugin repos when bumping.
