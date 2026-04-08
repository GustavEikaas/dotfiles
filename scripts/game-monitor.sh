#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
#  game-monitor.sh — GPU/CPU/network logger for lag spike diagnosis
#  Tested on Arch Linux  |  Requires: nvidia-utils, lm_sensors, iputils
# ─────────────────────────────────────────────────────────────────────────────

# ── CONFIG ───────────────────────────────────────────────────────────────────
INTERVAL=1           # seconds between samples (1 = 1 reading/sec)
PING_HOST="8.8.8.8"  # swap for a Hunt Showdown server IP for game-specific latency
LOG_DIR="${HOME}/.game-monitor/logs"

# Spike detection thresholds (used in 'analyze' mode)
THRESH_GPU_UTIL=95   # GPU utilisation %
THRESH_GPU_TEMP=85   # GPU temperature °C
THRESH_CPU_UTIL=90   # CPU utilisation %
THRESH_CPU_TEMP=85   # CPU package temperature °C
THRESH_PING=80       # ping ms

# ── HELPERS ──────────────────────────────────────────────────────────────────

die() { printf '\033[31mERROR:\033[0m %s\n' "$*" >&2; exit 1; }
info(){ printf '\033[36m→\033[0m %s\n' "$*"; }

check_deps() {
    local missing=()
    command -v nvidia-smi &>/dev/null || missing+=(nvidia-utils)
    command -v sensors    &>/dev/null || missing+=(lm_sensors)
    command -v ping       &>/dev/null || missing+=(iputils)
    if [[ ${#missing[@]} -gt 0 ]]; then
        die "Missing packages. Install with:\n  sudo pacman -S ${missing[*]}\n  (For lm_sensors also run: sudo sensors-detect)"
    fi
}

# CPU % using /proc/stat — non-blocking; drives loop timing via sleep $INTERVAL
_cpu_stat() {
    awk '/^cpu / {idle=$5+$6; tot=0; for(i=2;i<=NF;i++) tot+=$i; print idle, tot}' /proc/stat
}
cpu_percent() {
    local s1 s2 i1 t1 i2 t2
    read -r i1 t1 <<< "$(_cpu_stat)"
    sleep "$INTERVAL"
    read -r i2 t2 <<< "$(_cpu_stat)"
    local di=$(( i2 - i1 )) dt=$(( t2 - t1 ))
    (( dt == 0 )) && echo 0 || echo $(( 100 * (dt - di) / dt ))
}

gpu_stats() {
    # Returns: util,temp,mem_used,mem_total,power,core_clock,mem_clock
    nvidia-smi \
        --query-gpu=utilization.gpu,temperature.gpu,memory.used,memory.total,power.draw,clocks.current.graphics,clocks.current.memory \
        --format=csv,noheader,nounits \
        | tr -d ' '
}

cpu_temp() {
    # Intel: "Package id 0"; also handles Ryzen (Tdie/Tctl) if you swap CPUs later
    sensors 2>/dev/null \
        | grep -E 'Package id 0|Tdie|Tctl' \
        | grep -oP '\+\K[0-9]+' \
        | head -1
    # Fallback: read directly from hwmon if sensors returns nothing
}

ram_used_mb() {
    awk '/^MemTotal:/{t=$2} /^MemAvailable:/{a=$2} END{printf "%d",(t-a)/1024}' /proc/meminfo
}

ping_ms() {
    ping -c1 -W1 "$PING_HOST" 2>/dev/null \
        | grep -oP 'time=\K[0-9]+' \
        || echo "ERR"
}

# ── MONITOR MODE ─────────────────────────────────────────────────────────────

do_monitor() {
    check_deps
    mkdir -p "$LOG_DIR"

    local logfile="$LOG_DIR/session_$(date +%Y%m%d_%H%M%S).log"

    # CSV header
    printf '%s\n' \
        "# game-monitor session — $(date)" \
        "# Host: $(hostname)  |  Ping target: $PING_HOST  |  Interval: ${INTERVAL}s" \
        "time,gpu_util,gpu_temp_c,gpu_mem_used_mb,gpu_mem_total_mb,gpu_power_w,gpu_core_mhz,gpu_mem_mhz,cpu_util,cpu_temp_c,ram_used_mb,ping_ms" \
        > "$logfile"

    info "Logging to: $logfile"
    info "Run  ./game-monitor.sh analyze  after your match to see spikes."
    echo "Press Ctrl+C to stop."
    echo ""

    printf '\033[1m%-8s  %-9s  %-9s  %-16s  %-9s  %-9s  %-7s\033[0m\n' \
        "TIME" "GPU util" "GPU temp" "VRAM" "CPU util" "CPU temp" "PING"
    printf '%s\n' \
        "────────  ─────────  ─────────  ────────────────  ─────────  ─────────  ───────"

    local running=true
    trap 'running=false; echo ""' SIGINT SIGTERM

    while $running; do
        local ts gpu_data cpu_util ct ram pm
        ts=$(date +%H:%M:%S)

        # cpu_percent sleeps $INTERVAL — this drives the loop cadence
        cpu_util=$(cpu_percent)

        # Instant queries (all run after the sleep above)
        gpu_data=$(gpu_stats)
        local gu gt gm gmt gp gc gmc
        IFS=',' read -r gu gt gm gmt gp gc gmc <<< "$gpu_data"
        gp="${gp%%.*}"   # drop decimal from power

        ct="${ct:-$(cpu_temp)}"
        ct=$(cpu_temp)   # always refresh
        ram=$(ram_used_mb)
        pm=$(ping_ms)

        # Colour-code spikes in live output
        local col_gu='' col_gt='' col_cu='' col_ct='' col_pm='' rst='\033[0m'
        (( gu >= THRESH_GPU_UTIL )) && col_gu='\033[33m'
        (( gt >= THRESH_GPU_TEMP )) && col_gt='\033[31m'
        (( cpu_util >= THRESH_CPU_UTIL )) && col_cu='\033[33m'
        (( ct >= THRESH_CPU_TEMP )) && col_ct='\033[31m'
        [[ "$pm" =~ ^[0-9]+$ ]] && (( pm >= THRESH_PING )) && col_pm='\033[31m'

        printf "%-8s  ${col_gu}%-9s${rst}  ${col_gt}%-9s${rst}  %-16s  ${col_cu}%-9s${rst}  ${col_ct}%-9s${rst}  ${col_pm}%-7s${rst}\n" \
            "$ts" \
            "${gu}%" \
            "${gt}°C" \
            "${gm}/${gmt} MB" \
            "${cpu_util}%" \
            "${ct}°C" \
            "${pm}ms"

        # Write CSV row
        printf '%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s\n' \
            "$ts" "$gu" "$gt" "$gm" "$gmt" "$gp" "$gc" "$gmc" \
            "$cpu_util" "$ct" "$ram" "$pm" \
            >> "$logfile"
    done

    echo ""
    info "Session saved: $logfile"
    info "Run:  ./game-monitor.sh analyze  to review spikes"
}

# ── ANALYZE MODE ─────────────────────────────────────────────────────────────

do_analyze() {
    local logfile="${1:-}"

    if [[ -z "$logfile" ]]; then
        logfile=$(ls -t "$LOG_DIR"/session_*.log 2>/dev/null | head -1)
        [[ -n "$logfile" ]] || die "No sessions found in $LOG_DIR — run './game-monitor.sh start' first."
    fi
    [[ -f "$logfile" ]] || die "File not found: $logfile"

    echo ""
    printf '\033[1m═══════════════════════════════════════════════════════\033[0m\n'
    printf '\033[1m  Session: %s\033[0m\n' "$(basename "$logfile")"
    printf '\033[1m═══════════════════════════════════════════════════════\033[0m\n'
    echo ""

    awk \
        -v T_GU="$THRESH_GPU_UTIL" \
        -v T_GT="$THRESH_GPU_TEMP" \
        -v T_CU="$THRESH_CPU_UTIL" \
        -v T_CT="$THRESH_CPU_TEMP" \
        -v T_PM="$THRESH_PING" \
    'BEGIN {
        FS=","
        spikes=0; n=0
        max_gu=0; max_gt=0; max_gm=0; max_gp=0; max_gc=0
        max_cu=0; max_ct=0; max_ram=0; max_pm=0
        sum_gu=0; sum_gt=0; sum_cu=0; sum_ct=0
        sum_pm=0; pm_n=0
    }
    /^#/ || /^time/ { next }
    {
        n++
        ts=$1
        gu=$2; gt=$3; gm=$4; gmt=$5; gp=$6; gc=$7; gmc=$8
        cu=$9; ct=$10; ram=$11; pm=$12

        sum_gu+=gu; sum_gt+=gt; sum_cu+=cu; sum_ct+=ct
        if (gu+0>max_gu) max_gu=gu+0
        if (gt+0>max_gt) max_gt=gt+0
        if (gm+0>max_gm) max_gm=gm+0
        if (gp+0>max_gp) max_gp=gp+0
        if (gc+0>max_gc) max_gc=gc+0
        if (cu+0>max_cu) max_cu=cu+0
        if (ct+0>max_ct) max_ct=ct+0
        if (ram+0>max_ram) max_ram=ram+0
        if (pm+0==pm+0 && pm!="ERR") { sum_pm+=pm; pm_n++; if (pm+0>max_pm) max_pm=pm+0 }

        spike=""
        if (gu+0 >= T_GU) spike=spike "GPU_UTIL(" gu "%)  "
        if (gt+0 >= T_GT) spike=spike "GPU_TEMP(" gt "°C)  "
        if (cu+0 >= T_CU) spike=spike "CPU_UTIL(" cu "%)  "
        if (ct+0 >= T_CT) spike=spike "CPU_TEMP(" ct "°C)  "
        if (pm!="ERR" && pm+0 >= T_PM) spike=spike "PING(" pm "ms)  "
        if (spike != "") {
            spikes++
            if (spikes==1) printf "\033[33mSPIKES (above thresholds):\033[0m\n"
            printf "  \033[90m%s\033[0m  → \033[31m%s\033[0m\n", ts, spike
        }
    }
    END {
        if (n==0) { print "No data rows found."; exit }
        if (spikes==0) printf "\033[32m✓ No spikes above thresholds in this session.\033[0m\n"
        printf "\n\033[1m──────────────────────── Summary (%d samples) ─────────────────────────\033[0m\n", n
        printf "  GPU utilisation   avg \033[36m%d%%\033[0m   peak \033[33m%d%%\033[0m  (threshold %s%%)\n", sum_gu/n, max_gu, T_GU
        printf "  GPU temperature   avg \033[36m%d°C\033[0m  peak \033[33m%d°C\033[0m (threshold %s°C)\n", sum_gt/n, max_gt, T_GT
        printf "  GPU VRAM peak     \033[36m%d MB\033[0m\n", max_gm
        printf "  GPU power peak    \033[36m%d W\033[0m\n", max_gp
        printf "  GPU clock peak    \033[36m%d MHz\033[0m\n", max_gc
        printf "  CPU utilisation   avg \033[36m%d%%\033[0m   peak \033[33m%d%%\033[0m  (threshold %s%%)\n", sum_cu/n, max_cu, T_CU
        printf "  CPU temperature   avg \033[36m%d°C\033[0m  peak \033[33m%d°C\033[0m (threshold %s°C)\n", sum_ct/n, max_ct, T_CT
        printf "  RAM peak          \033[36m%d MB\033[0m\n", max_ram
        if (pm_n>0)
            printf "  Ping              avg \033[36m%dms\033[0m   peak \033[33m%dms\033[0m  (threshold %sms)\n", sum_pm/pm_n, max_pm, T_PM
        printf "\033[1m────────────────────────────────────────────────────────────────────\033[0m\n"
    }' "$logfile"

    echo ""
}

# ── LIST MODE ─────────────────────────────────────────────────────────────────

do_list() {
    echo "Saved sessions in $LOG_DIR:"
    local files
    files=$(ls -lt "$LOG_DIR"/session_*.log 2>/dev/null) || true
    if [[ -z "$files" ]]; then
        echo "  (none yet)"
    else
        echo "$files" | awk '{printf "  %s   %s %s %s\n", $NF, $6, $7, $8}'
    fi
}

# ── USAGE / ENTRY POINT ───────────────────────────────────────────────────────

usage() {
    cat <<'EOF'

  Usage: ./game-monitor.sh <command>

  Commands:
    start                 Start monitoring  (Ctrl+C to stop and save)
    analyze [logfile]     Analyze a session log (defaults to latest)
    list                  List all saved sessions

  Quickstart:
    chmod +x game-monitor.sh
    ./game-monitor.sh start          ← run before a match
    ./game-monitor.sh analyze        ← run after the match

  Config (top of script):
    INTERVAL     Sample interval in seconds  (default: 1)
    PING_HOST    IP to ping for latency      (default: 8.8.8.8)
    LOG_DIR      Log directory               (default: ~/.game-monitor/logs)
    THRESH_*     Spike detection thresholds

EOF
}

case "${1:-}" in
    start)   do_monitor ;;
    analyze) do_analyze "${2:-}" ;;
    list)    do_list ;;
    *)       usage ;;
esac
