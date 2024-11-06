#!/usr/bin/env bash
set -eu -o pipefail

ERROR_COUNT=0

############################################################################################
## System Checks
############################################################################################

# Check that the distro is supported
[ ! -f /etc/os-release ] && echo "[NETCONF] ERROR: could not locate '/etc/os-release'" && exit 1
. /etc/os-release
case ${ID_LIKE:-${ID}} in
    *debian*|*ubuntu*) : ;;
    *fedora*|*rhel*) : ;;
    *)
        echo "[NETCONF] ERROR: unsupported distribution family $ID_LIKE"
        ERROR_COUNT=$((ERROR_COUNT + 1))
        ;;
esac

# Check that user is root
[ "$(whoami)" != root ] && echo "[NETCONF] ERROR: must run as root" && ERROR_COUNT=$((ERROR_COUNT + 1))

############################################################################################
## Config file checks
############################################################################################

# Check that we can source config
[ ! -f config.sh ] && echo "[NETCONF] ERROR: Could not locate 'config.sh'" && exit 1
source config.sh

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
## Config content checks
############################################################################################

set +e
cat /etc/passwd | grep ^${SUDOUSER}: &> /dev/null
RES=$?
set -e
[ $RES != 0 ] && echo "[NETCONF] ERROR: user '${SUDOUSER}' does not exist in '/etc/passwd'." && ERROR_COUNT=$((ERROR_COUNT + 1))

DHCP_RANGE_START=${DHCP_RANGE%:*}
DHCP_RANGE_END=${DHCP_RANGE#*:}

# Check that interfaces exist
[ ! -d /sys/class/net/$WEBIFACE ] && echo "[NETCONF] ERROR: Interface $WEBIFACE does not exist." && ERROR_COUNT=$((ERROR_COUNT + 1))
[ ! -d /sys/class/net/$LANIFACE ] && echo "[NETCONF] ERROR: Interface $LANIFACE does not exist." && ERROR_COUNT=$((ERROR_COUNT + 1))

# Check that there is no overlap between Web IP and new subnet
WEBIP=$(ip addr show $WEBIFACE | grep -Po 'inet \K[\d.]+')
set +e
echo $WEBIP | grepcidr ${LANNET} &> /dev/null
[ $? == 0 ] && echo "[NETCONF] ERROR: Web IP '$WEBIP' belongs to subnet '${LANNET}'" && ERROR_COUNT=$((ERROR_COUNT + 1))

# Check that server IP and DHCP range belong to subnet
echo $SERVERLANIP | grepcidr ${LANNET} &> /dev/null
[ $? != 0 ] && echo "[NETCONF] ERROR: Server lan IP '$SERVERLANIP' does not belong to subnet '${LANNET}'" && ERROR_COUNT=$((ERROR_COUNT + 1))
echo $DHCP_RANGE_START | grepcidr ${LANNET} &> /dev/null
[ $? != 0 ] && echo "[NETCONF] ERROR: DHCP range start '$DHCP_RANGE_START' does not belong to subnet '${LANNET}'" && ERROR_COUNT=$((ERROR_COUNT + 1))
echo $DHCP_RANGE_END | grepcidr ${LANNET} &> /dev/null
[ $? != 0 ] && echo "[NETCONF] ERROR: DHCP range end '$DHCP_RANGE_END' does not belong to subnet '${LANNET}'" && ERROR_COUNT=$((ERROR_COUNT + 1))

# Check that the fixed IPs belong to the subnet and host/ip are not reused
HOSTLIST="%"
for FixedIP in $FIXED_IPS; do
  MAC=$(echo $FixedIP | rev | cut -d':' -f3- | rev )
  IP=$(echo $FixedIP | rev | cut -d':' -f2 | rev )
  NAME=$(echo $FixedIP | rev | cut -d':' -f1 | rev )
  set +e
  echo $IP | grepcidr ${LANNET} &> /dev/null
  [ $? != 0 ] && echo "[NETCONF] ERROR: Fixed IP '$IP' (for host '$NAME') does not belong to subnet '${LANNET}'" && ERROR_COUNT=$((ERROR_COUNT + 1))
  set -e
  case $HOSTLIST in
    *"%$IP%"*)
      echo "[NETCONF] ERROR: IP '$IP' is already used (hostname : $NAME)" && ERROR_COUNT=$((ERROR_COUNT + 1))
      ;;
    *"%$NAME%"*)
      echo "[NETCONF] ERROR: Hostname '$NAME' is already used (IP : $IP)" && ERROR_COUNT=$((ERROR_COUNT + 1))
      ;;
  esac
  HOSTLIST+="$IP%$NAME%"
