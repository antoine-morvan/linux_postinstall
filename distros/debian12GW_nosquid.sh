#!/usr/bin/env bash
set -eu -o pipefail

###################################################################################
##### TODO
##  * Switch back to script for iptables (more tedious to change rules with restore/save)
##  * Add network interfaces check early in the script ...
###################################################################################
## Sample post install script to configure a debian gateway with an ISC DHCP,
## bind9 DNS, IPTables with NAT and firewall, and transparent Squid proxy caching
## big files.
## 
## Tested on debian 12 x86-64
## Will not work on redhat: ipcalc implementation differs.
###################################################################################

###################################################################################
##### Bootstrap script :
###################################################################################
# #!/usr/bin/env bash
# set -eu -o pipefail
# wget --no-cache https://raw.githubusercontent.com/antoine-morvan/linux_postinstall/master/distros/debian12GW.sh -O debian12GW.sh
# chmod +x debian12GW.sh
# ./debian12GW.sh
###################################################################################

###################################################################################
##### Setup Configuration
###################################################################################

# the iface of the "outside"
WEBIFACE=eth0
# the iface of the LAN it will serve
LANIFACE=eth1

# network and mask of the LAN
DOMAIN_NAME=diablan
LANNET=172.29.255.0/24

# overide hostname: if set, change hostname
# HOSTNAME_OVERRIDE="gwtest"

###################################################################################
##### Static Configuration
###################################################################################

# list of DNS IPs to use when forwarding DNS requests from LAN

# Favor these 3
QUAD9_DNS_LIST="9.9.9.9 9.9.9.10"
CLOUDFARE_DNS_LIST="1.1.1.1 1.0.0.1"
OPENDNS_LIST="208.67.222.222 208.67.220.220"
# Can fallback on these
# CLOUDFARE_DNS_MALWARE_LIST="1.1.1.2 1.0.0.2"
# CLOUDFARE_DNS_MALWARE_ADULT_LIST="1.1.1.3 1.0.0.3"
# GOOGLE_PUBLIC_DNSLIST="8.8.8.8 8.8.4.4"
# VERISIGN_DNS_LIST="64.6.64.6 64.6.65.6"

set +eu +o pipefail
CURRENT_DNS=$(cat /etc/resolv.conf | grep nameserver | cut -d' ' -f2 | xargs)
set -eu -o pipefail
EXTERNALDNSLIST="$QUAD9_DNS_LIST $CLOUDFARE_DNS_LIST $OPENDNS_LIST $CURRENT_DNS"

# if address file fixed_hosts.list exists, will be read.
# example:
# 00:1c:bf:36:f9:5a	172.30.255.10	vostro-wifi
# 00:1c:23:ad:ee:8d	172.30.255.11	vostro-lan
[ -f fixed_hosts.list ] && FIXED_IPS=$(cat fixed_hosts.list \
  | sed -r 's/#.*//g' | sed -r 's/\s+$//g' | grep -v "^#\|^\s*$" \
  | sed -r 's/\s+/:/g' | sed 's/\r/\n/g')
FIXED_IPS=${FIXED_IPS:-""}

###################################################################################
##### System Setup
###################################################################################

# early check
[ ! -d /sys/class/net/$WEBIFACE ] && echo "[ERROR] Interface $WEBIFACE does not exist." && exit 1
[ ! -d /sys/class/net/$LANIFACE ] && echo "[ERROR] Interface $LANIFACE does not exist." && exit 1

GEN_CONFIG=NO
[ "${1:-}" == "--local-config-gen" ] && echo "[INFO] Generating configuration locally" && GEN_CONFIG=YES

echo "[INFO] Check user"
if [ "$GEN_CONFIG" != "YES" ]; then
  [ "$(whoami)" != "root" ] && echo "Error: need to be executed as root" && exit 1
fi
# extra groups to add normal users to
USER_EXTRA_GROUPS=sudo

###########################
##### Update && Install
###########################

