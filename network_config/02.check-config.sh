#!/usr/bin/env bash
set -eu -o pipefail

ERROR_COUNT=0

# Check that the distro is supported
[ ! -f /etc/os-release ] && echo "[NETCONF] ERROR: could not locate '/etc/os-release'" && exit 1
. /etc/os-release
case $ID_LIKE in
    *debian*|*ubuntu*) : ;;
    *fedora*|*rhel*) : ;;
    *)
        echo "[NETCONF] ERROR: unsupported distribution family $ID_LIKE"
        ERROR_COUNT=$((ERROR_COUNT + 1))
        ;;
esac

# Check that user is root
[ "$(whoami)" != root ] && echo "[NETCONF] ERROR: must run as root" && ERROR_COUNT=$((ERROR_COUNT + 1))

# Check that the config files are present
for file in \
  config.sh \
  config.dns.list \
  config.fixed_hosts.list \
  config.nat.list; do
    [ ! -f $file ] && echo "[NETCONF] ERROR: Could not locate '$file'" && exit 1
done

# Check that we can source config
source config.sh

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

# Check fixed host list parsability
[ -f config.fixed_hosts.list ] && FIXED_IPS=$(cat config.fixed_hosts.list \
  | sed -r 's/#.*//g' | sed -r 's/\s+$//g' | grep -v "^#\|^\s*$" \
  | sed -r 's/\s+/:/g' | sed 's/\r/\n/g')
FIXED_IPS=${FIXED_IPS:-""}

# Check that the fixed IPs belong to the subnet
for FixedIP in $FIXED_IPS; do
  MAC=$(echo $FixedIP | rev | cut -d':' -f3- | rev )
  IP=$(echo $FixedIP | rev | cut -d':' -f2 | rev )
  NAME=$(echo $FixedIP | rev | cut -d':' -f1 | rev )
  set +e
  echo $IP | grepcidr ${LANNET} &> /dev/null
  [ $? != 0 ] && echo "[NETCONF] ERROR: Fixed IP '$IP' (for host '$NAME') does not belong to subnet '${LANNET}'" && ERROR_COUNT=$((ERROR_COUNT + 1))
  set -e
done

#TODO : 
# check nat config (IPs are in the fixed ip list), ports are 1-65XXX, etc.

case $ERROR_COUNT in
  0)
    echo "[NETCONF] Checks passed."
    ;;
  *)
    echo "[NETCONF] Detected $ERROR_COUNT errors ; aborting."
    exit 1
    ;;
esac

exit 0
