#!/bin/sh
# monitor-wan-traffic.sh - live per-WAN throughput from kernel byte counters.
#
# Usage:
#   sh monitor-wan-traffic.sh                 # Mbit/s per WAN, every second
#   sh monitor-wan-traffic.sh -r              # raw byte counters instead
#   sh monitor-wan-traffic.sh [-r] DEV1 DEV2  # custom interfaces
#
# Default interfaces: pppoe-wan  pppoe-wan2

RAW=0
if [ "$1" = "-r" ]; then
    RAW=1
    shift
fi

WAN1="${1:-pppoe-wan}"
WAN2="${2:-pppoe-wan2}"

rd() {
    cat "/sys/class/net/$1/statistics/$2" 2>/dev/null || echo 0
}

if [ "$RAW" -eq 1 ]; then
    while true; do
        printf '%s  WAN1 RX=%-14s TX=%-14s | WAN2 RX=%-14s TX=%-14s\n' \
            "$(date '+%H:%M:%S')" \
            "$(rd "$WAN1" rx_bytes)" "$(rd "$WAN1" tx_bytes)" \
            "$(rd "$WAN2" rx_bytes)" "$(rd "$WAN2" tx_bytes)"
        sleep 1
    done
fi

a1=$(rd "$WAN1" rx_bytes); b1=$(rd "$WAN1" tx_bytes)
a2=$(rd "$WAN2" rx_bytes); b2=$(rd "$WAN2" tx_bytes)

while true; do
    sleep 1
    na1=$(rd "$WAN1" rx_bytes); nb1=$(rd "$WAN1" tx_bytes)
    na2=$(rd "$WAN2" rx_bytes); nb2=$(rd "$WAN2" tx_bytes)

    awk -v t="$(date '+%H:%M:%S')" \
        -v r1="$((na1 - a1))" -v t1="$((nb1 - b1))" \
        -v r2="$((na2 - a2))" -v t2="$((nb2 - b2))" \
        'BEGIN {
            printf "%s  WAN1 RX=%7.1f TX=%7.1f Mbit/s | WAN2 RX=%7.1f TX=%7.1f Mbit/s | TOTAL RX=%7.1f Mbit/s\n",
                t, r1*8/1e6, t1*8/1e6, r2*8/1e6, t2*8/1e6, (r1+r2)*8/1e6
        }'

    a1=$na1; b1=$nb1; a2=$na2; b2=$nb2
done
