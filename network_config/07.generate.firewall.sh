#!/usr/bin/env bash
set -eu -o pipefail

############################################################################################
## Load config
############################################################################################

source config.sh

############################################################################################
## Generate Firewall config
############################################################################################

echo "[NETCONF] INFO: Generate firewall rules"

FIREWALL_FOLDER=./gen.firewall/

FIREWALL_FOLDER=$FIREWALL_FOLDER/sbin/
SYSTEMD_LIBRARY=$FIREWALL_FOLDER/lib/systemd/system

mkdir -p $SYSTEMD_LIBRARY $FIREWALL_FOLDER
    
cat > ${FIREWALL_FOLDER}/firewall_router.down.sh << EOF
#!/usr/bin/env bash
set -eu -o pipefail

###
### Disable Routing
###

echo 0 > /proc/sys/net/ipv4/ip_forward

###
### Security Tuning
###

# Keep security tuning if set

###
### NFTable setup
###
NFTABLES="/usr/sbin/nft"
ILAN=$LANIFACE
IWAN=$WEBIFACE
ILO=lo
LAN=$LANNET
IPWAN=\$(ip addr show \$IWAN | grep -Po 'inet \K[\d.]+')

# Suppression de toutes les règles existantes (nettoyage)
\$NFTABLES flush ruleset

# Création des tables et chaînes
\$NFTABLES add table inet filter

# Définition des chaînes
\$NFTABLES add chain inet filter input { type filter hook input priority 0 \; policy drop \; }
\$NFTABLES add chain inet filter forward { type filter hook forward priority 0 \; policy drop \; }
\$NFTABLES add chain inet filter output { type filter hook output priority 0 \; policy drop \; }

# Autorisation du loopback
\$NFTABLES add rule inet filter input iifname "\$ILO" accept
\$NFTABLES add rule inet filter output oifname "\$ILO" accept

# Bloquer les paquets invalides
\$NFTABLES add rule inet filter input ct state invalid drop
\$NFTABLES add rule inet filter output ct state invalid drop
\$NFTABLES add rule inet filter forward ct state invalid drop

# Autoriser les paquets établis ou liés (réponses et connexions déjà ouvertes)
\$NFTABLES add rule inet filter input ct state established,related accept
\$NFTABLES add rule inet filter forward ct state established,related accept
\$NFTABLES add rule inet filter output ct state established,related accept

# Autoriser tout le trafic sortant
\$NFTABLES add rule inet filter output accept

# Autoriser le ping (ICMP)
\$NFTABLES add rule inet filter input ip protocol icmp icmp type echo-request accept
\$NFTABLES add rule inet filter output ip protocol icmp icmp type echo-reply accept

# Autoriser SSH (port 22)
\$NFTABLES add rule inet filter input tcp dport 22 ct state new accept

EOF
cat > ${FIREWALL_FOLDER}/firewall_router.up.sh << EOF
#!/usr/bin/env bash
set -eu -o pipefail

###
### Enable Routing
###

echo 1 > /proc/sys/net/ipv4/ip_forward

set +e
lsmod | grep "nf_nat_ftp" &> /dev/null
RES=\$?
set -e
if [ \$RES != 0 ]; then
  # note: will fail on LXC, need to run this on host
  set +e
  (
    modprobe nf_nat_ftp
    modprobe nf_conntrack_ftp
  ) &> /dev/null
  set -e
  # silently fail to keep main functionalities up
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

###
### NFTable setup
###
NFTABLES="/usr/sbin/nft"
ILAN=$LANIFACE
IWAN=$WEBIFACE
ILO=lo
LAN=$LANNET
IPWAN=\$(ip addr show \$IWAN | grep -Po 'inet \K[\d.]+')

# Suppression de toutes les règles existantes (nettoyage)
\$NFTABLES flush ruleset

# Création des tables et chaînes
\$NFTABLES add table inet filter

# Définition des chaînes
\$NFTABLES add chain inet filter input { type filter hook input priority 0 \; policy drop \; }
\$NFTABLES add chain inet filter forward { type filter hook forward priority 0 \; policy drop \; }
\$NFTABLES add chain inet filter output { type filter hook output priority 0 \; policy drop \; }

# Autorisation du loopback
\$NFTABLES add rule inet filter input iifname "\$ILO" accept
\$NFTABLES add rule inet filter output oifname "\$ILO" accept

# Bloquer les paquets invalides
\$NFTABLES add rule inet filter input ct state invalid drop
\$NFTABLES add rule inet filter output ct state invalid drop
\$NFTABLES add rule inet filter forward ct state invalid drop

# Autoriser les paquets établis ou liés (réponses et connexions déjà ouvertes)
\$NFTABLES add rule inet filter input ct state established,related accept
\$NFTABLES add rule inet filter forward ct state established,related accept
\$NFTABLES add rule inet filter output ct state established,related accept

# Autoriser tout le trafic sortant
\$NFTABLES add rule inet filter output accept

