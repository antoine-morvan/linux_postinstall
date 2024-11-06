#!/usr/bin/env bash
set -eu -o pipefail

############################################################################################
## Load config
############################################################################################

source config.sh

############################################################################################
## Generate DHCP config files
############################################################################################

DHCP_FOLDER=./gen.dhcp/
mkdir -p $DHCP_FOLDER
DHCPD_FILE=${DHCP_FOLDER}/dhcpd.conf
DHCPD_DEFAULT=${DHCP_FOLDER}/isc-dhcp-server

# case $GEN_CONFIG in
#   YES) 
#     DHCPD_FILE=./dhcpd.conf
#     DHCPD_DEFAULT=./isc-dhcp-server
#     ;;
#   *)   
#     DHCPD_FILE=/etc/dhcp/dhcpd.conf
#     DHCPD_DEFAULT=/etc/default/isc-dhcp-server
#     ;;
# esac

cat > ${DHCPD_DEFAULT} << EOF
INTERFACESv4="${LANIFACE}"
EOF
cat > ${DHCPD_FILE} << EOF
option domain-name ${DOMAIN_NAME};
option domain-name-servers ${SERVERLANIP};
default-lease-time 3600;
max-lease-time 48000;
authoritative;
ddns-update-style none;

subnet ${LANNET%/*} netmask ${LANMASK} {
  range ${DHCP_RANGE_START} ${DHCP_RANGE_END};
  option routers ${SERVERLANIP};
}

EOF

for FixedIP in $FIXED_IPS; do
  MAC=$(echo $FixedIP | rev | cut -d':' -f3- | rev )
  IP=$(echo $FixedIP | rev | cut -d':' -f2 | rev )
  NAME=$(echo $FixedIP | rev | cut -d':' -f1 | rev )
  cat >> ${DHCPD_FILE} << EOF
host $NAME {
        hardware ethernet $MAC;
        fixed-address $IP;
        option dhcp-client-identifier "$NAME";
        option host-name "$NAME";
}
EOF
done

############################################################################################
## Exit
############################################################################################
echo "[NETCONF] INFO: Generate DHCP Done."
exit 0
