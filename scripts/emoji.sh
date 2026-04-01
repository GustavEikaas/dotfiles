#!/bin/bash
rofimoji --action type --hidden-descriptions \
  --selector-args="-theme ~/.config/rofi/emoji.rasi \
  -kb-row-left Left \
  -kb-row-right Right \
  -kb-move-char-back ctrl+b \
  -kb-move-char-forward ctrl+f"
