My arch hyprland dotfiles

## First-time setup

1. **Install `jq` and `git`** (the only bootstrap dependencies):
   ```bash
   sudo pacman -S --needed git jq
   ```

2. **Clone the repo** and place it wherever you like:
   ```bash
   git clone https://github.com/YOUR_USERNAME/dotfiles.git ~/dotfiles
   cd ~/dotfiles
   ```

3. **Install all declared packages**:
   ```bash
   scripts/pkg.sh install
   ```
   This installs pacman packages with `sudo pacman -S --needed` and AUR packages with `yay`.
   `yay` itself must be installed separately if you don't have it yet — see the [yay install guide](https://github.com/Jguer/yay#installation).

4. **Symlink or copy config files** into place (manually for now, until a stow/symlink script is added).

## Package management

Packages are declared in `packages.txt` (plain pacman names, `aur:` prefix for AUR).
Pinned versions are recorded in `packages.lock` (generated — do not edit by hand).

```bash
# Install everything on a new machine
scripts/pkg.sh install

# After updating packages, re-pin the lockfile
scripts/pkg.sh generate

# Check if installed versions have drifted from the lockfile
scripts/pkg.sh check
```
