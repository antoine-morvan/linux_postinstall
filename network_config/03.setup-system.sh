#!/usr/bin/env bash
set -eu -o pipefail

# Check that we can source config
source config.sh

case ${ID_LIKE:-${ID}} in
    *debian*|*ubuntu*)
        usermod -aG sudo ${SUDOUSER}
        ;;
    *fedora*|*rhel*)
        usermod -aG wheel ${SUDOUSER}
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
