#!/usr/bin/env bash
set -eu -o pipefail

############################################################################################
## Load config
############################################################################################

# [ "$(whoami)" != root ] && echo "[NETCONF] ERROR: must run as root" && exit 1
source config.sh
echo "[NETCONF] INFO    :: Install files"

FIREWALL_FOLDER=./gen.firewall
BIND_FOLDER=./gen.bind
DHCP_FOLDER=./gen.dhcp

TARGET_DHCP=/etc/dhcp
TARGET_BIND=/etc/bind
TARGET_FIREWALL_SCRIPTS=/usr/sbin
TARGET_FIREWALL_SERVICE=$(systemd-analyze --system unit-paths | grep lib/systemd | head -n 1)

[ -d $DHCP_FOLDER ] && (
    echo "[NETCONF] INFO    ::  - DHCP"
    DHCPD_FILE=/etc/dhcp/dhcpd.conf
    DHCPD_DEFAULT=/etc/default/isc-dhcp-server

    cp -v $DHCP_FOLDER/dhcpd.conf ${DHCPD_FILE}
    cp -v $DHCP_FOLDER/isc-dhcp-server ${DHCPD_DEFAULT}
)

[ -d $BIND_FOLDER ] && (
    echo "[NETCONF] INFO    ::  - DNS"
    cp -v $BIND_FOLDER/named.conf.options ${TARGET_BIND}
    cp -v $BIND_FOLDER/named.conf.local ${TARGET_BIND}
    cp -v $BIND_FOLDER/db.${DOMAIN_NAME} ${TARGET_BIND}
    cp -v $BIND_FOLDER/db.[0-9]* ${TARGET_BIND}
)

[ -d $FIREWALL_FOLDER ] && (
    echo "[NETCONF] INFO    ::  - Firewall"
    cp -v $FIREWALL_FOLDER/scripts/firewall_router.*.sh $TARGET_FIREWALL_SCRIPTS/
    chmod +x $TARGET_FIREWALL_SCRIPTS/firewall_router.*.sh

    mkdir -p $TARGET_FIREWALL_SERVICE/
    cp -v $FIREWALL_FOLDER/service/firewall_router.service $TARGET_FIREWALL_SERVICE/

    systemctl daemon-reload
    systemctl enable firewall_router
)

############################################################################################
## Exit
############################################################################################
echo "[NETCONF] INFO    :: Restart services with : "
echo "systemctl restart isc-dhcp-server"
echo "systemctl restart bind9"
echo "systemctl restart firewall_router"
echo "[NETCONF] INFO    :: Install files: Done."

exit 0
