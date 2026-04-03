#!/bin/bash
STEP=5

case "$1" in
  up)   wpctl set-volume -l 1.0 @DEFAULT_AUDIO_SINK@ ${STEP}%+ ;;
  down) wpctl set-volume @DEFAULT_AUDIO_SINK@ ${STEP}%- ;;
  mute) wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle ;;
esac

VOLUME=$(wpctl get-volume @DEFAULT_AUDIO_SINK@)
VOL_NUM=$(echo "$VOLUME" | awk '{print int($2 * 100)}')
MUTED=$(echo "$VOLUME" | grep -c "MUTED")

BAR_LENGTH=12
FILLED=$(( VOL_NUM * BAR_LENGTH / 100 ))
BAR=""
for i in $(seq 1 $BAR_LENGTH); do
  [ $i -le $FILLED ] && BAR="${BAR}#" || BAR="${BAR}-"
done

PCT=$(printf '%3s%%' "$VOL_NUM")

if [ "$MUTED" -gt 0 ]; then
  BODY="<span color='#44475a'>[${BAR}]  muted</span>"
else
  BODY="<span color='#bd93f9'>[${BAR}]</span><span color='#6272a4'>  |  </span><span color='#f8f8f2'>${PCT}</span>"
fi

notify-send -u low \
  -h string:x-dunst-stack-tag:volume \
  -h string:app_name:volume-control \
  -t 1500 \
  " " "$BODY"
