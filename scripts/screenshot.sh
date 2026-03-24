#!/usr/bin/env bash

APP_NAME="Screen Capture"
NOTIFICATION_ICON="camera-photo-symbolic"

source "$HOME/.config/scripts/notification-handler.sh"

hyprpicker -r -z &
pid_picker=$!
trap 'kill "$pid_picker" 2>/dev/null' EXIT
sleep 0.1

region=$(slurp -b "#00000080" -c "#888888ff" -w 1) || exit 0
[[ -z "$region" ]] && exit 0

kill "$pid_picker" 2>/dev/null
trap - EXIT

tmp_file=$(mktemp /tmp/screenshot-XXXXXX.png)
grim -g "$region" "$tmp_file"
wl-copy < "$tmp_file"

notify_user \
    --a "${APP_NAME}" \
    --i "$tmp_file" \
    --s "Screenshot copied to clipboard" \
    --m "$(echo "$region" | sed 's/ / — size: /')" \
    --t 3000

(sleep 15 && rm -f "$tmp_file") &