done

# Check that DNS are reachable
case $DNS_LIST in
  "")
    echo "[NETCONF] WARNING: No DNS specified, falling back to system default"
    set +eu +o pipefail
    DNS_LIST=$(cat /etc/resolv.conf | grep nameserver | cut -d' ' -f2 | xargs)
    set -eu -o pipefail
    ;;
esac
for dns in $DNS_LIST; do
  set +e
  ping -c 1 $dns &> /dev/null
  RES=$?
  set -e
  [ $RES != 0 ] && echo "[NETCONF] ERROR: Could not ping DNS '$dns'." && ERROR_COUNT=$((ERROR_COUNT + 1))
done

# check nat config
# - Hosts are in the fixed ip list
# - not outside port reuse
# - ports are 1-65535
OUTSIDE_PORTS_USED="%"
for NAT_RULE in $NAT_LIST; do
  HOST=$(echo $NAT_RULE | cut -d'#' -f1 )
  # echo $HOST :
  case $HOSTLIST in
    *"%$HOST%"*) : ;;
    *)
      echo "[NETCONF] ERROR: Host '$HOST' in NAT rules list does not have fixed IP" && ERROR_COUNT=$((ERROR_COUNT + 1))
      ;;
  esac
  for portmap in $(echo $NAT_RULE | cut -d'#' -f2- | tr "#" "\n"); do
    OUTSIDE_RANGE=$(echo $portmap | cut -d':' -f1)
    case $OUTSIDE_RANGE in
      *[0-9]-[0-9]*) : ;;
      *)
        [ $OUTSIDE_RANGE -lt 1 ] && \
          echo "[NETCONF] ERROR: '$OUTSIDE_RANGE' is outside TCP range for host $HOST" && ERROR_COUNT=$((ERROR_COUNT + 1)) && continue
        OUTSIDE_RANGE="${OUTSIDE_RANGE}-${OUTSIDE_RANGE}"
        ;;
    esac
    for port in $(seq $(echo $OUTSIDE_RANGE | tr '-' ' ')); do
      case $OUTSIDE_PORTS_USED in
        *"%$port%"*)
          echo "[NETCONF] ERROR: Outside port '$port' is mapped several times" && ERROR_COUNT=$((ERROR_COUNT + 1))
          ;;
      esac
      [ $port -gt 65535 ] && \
        echo "[NETCONF] ERROR: '$port' is outside TCP range for host $HOST" && ERROR_COUNT=$((ERROR_COUNT + 1)) && continue
    done
    OUTSIDE_PORTS_USED+="$(seq $(echo $OUTSIDE_RANGE | tr '-' ' ') | xargs | sed 's/ /%/g')%"

    INSIDE_RANGE=$(echo $portmap | cut -d':' -f2)
    case $INSIDE_RANGE in
      "") INSIDE_RANGE=$OUTSIDE_RANGE ;;
      *[0-9]-[0-9]*) : ;;
      *)
        [ $INSIDE_RANGE -lt 1 ] && \
          echo "[NETCONF] ERROR: '$INSIDE_RANGE' is outside TCP range for host $HOST" && ERROR_COUNT=$((ERROR_COUNT + 1)) && continue
        INSIDE_RANGE="${INSIDE_RANGE}-${INSIDE_RANGE}"
        ;;
    esac
    for port in $(seq $(echo $INSIDE_RANGE | tr '-' ' ')); do
      [ $port -gt 65535 ] && \
        echo "[NETCONF] ERROR: '$port' is outside TCP range for host $HOST" && ERROR_COUNT=$((ERROR_COUNT + 1)) && continue
    done
    OUTSIDE_PORT_COUNT=$(seq $(echo $OUTSIDE_RANGE | tr '-' ' ') | wc -l)
    INSIDE_PORT_COUNT=$(seq $(echo $INSIDE_RANGE | tr '-' ' ') | wc -l)
    [ $INSIDE_PORT_COUNT != $OUTSIDE_PORT_COUNT ] && \
      echo "[NETCONF] ERROR: Outside '$OUTSIDE_RANGE' and inside '$INSIDE_RANGE' port range have different count for host $HOST" && \
      ERROR_COUNT=$((ERROR_COUNT + 1))
    # echo " >> $OUTSIDE_RANGE > $INSIDE_RANGE"
  done
done

############################################################################################
## Epilog
############################################################################################

case $ERROR_COUNT in
  0)
    echo "[NETCONF] Checks passed."
    ;;
  *)
    echo "[NETCONF] Detected $ERROR_COUNT errors, aborting."
    exit 1
    ;;
esac

exit 0
