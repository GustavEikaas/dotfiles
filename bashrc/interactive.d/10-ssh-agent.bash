if command -v ssh-agent >/dev/null 2>&1 && ! pgrep -u "$USER" ssh-agent >/dev/null; then
  eval "$(ssh-agent -s)" >/dev/null
fi
