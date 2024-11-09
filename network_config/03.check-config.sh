#!/usr/bin/env bash
set -eu -o pipefail

ERROR_COUNT=0

############################################################################################
## Config file checks
############################################################################################

echo "[NETCONF] INFO: Load config."
source config.sh

echo "[NETCONF] INFO: Load config."
############################################################################################
## System Checks
############################################################################################

# Check that the distro is supported
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
## Config content checks
############################################################################################

set +e
cat /etc/passwd | grep ^${SUDOUSER}: &> /dev/null
RES=$?
set -e
[ $RES != 0 ] && echo "[NETCONF] ERROR: user '${SUDOUSER}' does not exist in '/etc/passwd'." && ERROR_COUNT=$((ERROR_COUNT + 1))

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

# function to convert an IP address to an integer*
# from https://unix.stackexchange.com/a/563674
function int_ip() {
    OIFS=$IFS
    IFS='.'
    ip=($1)
    IFS=$OIFS
    echo "${ip[0]} * 256 ^ 3 + ${ip[1]} * 256 ^2 + ${ip[2]} * 256 ^1 + ${ip[3]} * 256 ^ 0" | bc
}

DHCP_RANGE_MIN=$(int_ip $DHCP_RANGE_START)
DHCP_RANGE_MAX=$(int_ip $DHCP_RANGE_END)

# Check that the fixed IPs belong to the subnet and host/ip are not reused
HOSTLIST="%"
for FixedIP in $FIXED_IPS; do
  MAC=$(echo $FixedIP | rev | cut -d':' -f3- | rev )
  IP=$(echo $FixedIP | rev | cut -d':' -f2 | rev )
  NAME=$(echo $FixedIP | rev | cut -d':' -f1 | rev )
  set +e
  echo $IP | grepcidr ${LANNET} &> /dev/null
  [ $? != 0 ] && echo "[NETCONF] ERROR: Fixed IP '$IP' does not belong to subnet '${LANNET}' (for host '$NAME')" && ERROR_COUNT=$((ERROR_COUNT + 1))
  set -e


  IP_VALUE=$(int_ip $IP)
  if [ $IP_VALUE -ge $DHCP_RANGE_MIN ] && [ $IP_VALUE -le $DHCP_RANGE_MAX ]; then
    echo "[NETCONF] ERROR: Fixed IP '$IP' is within the DHCP range ${DHCP_RANGE_START}-${DHCP_RANGE_END} (for host '$NAME')" && ERROR_COUNT=$((ERROR_COUNT + 1))
  fi

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
    PROTO=$(echo $portmap | cut -d'/' -f2)
    case $PROTO in
      [0-9]*) : ;; # no proto specified, cut returns the port
      u|udp|U|UDP|Udp) PROTO=udp ;;
      t|tcp|T|TCP|Tcp) PROTO=tcp ;;
      *)
        echo "[NETCONF] ERROR: Unknown protocol '$PROTO' for host $HOST NAT rule '$portmap'" && ERROR_COUNT=$((ERROR_COUNT + 1))
        ;;
    esac
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
      [ $port -eq 22 ] && \
        echo "[NETCONF] ERROR: '$port' is reserved" && ERROR_COUNT=$((ERROR_COUNT + 1)) && continue
    done
    OUTSIDE_PORTS_USED+="$(seq $(echo $OUTSIDE_RANGE | tr '-' ' ') | xargs | sed 's/ /%/g')%"

    INSIDE_RANGE=$(echo $portmap | cut -d':' -f2 | cut -d'/' -f1)
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
## Check firewall capabilities
############################################################################################

echo "[NETCONF] INFO: Testing nat_ftp modules"
# Test for nf_nat_ftp modules
set +e
lsmod | grep "nf_nat_ftp" &> /dev/null
RES=$?
set -e
if [ $RES != 0 ]; then
  # if not loaded, try to load them
  set +e
  modprobe nf_nat_ftp
  RES=$?
  set -e
  if [ $RES != 0 ]; then
    echo "[NETCONF] ERROR: module not loaded with current setup and not loadable."
    echo "[NETCONF] INFO: Consider adding this to /etc/modules :"
cat << EOF2
cat >> /etc/modules << EOF
nf_nat_ftp
nf_conntrack_ftp
EOF
EOF2
  else
    echo "[NETCONF] INFO: module not loaded with current setup but loadable."
  fi
else
  echo "[NETCONF] INFO: module loaded with current setup."
fi

############################################################################################
## Epilog
############################################################################################

case $ERROR_COUNT in
  0)
    echo "[NETCONF] INFO: Checks passed."
    ;;
  *)
    echo "[NETCONF] ERROR: Detected $ERROR_COUNT errors, aborting."
    exit 1
    ;;
esac

exit 0
