
#!/bin/bash
layout=$(hyprctl getoption input:kb_layout | awk 'NR==1 {print $2}')
if [ "$layout" = "us" ]; then
    echo '{"text": "EN", "class": "en"}'
else
    echo '{"text": "NO", "class": "no"}'
fi
