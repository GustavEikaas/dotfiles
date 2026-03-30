#!/bin/bash
COUNT=$(docker ps -q 2>/dev/null | wc -l)
NAMES=$(docker ps --format '{{.Names}}' 2>/dev/null | tr '\n' ' ')

if [ "$COUNT" -eq 0 ]; then
  echo '{"text": "", "tooltip": "No containers running", "class": "inactive"}'
else

  echo "{\"text\": \"󰡨 $COUNT\", \"tooltip\": \"$NAMES\", \"class\": \"active\"}"
fi

