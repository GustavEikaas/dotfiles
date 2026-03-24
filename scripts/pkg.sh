#!/usr/bin/env bash
# pkg.sh — dotfiles package manager
#
# Subcommands:
#   generate   Read packages.txt, query installed versions, write packages.lock
#   install    Install packages from packages.txt (pacman / yay for aur:)
#   check      Compare installed versions against packages.lock
#
# Usage: scripts/pkg.sh <generate|install|check>

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PACKAGES_TXT="$REPO_ROOT/packages.txt"
PACKAGES_LOCK="$REPO_ROOT/packages.lock"

die() { echo "error: $*" >&2; exit 1; }

read_packages() {
    while IFS= read -r line; do
        line="${line%%#*}"
        line="${line//[[:space:]]/}"
        [[ -z "$line" ]] && continue
        if [[ "$line" == aur:* ]]; then
            echo "aur:${line#aur:}"
        else
            echo "pacman:$line"
        fi
    done < "$PACKAGES_TXT"
}

installed_version() {
    pacman -Q "$1" 2>/dev/null | awk '{print $2}' || true
}

cmd_generate() {
    echo "==> Generating packages.lock from installed packages..."
    local entries="[]"

    while IFS=: read -r source name; do
        local ver
        ver="$(installed_version "$name")"
        if [[ -z "$ver" ]]; then
            echo "  [WARN] $name is not installed — skipping"
            continue
        fi
        echo "  $name  $ver  ($source)"
        entries="$(jq -n --argjson arr "$entries" \
            --arg n "$name" --arg v "$ver" --arg s "$source" \
            '$arr + [{name:$n,version:$v,source:$s}]')"
    done < <(read_packages)

    local timestamp
    timestamp="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

    jq -n --arg generated "$timestamp" --argjson packages "$entries" \
        '{generated:$generated,packages:$packages}' > "$PACKAGES_LOCK"

    echo "==> Written: $PACKAGES_LOCK"
}

cmd_install() {
    local pacman_pkgs=()
    local aur_pkgs=()

    while IFS=: read -r source name; do
        if [[ "$source" == "aur" ]]; then
            aur_pkgs+=("$name")
        else
            pacman_pkgs+=("$name")
        fi
    done < <(read_packages)

    if [[ ${#pacman_pkgs[@]} -gt 0 ]]; then
        echo "==> Installing pacman packages: ${pacman_pkgs[*]}"
        sudo pacman -S --needed --noconfirm "${pacman_pkgs[@]}"
    fi

    if [[ ${#aur_pkgs[@]} -gt 0 ]]; then
        if ! command -v yay &>/dev/null; then
            die "yay is not installed but AUR packages are required: ${aur_pkgs[*]}"
        fi
        echo "==> Installing AUR packages: ${aur_pkgs[*]}"
        yay -S --needed --noconfirm "${aur_pkgs[@]}"
    fi

    if [[ -f "$PACKAGES_LOCK" ]]; then
        echo ""
        cmd_check
    fi
}

cmd_check() {
    [[ -f "$PACKAGES_LOCK" ]] || die "packages.lock not found — run 'generate' first"

    echo "==> Comparing installed versions vs packages.lock"
    echo ""
    printf "%-22s %-20s %-20s %s\n" "PACKAGE" "LOCKED" "INSTALLED" "STATUS"
    printf "%-22s %-20s %-20s %s\n" "-------" "------" "---------" "------"

    local ok=0 drift=0 missing=0

    while IFS=$'\t' read -r name locked_ver source; do
        local inst_ver
        inst_ver="$(installed_version "$name")"

        if [[ -z "$inst_ver" ]]; then
            printf "%-22s %-20s %-20s %s\n" "$name" "$locked_ver" "(not installed)" "MISSING"
            ((missing++)) || true
        elif [[ "$inst_ver" == "$locked_ver" ]]; then
            printf "%-22s %-20s %-20s %s\n" "$name" "$locked_ver" "$inst_ver" "ok"
            ((ok++)) || true
        else
            printf "%-22s %-20s %-20s %s\n" "$name" "$locked_ver" "$inst_ver" "DRIFT"
            ((drift++)) || true
        fi
    done < <(jq -r '.packages[] | [.name, .version, .source] | @tsv' "$PACKAGES_LOCK")

    echo ""
    echo "  ok=$ok  drift=$drift  missing=$missing"
    echo ""
    if [[ $drift -gt 0 || $missing -gt 0 ]]; then
        echo "  Run 'scripts/pkg.sh generate' to update the lockfile to current versions."
    fi
}

[[ -f "$PACKAGES_TXT" ]] || die "packages.txt not found at $PACKAGES_TXT"

case "${1:-}" in
    generate) cmd_generate ;;
    install)  cmd_install ;;
    check)    cmd_check ;;
    *)
        echo "Usage: $(basename "$0") <generate|install|check>"
        echo ""
        echo "  generate   Write packages.lock from currently installed versions"
        echo "  install    Install all packages listed in packages.txt"
        echo "  check      Show drift between packages.lock and installed state"
        exit 1
        ;;
esac
