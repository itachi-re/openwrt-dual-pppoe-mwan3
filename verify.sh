#!/bin/sh
# verify.sh - one-shot health check for the dual-PPPoE mwan3 setup.
#
# Usage:  sh verify.sh
#
# Override defaults through environment variables, e.g.:
#   WAN2_MARK=0x300 sh verify.sh
# (mark / table depend on interface order in /etc/config/mwan3 - see `ip rule`)

WAN1_IF="${WAN1_IF:-wan}"
WAN2_IF="${WAN2_IF:-wan2}"
WAN1_DEV="${WAN1_DEV:-pppoe-wan}"
WAN2_DEV="${WAN2_DEV:-pppoe-wan2}"
WAN1_MARK="${WAN1_MARK:-0x100}"
WAN2_MARK="${WAN2_MARK:-0x500}"
TEST_IP="${TEST_IP:-1.1.1.1}"

PASS=0
FAIL=0

check() {
    desc="$1"
    shift
    if eval "$*" >/dev/null 2>&1; then
        printf '  [ OK ]  %s\n' "$desc"
        PASS=$((PASS + 1))
    else
        printf '  [FAIL]  %s\n' "$desc"
        FAIL=$((FAIL + 1))
    fi
}

echo "== PPPoE sessions"
check "$WAN1_IF is up"                  "ifstatus $WAN1_IF | grep -q '\"up\": true'"
check "$WAN2_IF is up"                  "ifstatus $WAN2_IF | grep -q '\"up\": true'"
check "default route via $WAN1_DEV"     "ip route | grep -q '^default.*dev $WAN1_DEV'"
check "default route via $WAN2_DEV"     "ip route | grep -q '^default.*dev $WAN2_DEV'"

echo "== mwan3"
check "$WAN1_IF online (mwan3)"         "mwan3 status | grep -q 'interface $WAN1_IF is online'"
check "$WAN2_IF online (mwan3)"         "mwan3 status | grep -q 'interface $WAN2_IF is online'"
check "policy route mark $WAN1_MARK -> $WAN1_DEV" \
      "ip route get $TEST_IP mark $WAN1_MARK | grep -q 'dev $WAN1_DEV'"
check "policy route mark $WAN2_MARK -> $WAN2_DEV" \
      "ip route get $TEST_IP mark $WAN2_MARK | grep -q 'dev $WAN2_DEV'"

echo "== Direct connectivity"
check "ping $TEST_IP via $WAN1_DEV"     "ping -I $WAN1_DEV -c 3 -W 3 $TEST_IP"
check "ping $TEST_IP via $WAN2_DEV"     "ping -I $WAN2_DEV -c 3 -W 3 $TEST_IP"

echo "== Firewall / NAT"
check "$WAN2_IF is in a firewall zone"  "uci show firewall | grep '\\.network=' | grep -q \"'$WAN2_IF'\""
check "nft knows $WAN2_DEV"             "nft list ruleset | grep -q '$WAN2_DEV'"
check "nft has masquerade"              "nft list ruleset | grep -q masquerade"

echo
printf 'Passed: %d   Failed: %d\n' "$PASS" "$FAIL"
echo "For the balanced-policy split, run:  mwan3 status"

[ "$FAIL" -eq 0 ]
