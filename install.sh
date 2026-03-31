#!/bin/bash
set -e
DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

NO_CONFIRM=false

# ── Symlink pairs  src:dst ────────────────────────────────────────────────────
SYMLINKS=(
    "$DOTFILES/hypr:$HOME/.config/hypr"
    "$DOTFILES/kitty:$HOME/.config/kitty"
    "$DOTFILES/rofi:$HOME/.config/rofi"
    "$DOTFILES/scripts:$HOME/.config/scripts"
    "$DOTFILES/wallpaper:$HOME/.config/wallpaper"
    "$DOTFILES/waybar:$HOME/.config/waybar"
    "$DOTFILES/bashrc:$HOME/.config/bashrc"
    "$DOTFILES/bashrc/bashrc:$HOME/.bashrc"
)

# ── Check mode ────────────────────────────────────────────────────────────────
check() {
    echo "==> Symlink status"
    for pair in "${SYMLINKS[@]}"; do
        local src="${pair%%:*}"
        local dst="${pair#*:}"
        if [ -L "$dst" ]; then
            local target
            target=$(readlink "$dst")
            if [ "$target" = "$src" ]; then
                printf "  \e[32m✓\e[0m  %-40s -> %s\n" "$dst" "$target"
            else
                printf "  \e[33m~\e[0m  %-40s -> %s  (expected: %s)\n" "$dst" "$target" "$src"
            fi
        elif [ -e "$dst" ]; then
            printf "  \e[33m!\e[0m  %-40s (exists, not a symlink)\n" "$dst"
        else
            printf "  \e[31m✗\e[0m  %-40s (missing)\n" "$dst"
        fi
    done

    echo ""
    bash "$DOTFILES/scripts/pkg.sh" check
}

# ── Symlink helper ────────────────────────────────────────────────────────────
symlink() {
    local src="$1"
    local dst="$2"
    mkdir -p "$(dirname "$dst")"

    if [ -L "$dst" ]; then
        echo "  already linked: $dst"
    elif [ -e "$dst" ]; then
        local backup="$dst.bak"
        if $NO_CONFIRM; then
            mv "$dst" "$backup"
            echo "  backed up:  $backup"
            ln -sf "$src" "$dst"
            echo "  linked:     $dst"
        else
            printf "  '%s' already exists. Back up to '%s'? [y/N] " "$dst" "$backup"
            read -r reply
            if [[ "$reply" =~ ^[Yy]$ ]]; then
                mv "$dst" "$backup"
                echo "  backed up:  $backup"
                ln -sf "$src" "$dst"
                echo "  linked:     $dst"
            else
                echo "  skipped:    $dst"
            fi
        fi
    else
        ln -sf "$src" "$dst"
        echo "  linked: $dst"
    fi
}

# ── Install mode ──────────────────────────────────────────────────────────────
install() {
    echo "==> Dotfiles: $DOTFILES"

    echo ""
    echo "==> Symlinking config folders..."
    for pair in "${SYMLINKS[@]}"; do
        symlink "${pair%%:*}" "${pair#*:}"
    done

    echo ""
    echo "==> Making scripts executable..."
    chmod +x "$DOTFILES/scripts/"*.sh

    echo ""
    bash "$DOTFILES/scripts/pkg.sh" install

    echo ""
    echo "==> Done!"
}

# ── Entry point ───────────────────────────────────────────────────────────────
# Parse flags first, then subcommand
COMMAND=""
for arg in "$@"; do
    case "$arg" in
        --no-confirm) NO_CONFIRM=true ;;
        --check | -c) COMMAND="check" ;;
        *) echo "Unknown option: $arg"; echo "Usage: $0 [--check|-c] [--no-confirm]"; exit 1 ;;
    esac
done

case "$COMMAND" in
    check)   check ;;
    *)       install ;;
esac
