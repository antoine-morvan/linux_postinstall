#!/usr/bin/env bash
set -eu -o pipefail

###
### TODO
###  * cleanup squid config
###  * add mechanism to prepare a list of local hosts (name:ip:mac)

## 
## sample post install script to configure a debian gateway with
## a dhcp, bind9 DNS, and transparent squid proxy caching big files.
## 
## tested on debian 12 x86-64
## 

## Bootstrap script :
###########################
# #!/usr/bin/env bash
# set -eu -o pipefail
# wget --no-cache https://raw.githubusercontent.com/antoine-morvan/linux_postinstall/master/distros/debian12GW.sh -O debian12GW.sh
# chmod +x debian12GW.sh
# ./debian12GW.sh
###########################

###########################
##### CONFIG
###########################

# the iface of the "outside"
WEBIFACE=enp0s3
# the iface of the LAN it will serve
LANIFACE=enp0s8

# network and mask of the LAN
LANNET=172.31.250.0/24
# list of DNS IPs to use when forwarding DNS requests from LAN
OPENDNS_LIST="208.67.222.222 208.67.220.220"
GOOGLE_LIST="8.8.8.8 8.8.4.4"
CLOUDFARE_LIST="1.1.1.1 1.0.0.1"
VERISIGN_LIST="64.6.64.6 64.6.65.6"
QUAD9_LIST="9.9.9.9 149.112.112.112"
EXTERNALDNSLIST="$OPENDNS_LIST $GOOGLE_LIST $CLOUDFARE_LIST $VERISIGN_LIST $QUAD9_LIST"
# number of IP addresses to save free from DHCP range
FIXEDADDRCOUNT=32
# minimum size of the DHCP range
MINGUESTIPS=50

# format: localname:ip:MACaddress
# TODO read from external to not disclose personal data here ?
FIXED_IPS=" \

"


# Squid settings
WEBCACHE_PORT=3128
WEBCACHE_PORT_INTERCEPT=3127
WEBCACHE_OBJMAXSIZE=512 #MB
WEBCACHE_SIZE=20000 #MB
WEBCACHE_PATH="/mnt/squidcache/"

###########################
##### SETUP
###########################

[ "$(whoami)" != "root" ] && echo "Error: need to be executed as root" && exit 1

## update
apt update
apt upgrade -y
apt dist-upgrade -y
apt autoremove -y
apt clean

## install deps
apt install -y bind9 isc-dhcp-server squid ipcalc bwm-ng iptraf nethogs byobu sudo htop iptables

echo ""
echo "Apt done."
echo ""

###########################
##### Setup Users
###########################

echo " -- Fix permissions"
## make general users part of sudo group (usually just the user added during setup)
l=$(grep "^UID_MIN" /etc/login.defs)
l1=$(grep "^UID_MAX" /etc/login.defs)
USERS=$(awk -F':' -v "min=${l##UID_MIN}" -v "max=${l1##UID_MAX}" '{ if ( $3 >= min && $3 <= max ) print $1}' /etc/passwd)
for USR in $USERS; do
  usermod -a -G sudo $USR
done

###########################
##### Setup Users
###########################

## calculate LAN addresses
LANMINIP=$(ipcalc -n -b ${LANNET} | grep HostMin | xargs | cut -d" " -f2)
LANMAXIP=$(ipcalc -n -b ${LANNET} | grep HostMax | xargs | cut -d" " -f2)
LANMASK=$(ipcalc -n -b ${LANNET} | grep Netmask | xargs | cut -d" " -f2)
LANBROADCAST=$(ipcalc -n -b ${LANNET} | grep Broadcast | xargs | cut -d" " -f2)
LANNETADDRESS=$(ipcalc -n -b ${LANNET} | grep Network | xargs | cut -d" " -f2 | cut -d"/" -f1)
LANHOSTCOUNT=$(ipcalc -n -b ${LANNET} | grep Hosts | xargs | cut -d" " -f2)

MINREQHOSTS=$((FIXEDADDRCOUNT + MINGUESTIPS + 1))
[ $LANHOSTCOUNT -le $MINREQHOSTS ] && echo "Error : network size is too small. Change netmask." && exit 1

SERVERLANIP=${LANMAXIP}

###########################
##### Setup interfaces
###########################

## set lan iface IP
cat >> /etc/network/interfaces << EOF
allow-hotplug ${LANIFACE}
iface ${LANIFACE} inet static
  address ${SERVERLANIP}
  netmask ${LANMASK}
  network ${LANNETADDRESS}
  broadcast ${LANBROADCAST}
EOF

###########################
##### Setup DHCP
###########################

## enable DHCPd on lan iface
sed -i -r "s/^(INTERFACESv4=).*/\1\"${LANIFACE}\"/g" /etc/default/isc-dhcp-server

## set DHCPd config
sed -i -r "s/^(option domain-name .*)/#\1/g" /etc/dhcp/dhcpd.conf
sed -i -r "s/^(option domain-name-servers)(.*)/\1 ${SERVERLANIP};/g" /etc/dhcp/dhcpd.conf

