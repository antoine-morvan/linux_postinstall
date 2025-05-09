#!/usr/bin/env bash
set -eu -o pipefail

############################################################################################
## Load config
############################################################################################

source config.sh

############################################################################################
## Generate Firewall config
############################################################################################

echo "[NETCONF] INFO    :: Generate firewall rules"

FIREWALL_FOLDER=./gen.firewall

SYSTEMD_LIBRARY=$FIREWALL_FOLDER/service
FIREWALL_FOLDER=$FIREWALL_FOLDER/scripts

mkdir -p ${SYSTEMD_LIBRARY} ${FIREWALL_FOLDER}

############################################################################################
## Down
############################################################################################
## disable all NAT rules
## only accept 22/tcp on host

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
# IPWAN=\$(ip addr show \$IWAN | grep -Po 'inet \K[\d.]+')
IPWAN=\$(ip -4 addr show \$IWAN | awk '/inet / {print \$2}' | cut -d'/' -f1)

# Suppression de toutes les règles existantes (nettoyage)
\$NFTABLES flush ruleset

# Création des tables et chaînes
\$NFTABLES add table inet filter

# Définition des chaînes
\$NFTABLES add chain inet filter input { type filter hook input priority 0 \; policy drop \; }
\$NFTABLES add chain inet filter forward { type filter hook forward priority 0 \; policy drop \; }
\$NFTABLES add chain inet filter output { type filter hook output priority 0 \; policy drop \; }

# Autorisation du loopback
\$NFTABLES add rule inet filter input iif "\$ILO" accept
\$NFTABLES add rule inet filter output oif "\$ILO" accept

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

############################################################################################
## Up
############################################################################################
## 1. Apply default rules
## 2. Accept Host ports from $HOST_OPEN_PORTS if declared
## 3. Apply NAT rules as defined in config.nat.list if present
## 4. Redirect everything to $DMZ_HOSTNAME if declared
## Note: port 22/tcp will be dropped if not in the above rules.

## 1. Apply default rules
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
# IPWAN=\$(ip addr show \$IWAN | grep -Po 'inet \K[\d.]+')
IPWAN=\$(ip -4 addr show \$IWAN | awk '/inet / {print \$2}' | cut -d'/' -f1)

# Suppression de toutes les règles existantes (nettoyage)
\$NFTABLES flush ruleset

# Création des tables et chaînes
\$NFTABLES add table inet filter

# Définition des chaînes
\$NFTABLES add chain inet filter input { type filter hook input priority 0 \; policy drop \; }
\$NFTABLES add chain inet filter forward { type filter hook forward priority 0 \; policy drop \; }
\$NFTABLES add chain inet filter output { type filter hook output priority 0 \; policy drop \; }

# Autorisation du loopback
\$NFTABLES add rule inet filter input iif "\$ILO" accept
\$NFTABLES add rule inet filter output oif "\$ILO" accept

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

# Ajout de la table NAT
\$NFTABLES add table inet nat

\$NFTABLES add chain inet nat output { type filter hook output priority -100 \; policy accept \; }
\$NFTABLES add chain inet nat prerouting { type nat hook prerouting priority -100 \; policy accept \; }
\$NFTABLES add chain inet nat postrouting { type nat hook postrouting priority -100 \; policy accept \; }

# Activation du NAT avec filtrage par source
\$NFTABLES add rule inet nat postrouting ip saddr \$LAN oif "\$IWAN" masquerade

# Autoriser les connexions du LAN vers le routeur
\$NFTABLES add rule inet filter input iif "\$ILAN" ct state new accept
\$NFTABLES add rule inet filter output oif "\$ILAN" ct state new accept

# Autoriser les paquets FORWARD du LAN vers le WAN
\$NFTABLES add rule inet filter forward iif "\$ILAN" oif "\$IWAN" ct state new accept

# Autoriser les paquets FORWARD du LAN vers le LAN
\$NFTABLES add rule inet filter forward iif "\$ILAN" oif "\$ILAN" ct state new accept

EOF

## 2. Accept Host ports from $HOST_OPEN_PORTS if declared
if [ "${HOST_OPEN_PORTS:-}" != "" ]; then
  echo "# 2. \${HOST_OPEN_PORTS} = '${HOST_OPEN_PORTS}'" >> ${FIREWALL_FOLDER}/firewall_router.up.sh
  for portmap in ${HOST_OPEN_PORTS:-}; do
    PROTO=$(echo $portmap | cut -d'/' -f2)
    case $PROTO in
      u|udp|U|UDP|Udp) PROTO=udp ;;
      *) PROTO=tcp ;;
    esac
    OUTSIDE_RANGE=$(echo $portmap | cut -d':' -f1 | cut -d'/' -f1)
    case $OUTSIDE_RANGE in
      *[0-9]-[0-9]*) : ;;
      *)
        OUTSIDE_RANGE="${OUTSIDE_RANGE}-${OUTSIDE_RANGE}"
        ;;
    esac
    cat >> ${FIREWALL_FOLDER}/firewall_router.up.sh << EOF
PORT_WAN="$OUTSIDE_RANGE"
PROTO="$PROTO"
\$NFTABLES add rule inet filter input iif \$IWAN \$PROTO dport \$PORT_WAN ct state new accept
\$NFTABLES add rule inet nat prerouting ip daddr \$IPWAN \$PROTO dport \$PORT_WAN return

EOF
  done
else
  echo "# 2. no \${HOST_OPEN_PORTS} declared." >> ${FIREWALL_FOLDER}/firewall_router.up.sh
fi

## 3. Apply NAT rules as defined in config.nat.list if present
if [ "${NAT_LIST:-}" != "" ]; then
  echo "# 3. \${NAT_LIST} declared" >> ${FIREWALL_FOLDER}/firewall_router.up.sh
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
      OUTSIDE_RANGE=$(echo $portmap | cut -d':' -f1 | cut -d'/' -f1)
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
\$NFTABLES add rule inet filter forward ip daddr \$HOST \$PROTO dport \$PORT_LAN accept
\$NFTABLES add rule inet nat prerouting ip daddr \$IPWAN \$PROTO dport \$PORT_WAN dnat to \${HOST}:\$PORT_LAN

EOF
    done
  done
else
  echo "# 3. no \${NAT_LIST} declared." >> ${FIREWALL_FOLDER}/firewall_router.up.sh
fi

## 4. Redirect everything to $DMZ_HOSTNAME if declared

if [ "${DMZ_HOSTNAME:-}" != "" ]; then
  echo "" >> ${FIREWALL_FOLDER}/firewall_router.up.sh
  HOST=$(lookup_ip $DMZ_HOSTNAME)
  cat >> ${FIREWALL_FOLDER}/firewall_router.up.sh << EOF
# 4. \${DMZ_HOSTNAME} = '${DMZ_HOSTNAME}'
HOST="$HOST"
\$NFTABLES add rule inet filter forward ip daddr \${HOST} accept
\$NFTABLES add rule inet nat prerouting ip daddr \${IPWAN} dnat to \${HOST}

EOF
else
  echo "# 4. no \${DMZ_HOSTNAME} declared." >> ${FIREWALL_FOLDER}/firewall_router.up.sh
fi

############################################################################################
## Generate service file
############################################################################################
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
echo "[NETCONF] INFO    :: Generate firewall Done."
exit 0