# Autoriser le ping (ICMP)
\$NFTABLES add rule inet filter input ip protocol icmp icmp type echo-request accept
\$NFTABLES add rule inet filter output ip protocol icmp icmp type echo-reply accept

# Autoriser SSH (port 22)
\$NFTABLES add rule inet filter input tcp dport 22 ct state new accept

# Ajout de la table NAT
\$NFTABLES add table inet nat

\$NFTABLES add chain inet nat output { type filter hook output priority -100 \; policy accept \; }
\$NFTABLES add chain inet nat prerouting { type nat hook prerouting priority 0 \; policy accept \; }
\$NFTABLES add chain inet nat postrouting { type nat hook postrouting priority 0 \; policy accept \; }

# Activation du NAT avec filtrage par source
\$NFTABLES add rule inet nat postrouting ip saddr \$LAN oifname "\$IWAN" masquerade

# Autoriser les connexions du LAN vers le routeur
\$NFTABLES add rule inet filter input iifname "\$ILAN" ct state new accept
\$NFTABLES add rule inet filter output oifname "\$ILAN" ct state new accept

# Autoriser les paquets FORWARD du LAN vers le WAN
\$NFTABLES add rule inet filter forward iifname "\$ILAN" oifname "\$IWAN" ct state new accept

# Autoriser les paquets FORWARD du LAN vers le LAN
\$NFTABLES add rule inet filter forward iifname "\$ILAN" oifname "\$ILAN" ct state new accept

EOF

for NAT_RULE in $NAT_LIST; do
  HOST=$(echo $NAT_RULE | cut -d'#' -f1)
  HOST=$(lookup_ip $HOST)

  # echo $HOST
  for portmap in $(echo $NAT_RULE | cut -d'#' -f2- | tr "#" "\n"); do
    PROTO=$(echo $portmap | cut -d'/' -f2)
    case $PROTO in
      u|udp|U|UDP|Udp) PROTO=udp ;;
      *) PROTO=tcp ;;
    esac
    OUTSIDE_RANGE=$(echo $portmap | cut -d':' -f1)
    case $OUTSIDE_RANGE in
      *[0-9]-[0-9]*) : ;;
      *)
        OUTSIDE_RANGE="${OUTSIDE_RANGE}-${OUTSIDE_RANGE}"
        ;;
    esac
    INSIDE_RANGE=$(echo $portmap | cut -d':' -f2 | cut -d'/' -f1)
    case $INSIDE_RANGE in
      "") INSIDE_RANGE=$OUTSIDE_RANGE ;;
      *[0-9]-[0-9]*) : ;;
      *)
        INSIDE_RANGE="${INSIDE_RANGE}-${INSIDE_RANGE}"
        ;;
    esac
    # echo " - $OUTSIDE_RANGE - $INSIDE_RANGE /$PROTO"
    cat >> ${FIREWALL_FOLDER}/firewall_router.up.sh << EOF
HOST="$HOST"
PORT_WAN="$OUTSIDE_RANGE"
PORT_LAN="$INSIDE_RANGE"
PROTO="$PROTO"
nft add rule inet filter forward ip daddr \$HOST \$PROTO dport \$PORT_WAN accept
nft add rule inet nat prerouting ip daddr \$IPWAN \$PROTO dport \$PORT_WAN dnat to \${HOST}:\$PORT_LAN

EOF
  done
done
# # TODO: nat bindings from file
# IP=172.29.255.10
# PORT_WAN=18022
# PORT_LAN=22
# PROTO=tcp

# nft add rule inet filter forward ip daddr $IP $PROTO dport $PORT_WAN accept
# nft add rule inet nat prerouting ip daddr $IPWAN $PROTO dport { $PORT_WAN } dnat to $IP

# nft add rule inet nat prerouting ip daddr $IPWAN $PROTO dport { $PORT_WAN } dnat to $IP

# nft add rule inet nat prerouting iif eth0 tcp dport { 80, 443 } dnat to 192.168.1.120

# nft add rule inet filter forward ip daddr 172.30.255.209 tcp dport 49612 counter accept
# nft add chain inet daddr 172.30.0.179 tcp dport 49612 counter dnat to 172.30.255.209:49612


#                 ip daddr 172.30.255.209 tcp dport 49612 counter accept
#                 ip daddr 172.30.0.179 tcp dport 49612 counter dnat to 172.30.255.209:49612

#                 ip daddr 172.30.255.209 tcp dport 27015-27032 counter accept
#                 ip daddr 172.30.255.209 udp dport 27015-27032 counter accept

#                 ip daddr 172.30.0.179 tcp dport 49612 counter dnat to 172.30.255.209
#                 ip daddr 172.30.0.179 tcp dport 49612 counter dnat to 172.30.255.209




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

############################################################################################
## Exit
############################################################################################
echo "[NETCONF] INFO: Generate firewall Done."
exit 0
