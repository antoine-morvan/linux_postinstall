#!/bin/bash -eu

## 
## sample post install script to configure a debian gateway with
## a dhcp, bind9 DNS, and transparent squid proxy caching big files.
## 
## tested on debian 10 x86-64
## 

###########################
##### CONFIG
###########################

# the iface of the "outside"
WEBIFACE=ens33
# the iface of the LAN it will serve
LANIFACE=ens34
# network and mask of the LAN
LANNET=172.30.250.0/24
# list of DNS IPs to use when forwarding DNS requests from LAN
EXTERNALDNSLIST="8.8.8.8 8.8.4.4"
# number of IP addresses to save free from DHCP range
FIXEDADDRCOUNT=24
# minimum size of the DHCP range
MINGUESTIPS=10

WEBCACHE_OBJMAXSIZE=512 #MB
WEBCACHE_SIZE=20000 #MB
WEBCACHE_PATH="/mnt/squidcache/"

###########################
##### SETUP
###########################

## update
apt update
apt upgrade -y
apt dist-upgrade -y
apt autoremove -y
apt clean

## install deps
apt install -y bind9 isc-dhcp-server squid ipcalc bwm-ng iptraf nethogs byobu sudo htop

echo ""
echo "Apt done."
echo ""

## calculate LAN addresses
LANMINIP=$(ipcalc -n -b ${LANNET} | grep HostMin | xargs | cut -d" " -f2)
LANMAXIP=$(ipcalc -n -b ${LANNET} | grep HostMax | xargs | cut -d" " -f2)
LANMASK=$(ipcalc -n -b ${LANNET} | grep Netmask | xargs | cut -d" " -f2)
LANBROADCAST=$(ipcalc -n -b ${LANNET} | grep Broadcast | xargs | cut -d" " -f2)
LANNETADDRESS=$(ipcalc -n -b ${LANNET} | grep Network | xargs | cut -d" " -f2 | cut -d"/" -f1)
LANHOSTCOUNT=$(ipcalc -n -b ${LANNET} | grep Hosts | xargs | cut -d" " -f2)

MINREQHOSTS=$((FIXEDADDRCOUNT + MINGUESTIPS + 1))
[ $LANHOSTCOUNT -le $MINREQHOSTS ] && echo "Error : network size is too small." && exit 1

SERVERLANIP=${LANMAXIP}

## set lan iface IP
cat >> /etc/network/interfaces << EOF
allow-hotplug ${LANIFACE}
iface ${LANIFACE} inet static
  address ${SERVERLANIP}
  netmask ${LANMASK}
  network ${LANNETADDRESS}
  broadcast ${LANBROADCAST}
EOF

## enable DHCPd on lan iface
sed -i -r "s/^(INTERFACESv4=).*/\1\"${LANIFACE}\"/g" /etc/default/isc-dhcp-server

## set DHCPd config
sed -i -r "s/^(option domain-name .*)/#\1/g" /etc/dhcp/dhcpd.conf
sed -i -r "s/^(option domain-name-servers)(.*)/\1 ${SERVERLANIP};/g" /etc/dhcp/dhcpd.conf

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

## enable basic NAT & firewall

cat > /etc/init.d/firewall << EOF
#!/bin/sh

### BEGIN INIT INFO
# Provides:          iptables
# Required-Start:    \$network
# Required-Stop:     \$network
# Default-Start:     2 3 4 5 S
# Default-Stop:      0 1 6
# Short-Description: Starts iptables
# Description:       Starts iptables, the firewall.
### END INIT INFO

DESC="Iptables Firewall"
NAME=iptables
DAEMON_ARGS=""
SCRIPTNAME=/etc/init.d/iptables

. /lib/lsb/init-functions

#################################################
#
# Script de firewall
#
#################################################

###Variables###
IPTABLES=/sbin/iptables
ILAN=$LANIFACE
IWAN=$WEBIFACE
ILO=lo
LAN=$LANNET
IPWAN=\$(/sbin/ifconfig \$IWAN | grep 'inet ' | tr -s ' ' | tr ' ' : | cut -d: -f4)
    
