# Troubleshooting

Run everything at once with:

```sh
sh scripts/verify.sh
```

Or step through the checklist manually.

## Checklist

| # | Question | Command | Expected |
|---|----------|---------|----------|
| 1 | Both PPPoE sessions up? | `mwan3 status` | `wan online` and `wan2 online` |
| 2 | WAN2 has Internet? | `ping -I pppoe-wan2 -c 3 1.1.1.1` | 0% packet loss |
| 3 | WAN2 policy route works? | `ip route get 1.1.1.1 mark 0x500` | `dev pppoe-wan2`, `table 5` |
| 4 | WAN2 in firewall zone? | `uci show firewall \| grep -E 'zone.*network\|zone.*masq'` | `'wan' 'wan6' 'wan2'` |
| 5 | WAN2 NAT exists? | `nft list ruleset \| grep -E -B2 -A4 'pppoe-wan2\|masquerade'` | `pppoe-wan2` and `masquerade` |
| 6 | mwan3 balanced? | `mwan3 status` | `balanced: wan2 (50%) wan (50%)` |

> The mark (`0x500`) and table (`5`) depend on interface order in `/etc/config/mwan3`. Check with `ip rule`.

## Common problems

**`mwan3 reload` does nothing / errors**
On this OpenWrt/mwan3 version use `mwan3 restart`.

**mwan3 shows 50/50, but all large traffic goes through WAN1**
Almost always the firewall problem below: `wan2` is not in the WAN zone.

**Proxy traffic is balanced instead of pinned to WAN1**
The proxy rule is below `default_rule_v4`. Rules are evaluated top to bottom, so move it above.

**`ip route get ... mark ...` shows the wrong device/table**
The mark/table numbers depend on interface order in `/etc/config/mwan3`. List the real values with `ip rule`.

**Existing downloads die when a WAN drops**
Expected. mwan3 does not migrate established connections. New connections use the remaining WAN.

## The critical firewall problem

Initially `wan2` was configured as a PPPoE interface and mwan3 was correctly marking traffic for it. However, the firewall WAN zone contained only:

```text
wan
wan6
```

and **not** `wan2`. The result:

```text
mwan3
  ↓
WAN2 routing table
  ↓
pppoe-wan2
  ↓
NO normal WAN-zone masquerading
  ↓
traffic fails
```

That is why mwan3 could show approximately `wan2 50% / wan 50%` while practically all large traffic still went through WAN1.

### Fix

```sh
uci add_list firewall.@zone[1].network='wan2'
uci commit firewall
/etc/init.d/firewall reload
```

(or `sh scripts/apply-firewall-fix.sh`, which finds the zone by name instead of by index)

Verify:

```sh
uci show firewall | grep -E 'zone.*name|zone.*network|zone.*masq'
```

```text
firewall.@zone[0].name='lan'
firewall.@zone[0].network='lan'

firewall.@zone[1].name='wan'
firewall.@zone[1].network='wan' 'wan6' 'wan2'
firewall.@zone[1].masq='1'
```

The firewall4 NAT chain should then contain:

```text
oifname { "eth1", "pppoe-wan", "pppoe-wan2" } jump srcnat_wan
```

with `meta nfproto ipv4 masquerade`.

## Lessons learned

> mwan3 can correctly mark and route traffic to a WAN while that WAN is still unusable for forwarded LAN traffic if the firewall/NAT configuration doesn't include the interface.

In this case mwan3 was already making the ~50/50 policy decision. The missing piece was `wan2` not being a member of the firewall's WAN zone. Once added, firewall4 included `pppoe-wan2` in the WAN zone and its IPv4 masquerading path, and independent LAN connections used both WAN paths.
