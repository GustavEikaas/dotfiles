#!/usr/bin/env bash

set -euo pipefail

REPO_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PACKAGES_SCRIPT="$REPO_ROOT/scripts/pkg.sh"
TARGET_HOME="${DOTFILES_INSTALL_HOME:-$HOME}"
CONFIG_HOME="${DOTFILES_CONFIG_HOME:-$TARGET_HOME/.config}"
BASHRC_LINK_TARGET="$REPO_ROOT/bashrc"
BASHRC_LINK_PATH="$CONFIG_HOME/bashrc"
BASHRC_FILE="$TARGET_HOME/.bashrc"
SOURCE_LINE="source \"$BASHRC_LINK_PATH/bashrc\""

die() {
  echo "error: $*" >&2
  exit 1
}

usage() {
  cat <<EOF
Usage: ./install.sh

Interactive setup wizard for this dotfiles repo.

It can:
  - install missing bootstrap packages (git and jq) when possible
  - run scripts/pkg.sh install
  - symlink bashrc/ to ~/.config/bashrc
  - ensure ~/.bashrc sources the repo bashrc loader

Environment overrides:
  DOTFILES_INSTALL_HOME  Override the home directory used for setup
  DOTFILES_CONFIG_HOME   Override the config directory used for bashrc
EOF
}

prompt_yes_no() {
  local prompt="$1"
  local default_answer="${2:-y}"
  local reply
  local suffix

  if [[ "$default_answer" == "y" ]]; then
    suffix="[Y/n]"
  else
    suffix="[y/N]"
  fi

  while true; do
    read -r -p "$prompt $suffix " reply
    reply="${reply:-$default_answer}"

    case "$reply" in
      [yY]|[yY][eE][sS]) return 0 ;;
      [nN]|[nN][oO]) return 1 ;;
      *) echo "Please answer y or n." ;;
    esac
  done
}

command_exists() {
  command -v "$1" >/dev/null 2>&1
}

print_header() {
  cat <<EOF
==> Dotfiles install wizard
Repo:        $REPO_ROOT
Target home: $TARGET_HOME
Config dir:  $CONFIG_HOME

This wizard can install packages and configure your Bash setup.
EOF
}

install_bootstrap_packages() {
  local -a missing=()
  local command_name

  for command_name in git jq; do
    if ! command_exists "$command_name"; then
      missing+=("$command_name")
    fi
  done

  if [[ ${#missing[@]} -eq 0 ]]; then
    return 0
  fi

  echo "Missing bootstrap packages: ${missing[*]}"

  if ! command_exists pacman; then
    echo "Skipping bootstrap install because pacman is not available."
    return 1
  fi

  if ! prompt_yes_no "Install missing bootstrap packages with sudo pacman?" "y"; then
    echo "Skipping bootstrap package installation."
    return 1
  fi

  sudo pacman -S --needed "${missing[@]}"

  for command_name in "${missing[@]}"; do
    if ! command_exists "$command_name"; then
      echo "Bootstrap package is still missing after install attempt: $command_name"
      return 1
    fi
  done
}

has_aur_packages() {
  grep -Eq '^[[:space:]]*aur:' "$REPO_ROOT/packages.txt"
}

install_declared_packages() {
  if ! prompt_yes_no "Install packages from packages.txt now?" "y"; then
    echo "Skipping package installation."
    return 0
  fi

  if ! install_bootstrap_packages; then
    echo "Package installation skipped because required bootstrap packages are missing."
    return 1
  fi

  if has_aur_packages && ! command_exists yay; then
    echo "Note: packages.txt includes AUR packages and yay is not installed."
    echo "scripts/pkg.sh install will fail until yay is installed."
  fi

  if bash "$PACKAGES_SCRIPT" install; then
    echo "Package installation completed."
    return 0
  fi

  echo "Package installation failed. Continuing with the remaining setup steps."
  return 1
}

is_bashrc_loader_line() {
  case "$1" in
    "source \"$BASHRC_LINK_PATH/bashrc\""|". \"$BASHRC_LINK_PATH/bashrc\""|"source $BASHRC_LINK_PATH/bashrc"|". $BASHRC_LINK_PATH/bashrc"|\
    "source ~/.config/bashrc/bashrc"|". ~/.config/bashrc/bashrc"|"source \"\$HOME/.config/bashrc/bashrc\""|". \"\$HOME/.config/bashrc/bashrc\""|\
    "source \$HOME/.config/bashrc/bashrc"|". \$HOME/.config/bashrc/bashrc")
      return 0
      ;;
  esac

  return 1
}

ensure_bashrc_loader_line() {
  local tmp_file
  local existing_line

  tmp_file="$(mktemp)"

  if [[ -f "$BASHRC_FILE" ]]; then
    while IFS= read -r existing_line || [[ -n "$existing_line" ]]; do
      if is_bashrc_loader_line "$existing_line"; then
        continue
      fi
      printf '%s\n' "$existing_line" >> "$tmp_file"
    done < "$BASHRC_FILE"
  fi

  printf '%s\n' "$SOURCE_LINE" >> "$tmp_file"
  mv "$tmp_file" "$BASHRC_FILE"
}

ensure_bashrc_symlink() {
  local current_target

  mkdir -p "$CONFIG_HOME"

  if [[ -L "$BASHRC_LINK_PATH" ]]; then
    current_target="$(readlink "$BASHRC_LINK_PATH")"
    if [[ "$current_target" != "$BASHRC_LINK_TARGET" ]]; then
      ln -sfn "$BASHRC_LINK_TARGET" "$BASHRC_LINK_PATH"
    fi
    return 0
  fi

  if [[ -e "$BASHRC_LINK_PATH" ]]; then
    echo "Cannot configure bashrc automatically because $BASHRC_LINK_PATH already exists and is not a symlink."
    echo "Move it out of the way manually, then rerun the installer."
    return 1
  fi

  ln -s "$BASHRC_LINK_TARGET" "$BASHRC_LINK_PATH"
}

configure_bashrc() {
  if ! prompt_yes_no "Configure bashrc in $BASHRC_LINK_PATH and update $BASHRC_FILE?" "y"; then
    echo "Skipping bashrc configuration."
    return 0
  fi

  if ! ensure_bashrc_symlink; then
    return 1
  fi

  ensure_bashrc_loader_line

  echo "Configured bashrc:"
  echo "  symlink: $BASHRC_LINK_PATH -> $BASHRC_LINK_TARGET"
  echo "  source:  $SOURCE_LINE"
}

main() {
  local package_status="skipped"
  local bashrc_status="skipped"

  case "${1:-}" in
    "" ) ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      usage >&2
      exit 1
      ;;
  esac

  [[ -f "$PACKAGES_SCRIPT" ]] || die "packages script not found at $PACKAGES_SCRIPT"
  [[ -d "$BASHRC_LINK_TARGET" ]] || die "bashrc directory not found at $BASHRC_LINK_TARGET"

  print_header
  echo ""

  if install_declared_packages; then
    package_status="completed"
  else
    package_status="needs attention"
  fi

  echo ""

  if configure_bashrc; then
    bashrc_status="configured"
  else
    bashrc_status="needs attention"
  fi

  cat <<EOF

==> Setup summary
Packages: $package_status
Bashrc:   $bashrc_status

Next steps:
  - Open a new shell, or run: source "$BASHRC_FILE"
  - If package installation failed because yay is missing, install yay and rerun ./install.sh
EOF
}

main "$@"