case "\$1" in
  start)
		log_begin_msg "Starting Iptables Firewall (purge & set rules)"

    ###CONFIG###
    #active le forward
    echo 1 > /proc/sys/net/ipv4/ip_forward

    modprobe ip_nat_ftp
    modprobe ip_conntrack_ftp

    #purge
    \$IPTABLES -t filter -F INPUT
    \$IPTABLES -t filter -F FORWARD
    \$IPTABLES -t filter -F OUTPUT

    \$IPTABLES -t nat -F PREROUTING
    \$IPTABLES -t nat -F OUTPUT
    \$IPTABLES -t nat -F POSTROUTING

    #par defaut
    \$IPTABLES -t filter -P INPUT DROP
    \$IPTABLES -t filter -P FORWARD DROP
    \$IPTABLES -t filter -P OUTPUT DROP
    \$IPTABLES -t nat -P PREROUTING ACCEPT
    \$IPTABLES -t nat -P OUTPUT ACCEPT
    \$IPTABLES -t nat -P POSTROUTING ACCEPT

    #"partage de connexion"
    \$IPTABLES -t nat -A POSTROUTING -s \$LAN -o \$IWAN -j MASQUERADE

    ###TUNING###
    # Active la protection broadcast echo
    echo 1 > /proc/sys/net/ipv4/icmp_echo_ignore_broadcasts

    # Active la protection TCP syn cookie
    echo 1 > /proc/sys/net/ipv4/tcp_syncookies

    # Enregistre les paquets avec des adresses impossibles
    # (cela inclut les paquets usurpés (spoofed), les paquets routés
    # source, les paquets redirigés), mais faites attention à ceci
    # sur les serveurs web très chargés
    echo 1 >/proc/sys/net/ipv4/conf/all/log_martians

    #Active la protection sur les mauvais messages d'erreur
    echo 1 > /proc/sys/net/ipv4/icmp_ignore_bogus_error_responses

    # Maintenant la protection ip spoofing
    echo 1 > /proc/sys/net/ipv4/conf/all/rp_filter

    # Désactive l'acceptation Redirect ICMP
    echo 0 > /proc/sys/net/ipv4/conf/all/accept_redirects
    echo 0 > /proc/sys/net/ipv4/conf/all/send_redirects

    # Désactive Source Routed
    echo 0 > /proc/sys/net/ipv4/conf/all/accept_source_route

    ###REGLES###
    #autorise les réponses
    \$IPTABLES -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
    \$IPTABLES -A FORWARD -m state --state ESTABLISHED,RELATED -j ACCEPT
    \$IPTABLES -A OUTPUT -m state --state ESTABLISHED,RELATED -j ACCEPT

    #autorise tout le loopback
    \$IPTABLES -A INPUT -i \$ILO -j ACCEPT
    \$IPTABLES -A OUTPUT -o \$ILO -j ACCEPT

    #autorise le trafic sortant du routeur
    \$IPTABLES -A OUTPUT -j ACCEPT
    \$IPTABLES -t nat -A OUTPUT -j ACCEPT

    #autorise le traffic du LAN vers le routeur
    \$IPTABLES -A INPUT -m state --state NEW -i \$ILAN -j ACCEPT
    \$IPTABLES -A OUTPUT -m state --state NEW -o \$ILAN -j ACCEPT

    #autorise le forward du LAN vers l'extérieur
    \$IPTABLES -A FORWARD -m state --state NEW -i \$ILAN -o \$IWAN -j ACCEPT

    #autorise le forward du LAN vers le LAN
    \$IPTABLES -A FORWARD -m state --state NEW -i \$ILAN -o \$ILAN -j ACCEPT

    # normal transparent proxy for HTTP
    \$IPTABLES -t nat -A PREROUTING -p tcp -i \$ILAN --dport 80 -j REDIRECT --to-port 3127
    \$IPTABLES -t nat -A OUTPUT -p tcp --dport 80 -m owner --uid-owner proxy -j ACCEPT
    \$IPTABLES -t nat -A OUTPUT -p tcp --dport 80 -j REDIRECT --to-ports 3127
	# normal transparent proxy for FTP
    \$IPTABLES -t nat -A PREROUTING -p tcp -i \$ILAN --dport 21 -j REDIRECT --to-port 3127
    \$IPTABLES -t nat -A OUTPUT -p tcp --dport 21 -m owner --uid-owner proxy -j ACCEPT
    \$IPTABLES -t nat -A OUTPUT -p tcp --dport 21 -j REDIRECT --to-ports 3127

    # allow ping
    \$IPTABLES -A INPUT -p icmp --icmp-type echo-request -j ACCEPT
    \$IPTABLES -A OUTPUT -p icmp --icmp-type echo-reply -j ACCEPT

    ###bindings####
    #autorise l'extérieur vers différents services internes à la passerelle
    #ssh
    \$IPTABLES -A INPUT -m state --state NEW -i \$IWAN -p Tcp --dport 22 -j ACCEPT

    ###NAT####
    #autorise l'extérieur vers différents services internes au LAN

    #IP=
    #PORT=
    #\$IPTABLES -A FORWARD -d \$IP -p tcp --dport \$PORT -j ACCEPT
    #\$IPTABLES -t nat -A PREROUTING -d \$IPWAN -p tcp --dport \$PORT -j DNAT --to-destination \$IP:\$PORT

		log_end_msg 0
		;;
  stop)
		log_begin_msg "Stopping Iptables Firewall (purge & accept all)"
		
		#purge
		\$IPTABLES -t filter -F INPUT
		\$IPTABLES -t filter -F FORWARD
		\$IPTABLES -t filter -F OUTPUT
		
		#accept by default
		\$IPTABLES -t filter -P INPUT ACCEPT
		\$IPTABLES -t filter -P FORWARD ACCEPT
		\$IPTABLES -t filter -P OUTPUT ACCEPT
		
		log_end_msg 0
		;;
  restart)
		\$0 start
		;;
  *)
	echo "Usage : \$0 {start | stop}"
	exit 1
	;;
esac

EOF
chmod +x /etc/init.d/firewall
update-rc.d firewall defaults

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

  dnssec-enable yes;
  dnssec-validation yes;

  auth-nxdomain no;
  listen-on-v6 { any; };
  listen-on { any; };
};
EOF

## setup squid

echo " -- Stop squid"
# stop squid before updating config
/etc/init.d/squid stop

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
http_port 3128
http_port 3127 intercept
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
/etc/init.d/squid start

echo " -- Check squid"
squid -k check

echo " -- Fix permissions"
## make general users part of sudo group
l=$(grep "^UID_MIN" /etc/login.defs)
l1=$(grep "^UID_MAX" /etc/login.defs)
USERS=$(awk -F':' -v "min=${l##UID_MIN}" -v "max=${l1##UID_MAX}" '{ if ( $3 >= min && $3 <= max ) print $1}' /etc/passwd)
for USR in $USERS; do
  usermod -a -G sudo $USR
done

## reboot

reboot
