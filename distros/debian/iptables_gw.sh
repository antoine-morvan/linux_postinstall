###Variables###
IPTABLES=/sbin/iptables
ILAN=eth1
IWAN=eth0
ILO=lo
LAN=172.30.255.128/25
IPWAN=$(/sbin/ifconfig $IWAN | grep 'inet ' | tr -s ' ' | tr ' ' : | cut -d: -f4)

###CONFIG###
#active le forward
echo 1 > /proc/sys/net/ipv4/ip_forward

modprobe ip_nat_ftp
modprobe ip_conntrack_ftp

#purge
$IPTABLES -t filter -F INPUT
$IPTABLES -t filter -F FORWARD
$IPTABLES -t filter -F OUTPUT

$IPTABLES -t nat -F PREROUTING
$IPTABLES -t nat -F OUTPUT
$IPTABLES -t nat -F POSTROUTING

#par defaut
$IPTABLES -t filter -P INPUT DROP
$IPTABLES -t filter -P FORWARD DROP
$IPTABLES -t filter -P OUTPUT DROP
$IPTABLES -t nat -P PREROUTING ACCEPT
$IPTABLES -t nat -P OUTPUT ACCEPT
$IPTABLES -t nat -P POSTROUTING ACCEPT

#"partage de connexion"
$IPTABLES -t nat -A POSTROUTING -s $LAN -o $IWAN -j MASQUERADE

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
$IPTABLES -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
$IPTABLES -A FORWARD -m state --state ESTABLISHED,RELATED -j ACCEPT
$IPTABLES -A OUTPUT -m state --state ESTABLISHED,RELATED -j ACCEPT

#autorise tout le loopback
$IPTABLES -A INPUT -i $ILO -j ACCEPT
$IPTABLES -A OUTPUT -o $ILO -j ACCEPT

#autorise le trafic sortant du routeur
$IPTABLES -A OUTPUT -j ACCEPT
$IPTABLES -t nat -A OUTPUT -j ACCEPT

#autorise le traffic du LAN vers le routeur
$IPTABLES -A INPUT -m state --state NEW -i $ILAN -j ACCEPT
$IPTABLES -A OUTPUT -m state --state NEW -o $ILAN -j ACCEPT

#autorise le forward du LAN vers l'extérieur
$IPTABLES -A FORWARD -m state --state NEW -i $ILAN -o $IWAN -j ACCEPT

#autorise le forward du LAN vers le LAN
$IPTABLES -A FORWARD -m state --state NEW -i $ILAN -o $ILAN -j ACCEPT

# normal transparent proxy
#$IPTABLES -t nat -A PREROUTING -p tcp -i $ILAN --dport 80 -j REDIRECT --to-port 3127
#$IPTABLES -t nat -A OUTPUT -p tcp --dport 80 -m owner --uid-owner proxy -j ACCEPT
#$IPTABLES -t nat -A OUTPUT -p tcp --dport 80 -j REDIRECT --to-ports 3127

# allow ping
$IPTABLES -A INPUT -p icmp --icmp-type echo-request -j ACCEPT
$IPTABLES -A OUTPUT -p icmp --icmp-type echo-reply -j ACCEPT

###bindings####
#autorise l'extérieur vers différents services internes à la passerelle
#ssh
$IPTABLES -A INPUT -m state --state NEW -i $IWAN -p Tcp --dport 22 -j ACCEPT

###NAT####
#autorise l'extérieur vers différents services internes au LAN

#IP=172.30.255.140
#PORT=20545
#$IPTABLES -A FORWARD -d $IP -p tcp --dport $PORT -j ACCEPT
#$IPTABLES -t nat -A PREROUTING -d $IPWAN -p tcp --dport $PORT -j DNAT --to-destination $IP:$PORT
