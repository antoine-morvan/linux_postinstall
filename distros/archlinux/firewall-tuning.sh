#! /bin/bash
###TUNING###
# Active la protection broadcast echo
echo 1 > /proc/sys/net/ipv4/icmp_echo_ignore_broadcasts

# Active la protection TCP syn cookie
echo 1 > /proc/sys/net/ipv4/tcp_syncookies

# Enregistre les paquets avec des adresses impossibles
# (cela inclut les paquets usurp�s (spoofed), les paquets rout�s
# source, les paquets redirig�s), mais faites attention � ceci
# sur les serveurs web tr�s charg�s
echo 1 >/proc/sys/net/ipv4/conf/all/log_martians

#Active la protection sur les mauvais messages d'erreur
echo 1 > /proc/sys/net/ipv4/icmp_ignore_bogus_error_responses

# Maintenant la protection ip spoofing
echo 1 > /proc/sys/net/ipv4/conf/all/rp_filter

# D�sactive l'acceptation Redirect ICMP
echo 0 > /proc/sys/net/ipv4/conf/all/accept_redirects
echo 0 > /proc/sys/net/ipv4/conf/all/send_redirects

# D�sactive Source Routed
echo 0 > /proc/sys/net/ipv4/conf/all/accept_source_route
