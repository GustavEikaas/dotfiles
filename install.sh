#!/bin/bash
set -e

DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "==> Dotfiles: $DOTFILES"

# ── Symlink helper ─────────────────────────────────────────────────────────────
symlink() {
    local src="$1"
    local dst="$2"

    mkdir -p "$(dirname "$dst")"

    if [ -L "$dst" ]; then
        echo "  already linked: $dst"
    elif [ -e "$dst" ]; then
        echo "  backing up: $dst -> $dst.bak"
        mv "$dst" "$dst.bak"
        ln -sf "$src" "$dst"
        echo "  linked: $dst"
    else
        ln -sf "$src" "$dst"
        echo "  linked: $dst"
    fi
}

# ── Symlinks ───────────────────────────────────────────────────────────────────
echo ""
echo "==> Symlinking config folders..."

symlink "$DOTFILES/hypr"      "$HOME/.config/hypr"
symlink "$DOTFILES/kitty"     "$HOME/.config/kitty"
symlink "$DOTFILES/rofi"      "$HOME/.config/rofi"
symlink "$DOTFILES/scripts"   "$HOME/.config/scripts"
symlink "$DOTFILES/wallpaper" "$HOME/.config/wallpaper"
symlink "$DOTFILES/waybar" "$HOME/.config/waybar"
symlink "$DOTFILES/bashrc" "$HOME/.config/bashrc"
symlink "$DOTFILES/bashrc/bashrc" "$HOME/.bashrc"

# ── Make scripts executable ────────────────────────────────────────────────────
echo ""
echo "==> Making scripts executable..."
chmod +x "$DOTFILES/scripts/"*.sh

# ── Install packages ───────────────────────────────────────────────────────────
echo ""
bash "$DOTFILES/scripts/pkg.sh" install

echo ""
echo "==> Done!"
