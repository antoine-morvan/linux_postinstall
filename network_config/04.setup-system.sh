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
## Setup interfaces
############################################################################################

set +e
type -f nmcli &> /dev/null
RES=$?
set -e
if [ $RES == 0 ]; then
  nmcli con add \
    con-name "static-$LANIFACE" \
    ifname $LANIFACE \
    type ethernet \
    ip4 $SERVERLANIP/$(echo $LANNET | cut -d'/' -f2)
else
  case ${ID_LIKE:-${ID}} in
      *debian*|*ubuntu*)
        # TODO : edit /etc/network/interfaces
        perl -0777 -i.original -pe 's///g' /etc/network/interfaces
        cat > /etc/network/interfaces.d/$LANIFACE << EOF
auto $LANIFACE
allow-hotplug $LANIFACE
iface $LANIFACE inet static
        address $SERVERLANIP/$(echo $LANNET | cut -d'/' -f2)
EOF
          ;;
      *fedora*|*rhel*)
          # TODO : edit /etc/sysconfig/network-scripts/ifcfg-$LANIFACE
          echo "ERROR: unsupported yet"
          exit 1
          ;;
  esac



## set lan iface IP
case $GEN_CONFIG in
  YES) INTERFACES_FILE=./interfaces             ;;
  *)   INTERFACES_FILE=/etc/network/interfaces  ;;
esac
cat >> ${INTERFACES_FILE} << EOF
auto ${WEBIFACE}
allow-hotplug ${WEBIFACE}
iface ${WEBIFACE} inet dhcp

auto ${LANIFACE}
iface ${LANIFACE} inet static
  address ${SERVERLANIP}
  netmask ${LANMASK}
  network ${LANNETADDRESS}
  broadcast ${LANBROADCAST}
EOF

## Set dhclient to use proper domain & name server
case $GEN_CONFIG in
  YES) DHCLIENT_FILE=./dhclient.conf          ;;
  *)   DHCLIENT_FILE=/etc/dhcp/dhclient.conf  ;;
esac
cat >> ${DHCLIENT_FILE} << EOF
supersede domain-name "$DOMAIN_NAME";
prepend domain-name-servers 127.0.0.1;
EOF

exit 0