sed -i -r "s/^#authoritative;/authoritative;/g" /etc/dhcp/dhcpd.conf

## calculate DHCP range
HOSTRANGEMIN=$(echo ${LANMINIP} | cut -d'.' -f4)
HOSTRANGEMIN=$((HOSTRANGEMIN+FIXEDADDRCOUNT))
HOSTRANGEMAX=$(echo ${LANMAXIP} | cut -d'.' -f4)
HOSTRANGEMAX=$((HOSTRANGEMAX - 1))
DHCPRANGESTARTIP=$(echo ${LANNETADDRESS} | cut -d'.' -f1-3).${HOSTRANGEMIN}
DHCPRANGESTOPIP=$(echo ${LANNETADDRESS} | cut -d'.' -f1-3).${HOSTRANGEMAX}

cat >> /etc/dhcp/dhcpd.conf << EOF
subnet ${LANNETADDRESS} netmask ${LANMASK} {
  range ${DHCPRANGESTARTIP} ${DHCPRANGESTOPIP};
  option routers ${SERVERLANIP};
}
EOF

###########################
##### Setup DNS
###########################

## setup DNS

cat > /etc/bind/named.conf.options << EOF
options {
  directory "/var/cache/bind";

  recursion yes;
  allow-query { any; };
  allow-recursion { any; };

  forwarders {
EOF
for dns in $EXTERNALDNSLIST; do
cat >> /etc/bind/named.conf.options << EOF
    $dns;
EOF
done
cat >> /etc/bind/named.conf.options << EOF
  };

  dnssec-validation auto;

  auth-nxdomain no;
  listen-on-v6 { any; };
  listen-on { any; };
};
EOF

###########################
##### Setup Proxy
###########################

echo " -- Stop squid"
# stop squid before updating config
systemctl stop squid

cat > /etc/squid/squid.conf << EOF
acl manager proto cache_object
acl localnet src ${LANNET}       # RFC1918 possible internal network
acl SSL_ports port 443          # https
acl Safe_ports port 80          # http
acl Safe_ports port 21          # ftp
acl Safe_ports port 443         # https
acl purge method PURGE
acl CONNECT method CONNECT
http_access deny manager
http_access deny purge
http_access deny !Safe_ports
http_access deny CONNECT !SSL_ports
http_access allow localhost
http_access allow localnet
icp_access allow localnet
icp_access deny all
http_port $WEBCACHE_PORT
http_port $WEBCACHE_PORT_INTERCEPT intercept
access_log /var/log/squid/access.log squid
acl shoutcast rep_header X-HTTP09-First-Line ^ICY.[0-9]
acl apache rep_header Server ^Apache
hosts_file /etc/hosts
coredump_dir /var/spool/squid

acl windowsupdate dstdomain windowsupdate.microsoft.com
acl windowsupdate dstdomain .update.microsoft.com
acl windowsupdate dstdomain download.windowsupdate.com
acl windowsupdate dstdomain redir.metaservices.microsoft.com
acl windowsupdate dstdomain images.metaservices.microsoft.com
acl windowsupdate dstdomain c.microsoft.com
acl windowsupdate dstdomain www.download.windowsupdate.com
acl windowsupdate dstdomain wustat.windows.com
acl windowsupdate dstdomain crl.microsoft.com
acl windowsupdate dstdomain sls.microsoft.com
acl windowsupdate dstdomain productactivation.one.microsoft.com
acl windowsupdate dstdomain ntservicepack.microsoft.com

# windows update files
refresh_pattern -i \.(cab|exe|ms[i|u|f]|[ap]sf|wm[v|a]|dat|zip)       4320 80% 129600 reload-into-ims

# pictures
refresh_pattern -i \.(gif|png|jpg|jpeg|ico)\$ 10080 90% 43200 override-expire ignore-no-cache ignore-no-store ignore-private
# medias
refresh_pattern -i \.(iso|avi|mkv|flac|wav|mp3|mp4|mpeg|swf|flv|x-flv)\$ 43200 90% 432000 override-expire ignore-no-cache ignore-no-store ignore-private
# packages & binaries
refresh_pattern -i \.(udeb|deb|drpm|rpm|exe|bin|ppt|doc|tiff)\$ 10080 90% 43200 override-expire ignore-no-cache ignore-no-store ignore-private
# archives
refresh_pattern -i \.(zip|tar|jar|tgz|ram|rar|gz|xz|bz2|7z)\$ 10080 90% 43200 override-expire ignore-no-cache ignore-no-store ignore-private

