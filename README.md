My arch hyprland dotfiles

## First-time setup

1. **Install `git`** so you can clone the repo:
   ```bash
   sudo pacman -S --needed git
   ```

2. **Clone the repo** and place it wherever you like:
   ```bash
   git clone https://github.com/YOUR_USERNAME/dotfiles.git ~/dotfiles
   cd ~/dotfiles
   ```

3. **Run the install wizard**:
   ```bash
   ./install.sh
   ```
   The wizard will:
   - offer to install missing bootstrap packages like `jq`
   - run `scripts/pkg.sh install` for the packages declared in `packages.txt`
   - symlink `bashrc/` to `~/.config/bashrc`
   - ensure `~/.bashrc` sources `~/.config/bashrc/bashrc`

   If `packages.txt` includes AUR packages, `yay` must already be installed or the package-install step will fail. See the [yay install guide](https://github.com/Jguer/yay#installation).

4. **Reload your shell**:
   ```bash
   source ~/.bashrc
   ```

If you prefer to do the Bash setup manually, use:

```bash
ln -sfn ~/dotfiles/bashrc ~/.config/bashrc
printf '\nsource ~/.config/bashrc/bashrc\n' >> ~/.bashrc
```

Bash will not automatically source `~/.config/bashrc` just because the directory exists or is symlinked there. One of Bash's normal startup files, such as `~/.bashrc`, must explicitly source `~/.config/bashrc/bashrc`.

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
