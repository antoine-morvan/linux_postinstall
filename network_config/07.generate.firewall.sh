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

PREFIX=./gen.firewall/

FIREWALL_FOLDER=$PREFIX/sbin/
SYSTEMD_LIBRARY=$PREFIX/lib/systemd/system

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
\$NFTABLES add table ip nat

# Définition des chaînes
\$NFTABLES add chain inet filter input { type filter hook input priority 0 \; policy drop \; }
\$NFTABLES add chain inet filter forward { type filter hook forward priority 0 \; policy drop \; }
\$NFTABLES add chain inet filter output { type filter hook output priority 0 \; policy drop \; }

\$NFTABLES add chain ip nat postrouting { type nat hook postrouting priority 100 \; policy drop \; }

# Activation du NAT avec filtrage par source
\$NFTABLES add rule ip nat postrouting ip saddr \$LAN oifname "\$IWAN" masquerade

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
\$NFTABLES add rule ip nat output accept

# Autoriser les connexions du LAN vers le routeur
\$NFTABLES add rule inet filter input iifname "\$ILAN" ct state new accept
\$NFTABLES add rule inet filter output oifname "\$ILAN" ct state new accept

# Autoriser les paquets FORWARD du LAN vers le WAN
\$NFTABLES add rule inet filter forward iifname "\$ILAN" oifname "\$IWAN" ct state new accept

# Autoriser les paquets FORWARD du LAN vers le LAN
\$NFTABLES add rule inet filter forward iifname "\$ILAN" oifname "\$ILAN" ct state new accept

# Autoriser le ping (ICMP)
\$NFTABLES add rule inet filter input ip protocol icmp icmp type echo-request accept
\$NFTABLES add rule inet filter output ip protocol icmp icmp type echo-reply accept

# Autoriser SSH (port 22) depuis le WAN
\$NFTABLES add rule inet filter input iifname "\$IWAN" tcp dport 22 ct state new accept

EOF
# TODO: nat bindings from file

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

# if [ "$GEN_CONFIG" != "YES" ]; then
#   chmod +x /usr/sbin/firewall_router.down.sh
#   chmod +x /usr/sbin/firewall_router.up.sh

#   systemctl enable firewall_router
# fi

############################################################################################
## Exit
############################################################################################
echo "[NETCONF] INFO: Generate firewall Done."
exit 0
