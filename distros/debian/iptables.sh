#! /bin/sh

### BEGIN INIT INFO
# Provides:          iptables
# Required-Start:    
# Required-Stop:     
# Default-Start:     2 3 4 5
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
ILO=lo

case "$1" in
  start)
		log_begin_msg "Starting Iptables Firewall (purge & set rules)"
		###CONFIG###
		#purge
		$IPTABLES -t filter -F INPUT
		$IPTABLES -t filter -F FORWARD
		$IPTABLES -t filter -F OUTPUT

		#par defaut
		$IPTABLES -t filter -P INPUT DROP
		$IPTABLES -t filter -P FORWARD DROP
		$IPTABLES -t filter -P OUTPUT DROP

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
		#autorise le trafic sortant du routeur
		$IPTABLES -A OUTPUT -j ACCEPT
		$IPTABLES -t nat -A OUTPUT -j ACCEPT

		#autorise les réponses
		$IPTABLES -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
		$IPTABLES -A FORWARD -m state --state ESTABLISHED,RELATED -j ACCEPT
		$IPTABLES -A OUTPUT -m state --state ESTABLISHED,RELATED -j ACCEPT

		#autorise tout le loopback
		$IPTABLES -A INPUT -i $ILO -j ACCEPT
		$IPTABLES -A OUTPUT -o $ILO -j ACCEPT
		
		#autorise tout avec les VMs en réseau interne
		#$IPTABLES -A INPUT -i vboxnet0 -j ACCEPT
		#$IPTABLES -A OUTPUT -o vboxnet0 -j ACCEPT

		###bindings####
		#autorise l'extérieur vers différents services internes
		#ssh
		$IPTABLES -A INPUT -m state --state NEW -p Tcp --dport 22 -j ACCEPT
		#web
		#$IPTABLES -A INPUT -m state --state NEW -p Tcp --dport 80 -j ACCEPT
		#web ssl
		#$IPTABLES -A INPUT -m state --state NEW -p Tcp --dport 443 -j ACCEPT

		#autoriser samba
		#$IPTABLES -A INPUT -m state --state NEW -p tcp --dport 137 -j ACCEPT
		#$IPTABLES -A INPUT -m state --state NEW -p tcp --dport 138 -j ACCEPT
		#$IPTABLES -A INPUT -m state --state NEW -p tcp --dport 139 -j ACCEPT
		#$IPTABLES -A INPUT -m state --state NEW -p tcp --dport 445 -j ACCEPT
		
		log_end_msg 0
		;;
  stop)
		log_begin_msg "Stopping Iptables Firewall (purge & accept all)"
		
		#purge
		$IPTABLES -t filter -F INPUT
		$IPTABLES -t filter -F FORWARD
		$IPTABLES -t filter -F OUTPUT
		
		#accept by default
		$IPTABLES -t filter -P INPUT ACCEPT
		$IPTABLES -t filter -P FORWARD ACCEPT
		$IPTABLES -t filter -P OUTPUT ACCEPT
		
		log_end_msg 0
		;;
  restart)
		$0 start
		;;
  *)
	echo "Usage : $0 {start | stop}"
	exit 1
	;;
esac