if [ "$GEN_CONFIG" != "YES" ] && [ "${HOSTNAME_OVERRIDE:-}" != "" ]; then
	PREV_HOSTNAME=$(hostname)
	echo "Override hostname from '$PREV_HOSTNAME' to '$HOSTNAME_OVERRIDE'"
	hostnamectl set-hostname $HOSTNAME_OVERRIDE
	sed -i "s/$PREV_HOSTNAME/$HOSTNAME_OVERRIDE/g" /etc/hosts
	export HOSTNAME=$HOSTNAME_OVERRIDE
fi

echo "[INFO] Update system"
if [ "$GEN_CONFIG" != "YES" ]; then
  apt update
  apt upgrade -y
  apt dist-upgrade -y
  apt autoremove -y
  apt clean
fi

  echo "[INFO] Install required packages"
if [ "$GEN_CONFIG" != "YES" ]; then
  apt install -y bind9 isc-dhcp-server ipcalc prips grepcidr bwm-ng iptraf nethogs byobu sudo htop iptables ca-certificates curl tree rsync vim
fi

###########################
##### Compute LAN Adresses
###########################

FIXEDADDRCOUNT=$(echo $FIXED_IPS | wc -w)

## calculate LAN addresses
LANMINIP=$(ipcalc -n -b ${LANNET} | grep HostMin | xargs | cut -d" " -f2)
LANMAXIP=$(ipcalc -n -b ${LANNET} | grep HostMax | xargs | cut -d" " -f2)
LANMASK=$(ipcalc -n -b ${LANNET} | grep Netmask | xargs | cut -d" " -f2)
LANBROADCAST=$(ipcalc -n -b ${LANNET} | grep Broadcast | xargs | cut -d" " -f2)
LANNETADDRESS=$(ipcalc -n -b ${LANNET} | grep Network | xargs | cut -d" " -f2 | cut -d"/" -f1)
LANHOSTCOUNT=$(ipcalc -n -b ${LANNET} | grep Hosts | xargs | cut -d" " -f2)

SERVERLANIP=${LANMAXIP}

HOSTRANGEMIN=$(echo ${LANMINIP} | cut -d'.' -f4)
HOSTRANGEMAX=$(echo ${LANMAXIP} | cut -d'.' -f4)
HOSTRANGEMIN=$(( (HOSTRANGEMAX + HOSTRANGEMIN) / 2)) # keep half the subnet for static IPs
HOSTRANGEMAX=$((HOSTRANGEMAX - 5)) # keep 5 addresses at the end of the range for static services
DHCPRANGESTARTIP=$(echo ${LANNETADDRESS} | cut -d'.' -f1-3).${HOSTRANGEMIN}
DHCPRANGESTOPIP=$(echo ${LANNETADDRESS} | cut -d'.' -f1-3).${HOSTRANGEMAX}

echo "[INFO] Configuration"
echo "[INFO] min IP         : $LANMINIP"
echo "[INFO] max IP         : $LANMAXIP"
echo "[INFO] netmask        : $LANMASK"
echo "[INFO] broadcast      : $LANBROADCAST"
echo "[INFO] net address    : $LANNETADDRESS"
echo "[INFO] net host count : $LANHOSTCOUNT"

echo "[INFO] server IP      : $SERVERLANIP"
echo "[INFO] DHCP start     : $DHCPRANGESTARTIP"
echo "[INFO] DHCP stop      : $DHCPRANGESTOPIP"

# sanity check : verify that the new network does not overlap WAN network
IPWANMASK=$(ip addr show $WEBIFACE | grep -Po 'inet \K[\d./]+')
WANMINIP=$(ipcalc -n -b ${IPWANMASK} | grep HostMin | xargs | cut -d" " -f2)
WANMAXIP=$(ipcalc -n -b ${IPWANMASK} | grep HostMax | xargs | cut -d" " -f2)
WANIPLIST=$(mktemp)
LANIPLIST=$(mktemp)
prips $WANMINIP $WANMAXIP | sort > $WANIPLIST
prips $LANMINIP $LANMAXIP | sort > $LANIPLIST
CONFLICTING_IPs=$(comm -12 $WANIPLIST $LANIPLIST | wc -l)
[ $CONFLICTING_IPs -gt 0 ] && \
  comm -12 $WANIPLIST $LANIPLIST && \
  echo "[ERROR] Web network and Lan network have conflicting IPs." && \
  exit 1