# distros packages & sources
refresh_pattern pkg\.tar\.xz\$   0       20%     4320 refresh-ims
refresh_pattern Packages\.bz2\$  0       20%     4320 refresh-ims
refresh_pattern Sources\.bz2\$   0       20%     4320 refresh-ims
refresh_pattern Release\.gpg\$   0       20%     4320 refresh-ims
refresh_pattern Release\$        0       20%     4320 refresh-ims
refresh_pattern (Release|Packages(.gz)*)\$       0       20%     2880
refresh_pattern \.pkg\.tar\.            0       20%     129600  reload-into-ims
refresh_pattern \.tar(\.bz2|\.gz|\.xz)\$              0       20%     129600  reload-into-ims
refresh_pattern Packages.gz\$            0       100%    129600  reload-into-ims

# general
refresh_pattern ^ftp:          1440    20%     10080
refresh_pattern ^gopher:       1440    0%      1440
refresh_pattern -i youtube.com/.* 10080 90% 43200
refresh_pattern -i (/cgi-bin/|\?) 0    0%      0
refresh_pattern . 0 40% 40320


maximum_object_size ${WEBCACHE_OBJMAXSIZE} MB
range_offset_limit -1 windowsupdate
quick_abort_min -1

cache_dir aufs ${WEBCACHE_PATH} ${WEBCACHE_SIZE} 16 256

shutdown_lifetime 5 seconds

EOF

echo " -- Clear squid cache"
# clear cache path
rm -rf ${WEBCACHE_PATH}/*
mkdir -p ${WEBCACHE_PATH}
chown proxy:proxy ${WEBCACHE_PATH}
echo " -- Init squid cache && sleep 5s"
# init cache structure
squid -z

sleep 5

echo " -- Start squid"
systemctl start squid

echo " -- Check squid"
squid -k check


###########################
##### Setup Firewall
###########################

cat > /usr/sbin/firewall_router.down.sh << EOF
#!/usr/bin/env bash
set -eu -o pipefail

###
### Disable Routing
###

echo 0 > /proc/sys/net/ipv4/ip_forward

modprobe -r ip_nat_ftp
modprobe -r ip_conntrack_ftp

###
### IPTable restore
###

# sets defaults
RULES_FILE=/etc/iptables.defaults.rules
if [ -f \$RULES_FILE ]; then
  /usr/sbin/iptables -F
  /usr/sbin/iptables-restore  < \$RULES_FILE
else
  echo "Warning: no iptable rules were found under '\$RULES_FILE'"
fi

###
### Security Tuning
###

# Keep security tuning if set

EOF
cat > /usr/sbin/firewall_router.up.sh << EOF
#!/usr/bin/env bash
set -eu -o pipefail

###
### Enable Routing
###

echo 1 > /proc/sys/net/ipv4/ip_forward

modprobe ip_nat_ftp
modprobe ip_conntrack_ftp

###
### IPTable restore
###

# sets firewall rules, enables NAT, transparent ftp/http redirect to proxy
RULES_FILE=/etc/iptables.rules
if [ -f \$RULES_FILE ]; then
  /usr/sbin/iptables -F
  /usr/sbin/iptables-restore  < \$RULES_FILE
else
  echo "Warning: no iptable rules were found under '\$RULES_FILE'"
fi

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

EOF

cat > /usr/lib/systemd/system/firewall_router.service << EOF
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

cat > /usr/sbin/firewall_router.iptables_gen.sh << EOF
#!/usr/bin/env bash
set -eu -o pipefail

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

# Transparent redirect HTTP to proxy
\$IPTABLES -t nat -A PREROUTING -p tcp -i \$ILAN --dport 80 -j REDIRECT --to-port $WEBCACHE_PORT_INTERCEPT
\$IPTABLES -t nat -A OUTPUT -p tcp --dport 80 -m owner --uid-owner proxy -j ACCEPT
\$IPTABLES -t nat -A OUTPUT -p tcp --dport 80 -j REDIRECT --to-ports $WEBCACHE_PORT_INTERCEPT

# Transparent redirect FTP to proxy
\$IPTABLES -t nat -A PREROUTING -p tcp -i \$ILAN --dport 21 -j REDIRECT --to-port $WEBCACHE_PORT_INTERCEPT
\$IPTABLES -t nat -A OUTPUT -p tcp --dport 21 -m owner --uid-owner proxy -j ACCEPT
\$IPTABLES -t nat -A OUTPUT -p tcp --dport 21 -j REDIRECT --to-ports $WEBCACHE_PORT_INTERCEPT

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

chmod +x /usr/sbin/firewall_router.iptables_gen.sh
chmod +x /usr/sbin/firewall_router.down.sh
chmod +x /usr/sbin/firewall_router.up.sh

# save default rules
/usr/sbin/iptables-save > /etc/iptables.defaults.rules
# configure iptables
/usr/sbin/firewall_router.iptables_gen.sh
# save rules
/usr/sbin/iptables-save > /etc/iptables.rules

systemctl enable firewall_router

###########################
##### Cleanup
###########################

SLEEP_TIME=5
echo -n "Rebooting in $SLEEP_TIME s "
for i in $(seq 1 $SLEEP_TIME); do echo -n "."; sleep 1; done
echo ""
echo "Rebooting"
reboot
