#!/usr/bin/env bash
set -euo pipefail

version="${GO_FTW_VERSION:?GO_FTW_VERSION is required}"
cache_root="${XDG_CACHE_HOME:-$HOME/.cache}/vimbadmin-crs-plugin/go-ftw"
cache_dir="${cache_root}/${version}"
cached_ftw="${cache_dir}/ftw"

if [ ! -x "$cached_ftw" ]; then
    tmp="$(mktemp -d)"
    trap 'rm -rf "$tmp"' EXIT
    mkdir -p "$cache_dir"

    for attempt in 1 2 3; do
        rm -f "$tmp/ftw.tgz" "$tmp/ftw"
        if gh release download -R coreruleset/go-ftw \
            -p 'ftw_*_linux_amd64.tar.gz' \
            -O "$tmp/ftw.tgz" "$version" \
            && tar -xzf "$tmp/ftw.tgz" -C "$tmp" ftw; then
            install -m 0755 "$tmp/ftw" "$cached_ftw"
            break
        fi
        echo "ftw download attempt ${attempt} failed; retrying"
        sleep 5
    done
fi

test -x "$cached_ftw"
install -m 0755 "$cached_ftw" ./ftw