###########################
##### Setup Users
###########################

echo "[INFO] Fix permissions"
## make general users (usually just the user added during setup) part of sudo and docker groups
l=$(grep "^UID_MIN" /etc/login.defs)
l1=$(grep "^UID_MAX" /etc/login.defs)
USERS=$(awk -F':' -v "min=${l##UID_MIN}" -v "max=${l1##UID_MAX}" '{ if ( $3 >= min && $3 <= max ) print $1}' /etc/passwd)
for USR in $USERS; do
  echo "[INFO]  - add $USER_EXTRA_GROUPS to $USR"
  if [ "$GEN_CONFIG" != "YES" ]; then
    usermod -a -G $USER_EXTRA_GROUPS $USR
  fi
done

###########################
##### Check configuration
###########################

echo "[INFO] Check configuration"

for FixedIP in $FIXED_IPS; do
  MAC=$(echo $FixedIP | rev | cut -d':' -f3- | rev )
  IP=$(echo $FixedIP | rev | cut -d':' -f2 | rev )
  NAME=$(echo $FixedIP | rev | cut -d':' -f1 | rev )
  set +e
  echo $IP | grepcidr ${LANNET} &> /dev/null
  RES=$?
  set -e
  [ $RES != 0 ] && echo "ERROR: $IP (for host $NAME) does not belong to subnet ${LANNET}" && exit 1
done

###########################
##### Setup interfaces
###########################

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

###################################################################################
##### DHCP Setup
###################################################################################

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

###################################################################################
##### DNS Setup
###################################################################################

echo "[INFO] Setup DNS"
## setup DNS

case $GEN_CONFIG in
  YES) BIND_FOLDER=.          ;;
  *)   BIND_FOLDER=/etc/bind/ ;;
esac

cat > ${BIND_FOLDER}/named.conf.options << EOF
options {
  directory "/var/cache/bind";

  recursion yes;
  allow-query { any; };
  allow-recursion { any; };
  allow-query-cache { any; };

  forwarders {
EOF

for dns in $EXTERNALDNSLIST; do
cat >> ${BIND_FOLDER}/named.conf.options << EOF
    $dns;
EOF
done
cat >> ${BIND_FOLDER}/named.conf.options << EOF
  };

  dnssec-validation auto;

  auth-nxdomain no;
  listen-on-v6 { any; };
  listen-on { any; };
};
EOF

cat >> ${BIND_FOLDER}/named.conf.local  << EOF

zone "${DOMAIN_NAME}" {
    type master;
    file "${BIND_FOLDER}/db.${DOMAIN_NAME}";
};

EOF
cat >> ${BIND_FOLDER}/db.${DOMAIN_NAME} << EOF
\$TTL    604800
@       IN      SOA     $HOSTNAME.$DOMAIN_NAME. root.$HOSTNAME.$DOMAIN_NAME. (
                              2         ; Serial
                         604800         ; Refresh
                          86400         ; Retry
                        2419200         ; Expire
                         604800 )       ; Negative Cache TTL
;
@       IN      NS      $HOSTNAME.$DOMAIN_NAME.
@       IN      A       127.0.0.1

localhost.$DOMAIN_NAME. IN A 127.0.0.1
$HOSTNAME.$DOMAIN_NAME. IN A ${SERVERLANIP}
;your sites
EOF

ZONES=""
# Add reverse for router
IP_ZONE=$(echo $SERVERLANIP |cut -d'.' -f-3)
LAST_DIGIT=$(echo $SERVERLANIP |cut -d'.' -f4)
ZONE_FILE=${BIND_FOLDER}/db.$IP_ZONE
if [ ! -f $ZONE_FILE ]; then
  ZONES+=" $IP_ZONE"
  cat > $ZONE_FILE << EOF
