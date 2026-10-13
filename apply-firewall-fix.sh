#!/bin/sh
# apply-firewall-fix.sh
#
# Adds a PPPoE interface (default: wan2) to the firewall zone named "wan" so
# that traffic leaving through pppoe-wan2 gets masqueraded.
#
# Unlike `uci add_list firewall.@zone[1]...`, this finds the zone by NAME,
# so it still works if your zones are in a different order.
#
# Usage:  sh apply-firewall-fix.sh [interface] [zone-name]
#         sh apply-firewall-fix.sh wan2 wan

IFACE="${1:-wan2}"
ZONE_NAME="${2:-wan}"

find_zone() {
    uci show firewall \
        | sed -n "s/^firewall\.\([^.]*\)\.name='$1'$/\1/p" \
        | while read -r s; do
            if [ "$(uci -q get "firewall.$s")" = "zone" ]; then
                echo "$s"
                break
            fi
        done
}

SECTION="$(find_zone "$ZONE_NAME")"

if [ -z "$SECTION" ]; then
    echo "ERROR: firewall zone '$ZONE_NAME' not found." >&2
    exit 1
fi

if uci -q get "firewall.$SECTION.network" | tr ' ' '\n' | grep -qx "$IFACE"; then
    echo "OK: '$IFACE' is already in zone '$ZONE_NAME' ($SECTION). Nothing to do."
    exit 0
fi

echo "Adding '$IFACE' to zone '$ZONE_NAME' ($SECTION)..."
uci add_list "firewall.$SECTION.network=$IFACE"
uci commit firewall
/etc/init.d/firewall reload

echo
echo "Result:"
uci show firewall | grep -E "firewall\.$(echo "$SECTION" | sed 's/[][]/\\&/g')\.(name|network|masq)"
