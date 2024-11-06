#!/usr/bin/env bash

############################################################################################
## Settings
############################################################################################

# the iface of the "outside"
WEBIFACE=eth0
# the iface of the LAN it will serve
LANIFACE=eth1

# network and mask of the LAN
DOMAIN_NAME=diablan

LANNET=172.29.0.0/16
SERVERLANIP=172.29.255.254
DHCP_RANGE=172.29.255.10:172.29.255.200

SUDOUSER=koubi

# overide hostname: if set, change hostname
# HOSTNAME_OVERRIDE="gwtest"

############################################################################################
## Defaults
############################################################################################

[ ! -f /etc/os-release ] && echo "[NETCONF] ERROR: could not locate '/etc/os-release'" && exit 1
. /etc/os-release

SUDOUSER=${SUDOUSER:-"admin"}
DOMAIN_NAME=${DOMAIN_NAME:-"mydomain"}
LANNET=${LANNET:-"192.168.30.0/24"}
SERVERLANIP=${SERVERLANIP:-"192.168.30.254"}
DHCP_RANGE=${DHCP_RANGE:-"192.168.30.100:192.168.30.200"}
DHCP_RANGE_START=${DHCP_RANGE%:*}
DHCP_RANGE_END=${DHCP_RANGE#*:}
function portableIPcalc() {
  case ${ID_LIKE:-${ID}} in
    *debian*|*ubuntu*) ipcalc --nobinary ${LANNET} ;;
    *fedora*|*rhel*)   ipcalc ${LANNET}            ;;
  esac | grep $1 | xargs | cut -d' ' -f2
}
LANMASK=$(portableIPcalc Netmask)
LANBROADCAST=$(portableIPcalc Broadcast)

# Check DNS list parsability
# Format : IP # COMMENT
# example
# 1.1.1.1 # cloudflare
# 8.8.8.8 # google
[ ! -f config.dns.list ] && echo "[NETCONF] WARNING: Could not locate 'config.dns.list'"
[ -f config.dns.list ] && DNS_LIST=$(cat config.dns.list \
  | sed -r 's/#.*//g' | sed -r 's/\s+$//g' | grep -v "^#\|^\s*$" | xargs)
DNS_LIST=${DNS_LIST:-""}

# Check fixed host list parsability
# Format : MAC IP HOSTNAME # comments
# example
# 00:1c:bf:36:f9:5a	172.30.255.10	PC1
# 00:1c:23:ad:ee:8d	172.30.255.11	PC2 # should not connect
# 00:1c:ab:ad:ee:dd	172.30.255.16	server1 # web server
[ ! -f config.fixed_hosts.list ] && echo "[NETCONF] WARNING: Could not locate 'config.fixed_hosts.list'"
[ -f config.fixed_hosts.list ] && FIXED_IPS=$(cat config.fixed_hosts.list \
  | sed -r 's/#.*//g' | sed -r 's/\s+$//g' | grep -v "^#\|^\s*$" \
  | sed -r 's/\s+/:/g' | sed 's/\r/\n/g')
FIXED_IPS=${FIXED_IPS:-""}

# Check NAT list parsability
# Format : IP/Hostname port-list # COMMENT
# example
# PC1 22:22 54321-54329:54321-54329 #
# 172.30.255.16 80 443 18022:22 #
[ ! -f config.nat.list ] && echo "[NETCONF] WARNING: Could not locate 'config.nat.list'"
[ -f config.nat.list ] && NAT_LIST=$(cat config.nat.list \
  | sed -r 's/#.*//g' | sed -r 's/\s+$//g' | grep -v "^#\|^\s*$" \
  | sed -r 's/\s+/#/g' | sed 's/\r/\n/g')
NAT_LIST=${NAT_LIST:-""}

############################################################################################
## Return
############################################################################################
