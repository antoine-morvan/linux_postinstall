#!/usr/bin/env bash
set -eu -o pipefail

############################################################################################
## Load config
############################################################################################

# source config
[ -f config.sh ] && source config.sh
SUDOUSER=${SUDOUSER:-"admin"}
DOMAIN_NAME=${DOMAIN_NAME:-"mydomain"}
LANNET=${LANNET:-"192.168.30.0/24"}
SERVERLANIP=${SERVERLANIP:-"192.168.30.254"}
DHCP_RANGE=${DHCP_RANGE:-"192.168.30.100:192.168.30.200"}

[ ! -f /etc/os-release ] && echo "[NETCONF] ERROR: could not locate '/etc/os-release'" && exit 1
. /etc/os-release

############################################################################################
## Setup users
############################################################################################

echo "[NETCONF] INFO: setup user group"
# Make user soduer
case ${ID_LIKE:-${ID}} in
    *debian*|*ubuntu*)
        usermod -aG sudo ${SUDOUSER}
        ;;
    *fedora*|*rhel*)
        usermod -aG wheel ${SUDOUSER}
        ;;
esac

echo "[NETCONF] INFO: lock root"
# Lock root account
passwd -l root

############################################################################################
## Overide hostname
############################################################################################

PREV_HOSTNAME=$(hostname)
if [ "${HOSTNAME_OVERRIDE:-}" != "" ] && [ "${HOSTNAME_OVERRIDE:-}" != "${PREV_HOSTNAME}" ]; then
  echo "[NETCONF] INFO: Overide hostname (from $PREV_HOSTNAME to $HOSTNAME_OVERRIDE)"
	echo "Override hostname from '$PREV_HOSTNAME' to '$HOSTNAME_OVERRIDE'"
	hostnamectl set-hostname $HOSTNAME_OVERRIDE
	sed -i "s/$PREV_HOSTNAME/$HOSTNAME_OVERRIDE/g" /etc/hosts
	export HOSTNAME=$HOSTNAME_OVERRIDE
fi

############################################################################################
## Setup interfaces
############################################################################################

echo "[NETCONF] INFO: Setup lan interface"
set +e
type -f nmcli &> /dev/null
RES=$?
set -e
if [ $RES == 0 ]; then
  echo "[NETCONF] INFO:  - using nmcli"
  # Restart network manager in case it was updated
  echo "[NETCONF] INFO:  - restarting NetworkManager"
  systemctl restart NetworkManager
  CONNECTION_NAME="static-$HOSTNAME-$LANIFACE"
  set +e
  nmcli con show $CONNECTION_NAME &> /dev/null
  RES=$?
  set -e
  # delete connection if existing
  if [ $RES == 0 ]; then
    echo "[NETCONF] INFO:  - delete existing connection"
    nmcli con del $CONNECTION_NAME
  fi

  echo "[NETCONF] INFO:  - add new connection"
  nmcli con add \
    con-name "$CONNECTION_NAME" \
    ifname $LANIFACE \
    type ethernet \
    ip4 $SERVERLANIP/$(echo $LANNET | cut -d'/' -f2)
else
  case ${ID_LIKE:-${ID}} in
      *debian*|*ubuntu*)
        echo "[NETCONF] INFO:  - using /etc/network/interfaces"
        # Remove interface definition from /etc/network/interfaces
        echo "[NETCONF] INFO:  - Remove existing interface definition"
        tmpfile=$(mktemp)
        cp /etc/network/interfaces $tmpfile
        cat $tmpfile | \
            perl -0777 -pe "s/((allow-hotplug $LANIFACE\n)|(auto $LANIFACE\n))*iface $LANIFACE.*static.*\n((\s*address.*(\n)?)|(\s*netmask.*(\n)?)|(\s*gateway.*(\n)?)|(\s*network.*(\n)?)|(\s*broadcast.*(\n)?))*/# deleted $LANIFACE config\n/g" | \
            perl -0777 -pe "s/((allow-hotplug $LANIFACE\n)|(auto $LANIFACE\n))*iface $LANIFACE.*dhcp.*\n/# deleted $LANIFACE config\n/g" \
            > /etc/network/interfaces
        rm $tmpfile

        # Add interface definition
        echo "[NETCONF] INFO:  - Add interface definition"
        cat >> /etc/network/interfaces << EOF
auto $LANIFACE
allow-hotplug $LANIFACE
iface $LANIFACE inet static
        address $SERVERLANIP/$(echo $LANNET | cut -d'/' -f2)
EOF
          ;;
      *fedora*|*rhel*)
          # TODO : edit /etc/sysconfig/network-scripts/ifcfg-$LANIFACE
          echo "[NETCONF] INFO:  - using /etc/sysconfig/network-scripts/ifcfg-$LANIFACE"
          echo "[NETCONF] ERROR: unsupported yet : non nmcli static ip settings"
          exit 1
          ;;
  esac
fi

echo "[NETCONF] INFO:  - Fix DHCP client settings for DNS to search in new domain"
cat > /etc/dhcp/dhclient.conf << EOF
supersede domain-name "$DOMAIN_NAME";
prepend domain-search "$DOMAIN_NAME";
prepend domain-name-servers 127.0.0.1;
EOF

exit 0