\$TTL    604800
@       IN      SOA     $HOSTNAME.$DOMAIN_NAME. root.$HOSTNAME.$DOMAIN_NAME. (
                            2         ; Serial
                        604800         ; Refresh
                        86400         ; Retry
                      2419200         ; Expire
                        604800 )       ; Negative Cache TTL
      NS      $HOSTNAME.$DOMAIN_NAME.
EOF
fi
echo "$LAST_DIGIT PTR $HOSTNAME.$DOMAIN_NAME." >> $ZONE_FILE

# Add reverse for fixed hosts
for FixedIP in $FIXED_IPS; do
  MAC=$(echo $FixedIP | rev | cut -d':' -f3- | rev )
  IP=$(echo $FixedIP | rev | cut -d':' -f2 | rev )
  NAME=$(echo $FixedIP | rev | cut -d':' -f1 | rev )
  echo "$NAME.$DOMAIN_NAME. IN A $IP" >> ${BIND_FOLDER}/db.${DOMAIN_NAME}

  IP_ZONE=$(echo $IP |cut -d'.' -f-3)
  LAST_DIGIT=$(echo $IP |cut -d'.' -f4)
  ZONE_FILE=${BIND_FOLDER}/db.$IP_ZONE
  if [ ! -f $ZONE_FILE ]; then
    ZONES+=" $IP_ZONE"
    cat > $ZONE_FILE << EOF
\$TTL    604800
@       IN      SOA     $HOSTNAME.$DOMAIN_NAME. root.$HOSTNAME.$DOMAIN_NAME. (
                              2         ; Serial
                         604800         ; Refresh
                          86400         ; Retry
                        2419200         ; Expire
                         604800 )       ; Negative Cache TTL
        NS      $HOSTNAME.$DOMAIN_NAME.
EOF
  fi
  echo "$LAST_DIGIT PTR $NAME.$DOMAIN_NAME." >> $ZONE_FILE
done

for ZONE in $ZONES; do
  ZONE_FILE=${BIND_FOLDER}/db.$IP_ZONE
  REV_ZONE=$(echo $ZONE | cut -d'.' -f3).$(echo $ZONE | cut -d'.' -f2).$(echo $ZONE | cut -d'.' -f1)
  cat >> ${BIND_FOLDER}/named.conf.local  << EOF
zone "${REV_ZONE}.in-addr.arpa" {
    type master;
    file "${ZONE_FILE}";
};
EOF
done

###################################################################################
##### Firewall Setup
###################################################################################

case $GEN_CONFIG in
  YES) 
    FIREWALL_FOLDER=.
    SYSTEMD_LIBRARY=.
    ;;
  *)
    FIREWALL_FOLDER=/usr/sbin/
    SYSTEMD_LIBRARY=/usr/lib/systemd/system
    ;;
esac

cat > ${FIREWALL_FOLDER}/firewall_router.down.sh << EOF
#!/usr/bin/env bash
set -eu -o pipefail

###
### Disable Routing
###

echo 0 > /proc/sys/net/ipv4/ip_forward

modprobe -r ip_nat_ftp
modprobe -r ip_conntrack_ftp

###
### Security Tuning
###

# Keep security tuning if set

###
### IPTable setup
###

IPTABLES=/usr/sbin/iptables
ILAN=$LANIFACE
IWAN=$WEBIFACE
ILO=lo
LAN=$LANNET
IPWAN=\$(ip addr show \$IWAN | grep -Po 'inet \K[\d.]+')

# Purge
\$IPTABLES -F
\$IPTABLES -X
\$IPTABLES -Z

\$IPTABLES -t filter -F INPUT
\$IPTABLES -t filter -F FORWARD
\$IPTABLES -t filter -F OUTPUT

\$IPTABLES -t nat -F PREROUTING
\$IPTABLES -t nat -F OUTPUT
\$IPTABLES -t nat -F POSTROUTING

# Default: drop
\$IPTABLES -t filter -P INPUT   DROP
\$IPTABLES -t filter -P FORWARD DROP
\$IPTABLES -t filter -P OUTPUT  DROP
\$IPTABLES -t nat -P PREROUTING  ACCEPT
\$IPTABLES -t nat -P OUTPUT      ACCEPT
\$IPTABLES -t nat -P POSTROUTING ACCEPT

