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

# Make user soduer
case ${ID_LIKE:-${ID}} in
    *debian*|*ubuntu*)
        usermod -aG sudo ${SUDOUSER}
        ;;
    *fedora*|*rhel*)
        usermod -aG wheel ${SUDOUSER}
        ;;
esac

# Lock root account
passwd -l root

############################################################################################
## Overide hostname
############################################################################################

PREV_HOSTNAME=$(hostname)
if [ "${HOSTNAME_OVERRIDE:-}" != "" ] && [ "${HOSTNAME_OVERRIDE:-}" != "${PREV_HOSTNAME}" ]; then
	echo "Override hostname from '$PREV_HOSTNAME' to '$HOSTNAME_OVERRIDE'"
	hostnamectl set-hostname $HOSTNAME_OVERRIDE
	sed -i "s/$PREV_HOSTNAME/$HOSTNAME_OVERRIDE/g" /etc/hosts
	export HOSTNAME=$HOSTNAME_OVERRIDE
fi

############################################################################################
## Setup interfaces
############################################################################################

set +e
type -f nmcli &> /dev/null
RES=$?
set -e
if [ $RES == 0 ]; then
  CONNECTION_NAME="static-$HOSTNAME-$LANIFACE"
  set +e
  nmcli con show $CONNECTION_NAME &> /dev/null
  RES=$?
  set -e
  # delete connection if existing
  if [ $RES == 0 ]; then
    nmcli con del $CONNECTION_NAME
  fi

  nmcli con add \
    con-name "static-gw-$LANIFACE" \
    ifname $LANIFACE \
    type ethernet \
    ip4 $SERVERLANIP/$(echo $LANNET | cut -d'/' -f2)
else
  case ${ID_LIKE:-${ID}} in
      *debian*|*ubuntu*)
        # Remove interface definition from /etc/network/interfaces
        tmpfile=$(mktemp)
        cp /etc/network/interfaces $tmpfile
        cat $tmpfile | \
            perl -0777 -pe "s/((allow-hotplug $LANIFACE\n)|(auto $LANIFACE\n))*iface $LANIFACE.*static.*\n((\s*address.*(\n)?)|(\s*netmask.*(\n)?)|(\s*gateway.*(\n)?)|(\s*network.*(\n)?)|(\s*broadcast.*(\n)?))*/# deleted $LANIFACE config\n/g" | \
            perl -0777 -pe "s/((allow-hotplug $LANIFACE\n)|(auto $LANIFACE\n))*iface $LANIFACE.*dhcp.*\n/# deleted $LANIFACE config\n/g" \
            > /etc/network/interfaces
        rm $tmpfile

        # Add interface definition
        cat >> /etc/network/interfaces << EOF
auto $LANIFACE
allow-hotplug $LANIFACE
iface $LANIFACE inet static
        address $SERVERLANIP/$(echo $LANNET | cut -d'/' -f2)
EOF
          ;;
      *fedora*|*rhel*)
          # TODO : edit /etc/sysconfig/network-scripts/ifcfg-$LANIFACE
          echo "ERROR: unsupported yet : non nmcli static ip settings"
          exit 1
          ;;
  esac
fi



exit 0

############################################################################################
## Archive
############################################################################################


case $GEN_CONFIG in
  YES) DHCLIENT_FILE=./dhclient.conf          ;;
  *)   DHCLIENT_FILE=/etc/dhcp/dhclient.conf  ;;
esac
cat >> ${DHCLIENT_FILE} << EOF
supersede domain-name "$DOMAIN_NAME";
prepend domain-name-servers 127.0.0.1;
EOF

exit 0
