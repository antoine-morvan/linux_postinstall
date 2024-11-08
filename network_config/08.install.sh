#!/usr/bin/env bash
set -eu -o pipefail

############################################################################################
## Load config
############################################################################################

# [ "$(whoami)" != root ] && echo "[NETCONF] ERROR: must run as root" && exit 1
source config.sh


FIREWALL_FOLDER=./gen.firewall
BIND_FOLDER=./gen.bind
DHCP_FOLDER=./gen.dhcp

TARGET_DHCP=/etc/dhcp/
TARGET_BIND=/etc/bind/
TARGET_FIREWALL=/usr/

[ -d $DHCP_FOLDER ] && (
    DHCPD_FILE=/etc/dhcp/dhcpd.conf
    DHCPD_DEFAULT=/etc/default/isc-dhcp-server

    cp $DHCP_FOLDER/dhcpd.conf ${DHCPD_FILE}
    cp $DHCP_FOLDER/isc-dhcp-server ${DHCPD_DEFAULT}
)
[ -d $BIND_FOLDER ] && (
    cp $BIND_FOLDER/named.conf.options ${TARGET_BIND}
    cp $BIND_FOLDER/named.conf.local ${TARGET_BIND}
    cp $BIND_FOLDER/db.${DOMAIN_NAME} ${TARGET_BIND}
    cp $BIND_FOLDER/db.[0-9]* ${TARGET_BIND}
)
[ -d $FIREWALL_FOLDER ] && (
    cp $FIREWALL_FOLDER/* $TARGET_FIREWALL
)

############################################################################################
## Done
############################################################################################
exit 0