# Allow loopback
\$IPTABLES -A INPUT -i \$ILO -j ACCEPT
\$IPTABLES -A OUTPUT -o \$ILO -j ACCEPT

# Drop invalid packets
\$IPTABLES -A INPUT   -m state --state INVALID -j DROP
\$IPTABLES -A OUTPUT  -m state --state INVALID -j DROP
\$IPTABLES -A FORWARD -m state --state INVALID -j DROP

# Allow answers
\$IPTABLES -A INPUT   -m state --state ESTABLISHED,RELATED -j ACCEPT
\$IPTABLES -A FORWARD -m state --state ESTABLISHED,RELATED -j ACCEPT
\$IPTABLES -A OUTPUT  -m state --state ESTABLISHED,RELATED -j ACCEPT

# Allow outgoing trafic from the router
\$IPTABLES -A OUTPUT -j ACCEPT

# Allow ping (in & out)
\$IPTABLES -A INPUT -p icmp --icmp-type echo-request -j ACCEPT
\$IPTABLES -A OUTPUT -p icmp --icmp-type echo-reply -j ACCEPT

# Allow SSH only, from anywhere
\$IPTABLES -A INPUT -m state --state NEW -p Tcp --dport 22 -j ACCEPT

EOF
cat > ${FIREWALL_FOLDER}/firewall_router.up.sh << EOF
#!/usr/bin/env bash
set -eu -o pipefail

###
### Enable Routing
###

echo 1 > /proc/sys/net/ipv4/ip_forward

modprobe ip_nat_ftp
modprobe ip_conntrack_ftp

###
### Security Tuning
###

# Enable broadcast echo protection
echo 1 > /proc/sys/net/ipv4/icmp_echo_ignore_broadcasts

# Enable TCP syn cookie protection
echo 1 > /proc/sys/net/ipv4/tcp_syncookies

# Store packets with impossible addresses
# Actually disabled
echo 0 > /proc/sys/net/ipv4/conf/all/log_martians

# Ignore ICMP bogus error responses
echo 1 > /proc/sys/net/ipv4/icmp_ignore_bogus_error_responses

# Enable IP spoofing protection
echo 1 > /proc/sys/net/ipv4/conf/all/rp_filter

# Disable ICMP redirects
echo 0 > /proc/sys/net/ipv4/conf/all/accept_redirects
echo 0 > /proc/sys/net/ipv4/conf/all/send_redirects

# Disable Source Routed
echo 0 > /proc/sys/net/ipv4/conf/all/accept_source_route

###
### IPTable setup
###

IPTABLES=/usr/sbin/iptables
ILAN=$LANIFACE
IWAN=$WEBIFACE
ILO=lo
LAN=$LANNET
IPWAN=\$(ip addr show \$IWAN | grep -Po 'inet \K[\d.]+')

# Purge
\$IPTABLES -F
\$IPTABLES -X
\$IPTABLES -Z

\$IPTABLES -t filter -F INPUT
\$IPTABLES -t filter -F FORWARD
\$IPTABLES -t filter -F OUTPUT

\$IPTABLES -t nat -F PREROUTING
\$IPTABLES -t nat -F OUTPUT
\$IPTABLES -t nat -F POSTROUTING

# Default: drop
\$IPTABLES -t filter -P INPUT   DROP
\$IPTABLES -t filter -P FORWARD DROP
\$IPTABLES -t filter -P OUTPUT  DROP
\$IPTABLES -t nat -P PREROUTING  ACCEPT
\$IPTABLES -t nat -P OUTPUT      ACCEPT
\$IPTABLES -t nat -P POSTROUTING ACCEPT

# Enable NAT
\$IPTABLES -t nat -A POSTROUTING -s \$LAN -o \$IWAN -j MASQUERADE

# Allow loopback
\$IPTABLES -A INPUT -i \$ILO -j ACCEPT
\$IPTABLES -A OUTPUT -o \$ILO -j ACCEPT

