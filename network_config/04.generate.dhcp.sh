#!/usr/bin/env bash
set -eu -o pipefail

# Check that we can source config
source config.sh

[ -f config.fixed_hosts.list ] && FIXED_IPS=$(cat config.fixed_hosts.list \
  | sed -r 's/#.*//g' | sed -r 's/\s+$//g' | grep -v "^#\|^\s*$" \
  | sed -r 's/\s+/:/g' | sed 's/\r/\n/g')
FIXED_IPS=${FIXED_IPS:-""}



case $GEN_CONFIG in
  YES) 
    DHCPD_FILE=./dhcpd.conf
    DHCPD_DEFAULT=./isc-dhcp-server
    ;;
  *)   
    DHCPD_FILE=/etc/dhcp/dhcpd.conf
    DHCPD_DEFAULT=/etc/default/isc-dhcp-server
    ;;
esac

case $GEN_CONFIG in
  YES)
    cat > ${DHCPD_DEFAULT} << EOF
INTERFACESv4="${LANIFACE}"
EOF
    cat > ${DHCPD_FILE} << EOF
option domain-name ${DOMAIN_NAME};
option domain-name-servers ${SERVERLANIP};
authoritative;
EOF
    ;;
  *)
    ## enable DHCPd on lan iface
    sed -i -r "s/^(INTERFACESv4=).*/\1\"${LANIFACE}\"/g" ${DHCPD_DEFAULT}

    ## set DHCPd config
    sed -i -r "s/^(option domain-name )(.*)/\1${DOMAIN_NAME};/g" ${DHCPD_FILE}
    sed -i -r "s/^(option domain-name-servers )(.*)/\1${SERVERLANIP};/g" ${DHCPD_FILE}
    sed -i -r "s/^#authoritative;/authoritative;/g" ${DHCPD_FILE}
    ;;
esac


cat >> ${DHCPD_FILE} << EOF
subnet ${LANNETADDRESS} netmask ${LANMASK} {
  range ${DHCPRANGESTARTIP} ${DHCPRANGESTOPIP};
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