# Drop invalid packets
\$IPTABLES -A INPUT   -m state --state INVALID -j DROP
\$IPTABLES -A OUTPUT  -m state --state INVALID -j DROP
\$IPTABLES -A FORWARD -m state --state INVALID -j DROP

# Allow answers
\$IPTABLES -A INPUT   -m state --state ESTABLISHED,RELATED -j ACCEPT
\$IPTABLES -A FORWARD -m state --state ESTABLISHED,RELATED -j ACCEPT
\$IPTABLES -A OUTPUT  -m state --state ESTABLISHED,RELATED -j ACCEPT

# Allow outgoing trafic from the router
\$IPTABLES -A OUTPUT -j ACCEPT
\$IPTABLES -t nat -A OUTPUT -j ACCEPT

# Allow from LAN to routeur
\$IPTABLES -A INPUT -m state --state NEW -i \$ILAN -j ACCEPT
\$IPTABLES -A OUTPUT -m state --state NEW -o \$ILAN -j ACCEPT

# Allow FORWARD from LAN to WAN
\$IPTABLES -A FORWARD -m state --state NEW -i \$ILAN -o \$IWAN -j ACCEPT

# Allow FORWARD from LAN to LAN
\$IPTABLES -A FORWARD -m state --state NEW -i \$ILAN -o \$ILAN -j ACCEPT

# Allow ping (in & out)
\$IPTABLES -A INPUT -p icmp --icmp-type echo-request -j ACCEPT
\$IPTABLES -A OUTPUT -p icmp --icmp-type echo-reply -j ACCEPT

### GW bindings ###
\$IPTABLES -A INPUT -m state --state NEW -i \$IWAN -p Tcp --dport 22 -j ACCEPT # allow ssh
# \$IPTABLES -A INPUT -m state --state NEW -i \$IWAN -p Tcp --dport 2222 -j ACCEPT
# \$IPTABLES -A INPUT -m state --state NEW -i \$IWAN -p Tcp --dport 8080 -j ACCEPT

### NAT bindings ###

## Comment: Allow WAN on port \$PORT_WAN to reach \$IP on port \$PORT_LAN
## TODO: check if working ...
# IP=172.30.255.209
# PORT_WAN=49612
# PORT_LAN=49612
# \$IPTABLES -A FORWARD -d \$IP -p tcp --dport \$PORT_LAN -j ACCEPT
# \$IPTABLES -t nat -A PREROUTING -d \$IPWAN -p tcp --dport \$PORT_WAN -j DNAT --to-destination \$IP:\$PORT_LAN

## Comment: example with multiple ports/protocols
# \$IPTABLES -A FORWARD -d \$IP -p tcp --dport 27015:27032 -j ACCEPT
# \$IPTABLES -A FORWARD -d \$IP -p udp --dport 27015:27032 -j ACCEPT
# \$IPTABLES -t nat -A PREROUTING -d \$IPWAN -p tcp --dport \$PORT_WAN -j DNAT --to-destination \$IP
# \$IPTABLES -t nat -A PREROUTING -d \$IPWAN -p tcp --dport \$PORT_WAN -j DNAT --to-destination \$IP

EOF

cat > ${SYSTEMD_LIBRARY}/firewall_router.service << EOF
[Unit]
Description=Firewall
After=network.target

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/usr/sbin/firewall_router.up.sh
ExecStop=/usr/sbin/firewall_router.down.sh

[Install]
WantedBy=multi-user.target
EOF

if [ "$GEN_CONFIG" != "YES" ]; then
  chmod +x /usr/sbin/firewall_router.down.sh
  chmod +x /usr/sbin/firewall_router.up.sh

  systemctl enable firewall_router
fi

###################################################################################
##### Cleanup
###################################################################################

if [ "$GEN_CONFIG" != "YES" ]; then
  SLEEP_TIME=5
  echo -n "Rebooting in $SLEEP_TIME s "
  for i in $(seq 1 $SLEEP_TIME); do echo -n "."; sleep 1; done
  echo ""
  echo "Rebooting"
  reboot
fi
